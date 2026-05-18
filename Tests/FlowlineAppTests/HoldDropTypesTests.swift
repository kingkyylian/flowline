import AppKit
import Testing
@testable import FlowlineApp

@MainActor
@Test func holdDropTypesAcceptFileURLsTextImagesAndFilePromises() throws {
  let types = Set(HoldDropTypes.pasteboardTypes.map(\.rawValue))

  #expect(types.contains(NSPasteboard.PasteboardType.fileURL.rawValue))
  #expect(types.contains(NSPasteboard.PasteboardType.URL.rawValue))
  #expect(types.contains(NSPasteboard.PasteboardType.string.rawValue))
  #expect(types.contains(NSPasteboard.PasteboardType.png.rawValue))
  #expect(types.contains(NSPasteboard.PasteboardType.tiff.rawValue))
  #expect(types.contains(HoldImageDataReader.jpegPasteboardType.rawValue))
  #expect(types.contains(HoldItemDragProvider.terminalFilenamesPasteboardType.rawValue))

  for promisedType in NSFilePromiseReceiver.readableDraggedTypes {
    #expect(types.contains(promisedType))
  }
}

@MainActor
@Test func holdDropPayloadDetectorAcceptsLegacyFilenameDrags() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let screenshot = URL(fileURLWithPath: "/tmp/Screenshot Flowline.png")
  pasteboard.declareTypes([HoldItemDragProvider.terminalFilenamesPasteboardType], owner: nil)
  pasteboard.setPropertyList([screenshot.path], forType: HoldItemDragProvider.terminalFilenamesPasteboardType)

  #expect(HoldDropPayloadDetector.hasHoldPayload(in: pasteboard))
  #expect(HoldDropPayloadDetector.fileURLs(in: pasteboard) == [screenshot])
}

@MainActor
@Test func holdDropPayloadDetectorRejectsEmptyDragPasteboards() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  pasteboard.clearContents()

  #expect(!HoldDropPayloadDetector.hasHoldPayload(in: pasteboard))
}

@MainActor
@Test func overlayDragActivationExpandsForFileDragPasteboard() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let screenshot = URL(fileURLWithPath: "/tmp/Screenshot Flowline.png")
  pasteboard.writeObjects([screenshot as NSURL])

  #expect(
    OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: .leftMouseDragged,
      positionMode: .notch,
      isExpanded: false,
      dragPasteboard: pasteboard,
      mouseLocation: NSPoint(x: 620, y: 870),
      collapsedFrame: NSRect(x: 500, y: 850, width: 240, height: 44)
    )
  )
}

@MainActor
@Test func holdImageDataReaderConvertsJPEGDropsToPNG() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let image = testImage()
  let tiff = try #require(image.tiffRepresentation)
  let bitmap = try #require(NSBitmapImageRep(data: tiff))
  let jpeg = try #require(bitmap.representation(using: .jpeg, properties: [:]))

  pasteboard.declareTypes([HoldImageDataReader.jpegPasteboardType], owner: nil)
  pasteboard.setData(jpeg, forType: HoldImageDataReader.jpegPasteboardType)

  let png = try #require(HoldImageDataReader.pngData(from: pasteboard))

  #expect(NSBitmapImageRep(data: png) != nil)
}

private func testImage() -> NSImage {
  let image = NSImage(size: NSSize(width: 4, height: 4))
  image.lockFocus()
  NSColor.systemGreen.setFill()
  NSRect(x: 0, y: 0, width: 4, height: 4).fill()
  image.unlockFocus()
  return image
}
