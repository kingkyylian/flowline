import AppKit
import SwiftUI

@MainActor
final class OverlayHostingView: NSHostingView<OverlayRootView> {
  private let state: AppState
  private var notchTrackingArea: NSTrackingArea?

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

  override func updateTrackingAreas() {
    if let notchTrackingArea {
      removeTrackingArea(notchTrackingArea)
    }

    let trackingArea = NSTrackingArea(
      rect: collapsedNotchFrame,
      options: [.mouseEnteredAndExited, .activeAlways],
      owner: self
    )
    addTrackingArea(trackingArea)
    notchTrackingArea = trackingArea

    super.updateTrackingAreas()
    syncNotchHoverState()
  }

  override func mouseEntered(with event: NSEvent) {
    guard state.positionMode == .notch, !state.isExpanded else {
      super.mouseEntered(with: event)
      return
    }

    state.isHovering = true
  }

  override func mouseExited(with event: NSEvent) {
    guard state.positionMode == .notch, !state.isExpanded else {
      super.mouseExited(with: event)
      return
    }

    state.isHovering = false
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

  private var collapsedNotchFrame: NSRect {
    NSRect(
      x: (bounds.width - state.physicalNotchWidth) / 2,
      y: bounds.height - state.physicalNotchHeight,
      width: state.physicalNotchWidth,
      height: state.physicalNotchHeight
    )
  }

  private func syncNotchHoverState() {
    guard state.positionMode == .notch, !state.isExpanded, let window else {
      return
    }

    let pointInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
    let pointInView = convert(pointInWindow, from: nil)
    state.isHovering = collapsedNotchFrame.contains(pointInView)
  }
}
