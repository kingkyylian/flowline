import Foundation
import AppKit
import Testing
@testable import FlowlineApp

private struct FakeScreenshotTextRecognizer: ScreenshotTextRecognizing {
  let text: String?

  func recognizeText(in url: URL) async -> String? {
    text
  }
}

@MainActor
@Test func shelfServiceUsesLowLatencyAutoCaptureCadence() {
  #expect(ShelfService.pasteboardPollInterval == 0.1)
  #expect(ShelfService.screenshotPollInterval == 1.0)
  #expect(ShelfService.screenshotEventRescanDelays == [0.08, 0.20, 0.45])
}

@MainActor
@Test func shelfServiceStoresDroppedTextAndLinksImmediately() throws {
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory }
  )

  service.addText("https://example.com/release")
  service.addText("plain hold note")

  #expect(service.items.map(\.kind) == [.text, .link])
  #expect(service.items.map(\.title) == ["plain hold note", "example.com"])
}

@MainActor
@Test func shelfServiceMovesScreenshotsFromWatchedDirectoryIntoStash() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory }
  )
  service.start()
  defer { service.stop() }

  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-10.png")
  try Data("ss".utf8).write(to: screenshot)

  service.refreshHoldSourcesForTesting()

  #expect(service.items.first?.kind == .screenshot)
  #expect(service.items.first?.title == "Screenshot 2026-05-10.png")
  #expect(service.items.first?.url?.deletingLastPathComponent() == stashDirectory)
  #expect(fileManager.fileExists(atPath: stashDirectory.appendingPathComponent("Screenshot 2026-05-10.png").path))
  #expect(!fileManager.fileExists(atPath: screenshot.path))
}

@MainActor
@Test func shelfServiceAddsScreenshotSoonAfterDirectoryWrite() async throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory }
  )
  service.start()
  defer { service.stop() }

  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-11 immediate.png")
  try Data("ss".utf8).write(to: screenshot)

  let deadline = Date().addingTimeInterval(0.45)
  while Date() < deadline {
    if service.items.first?.title == "Screenshot 2026-05-11 immediate.png" {
      break
    }

    try await Task.sleep(for: .milliseconds(25))
  }

  #expect(service.items.first?.title == "Screenshot 2026-05-11 immediate.png")
  #expect(service.items.first?.url?.deletingLastPathComponent() == stashDirectory)
}

@MainActor
@Test func shelfServiceCapturesLateScreenshotWithOldModificationDateWithoutImportingExistingFiles() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let startedAt = Date()
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let existing = directory.appendingPathComponent("Screenshot 2026-05-11 existing.png")
  try Data("old".utf8).write(to: existing)
  try fileManager.setAttributes(
    [.modificationDate: startedAt.addingTimeInterval(-60)],
    ofItemAtPath: existing.path
  )

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory },
    nowProvider: { startedAt }
  )
  service.start()
  defer { service.stop() }

  let delayed = directory.appendingPathComponent("Screenshot 2026-05-11 delayed.png")
  try Data("ss".utf8).write(to: delayed)
  try fileManager.setAttributes(
    [.modificationDate: startedAt.addingTimeInterval(-30)],
    ofItemAtPath: delayed.path
  )

  service.refreshHoldSourcesForTesting()

  #expect(service.items.map(\.title) == ["Screenshot 2026-05-11 delayed.png"])
  #expect(fileManager.fileExists(atPath: existing.path))
  #expect(!fileManager.fileExists(atPath: delayed.path))
}

@MainActor
@Test func shelfServiceStashesDroppedScreenshotFiles() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory }
  )
  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-11 promised.png")
  try Data("ss".utf8).write(to: screenshot)

  service.addScreenshotFiles([screenshot])

  let item = try #require(service.items.first)
  #expect(item.kind == .screenshot)
  #expect(item.url?.deletingLastPathComponent() == stashDirectory)
  #expect(fileManager.fileExists(atPath: stashDirectory.appendingPathComponent("Screenshot 2026-05-11 promised.png").path))
  #expect(!fileManager.fileExists(atPath: screenshot.path))
}

@MainActor
@Test func shelfServiceAddsOCRTextToDroppedScreenshot() async throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory },
    screenshotTextRecognizer: FakeScreenshotTextRecognizer(text: "recognized terminal output")
  )
  let screenshot = directory.appendingPathComponent("Screenshot OCR.png")
  try Data("ss".utf8).write(to: screenshot)

  service.addScreenshotFiles([screenshot])

  let deadline = Date().addingTimeInterval(0.45)
  while Date() < deadline {
    if service.items.first?.ocrText == "recognized terminal output" {
      break
    }

    try await Task.sleep(for: .milliseconds(25))
  }

  let item = try #require(service.items.first)
  #expect(item.kind == .screenshot)
  #expect(item.ocrText == "recognized terminal output")
}

@MainActor
@Test func shelfServiceDeletesStashedScreenshotFileWhenItemIsRemoved() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory }
  )
  service.start()
  defer { service.stop() }

  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-11.png")
  try Data("ss".utf8).write(to: screenshot)

  service.refreshHoldSourcesForTesting()

  let item = try #require(service.items.first)
  let stashedPath = try #require(item.url?.path)
  #expect(fileManager.fileExists(atPath: stashedPath))

  service.remove(id: item.id)

  #expect(!fileManager.fileExists(atPath: stashedPath))
}

@MainActor
@Test func shelfServiceKeepsStashedScreenshotFileWhenItemIsExported() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory }
  )
  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-11 export.png")
  try Data("ss".utf8).write(to: screenshot)

  service.addScreenshotFiles([screenshot])

  let item = try #require(service.items.first)
  let stashedPath = try #require(item.url?.path)
  #expect(fileManager.fileExists(atPath: stashedPath))

  service.export(id: item.id)

  #expect(service.items.isEmpty)
  #expect(fileManager.fileExists(atPath: stashedPath))
}

@MainActor
@Test func shelfServiceDeletesStashedScreenshotFilesWhenCleared() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory }
  )
  service.start()
  defer { service.stop() }

  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-11 clear.png")
  try Data("ss".utf8).write(to: screenshot)

  service.refreshHoldSourcesForTesting()

  let stashedPath = try #require(service.items.first?.url?.path)
  #expect(fileManager.fileExists(atPath: stashedPath))

  service.clear()

  #expect(!fileManager.fileExists(atPath: stashedPath))
}

@MainActor
@Test func shelfServiceDeletesStashedScreenshotFileWhenItemExpires() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let start = Date()
  var now = start
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory },
    retention: 1,
    nowProvider: { now }
  )
  service.start()
  defer { service.stop() }

  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-11 expiry.png")
  try Data("ss".utf8).write(to: screenshot)

  service.refreshHoldSourcesForTesting()

  let stashedPath = try #require(service.items.first?.url?.path)
  #expect(fileManager.fileExists(atPath: stashedPath))

  now = start.addingTimeInterval(2)
  service.refreshHoldSourcesForTesting()

  #expect(service.items.isEmpty)
  #expect(!fileManager.fileExists(atPath: stashedPath))
}

@MainActor
@Test func shelfServiceDeletesExpiredStashedScreenshotBeforeAddingDroppedText() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let start = Date()
  var now = start
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory },
    retention: 1,
    nowProvider: { now }
  )
  service.start()
  defer { service.stop() }

  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-11 drop text.png")
  try Data("ss".utf8).write(to: screenshot)

  service.refreshHoldSourcesForTesting()

  let stashedPath = try #require(service.items.first?.url?.path)
  #expect(fileManager.fileExists(atPath: stashedPath))

  now = start.addingTimeInterval(2)
  service.addText("fresh note")

  #expect(service.items.map(\.title) == ["fresh note"])
  #expect(!fileManager.fileExists(atPath: stashedPath))
}

@MainActor
@Test func shelfServiceStashesClipboardScreenshotImages() throws {
  let fileManager = FileManager.default
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory },
    pasteboardProvider: { pasteboard }
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.writeObjects([testImage()])

  service.refreshHoldSourcesForTesting()

  let item = try #require(service.items.first)
  #expect(item.kind == .screenshot)
  #expect(item.title.hasPrefix("Clipboard Screenshot "))
  #expect(item.url?.deletingLastPathComponent() == stashDirectory)
  #expect(item.url?.pathExtension == "png")
  #expect(fileManager.fileExists(atPath: item.url?.path ?? ""))
}

@MainActor
@Test func shelfServiceLeavesClipboardTextForUserByDefault() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
    pasteboardProvider: { pasteboard }
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.setString("copied terminal text", forType: .string)

  service.refreshHoldSourcesForTesting()

  #expect(service.items.isEmpty)
}

@MainActor
@Test func shelfServiceCapturesClipboardTextWhenUserEnablesIt() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
    pasteboardProvider: { pasteboard },
    autoCaptureOptions: ShelfAutoCaptureOptions(screenshots: true, clipboardText: true)
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.setString("copied on purpose", forType: .string)

  service.refreshHoldSourcesForTesting()

  #expect(service.items.map(\.title) == ["copied on purpose"])
}

@MainActor
@Test func shelfServiceCapturesOnlyNewClipboardTextAfterUserEnablesIt() throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
    pasteboardProvider: { pasteboard }
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.setString("old copied text", forType: .string)

  service.updateAutoCaptureOptions(ShelfAutoCaptureOptions(screenshots: true, clipboardText: true))
  service.refreshHoldSourcesForTesting()

  pasteboard.clearContents()
  pasteboard.setString("new copied text", forType: .string)
  service.refreshHoldSourcesForTesting()

  #expect(service.items.map(\.title) == ["new copied text"])
}

@MainActor
@Test func shelfServiceCapturesClipboardTextQuicklyWhenEnabled() async throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
    pasteboardProvider: { pasteboard },
    autoCaptureOptions: ShelfAutoCaptureOptions(screenshots: false, clipboardText: true)
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.setString("fast copied text", forType: .string)

  let deadline = Date().addingTimeInterval(0.35)
  while Date() < deadline {
    if service.items.first?.title == "fast copied text" {
      break
    }

    try await Task.sleep(for: .milliseconds(25))
  }

  #expect(service.items.first?.title == "fast copied text")
}

@MainActor
@Test func shelfServiceLeavesClipboardImagesAloneWhenScreenshotCaptureIsDisabled() throws {
  let fileManager = FileManager.default
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory },
    pasteboardProvider: { pasteboard },
    autoCaptureOptions: ShelfAutoCaptureOptions(screenshots: false, clipboardText: false)
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.writeObjects([testImage()])

  service.refreshHoldSourcesForTesting()

  #expect(service.items.isEmpty)
}

@MainActor
@Test func shelfServiceLeavesScreenshotDirectoryAloneWhenScreenshotCaptureIsDisabled() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [directory] },
    screenshotStashDirectoryProvider: { stashDirectory },
    autoCaptureOptions: ShelfAutoCaptureOptions(screenshots: false, clipboardText: false)
  )
  service.start()
  defer { service.stop() }

  let screenshot = directory.appendingPathComponent("Screenshot auto off.png")
  try Data("ss".utf8).write(to: screenshot)

  service.refreshHoldSourcesForTesting()

  #expect(service.items.isEmpty)
  #expect(fileManager.fileExists(atPath: screenshot.path))
}

@MainActor
@Test func shelfServiceStillAcceptsDroppedScreenshotsWhenAutoScreenshotCaptureIsDisabled() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory },
    autoCaptureOptions: ShelfAutoCaptureOptions(screenshots: false, clipboardText: false)
  )
  let screenshot = directory.appendingPathComponent("Screenshot manual.png")
  try Data("ss".utf8).write(to: screenshot)

  service.addScreenshotFiles([screenshot])

  #expect(service.items.first?.kind == .screenshot)
  #expect(service.items.first?.title == "Screenshot manual.png")
}

@MainActor
@Test func shelfServiceIgnoresPasteboardWritesAlreadyHandledByHoldActions() throws {
  let fileManager = FileManager.default
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory },
    pasteboardProvider: { pasteboard }
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.writeObjects([testImage()])
  service.markPasteboardWriteHandled()

  service.refreshHoldSourcesForTesting()

  #expect(service.items.isEmpty)
}

@MainActor
@Test func shelfServicePrefersClipboardImageWhenPasteboardAlsoHasText() throws {
  let fileManager = FileManager.default
  let stashDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: stashDirectory) }

  let pasteboard = NSPasteboard.withUniqueName()
  let service = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { stashDirectory },
    pasteboardProvider: { pasteboard }
  )
  service.start()
  defer { service.stop() }

  pasteboard.clearContents()
  pasteboard.declareTypes([.tiff, .string], owner: nil)
  pasteboard.setData(testImage().tiffRepresentation, forType: .tiff)
  pasteboard.setString("fallback text", forType: .string)

  service.refreshHoldSourcesForTesting()

  let item = try #require(service.items.first)
  #expect(item.kind == .screenshot)
  #expect(item.title.hasPrefix("Clipboard Screenshot "))
}

private func testImage() -> NSImage {
  let image = NSImage(size: NSSize(width: 4, height: 4))
  image.lockFocus()
  NSColor.systemBlue.setFill()
  NSRect(x: 0, y: 0, width: 4, height: 4).fill()
  image.unlockFocus()
  return image
}
