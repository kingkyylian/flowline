import AppKit
import Testing
@testable import FlowlineApp

@Test func flowlineMarkUsesCompactMenuBarMetrics() {
  #expect(FlowlineMarkMetrics.menuBarSize == 18)
  #expect(FlowlineMarkMetrics.collapsedSize == 13)
  #expect(FlowlineMarkMetrics.strokeWidth == 2.25)
}

@Test func flowlineMarkUsesSingleFlowRibbonInsteadOfBrokenY() throws {
  let source = try String(
    contentsOfFile: "Sources/FlowlineApp/Views/FlowlineMarkView.swift",
    encoding: .utf8
  )

  #expect(source.contains("FlowlineMarkRibbonPath"))
  #expect(source.contains("path.addCurve"))
  #expect(!source.contains("FlowlineMarkBrokenYPath"))
}

@Test func appIconRendererUsesFlowRibbonArtwork() throws {
  let source = try String(
    contentsOfFile: "script/generate_app_icon.swift",
    encoding: .utf8
  )

  #expect(source.contains("drawFlowRibbon"))
  #expect(!source.contains("drawSegment(from: p(289, 319)"))
  #expect(!source.contains("drawSegment(from: p(735, 319)"))
}

@MainActor
@Test func flowlineMenuBarImageIsTemplateAndSizedForStatusBar() {
  let image = FlowlineMarkImage.menuBarIcon

  #expect(image.size.width == FlowlineMarkMetrics.menuBarSize)
  #expect(image.size.height == FlowlineMarkMetrics.menuBarSize)
  #expect(image.isTemplate)
}

@MainActor
@Test func flowlineMenuBarImageContainsVisibleArtwork() throws {
  let image = FlowlineMarkImage.menuBarIcon
  let data = try #require(image.tiffRepresentation)
  let bitmap = try #require(NSBitmapImageRep(data: data))
  var paintedPixels = 0

  for y in 0..<bitmap.pixelsHigh {
    for x in 0..<bitmap.pixelsWide {
      if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2 {
        paintedPixels += 1
      }
    }
  }

  #expect(paintedPixels > 24)
}
