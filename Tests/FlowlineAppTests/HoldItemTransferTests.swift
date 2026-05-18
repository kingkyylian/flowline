import AppKit
import Testing
import UniformTypeIdentifiers
@testable import FlowlineApp
import FlowlineCore

@MainActor
@Test func holdPasteboardWriterCopiesScreenshotAsImage() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("png")
  try writeTinyPNG(to: url)
  defer { try? FileManager.default.removeItem(at: url) }

  let item = ShelfItem(
    kind: .screenshot,
    title: url.lastPathComponent,
    value: url.path,
    url: url
  )

  HoldPasteboardWriter.write(item, to: pasteboard)

  #expect(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
  #expect(pasteboard.data(forType: .png) != nil || pasteboard.data(forType: .tiff) != nil)
  #expect(pasteboard.string(forType: .string) == nil)
  #expect(!pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]))
}

@MainActor
@Test func holdPasteboardWriterCopiesFilesAsFileURLAndShellPath() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let url = URL(fileURLWithPath: "/tmp/Archive 2026.zip")
  let item = ShelfItem(
    kind: .file,
    title: url.lastPathComponent,
    value: url.path,
    url: url
  )

  HoldPasteboardWriter.write(item, to: pasteboard)

  #expect(pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]))
  #expect(pasteboard.string(forType: .string) == "'/tmp/Archive 2026.zip'")
}

@MainActor
@Test func holdPasteboardWriterCopiesTextAsPlainString() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let item = ShelfItem(kind: .text, title: "note", value: "plain note", url: nil)

  HoldPasteboardWriter.write(item, to: pasteboard)

  #expect(pasteboard.string(forType: .string) == "plain note")
}

@MainActor
@Test func holdPasteboardWriterCopiesLinkAsURLAndPlainString() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let url = URL(string: "https://example.com/release")!
  let item = ShelfItem(kind: .link, title: "example.com", value: url.absoluteString, url: url)

  HoldPasteboardWriter.write(item, to: pasteboard)

  #expect(pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: false]))
  #expect(pasteboard.string(forType: .string) == "https://example.com/release")
}

@MainActor
@Test func holdPasteboardWriterCopiesScreenshotOCRTextWhenRequested() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let item = ShelfItem(
    kind: .screenshot,
    title: "Screenshot.png",
    value: "/tmp/Screenshot.png",
    url: URL(fileURLWithPath: "/tmp/Screenshot.png"),
    ocrText: "recognized terminal output"
  )

  #expect(HoldPasteboardWriter.writeOCRText(item, to: pasteboard))
  #expect(pasteboard.string(forType: .string) == "recognized terminal output")
}

@MainActor
@Test func holdPasteboardWriterDoesNotCopyMissingOCRText() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let item = ShelfItem(
    kind: .screenshot,
    title: "Screenshot.png",
    value: "/tmp/Screenshot.png",
    url: URL(fileURLWithPath: "/tmp/Screenshot.png")
  )

  #expect(!HoldPasteboardWriter.writeOCRText(item, to: pasteboard))
  #expect(pasteboard.string(forType: .string) == nil)
}

@MainActor
@Test func holdDragProviderExportsScreenshotAsFileURLAndTextPath() throws {
  let url = URL(fileURLWithPath: "/tmp/Ekran Resmi 2026-05-11 15.30.00.png")
  let item = ShelfItem(
    kind: .screenshot,
    title: url.lastPathComponent,
    value: url.path,
    url: url
  )

  let provider = HoldItemDragProvider.provider(for: item)
  let types = Set(provider.registeredTypeIdentifiers)

  #expect(types.contains(UTType.fileURL.identifier))
  #expect(types.contains(NSPasteboard.PasteboardType.string.rawValue))
  #expect(types.contains(UTType.plainText.identifier))
  #expect(types.contains(HoldItemDragProvider.terminalFilenamesPasteboardType.rawValue))
  #expect(types.contains(HoldItemDragProvider.legacyStringPasteboardType.rawValue))
}

@MainActor
@Test func holdDragProviderExportsLinkAsURLAndPlainText() throws {
  let url = URL(string: "https://example.com/release")!
  let item = ShelfItem(kind: .link, title: "example.com", value: url.absoluteString, url: url)

  let provider = HoldItemDragProvider.provider(for: item)
  let types = Set(provider.registeredTypeIdentifiers)

  #expect(types.contains(UTType.url.identifier))
  #expect(types.contains(UTType.plainText.identifier))
}

private func writeTinyPNG(to url: URL) throws {
  let image = NSImage(size: NSSize(width: 2, height: 2))
  image.lockFocus()
  NSColor.systemRed.setFill()
  NSRect(x: 0, y: 0, width: 2, height: 2).fill()
  image.unlockFocus()

  let tiffData = try #require(image.tiffRepresentation)
  let bitmap = try #require(NSBitmapImageRep(data: tiffData))
  let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
  try pngData.write(to: url)
}
