import AppKit

@MainActor
struct HoldDropImporter {
  let addFiles: @MainActor ([URL]) -> Void
  let addText: @MainActor (String) -> Void
  let addScreenshots: @MainActor ([URL]) -> Void
  var promisedFileDestination: @MainActor () -> URL = Self.defaultPromisedFileDestination

  func importDrop(from pasteboard: NSPasteboard) -> Bool {
    switch HoldDropPayloadDetector.importRoute(in: pasteboard) {
    case .filePromise:
      return receiveFilePromises(from: pasteboard)
    case .fileURL:
      return importFileURLs(from: pasteboard)
    case .webURL:
      return importWebURLs(from: pasteboard)
    case .imageData:
      return importImageData(from: pasteboard)
    case .text:
      return importText(from: pasteboard)
    case nil:
      return false
    }
  }

  private func receiveFilePromises(from pasteboard: NSPasteboard) -> Bool {
    guard let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
          !receivers.isEmpty else {
      return false
    }

    let destination = promisedFileDestination()
    try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let addScreenshots = addScreenshots

    receivers.forEach { receiver in
      receiver.receivePromisedFiles(
        atDestination: destination,
        options: [:],
        operationQueue: .main
      ) { fileURL, error in
        guard error == nil else {
          return
        }

        Task { @MainActor in
          addScreenshots([fileURL])
        }
      }
    }

    return true
  }

  private func importFileURLs(from pasteboard: NSPasteboard) -> Bool {
    let urls = HoldDropPayloadDetector.fileURLs(in: pasteboard)
    guard !urls.isEmpty else {
      return false
    }

    addFiles(urls)
    return true
  }

  private func importWebURLs(from pasteboard: NSPasteboard) -> Bool {
    let webURLs = HoldDropPayloadDetector.webURLs(in: pasteboard)
    guard !webURLs.isEmpty else {
      return false
    }

    webURLs.forEach { addText($0.absoluteString) }
    return true
  }

  private func importText(from pasteboard: NSPasteboard) -> Bool {
    guard let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }

    addText(text)
    return true
  }

  private func importImageData(from pasteboard: NSPasteboard) -> Bool {
    guard let data = HoldImageDataReader.pngData(from: pasteboard) else {
      return false
    }

    let destination = promisedFileDestination()
      .appendingPathComponent("Dropped Screenshot \(Self.dropTimestamp.string(from: Date())).png")
    do {
      try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: destination, options: .atomic)
      addScreenshots([destination])
      return true
    } catch {
      return false
    }
  }

  private static func defaultPromisedFileDestination() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("Flowline", isDirectory: true)
      .appendingPathComponent("HoldDrops", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
  }

  private static let dropTimestamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
    return formatter
  }()
}
