import SwiftUI

enum NotchAgentColumnLayout {
  static let headerLift: CGFloat = 12
  static let usageRowComponentSpacing: CGFloat = 4
  static let usageProviderLabelWidth: CGFloat = 40
  static let usageProviderLabelFontSize: CGFloat = 10.2
  static let usageProviderLabelMinimumScaleFactor: CGFloat = 1
  static let usageWindowLabelFontSize: CGFloat = 8.2
  static let usageWindowLabelWidth: CGFloat = 7
  static let usagePercentFontSize: CGFloat = 9.5
  static let usagePercentWidth: CGFloat = 19
  static let usagePercentMinimumScaleFactor: CGFloat = 0.82
  static let usageChipWidth: CGFloat = 30
  static let usageChipHeight: CGFloat = 17
  static let usageResetIconFontSize: CGFloat = 8.2
  static let usageResetLabelFontSize: CGFloat = 9
  static let usageResetLabelMinimumScaleFactor: CGFloat = 0.78
  static let usageResetChipWidth: CGFloat = 31
  static let usageResetChipHeight: CGFloat = 17

  static func showsActions(
    hasUsageRows: Bool,
    showsUtilityActions: Bool,
    hasContextualActions: Bool
  ) -> Bool {
    guard !hasUsageRows else {
      return false
    }

    return showsUtilityActions || hasContextualActions
  }
}
