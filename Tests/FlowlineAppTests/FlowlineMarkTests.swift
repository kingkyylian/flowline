import AppKit
import Testing
@testable import FlowlineApp

@Test func flowlineMarkUsesCompactMenuBarMetrics() {
  #expect(FlowlineMarkMetrics.menuBarSize == 18)
  #expect(FlowlineMarkMetrics.collapsedSize == 13)
  #expect(FlowlineMarkMetrics.strokeWidth == 2.4)
  #expect(FlowlineMarkMetrics.armOuterXRatio == 0.27)
  #expect(FlowlineMarkMetrics.leftJointXRatio == 0.47)
  #expect(FlowlineMarkMetrics.rightJointXRatio == 0.53)
  #expect(FlowlineMarkMetrics.armTopYRatio == 0.28)
  #expect(FlowlineMarkMetrics.armJointYRatio == 0.50)
  #expect(FlowlineMarkMetrics.stemStartYRatio == 0.58)
  #expect(FlowlineMarkMetrics.stemEndYRatio == 0.80)
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
