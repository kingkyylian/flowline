import Foundation

enum NotchMetrics {
  static let windowWidth = 600.0
  static let collapsedHeight = 32.0
  static let expandedHeight = 154.0
  static let fallbackPhysicalWidth = 179.0
  static let companionFallbackWidth = 260.0
  static let hoverWidth = 235.0
  static let expandedWidth = 600.0
  static let expandedContentWidth = 560.0
  static let expandedContentHeight = 104.0
  static let contextColumnWidth = 138.0
  static let agentColumnWidth = 212.0
  static let utilityColumnWidth = 194.0

  static var collapsedWidth: Double {
    fallbackPhysicalWidth
  }
}
