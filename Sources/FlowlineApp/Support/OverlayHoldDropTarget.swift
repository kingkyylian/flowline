import AppKit
import FlowlineCore

enum OverlayHoldDropTarget {
  static func containsExpandedHoldDrop(_ point: NSPoint, preferences: FlowlineModulePreferences) -> Bool {
    let layout = NotchModuleSlotLayout.layout(for: preferences)
    return holdFrames(for: layout).contains { $0.contains(point) }
  }

  private static func holdFrames(for layout: NotchModuleSlotLayout) -> [NSRect] {
    if layout.left == .shelf {
      return [leftHoldFrame]
    }

    return []
  }

  private static var leftHoldFrame: NSRect {
    NSRect(
      x: 0,
      y: 0,
      width: NotchMetrics.contextColumnWidth + 40,
      height: NotchMetrics.expandedHeight
    ).insetBy(dx: -8, dy: -8)
  }

}
