import AppKit
import SwiftUI

@MainActor
final class OverlayHostingView: NSHostingView<OverlayRootView> {
  private let state: AppState

  init(state: AppState) {
    self.state = state
    super.init(rootView: OverlayRootView(state: state))
  }

  @available(*, unavailable)
  required init(rootView: OverlayRootView) {
    fatalError("Use init(state:)")
  }

  @available(*, unavailable)
  required dynamic init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard state.positionMode == .notch else {
      return super.hitTest(point)
    }

    let size = state.isExpanded
      ? NSSize(width: NotchMetrics.expandedWidth, height: NotchMetrics.expandedHeight)
      : NSSize(width: state.physicalNotchWidth, height: state.physicalNotchHeight)

    let hitFrame = NSRect(
      x: (bounds.width - size.width) / 2,
      y: bounds.height - size.height,
      width: size.width,
      height: size.height
    ).insetBy(dx: state.isExpanded ? -4 : 0, dy: state.isExpanded ? -4 : 0)

    guard hitFrame.contains(point) else {
      return nil
    }

    return super.hitTest(point)
  }
}
