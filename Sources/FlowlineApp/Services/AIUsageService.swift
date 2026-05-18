import Combine
import FlowlineCore
import Foundation

@MainActor
final class AIUsageService: ObservableObject {
  @Published private(set) var snapshot: AIUsageSnapshot?

  private let homeDirectory: URL
  private let environment: [String: String]
  private let http: any AIUsageHTTPClient
  private var timer: Timer?

  init(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    http: any AIUsageHTTPClient = URLSessionAIUsageHTTPClient()
  ) {
    self.homeDirectory = homeDirectory
    self.environment = environment
    self.http = http
  }

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
    let homeDirectory = homeDirectory
    let environment = environment
    let http = http

    Task {
      let snapshot = await Self.readSnapshot(
        homeDirectory: homeDirectory,
        environment: environment,
        http: http
      )

      self.snapshot = snapshot
    }
  }

  nonisolated private static func readSnapshot(
    homeDirectory: URL,
    environment: [String: String],
    http: any AIUsageHTTPClient
  ) async -> AIUsageSnapshot? {
    var providers = await AIUsageDirectReader(
      homeDirectory: homeDirectory,
      environment: environment,
      http: http
    ).readProviders()

    if let codexUsage = readCodexProviderFromSessionLogs(homeDirectory: homeDirectory) {
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

  nonisolated private static func readCodexProviderFromSessionLogs(homeDirectory: URL) -> TimedProviderUsage? {
    let sessionsURL = homeDirectory.appendingPathComponent(".codex/sessions")

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

  private struct SessionTimestamp: Decodable {
    var timestamp: String?
  }
}
