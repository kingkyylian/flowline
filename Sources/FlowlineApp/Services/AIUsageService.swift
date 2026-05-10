import Combine
import FlowlineCore
import Foundation

@MainActor
final class AIUsageService: ObservableObject {
  @Published private(set) var snapshot: AIUsageSnapshot?

  nonisolated private static let cacheFreshnessInterval: TimeInterval = 15 * 60
  private var timer: Timer?

  func start() {
    refresh()

    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  func refreshNow() {
    refresh()
  }

  private func refresh() {
    Task.detached {
      let snapshot = Self.readSnapshot()

      await MainActor.run {
        self.snapshot = snapshot
      }
    }
  }

  nonisolated private static func readSnapshot() -> AIUsageSnapshot? {
    let databaseURL = FileManager.default
      .homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Caches/com.steipete.codexbar/Cache.db")

    let cacheProviders: [TimedProviderUsage]
    if FileManager.default.fileExists(atPath: databaseURL.path) {
      cacheProviders = [
        readProvider(
          from: databaseURL,
          matching: "chatgpt.com/backend-api/wham/usage",
          parse: CodexUsageParser.parseProvider
        ),
        readProvider(
          from: databaseURL,
          matching: "api.anthropic.com/api/oauth/usage",
          parse: ClaudeUsageParser.parse
        ),
        readProvider(
          from: databaseURL,
          matching: "cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota",
          parse: GeminiUsageParser.parse
        )
      ].compactMap { $0 }
    } else {
      cacheProviders = []
    }

    var providers = cacheProviders

    if let codexUsage = readCodexProviderFromSessionLogs() {
      providers.removeAll { $0.usage.provider == .codex }
      providers.append(codexUsage)
    }

    guard !providers.isEmpty else {
      return nil
    }

    return AIUsageSnapshot(
      providers: providers.map(\.usage),
      updatedAt: providers.map(\.recordedAt).max() ?? Date()
    )
  }

  nonisolated private static func readProvider(
    from databaseURL: URL,
    matching requestKeyPattern: String,
    parse: (Data) throws -> AIProviderUsage
  ) -> TimedProviderUsage? {
    let query = """
      select r.time_stamp as timeStamp, d.receiver_data as data
      from cfurl_cache_response r
      join cfurl_cache_receiver_data d using(entry_ID)
      where r.request_key like '%\(requestKeyPattern)%'
      order by r.time_stamp desc
      limit 1;
      """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = ["-json", databaseURL.path, query]

    let output = Pipe()
    process.standardOutput = output
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return nil
    }

    guard process.terminationStatus == 0 else {
      return nil
    }

    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    guard
      let row = try? JSONDecoder().decode([CacheRow].self, from: outputData).first,
      let recordedAt = cacheDate(from: row.timeStamp),
      abs(Date().timeIntervalSince(recordedAt)) <= cacheFreshnessInterval,
      let data = row.data.data(using: .utf8),
      let usage = try? parse(data)
    else {
      return nil
    }

    return TimedProviderUsage(usage: usage, recordedAt: recordedAt)
  }

  nonisolated private static func readCodexProviderFromSessionLogs() -> TimedProviderUsage? {
    let sessionsURL = FileManager.default
      .homeDirectoryForCurrentUser
      .appendingPathComponent(".codex/sessions")

    guard let enumerator = FileManager.default.enumerator(
      at: sessionsURL,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return nil
    }

    var files: [(url: URL, modifiedAt: Date)] = []
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
      let modifiedAt = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      files.append((fileURL, modifiedAt))
    }

    for file in files.sorted(by: { $0.modifiedAt > $1.modifiedAt }) {
      if let usage = readLatestCodexProvider(from: file.url) {
        return usage
      }
    }

    return nil
  }

  nonisolated private static func readLatestCodexProvider(from fileURL: URL) -> TimedProviderUsage? {
    guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
      return nil
    }

    for line in contents.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
      guard
        let data = String(line).data(using: .utf8),
        let recordedAt = sessionEventDate(from: data),
        let usage = try? CodexUsageParser.parseSessionEventProvider(data)
      else {
        continue
      }

      return TimedProviderUsage(usage: usage, recordedAt: recordedAt)
    }

    return nil
  }

  nonisolated private static func cacheDate(from value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: value)
  }

  nonisolated private static func sessionEventDate(from data: Data) -> Date? {
    guard
      let event = try? JSONDecoder().decode(SessionTimestamp.self, from: data),
      let timestamp = event.timestamp
    else {
      return nil
    }

    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let plainFormatter = ISO8601DateFormatter()
    plainFormatter.formatOptions = [.withInternetDateTime]

    return fractionalFormatter.date(from: timestamp) ?? plainFormatter.date(from: timestamp)
  }

  private struct TimedProviderUsage {
    var usage: AIProviderUsage
    var recordedAt: Date
  }

  private struct CacheRow: Decodable {
    var timeStamp: String
    var data: String
  }

  private struct SessionTimestamp: Decodable {
    var timestamp: String?
  }
}
