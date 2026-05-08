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
