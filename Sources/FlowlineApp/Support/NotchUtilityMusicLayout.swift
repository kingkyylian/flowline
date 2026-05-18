import FlowlineCore
import SwiftUI

enum NotchUtilityMusicLayout {
  static let headerLift: CGFloat = 22
  static let headerShiftX: CGFloat = 20
  static let transportButtonHeight: CGFloat = 24

  static func leadingInset(
    columnWidth: CGFloat = NotchMetrics.utilityColumnWidth,
    contentWidth: CGFloat = NotchMetrics.musicTimelineWidth,
    trailingInset: CGFloat = FlowlineDesign.Metrics.notchColumnPadding
  ) -> CGFloat {
    max(0, columnWidth - contentWidth - trailingInset)
  }
}

enum NotchHoldHeaderLayout {
  static let headerLift = NotchUtilityMusicLayout.headerLift
  static let headerShiftX: CGFloat = 0

  static func headerShiftX(for placement: FlowlineModulePlacement) -> CGFloat {
    switch placement {
    case .left:
      return headerShiftX
    case .right:
      return NotchUtilityMusicLayout.headerShiftX
    }
  }

  static func leadingInset(for placement: FlowlineModulePlacement) -> CGFloat {
    switch placement {
    case .left:
      return FlowlineDesign.Metrics.notchColumnPadding
    case .right:
      return NotchUtilityMusicLayout.leadingInset()
    }
  }
}

enum NotchWorkspaceHeaderLayout {
  static let headerLift = NotchHoldHeaderLayout.headerLift
  static let headerShiftX = NotchHoldHeaderLayout.headerShiftX
}

enum NotchCalendarLayout {
  static let headerLift = NotchUtilityMusicLayout.headerLift
  static let verticalPadding: CGFloat = 8

  static func headerShiftX(for placement: FlowlineModulePlacement) -> CGFloat {
    switch placement {
    case .left:
      return 0
    case .right:
      return NotchUtilityMusicLayout.headerShiftX
    }
  }

  static func contentWidth(for placement: FlowlineModulePlacement) -> CGFloat {
    switch placement {
    case .left:
      return max(0, NotchMetrics.contextColumnWidth - (FlowlineDesign.Metrics.notchColumnPadding * 2))
    case .right:
      return NotchMetrics.musicTimelineWidth
    }
  }

  static func leadingInset(for placement: FlowlineModulePlacement) -> CGFloat {
    switch placement {
    case .left:
      return FlowlineDesign.Metrics.notchColumnPadding
    case .right:
      return NotchUtilityMusicLayout.leadingInset(contentWidth: contentWidth(for: .right))
    }
  }

  static func trailingInset(for placement: FlowlineModulePlacement) -> CGFloat {
    FlowlineDesign.Metrics.notchColumnPadding
  }
}
