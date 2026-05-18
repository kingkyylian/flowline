import Foundation

public struct ScreenshotFileScanner: Sendable {
  public private(set) var lastScanDate: Date
  private let scanGrace: TimeInterval
  private var seenPaths: Set<String>

  public init(startedAt: Date = Date(), scanGrace: TimeInterval = 2) {
    self.lastScanDate = startedAt
    self.scanGrace = scanGrace
    self.seenPaths = []
  }

  public mutating func seedSeenFiles(
    in directories: [URL],
    fileManager: FileManager = .default
  ) {
    uniqueDirectories(from: directories)
      .flatMap { directory in
        screenshotFiles(
          in: directory,
          modifiedAfter: .distantPast,
          fileManager: fileManager,
          includeUnseenBeforeCutoff: true
        )
      }
      .forEach { url in
        seenPaths.insert(url.standardizedFileURL.path)
      }
  }

  public mutating func scan(
    in directories: [URL],
    now: Date = Date(),
    fileManager: FileManager = .default,
    includeUnseenBeforeCutoff: Bool = false
  ) -> [URL] {
    let cutoff = lastScanDate.addingTimeInterval(-scanGrace)
    defer { lastScanDate = now }

    let urls = uniqueDirectories(from: directories).flatMap { directory in
      screenshotFiles(
        in: directory,
        modifiedAfter: cutoff,
        fileManager: fileManager,
        includeUnseenBeforeCutoff: includeUnseenBeforeCutoff
      )
    }
    .sorted { lhs, rhs in
      fileDiscoveryDate(for: lhs, fileManager: fileManager) < fileDiscoveryDate(for: rhs, fileManager: fileManager)
    }

    return urls.filter { url in
      let path = url.standardizedFileURL.path
      guard !seenPaths.contains(path) else {
        return false
      }

      seenPaths.insert(path)
      return true
    }
  }

  private func uniqueDirectories(from directories: [URL]) -> [URL] {
    Array(Set(directories.map { $0.standardizedFileURL }))
  }

  private func screenshotFiles(
    in directory: URL,
    modifiedAfter cutoff: Date,
    fileManager: FileManager,
    includeUnseenBeforeCutoff: Bool
  ) -> [URL] {
    guard let urls = try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return urls.filter { url in
      guard ShelfStore.isScreenshotFile(url),
            isRegularFile(url, fileManager: fileManager) else {
        return false
      }

      return includeUnseenBeforeCutoff || fileDiscoveryDate(for: url, fileManager: fileManager) >= cutoff
    }
  }

  private func isRegularFile(_ url: URL, fileManager: FileManager) -> Bool {
    let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
    return values?.isRegularFile == true || fileManager.fileExists(atPath: url.path)
  }

  private func fileDiscoveryDate(for url: URL, fileManager: FileManager) -> Date {
    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
    let resourceDate = [
      values?.contentModificationDate,
      values?.creationDate
    ]
    .compactMap { $0 }
    .max()

    if let resourceDate {
      return resourceDate
    }

    let attributes = try? fileManager.attributesOfItem(atPath: url.path)
    return [
      attributes?[.modificationDate] as? Date,
      attributes?[.creationDate] as? Date
    ]
    .compactMap { $0 }
    .max() ?? .distantPast
  }
}
