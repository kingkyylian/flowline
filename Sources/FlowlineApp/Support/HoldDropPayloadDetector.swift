import AppKit

enum HoldDropPayloadDetector {
  static func hasHoldPayload(in pasteboard: NSPasteboard) -> Bool {
    importRoute(in: pasteboard) != nil
  }

  static func importRoute(in pasteboard: NSPasteboard) -> HoldDropImportRoute? {
    HoldDropImportPlan.route(
      hasFilePromise: hasFilePromise(in: pasteboard),
      hasFileURL: !fileURLs(in: pasteboard).isEmpty,
      hasWebURL: !webURLs(in: pasteboard).isEmpty,
      hasImageData: HoldImageDataReader.hasImageData(in: pasteboard),
      hasText: hasText(in: pasteboard)
    )
  }

  static func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
       !urls.isEmpty {
      return urls
    }

    return legacyFilenameURLs(in: pasteboard)
  }

  static func webURLs(in pasteboard: NSPasteboard) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: false]
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
      return []
    }

    return urls.filter { !$0.isFileURL }
  }

  private static func hasFilePromise(in pasteboard: NSPasteboard) -> Bool {
    pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil)
  }

  private static func hasText(in pasteboard: NSPasteboard) -> Bool {
    guard let text = pasteboard.string(forType: .string) else {
      return false
    }

    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private static func legacyFilenameURLs(in pasteboard: NSPasteboard) -> [URL] {
    guard let paths = pasteboard.propertyList(forType: HoldItemDragProvider.terminalFilenamesPasteboardType) as? [String] else {
      return []
    }

    return paths.map { URL(fileURLWithPath: $0) }
  }
}
