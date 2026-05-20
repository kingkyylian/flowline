import Testing
import Foundation
@testable import FlowlineCore

@Test func keepsNewestTextItemsFirstAndDeduplicates() throws {
  var store = ShelfStore(limit: 3)

  store.addText("alpha")
  store.addText("beta")
  store.addText("alpha")

  #expect(store.items.map(\.title) == ["alpha", "beta"])
}

@Test func capsShelfItemsAtLimit() throws {
  var store = ShelfStore(limit: 2)

  store.addText("one")
  store.addText("two")
  store.addText("three")

  #expect(store.items.map(\.title) == ["three", "two"])
}

@Test func storesFileURLsAsShelfItems() throws {
  var store = ShelfStore(limit: 5)
  let file = URL(fileURLWithPath: "/tmp/Flowline Demo.txt")

  store.addFile(file)

  #expect(store.items.first?.kind == .file)
  #expect(store.items.first?.url == file)
  #expect(store.items.first?.title == "Flowline Demo.txt")
}

@Test func storesScreenshotFilesButIgnoresOrdinaryPhotos() throws {
  var store = ShelfStore(limit: 5)

  store.addFile(URL(fileURLWithPath: "/tmp/Screen Shot 2026-05-10 at 22.40.00.png"))
  store.addFile(URL(fileURLWithPath: "/tmp/Ekran Resmi 2026-05-10 22.41.00.png"))
  store.addFile(URL(fileURLWithPath: "/tmp/vacation-photo.jpg"))
  store.addFile(URL(fileURLWithPath: "/tmp/camera.heic"))

  #expect(store.items.map(\.kind) == [.screenshot, .screenshot])
  #expect(store.items.map(\.title) == [
    "Ekran Resmi 2026-05-10 22.41.00.png",
    "Screen Shot 2026-05-10 at 22.40.00.png"
  ])
}

@Test func explicitScreenshotDropsAcceptGenericImageFilenames() throws {
  var store = ShelfStore(limit: 5)
  let file = URL(fileURLWithPath: "/tmp/image.png")

  store.addScreenshotFile(file)

  #expect(store.items.first?.kind == .screenshot)
  #expect(store.items.first?.title == "image.png")
  #expect(store.items.first?.url == file)
}

@Test func updatesScreenshotOCRTextWithoutChangingStoredFile() throws {
  var store = ShelfStore(limit: 5)
  let file = URL(fileURLWithPath: "/tmp/image.png")

  let inserted = store.addScreenshotFile(file)
  let item = try #require(inserted)
  let didUpdateOCRText = store.updateOCRText("hello world", for: item.id)

  #expect(didUpdateOCRText)
  #expect(store.items.first?.kind == .screenshot)
  #expect(store.items.first?.url == file)
  #expect(store.items.first?.ocrText == "hello world")
}

@Test func classifiesOnlyAbsoluteWebURLsAsLinks() throws {
  var store = ShelfStore(limit: 5)

  store.addText("arc b580 cs2")
  store.addText("https://example.com/release-notes")

  #expect(store.items[0].kind == .link)
  #expect(store.items[0].title == "example.com")
  #expect(store.items[1].kind == .text)
  #expect(store.items[1].title == "arc b580 cs2")
}

@Test func classifiesLargeCodeBlocksAsCodeAndKeepsFullValue() throws {
  let code = (1...120)
    .map { "func generated\($0)() { return \($0) }" }
    .joined(separator: "\n")
  var store = ShelfStore(limit: 5)

  store.addText(code)

  let item = try #require(store.items.first)
  #expect(item.kind == .code)
  #expect(item.title == "func generated1() { return 1 }")
  #expect(item.value == code)
}

@Test func keepsOrdinaryMultilineNotesAsText() throws {
  let note = """
  launch checklist
  test screenshot drag
  polish hold copy
  write landing copy
  """
  var store = ShelfStore(limit: 5)

  store.addText(note)

  #expect(store.items.first?.kind == .text)
}

@Test func keepsOrdinaryWebURLsWithDigitsVisible() throws {
  var store = ShelfStore(limit: 5)

  store.addText("https://example.com/posts/2026")

  #expect(store.items.first?.kind == .link)
  #expect(store.items.first?.title == "example.com")
}

@Test func masksSensitiveClipboardTextWithoutExpiry() throws {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let secret = "A9x!kL4#pQ7$vN2"
  var store = ShelfStore(limit: 5)

  store.addText(secret, now: now)

  let item = try #require(store.items.first)
  #expect(item.kind == .sensitive)
  #expect(item.title == "Sensitive clip")
  #expect(item.value == secret)
  #expect(item.expiresAt == nil)
}

@Test func prunesExpiredShelfItems() throws {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  var store = ShelfStore(limit: 5)

  store.addText("temporary note", now: now)
  store.pruneExpired(now: now.addingTimeInterval(901))

  #expect(store.items.isEmpty)
}

@Test func cyclesHoldItemsWithoutLosingThem() throws {
  var store = ShelfStore(limit: 5)

  store.addText("one")
  store.addText("two")
  store.addText("three")
  store.cycle()

  #expect(store.items.map(\.title) == ["two", "one", "three"])
}
