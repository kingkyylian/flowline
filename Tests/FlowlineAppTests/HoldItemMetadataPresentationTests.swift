import Foundation
import Testing
@testable import FlowlineApp
import FlowlineCore

@Test func codeMetadataShowsLineCountBeforeExpiry() {
  let item = ShelfItem(
    kind: .code,
    title: "generated.swift",
    value: "let a = 1\nlet b = 2\nprint(a + b)",
    url: nil
  )

  #expect(HoldItemMetadataPresentation.label(for: item, expiry: "14m") == "CODE · 3 lines · 14m")
}

@Test func largeTextMetadataShowsCharacterCount() {
  let item = ShelfItem(
    kind: .text,
    title: "long note",
    value: String(repeating: "a", count: 1_240),
    url: nil
  )

  #expect(HoldItemMetadataPresentation.label(for: item, expiry: "14m") == "TEXT · 1.2k chars · 14m")
}

@Test func shortTextMetadataShowsCharacterCountForStableCaptions() {
  let item = ShelfItem(
    kind: .text,
    title: "short note",
    value: "Yaptim knka. Screen...",
    url: nil
  )

  #expect(HoldItemMetadataPresentation.label(for: item, expiry: "14m") == "TEXT · 22 chars · 14m")
}

@Test func screenshotMetadataShowsOCRWordCountWhenReady() {
  let item = ShelfItem(
    kind: .screenshot,
    title: "Screenshot.png",
    value: "/tmp/Screenshot.png",
    url: URL(fileURLWithPath: "/tmp/Screenshot.png"),
    ocrText: "hello world"
  )

  #expect(HoldItemMetadataPresentation.label(for: item, expiry: "14m") == "SS · OCR 2w · 14m")
}
