import AppKit
import Testing
@testable import FlowlineApp
import FlowlineCore

@MainActor
@Test func holdDropImporterImportsPlainTextIntoHold() throws {
  try withHoldDropImporterHarness { harness in
    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("dropped hold note", forType: .string)

    #expect(harness.importer.importDrop(from: pasteboard))

    let item = try #require(harness.state.snapshot.shelfItems.first)
    #expect(item.kind == .text)
    #expect(item.title == "dropped hold note")
  }
}

@MainActor
@Test func holdDropImporterImportsWebURLIntoHold() throws {
  try withHoldDropImporterHarness { harness in
    let pasteboard = NSPasteboard.withUniqueName()
    let url = try #require(URL(string: "https://example.com/release"))
    pasteboard.writeObjects([url as NSURL])

    #expect(harness.importer.importDrop(from: pasteboard))

    let item = try #require(harness.state.snapshot.shelfItems.first)
    #expect(item.kind == .link)
    #expect(item.title == "example.com")
    #expect(item.value == "https://example.com/release")
  }
}

@MainActor
@Test func holdDropImporterImportsFinderFileURLIntoHold() throws {
  try withHoldDropImporterHarness { harness in
    let pasteboard = NSPasteboard.withUniqueName()
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
    try Data("finder file".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    pasteboard.writeObjects([file as NSURL])

    #expect(harness.importer.importDrop(from: pasteboard))

    let item = try #require(harness.state.snapshot.shelfItems.first)
    #expect(item.kind == .file)
    #expect(item.title == file.lastPathComponent)
    #expect(item.url == file)
  }
}

@MainActor
private final class HoldDropImporterHarness {
  let state: AppState
  let importer: HoldDropImporter

  init() {
    let shelfService = ShelfService(
      screenshotDirectoriesProvider: { [] },
      screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
      pasteboardProvider: { NSPasteboard.withUniqueName() },
      screenshotTextRecognizer: nil
    )
    state = AppState(shelfService: shelfService)
    importer = HoldDropImporter(
      addFiles: state.addShelfFiles,
      addText: state.addShelfText,
      addScreenshots: state.addShelfScreenshots
    )
  }
}

@MainActor
private func withHoldDropImporterHarness(_ body: (HoldDropImporterHarness) throws -> Void) rethrows {
  let defaults = UserDefaults.standard
  let keys = [
    "module.workspace.enabled",
    "module.music.enabled",
    "module.calendar.enabled",
    "module.shelf.enabled"
  ]
  let previousValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
  defaults.set(false, forKey: "module.workspace.enabled")
  defaults.set(false, forKey: "module.music.enabled")
  defaults.set(false, forKey: "module.calendar.enabled")
  defaults.set(true, forKey: "module.shelf.enabled")
  defer {
    for (key, value) in previousValues {
      if let value {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  try body(HoldDropImporterHarness())
}
