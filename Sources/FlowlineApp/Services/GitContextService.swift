import AppKit
import FlowlineCore
import Foundation

final class GitContextService {
  private struct CachedStatus {
    var context: ActiveAppContext
    var directory: URL?
    var status: GitStatus?
    var timestamp: Date
  }

  private let cacheInterval: TimeInterval = 5
  private var cachedStatus: CachedStatus?

  func statusForFrontmostContext(_ context: ActiveAppContext) -> GitStatus? {
    let now = Date()
    if let cachedStatus,
       cachedStatus.context == context,
       now.timeIntervalSince(cachedStatus.timestamp) < cacheInterval {
      return cachedStatus.status
    }

    guard let directory = likelyWorkingDirectory(for: context) else {
      cachedStatus = CachedStatus(context: context, directory: nil, status: nil, timestamp: now)
      return nil
    }

    if let cachedStatus,
       cachedStatus.directory == directory,
       now.timeIntervalSince(cachedStatus.timestamp) < cacheInterval {
      return cachedStatus.status
    }

    let status = status(in: directory)
    cachedStatus = CachedStatus(context: context, directory: directory, status: status, timestamp: now)
    return status
  }

  private func status(in directory: URL) -> GitStatus? {
    guard runGit(["rev-parse", "--is-inside-work-tree"], in: directory)?
      .trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
      return nil
    }

    let branch = runGit(["branch", "--show-current"], in: directory) ?? ""
    let porcelain = runGit(["status", "--porcelain"], in: directory) ?? ""

    return GitStatusParser.parse(branchOutput: branch, porcelainOutput: porcelain)
  }

  private func likelyWorkingDirectory(for context: ActiveAppContext) -> URL? {
    if let title = context.windowTitle {
      let components = title.components(separatedBy: CharacterSet(charactersIn: "—-"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

      for component in components.reversed() where !component.isEmpty {
        let candidate = URL(fileURLWithPath: NSString(string: component).expandingTildeInPath)
        if FileManager.default.fileExists(atPath: candidate.path) {
          return candidate
        }
      }
    }

    return nil
  }

  private func runGit(_ arguments: [String], in directory: URL) -> String? {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = directory
    process.standardOutput = pipe
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

    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
  }
}
