import FlowlineCore
import SwiftUI

enum NotchHoldTrayLayout {
  static let bodySpacing: CGFloat = 16
  static let contentHorizontalPadding: CGFloat = 6
  static let contentTopPadding: CGFloat = 2
  static let contentBottomPadding: CGFloat = 0
  static let trayHeight: CGFloat = 62
  static let trayHorizontalPadding: CGFloat = 8
  static let previewTextSpacing: CGFloat = 7
  static let previewWidth: CGFloat = 56
  static let previewHeight: CGFloat = 66
  static let previewMediaHeight: CGFloat = 48
  static let previewOffsetY: CGFloat = 12
  static let previewCornerRadius: CGFloat = 3
  static let previewCaptionSpacing: CGFloat = 2
  static let screenshotPreviewCaptionSpacing: CGFloat = 5
  static let previewCaptionHorizontalInset: CGFloat = 1
  static let screenshotPreviewOverlayHorizontalPadding: CGFloat = 7
  static let screenshotPreviewOverlayVerticalPadding: CGFloat = 5
  static let textCardPreviewLineFontSize: CGFloat = 5.4
  static let textCardPreviewLineSpacing: CGFloat = 1.7
  static let textCardPreviewContentPadding: CGFloat = 7
  static let textCardPreviewBadgeFontSize: CGFloat = 8.5
  static let textCardPreviewDetailFontSize: CGFloat = 8
  static let iconCardSymbolFontSize: CGFloat = 20
  static let fileMarkWidth: CGFloat = 24
  static let fileMarkHeight: CGFloat = 31
  static let fileMarkCornerRadius: CGFloat = 5
  static let fileMarkStrokeWidth: CGFloat = 2
  static let fileMarkDetailWidth: CGFloat = 10
  static let stackBadgeWidth: CGFloat = 28
  static let stackBadgeHeight: CGFloat = 16
  static let stackBadgeTopInset: CGFloat = 5
  static let stackBadgeTrailingInset: CGFloat = 6
  static let stackBadgeIconFontSize: CGFloat = 7
  static let stackBadgeFontSize: CGFloat = 8.5
  static let minimumTextWidth: CGFloat = 36
  static let titleFontSize: CGFloat = 12
  static let metadataFontSize: CGFloat = 10.5
  static let emptyIconSize: CGFloat = 20
  static let emptyIconFrameWidth: CGFloat = 24
  static let emptyHeadlineSpacing: CGFloat = 7
  static let emptyStackSpacing: CGFloat = 3
  static let textPreviewFontSize: CGFloat = 4.4
  static let textPreviewLineSpacing: CGFloat = 1.2
  static let textPreviewPadding: CGFloat = 4
  static let inlinePreviewMaxLines = HoldPreviewPresentation.maxInlinePreviewLines
  static let inlinePreviewFontSize: CGFloat = 7.1
  static let inlinePreviewLineSpacing: CGFloat = 1.5
  static let inlinePreviewVerticalPadding: CGFloat = 6
  static let inlinePreviewHeight: CGFloat = previewHeight
  static let inlinePreviewOffsetY: CGFloat = previewOffsetY
  static let showsFloatingPeek = false
  static let emptyTitle = "Drop\nhere"
  static let emptySubtitle = "ss · text · code"
  static let emptyTrayTopOffsetY: CGFloat = 24
  static let emptyContentOffsetY: CGFloat = 5
  static let recessedContentScale: CGFloat = 0.965
  static let recessedContentDropY: CGFloat = 2
  static let recessedDepthOpacity = 0.18
  static let recessedRimOpacity = 0.42
  static let recessedHighlightOpacity = 0.16
  static let dropLandingDurationMilliseconds = 180
  static let showsOuterBorder = false
  static let showsActionButtonBorder = false
  static let actionButtonSize: CGFloat = NotchUtilityMusicLayout.transportButtonHeight
  static let actionIconFontSize: CGFloat = 10
  static let actionLabelFontSize: CGFloat = 6.5
  static let actionButtonContentSpacing: CGFloat = 1
  static let actionRowOffsetY: CGFloat = 8

  static func actionRowWidth(for placement: FlowlineModulePlacement) -> CGFloat {
    switch placement {
    case .left:
      return CGFloat(NotchMetrics.contextColumnWidth) - (contentHorizontalPadding * 2)
    case .right:
      return CGFloat(NotchMetrics.musicTimelineWidth)
    }
  }

  static func actionRowLeadingOffset(for placement: FlowlineModulePlacement) -> CGFloat {
    switch placement {
    case .left:
      return 0
    case .right:
      return max(0, NotchUtilityMusicLayout.leadingInset() - contentHorizontalPadding)
    }
  }

  static func trayTopOffset(hasVisibleItem: Bool) -> CGFloat {
    hasVisibleItem ? 0 : emptyTrayTopOffsetY
  }
}
