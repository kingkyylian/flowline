import Combine
import FlowlineCore
import Foundation

@MainActor
final class AIUsageService: ObservableObject {
  @Published private(set) var snapshot: AIUsageSnapshot?

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

    guard FileManager.default.fileExists(atPath: databaseURL.path) else {
      return nil
    }

    let providers = [
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

    guard !providers.isEmpty else {
      return nil
    }

    return AIUsageSnapshot(providers: providers, updatedAt: Date())
  }

  nonisolated private static func readProvider(
    from databaseURL: URL,
    matching requestKeyPattern: String,
    parse: (Data) throws -> AIProviderUsage
  ) -> AIProviderUsage? {
    let query = """
      select d.receiver_data
      from cfurl_cache_response r
      join cfurl_cache_receiver_data d using(entry_ID)
      where r.request_key like '%\(requestKeyPattern)%'
      order by r.time_stamp desc
      limit 1;
      """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [databaseURL.path, query]

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

    let data = output.fileHandleForReading.readDataToEndOfFile()
    return try? parse(data)
  }
}
