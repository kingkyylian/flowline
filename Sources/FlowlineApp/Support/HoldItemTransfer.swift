import AppKit
import FlowlineCore
import UniformTypeIdentifiers

enum HoldShellPathFormatter {
  static func format(_ path: String) -> String {
    let safePattern = #"^[A-Za-z0-9_@%+=:,./-]+$"#
    if path.range(of: safePattern, options: .regularExpression) != nil {
      return path
    }

    return "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
  }
}

enum HoldPasteboardWriter {
  static func write(_ item: ShelfItem, to pasteboard: NSPasteboard) {
    pasteboard.clearContents()

    if item.kind == .screenshot, let url = item.url {
      if writeImage(at: url, to: pasteboard) {
        return
      }

      writeFileURL(url, to: pasteboard)
    } else if item.kind == .file, let url = item.url {
      writeFileURL(url, to: pasteboard)
    } else if item.kind == .link, let url = item.url {
      pasteboard.writeObjects([url as NSURL])
      pasteboard.setString(url.absoluteString, forType: .string)
    } else {
      pasteboard.setString(item.value, forType: .string)
    }
  }

  @discardableResult
  static func writeOCRText(_ item: ShelfItem, to pasteboard: NSPasteboard) -> Bool {
    guard item.kind == .screenshot,
          let text = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty else {
      return false
    }

    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    return true
  }

  private static func writeFileURL(_ url: URL, to pasteboard: NSPasteboard) {
    pasteboard.writeObjects([url as NSURL])
    pasteboard.setString(HoldShellPathFormatter.format(url.path), forType: .string)
  }

  private static func writeImage(at url: URL, to pasteboard: NSPasteboard) -> Bool {
    guard let image = NSImage(contentsOf: url) else {
      return false
    }

    let wroteImage = pasteboard.writeObjects([image])
    if let pngData = pngData(for: image, sourceURL: url) {
      pasteboard.setData(pngData, forType: .png)
    }

    if let tiffData = image.tiffRepresentation {
      pasteboard.setData(tiffData, forType: .tiff)
    }

    return wroteImage || pasteboard.data(forType: .png) != nil || pasteboard.data(forType: .tiff) != nil
  }

  private static func pngData(for image: NSImage, sourceURL: URL) -> Data? {
    if sourceURL.pathExtension.lowercased() == "png",
       let data = try? Data(contentsOf: sourceURL) {
      return data
    }

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
      return nil
    }

    return bitmap.representation(using: .png, properties: [:])
  }
}

enum HoldItemDragProvider {
  static let terminalFilenamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
  static let legacyStringPasteboardType = NSPasteboard.PasteboardType("NSStringPboardType")

  static func provider(for item: ShelfItem) -> NSItemProvider {
    if (item.kind == .file || item.kind == .screenshot), let url = item.url {
      let provider = NSItemProvider(object: url as NSURL)
      provider.suggestedName = url.lastPathComponent
      registerFileURL(url, on: provider)
      registerPlainText(HoldShellPathFormatter.format(url.path), on: provider)
      registerTerminalFilename(url, on: provider)
      return provider
    }

    if item.kind == .link, let url = item.url {
      let provider = NSItemProvider(object: url as NSURL)
      registerPlainText(url.absoluteString, on: provider)
      return provider
    }

    let provider = NSItemProvider(object: item.value as NSString)
    registerPlainText(item.value, on: provider)
    return provider
  }

  private static func registerPlainText(_ text: String, on provider: NSItemProvider) {
    let data = Data(text.utf8)
    let typeIdentifiers = [
      UTType.plainText.identifier,
      NSPasteboard.PasteboardType.string.rawValue,
      legacyStringPasteboardType.rawValue
    ]

    for typeIdentifier in typeIdentifiers where !provider.registeredTypeIdentifiers.contains(typeIdentifier) {
      provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
        completion(data, nil)
        return nil
      }
    }
  }

  private static func registerFileURL(_ url: URL, on provider: NSItemProvider) {
    let data = Data(url.absoluteString.utf8)
    let typeIdentifiers = [
      UTType.fileURL.identifier,
      NSPasteboard.PasteboardType.fileURL.rawValue
    ]

    for typeIdentifier in typeIdentifiers where !provider.registeredTypeIdentifiers.contains(typeIdentifier) {
      provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
        completion(data, nil)
        return nil
      }
    }
  }

  private static func registerTerminalFilename(_ url: URL, on provider: NSItemProvider) {
    guard let data = try? PropertyListSerialization.data(
      fromPropertyList: [url.path],
      format: .xml,
      options: 0
    ) else {
      return
    }

    let typeIdentifier = terminalFilenamesPasteboardType.rawValue
    guard !provider.registeredTypeIdentifiers.contains(typeIdentifier) else {
      return
    }

    provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
      completion(data, nil)
      return nil
    }
  }
}
