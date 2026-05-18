import Testing
import Foundation
import FlowlineCore
@testable import FlowlineApp

@Test func holdPreviewUsesFirstMeaningfulTextLines() {
  let preview = HoldPreviewPresentation.lines(
    for: "  Mevcut durum: iPhone'da bot icin tuning yapilmis\n\n  ama commitlenmemis."
  )

  #expect(preview == [
    "Mevcut durum: i...",
    "ama commitlenme..."
  ])
}

@Test func holdPreviewLimitsLongCodeLinesForTinyThumbnail() {
  let preview = HoldPreviewPresentation.lines(
    for: "func generatedPredictionScore() { return 42 }\nlet threshold = 0.73\nprint(threshold)"
  )

  #expect(preview == [
    "func generatedP...",
    "let threshold =...",
    "print(threshold)"
  ])
}

@Test func holdPreviewBuildsReadablePeekForTextItems() {
  let item = ShelfItem(
    kind: .text,
    title: "raw title",
    value: "First useful line\nsecond useful line\nthird useful line\nfourth useful line\nfifth useful line\nsixth useful line",
    url: nil
  )

  #expect(HoldPreviewPresentation.title(for: item) == "First useful line")
  #expect(HoldPreviewPresentation.thumbnailLines(for: item) == [
    "First useful line",
    "second useful line",
    "third useful line"
  ])
  #expect(HoldPreviewPresentation.peekLines(for: item) == [
    "First useful line",
    "second useful line",
    "third useful line",
    "fourth useful line",
    "fifth useful line"
  ])
  #expect(HoldPreviewPresentation.tooltipText(for: item) == """
First useful line
second useful line
third useful line
fourth useful line
fifth useful line
""")
}

@Test func holdPreviewBuildsCompactInlinePreviewForTrayHover() {
  let item = ShelfItem(
    kind: .code,
    title: "raw title",
    value: "func longGeneratedPredictionScore() { return 42 }\nlet threshold = 0.73\nprint(threshold)\nreturn threshold\nunused trailing line",
    url: nil
  )

  #expect(HoldPreviewPresentation.inlinePreviewLines(for: item) == [
    "func longGeneratedPredict...",
    "let threshold = 0.73",
    "print(threshold)",
    "return threshold"
  ])
}

@Test func holdPreviewSummaryUsesTextMetadataInsteadOfContentExcerpt() {
  let item = ShelfItem(
    kind: .text,
    title: "raw title",
    value: "t\nflowline - flowline - codex - 81x24\ntitle normal durumda ayni kaliyor",
    url: nil
  )

  let summary = HoldPreviewPresentation.summary(for: item)

  #expect(summary.title == "TEXT")
  #expect(summary.detail == "3 lines")
}

@Test func holdPreviewSummaryUsesCodeMetadataInsteadOfContentExcerpt() {
  let item = ShelfItem(
    kind: .code,
    title: "raw title",
    value: "x\nfunc renderHoldTray() -> some View",
    url: nil
  )

  let summary = HoldPreviewPresentation.summary(for: item)

  #expect(summary.title == "CODE")
  #expect(summary.detail == "2 lines")
}

@Test func holdPreviewSummaryKeepsFileAndScreenshotTitles() {
  let file = ShelfItem(
    kind: .file,
    title: "Notes.md",
    value: "/tmp/Notes.md",
    url: URL(fileURLWithPath: "/tmp/Notes.md")
  )
  let screenshot = ShelfItem(
    kind: .screenshot,
    title: "Ekran Resmi.png",
    value: "/tmp/Ekran Resmi.png",
    url: URL(fileURLWithPath: "/tmp/Ekran Resmi.png")
  )

  #expect(HoldPreviewPresentation.summary(for: file).title == "Notes.md")
  #expect(HoldPreviewPresentation.summary(for: screenshot).title == "Ekran Resmi.png")
}

@Test func holdPreviewShowsScreenshotOCRInlineWithoutChangingThumbnail() {
  let item = ShelfItem(
    kind: .screenshot,
    title: "Ekran Resmi.png",
    value: "/tmp/Ekran Resmi.png",
    url: URL(fileURLWithPath: "/tmp/Ekran Resmi.png"),
    ocrText: "terminal output line one\nterminal output line two\nterminal output line three"
  )

  #expect(HoldPreviewPresentation.thumbnailLines(for: item).isEmpty)
  #expect(HoldPreviewPresentation.title(for: item) == "Ekran Resmi.png")
  #expect(HoldPreviewPresentation.inlinePreviewLines(for: item) == [
    "terminal output line one",
    "terminal output line two",
    "terminal output line three"
  ])
}

@Test func holdPreviewDoesNotShowScreenshotPathAsInlineDetailWithoutOCR() {
  let item = ShelfItem(
    kind: .screenshot,
    title: "Ekran Resmi.png",
    value: "/tmp/private/screenshot.png",
    url: URL(fileURLWithPath: "/tmp/private/screenshot.png")
  )

  #expect(HoldPreviewPresentation.inlinePreviewLines(for: item).isEmpty)
}

@Test func holdPreviewDoesNotExposeSensitiveValues() {
  let item = ShelfItem(
    kind: .sensitive,
    title: "Sensitive clip",
    value: "sk-secret-token-should-not-render",
    url: nil
  )

  #expect(HoldPreviewPresentation.title(for: item) == "Sensitive clip")
  #expect(HoldPreviewPresentation.thumbnailLines(for: item).isEmpty)
  #expect(HoldPreviewPresentation.peekLines(for: item).isEmpty)
  #expect(HoldPreviewPresentation.inlinePreviewLines(for: item).isEmpty)
  #expect(HoldPreviewPresentation.tooltipText(for: item) == "Sensitive clip")
}
