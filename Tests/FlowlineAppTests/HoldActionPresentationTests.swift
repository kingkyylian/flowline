import Foundation
import Testing
@testable import FlowlineApp
import FlowlineCore

@Test func holdActionsStayUnderThreeForMultipleScreenshots() {
  let item = ShelfItem(
    kind: .screenshot,
    title: "Ekran Resmi.png",
    value: "/tmp/Ekran Resmi.png",
    url: URL(fileURLWithPath: "/tmp/Ekran Resmi.png")
  )

  let actions = HoldActionPresentation.actions(for: item, itemCount: 4)

  #expect(actions.map(\.label) == ["IMG", "NEXT", "DEL"])
  #expect(actions.count <= 3)
  #expect(actions.filter { $0.isDestructive }.map(\.label) == ["DEL"])
}

@Test func holdActionsExposeOCRTextForSingleScreenshotWhenAvailable() {
  let item = ShelfItem(
    kind: .screenshot,
    title: "Ekran Resmi.png",
    value: "/tmp/Ekran Resmi.png",
    url: URL(fileURLWithPath: "/tmp/Ekran Resmi.png"),
    ocrText: "recognized terminal output"
  )

  let actions = HoldActionPresentation.actions(for: item, itemCount: 1)

  #expect(actions.map(\.label) == ["IMG", "TEXT", "DEL"])
  #expect(actions.count == 3)
}

@Test func holdActionsUseCopyAndDeleteForSingleTextItem() {
  let item = ShelfItem(kind: .text, title: "note", value: "hello", url: nil)

  let actions = HoldActionPresentation.actions(for: item, itemCount: 1)

  #expect(actions.map(\.label) == ["COPY", "DEL"])
  #expect(actions.count == 2)
}
