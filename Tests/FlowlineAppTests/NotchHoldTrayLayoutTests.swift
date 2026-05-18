import Testing
import SwiftUI
@testable import FlowlineApp

@Test func holdTrayUsesLargerPreviewSurface() {
  #expect(NotchHoldTrayLayout.trayHeight == 62)
  #expect(NotchHoldTrayLayout.previewWidth == 56)
  #expect(NotchHoldTrayLayout.previewHeight == 66)
  #expect(NotchHoldTrayLayout.previewMediaHeight == 48)
  #expect(NotchHoldTrayLayout.previewOffsetY == 12)
  #expect(NotchHoldTrayLayout.previewCornerRadius == 3)
  #expect(NotchHoldTrayLayout.previewCaptionSpacing == 2)
  #expect(NotchHoldTrayLayout.screenshotPreviewCaptionSpacing == 5)
  #expect(NotchHoldTrayLayout.screenshotPreviewCaptionSpacing > NotchHoldTrayLayout.previewCaptionSpacing)
  #expect(NotchHoldTrayLayout.previewCaptionHorizontalInset == 1)
  #expect(NotchHoldTrayLayout.screenshotPreviewOverlayHorizontalPadding == 7)
  #expect(NotchHoldTrayLayout.screenshotPreviewOverlayVerticalPadding == 5)
  #expect(NotchHoldTrayLayout.textCardPreviewLineFontSize == 5.4)
  #expect(NotchHoldTrayLayout.textCardPreviewLineSpacing == 1.7)
  #expect(NotchHoldTrayLayout.textCardPreviewContentPadding == 7)
  #expect(NotchHoldTrayLayout.textCardPreviewBadgeFontSize == 8.5)
  #expect(NotchHoldTrayLayout.textCardPreviewDetailFontSize == 8)
  #expect(NotchHoldTrayLayout.iconCardSymbolFontSize == 20)
  #expect(NotchHoldTrayLayout.fileMarkWidth == 24)
  #expect(NotchHoldTrayLayout.fileMarkHeight == 31)
  #expect(NotchHoldTrayLayout.fileMarkCornerRadius == 5)
  #expect(NotchHoldTrayLayout.fileMarkStrokeWidth == 2)
  #expect(NotchHoldTrayLayout.fileMarkDetailWidth == 10)
  #expect(NotchHoldTrayLayout.stackBadgeWidth == 28)
  #expect(NotchHoldTrayLayout.stackBadgeHeight == 16)
}

@Test func holdPreviewGrowsDownIntoTrayBottomSpace() {
  let previewTop = ((NotchHoldTrayLayout.trayHeight - NotchHoldTrayLayout.previewHeight) / 2)
    + NotchHoldTrayLayout.previewOffsetY
  let bottomOverflow = previewTop
    + NotchHoldTrayLayout.previewHeight
    - NotchHoldTrayLayout.trayHeight

  #expect(previewTop == 10)
  #expect(bottomOverflow == 14)
}

@Test func holdPreviewReservesSpaceForCaptionBelowMedia() {
  let captionSpace = NotchHoldTrayLayout.previewHeight
    - NotchHoldTrayLayout.previewMediaHeight
    - NotchHoldTrayLayout.previewCaptionSpacing

  #expect(captionSpace == 16)
}

@Test func holdPreviewKeepsBreathingRoomAboveActionButtonsAfterMediaGrowth() {
  let previewTop = ((NotchHoldTrayLayout.trayHeight - NotchHoldTrayLayout.previewHeight) / 2)
    + NotchHoldTrayLayout.previewOffsetY
  let previewBottom = NotchHoldTrayLayout.contentTopPadding
    + previewTop
    + NotchHoldTrayLayout.previewHeight
  let actionTop = NotchHoldTrayLayout.contentTopPadding
    + NotchHoldTrayLayout.trayHeight
    + NotchHoldTrayLayout.bodySpacing
    + NotchHoldTrayLayout.actionRowOffsetY

  #expect(actionTop - previewBottom == 10)
}

@Test func holdScreenshotPreviewUsesWideCardProportions() {
  let availableWidth = NotchHoldTrayLayout.actionRowWidth(for: .left)
    - (NotchHoldTrayLayout.trayHorizontalPadding * 2)

  #expect(availableWidth == 120)
  #expect((availableWidth / NotchHoldTrayLayout.previewHeight) > 1.8)
}

@Test func holdTrayUsesLargerReadableType() {
  #expect(NotchHoldTrayLayout.titleFontSize == 12)
  #expect(NotchHoldTrayLayout.metadataFontSize == 10.5)
  #expect(NotchHoldTrayLayout.emptyIconSize == 20)
}

@Test func holdTrayEmptyTitleUsesTwoLinesToAvoidTruncatingCopy() {
  #expect(NotchHoldTrayLayout.emptyTitle == "Drop\nhere")
  #expect(NotchHoldTrayLayout.emptyTitle.split(separator: "\n").count == 2)
  #expect(NotchHoldTrayLayout.emptySubtitle == "ss · text · code")
}

@Test func holdTrayEmptyHeadlineKeepsIconBesideTitleAndCenteredOverSubtitle() {
  #expect(NotchHoldTrayLayout.emptyIconSize > NotchHoldTrayLayout.titleFontSize)
  #expect(NotchHoldTrayLayout.emptyIconFrameWidth == 24)
  #expect(NotchHoldTrayLayout.emptyHeadlineSpacing == 7)
  #expect(NotchHoldTrayLayout.emptyStackSpacing == 3)
}

@Test func holdTrayEmptyContentAlignsLowerWithMusicContent() {
  #expect(NotchHoldTrayLayout.emptyTrayTopOffsetY == 24)
  #expect(NotchHoldTrayLayout.emptyContentOffsetY == 5)
  #expect(NotchHoldTrayLayout.trayTopOffset(hasVisibleItem: false) == 24)
  #expect(NotchHoldTrayLayout.trayTopOffset(hasVisibleItem: true) == 0)
}

@Test func holdTrayDoesNotDrawOuterLightRectangle() {
  #expect(!NotchHoldTrayLayout.showsOuterBorder)
}

@Test func holdActionButtonsDoNotDrawLightRectangles() {
  #expect(!NotchHoldTrayLayout.showsActionButtonBorder)
}

@Test func holdActionButtonsUseCompactMusicAlignedMetrics() {
  #expect(NotchHoldTrayLayout.actionButtonSize == NotchUtilityMusicLayout.transportButtonHeight)
  #expect(NotchHoldTrayLayout.actionButtonSize < FlowlineDesign.Metrics.iconButtonSize)
  #expect(NotchHoldTrayLayout.actionIconFontSize == 10)
  #expect(NotchHoldTrayLayout.actionLabelFontSize == 6.5)
  #expect(NotchHoldTrayLayout.actionButtonContentSpacing == 1)
  #expect(NotchHoldTrayLayout.actionRowOffsetY == 8)
}

@Test func holdActionRowSitsLowerWhileKeepingTheColumnFilled() {
  let rowTop = NotchHoldTrayLayout.contentTopPadding
    + NotchHoldTrayLayout.trayHeight
    + NotchHoldTrayLayout.bodySpacing

  #expect(rowTop == 80)
  #expect(NotchHoldTrayLayout.contentBottomPadding == 0)
}

@Test func holdActionRowVisuallyDropsToMusicControlCenter() {
  let visualCenterY = NotchHoldTrayLayout.contentTopPadding
    + NotchHoldTrayLayout.trayHeight
    + NotchHoldTrayLayout.bodySpacing
    + NotchHoldTrayLayout.actionRowOffsetY
    + (NotchHoldTrayLayout.actionButtonSize / 2)

  #expect(visualCenterY == 100)
}

@Test func holdActionRowUsesMusicWidthWhenHoldIsRightSideModule() {
  #expect(NotchHoldTrayLayout.actionRowWidth(for: .right) == CGFloat(NotchMetrics.musicTimelineWidth))
  #expect(
    NotchHoldTrayLayout.actionRowLeadingOffset(for: .right)
      + NotchHoldTrayLayout.contentHorizontalPadding
      == NotchUtilityMusicLayout.leadingInset()
  )
}

@Test func holdTrayAndActionRowShareStableHorizontalMetrics() {
  let leftWidth = CGFloat(NotchMetrics.contextColumnWidth) - (NotchHoldTrayLayout.contentHorizontalPadding * 2)
  let rightWidth = CGFloat(NotchMetrics.musicTimelineWidth)

  #expect(NotchHoldTrayLayout.actionRowWidth(for: .left) == leftWidth)
  #expect(NotchHoldTrayLayout.actionRowWidth(for: .right) == rightWidth)
  #expect(NotchHoldTrayLayout.actionRowLeadingOffset(for: .left) == 0)
  #expect(NotchHoldTrayLayout.actionRowLeadingOffset(for: .right) > 0)
}

@Test func holdActionRowFitsLeftSideModule() {
  let availableWidth = CGFloat(NotchMetrics.contextColumnWidth) - (NotchHoldTrayLayout.contentHorizontalPadding * 2)

  #expect(NotchHoldTrayLayout.actionRowWidth(for: .left) == availableWidth)
  #expect(NotchHoldTrayLayout.actionRowLeadingOffset(for: .left) == 0)
  #expect((NotchHoldTrayLayout.actionButtonSize * 3) <= availableWidth)
}

@Test func holdTrayFitsWithActionButtonsInsideLeftColumnHeight() {
  let occupiedHeight = NotchHoldTrayLayout.contentTopPadding
    + NotchHoldTrayLayout.trayHeight
    + NotchHoldTrayLayout.bodySpacing
    + NotchHoldTrayLayout.actionButtonSize
    + NotchHoldTrayLayout.contentBottomPadding

  #expect(occupiedHeight <= CGFloat(NotchMetrics.expandedContentHeight))
  #expect(occupiedHeight == CGFloat(NotchMetrics.expandedContentHeight))
}

@Test func holdTrayEmptyDropTargetFitsAfterLowerAlignment() {
  let occupiedHeight = NotchHoldTrayLayout.contentTopPadding
    + NotchHoldTrayLayout.emptyTrayTopOffsetY
    + NotchHoldTrayLayout.trayHeight
    + NotchHoldTrayLayout.contentBottomPadding

  #expect(occupiedHeight <= CGFloat(NotchMetrics.expandedContentHeight))
}

@Test func holdTrayDefinesRecessedDropFeedback() {
  #expect(NotchHoldTrayLayout.recessedContentScale == 0.965)
  #expect(NotchHoldTrayLayout.recessedContentDropY == 2)
  #expect(NotchHoldTrayLayout.recessedDepthOpacity == 0.18)
  #expect(NotchHoldTrayLayout.dropLandingDurationMilliseconds == 180)
}

@Test func holdTrayInlinePreviewFitsInsideTrayWithoutCoveringActions() {
  let previewHeight = (NotchHoldTrayLayout.inlinePreviewVerticalPadding * 2)
    + (NotchHoldTrayLayout.inlinePreviewFontSize * CGFloat(NotchHoldTrayLayout.inlinePreviewMaxLines))
    + (NotchHoldTrayLayout.inlinePreviewLineSpacing * CGFloat(NotchHoldTrayLayout.inlinePreviewMaxLines - 1))

  #expect(NotchHoldTrayLayout.inlinePreviewHeight == NotchHoldTrayLayout.previewHeight)
  #expect(NotchHoldTrayLayout.inlinePreviewOffsetY == NotchHoldTrayLayout.previewOffsetY)
  #expect(!NotchHoldTrayLayout.showsFloatingPeek)
  #expect(previewHeight <= NotchHoldTrayLayout.inlinePreviewHeight)
}

@Test func holdIconCardUsesWideCenteredMediaSurface() {
  let availableWidth = CGFloat(NotchMetrics.contextColumnWidth) - (NotchHoldTrayLayout.contentHorizontalPadding * 2)
  let mediaWidth = availableWidth - (NotchHoldTrayLayout.trayHorizontalPadding * 2)

  #expect(mediaWidth == 120)
  #expect(NotchHoldTrayLayout.iconCardSymbolFontSize > 12)
  #expect(NotchHoldTrayLayout.iconCardSymbolFontSize < NotchHoldTrayLayout.previewMediaHeight / 2)
}

@Test func holdStackBadgeStaysDetachedFromCaptionArea() {
  #expect(NotchHoldTrayLayout.stackBadgeTopInset == 5)
  #expect(NotchHoldTrayLayout.stackBadgeTrailingInset == 6)
  #expect(NotchHoldTrayLayout.stackBadgeWidth < NotchHoldTrayLayout.previewMediaHeight)
  #expect(NotchHoldTrayLayout.stackBadgeHeight < NotchHoldTrayLayout.previewMediaHeight / 2)
  #expect(NotchHoldTrayLayout.stackBadgeFontSize < NotchHoldTrayLayout.metadataFontSize)
}

@Test func holdInlineHoverPreviewSharesCardCenter() {
  let cardCenter = ((NotchHoldTrayLayout.trayHeight - NotchHoldTrayLayout.previewHeight) / 2)
    + NotchHoldTrayLayout.previewOffsetY
    + (NotchHoldTrayLayout.previewHeight / 2)
  let inlineCenter = ((NotchHoldTrayLayout.trayHeight - NotchHoldTrayLayout.inlinePreviewHeight) / 2)
    + NotchHoldTrayLayout.inlinePreviewOffsetY
    + (NotchHoldTrayLayout.inlinePreviewHeight / 2)

  #expect(inlineCenter == cardCenter)
}
