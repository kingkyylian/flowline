import AppKit
import FlowlineCore

enum OverlayDragActivation {
  static func shouldExpandCollapsedNotch(
    eventType: NSEvent.EventType,
    positionMode: PositionMode,
    isExpanded: Bool,
    dragPasteboard: NSPasteboard?,
    dragPasteboardBaselineChangeCount: Int? = nil,
    mouseLocation: NSPoint,
    collapsedFrame: NSRect
  ) -> Bool {
    shouldExpandCollapsedNotch(
      eventType: eventType,
      positionMode: positionMode,
      isExpanded: isExpanded,
      hasHoldPayload: hasFreshHoldPayload(
        in: dragPasteboard,
        baselineChangeCount: dragPasteboardBaselineChangeCount
      ),
      mouseLocation: mouseLocation,
      collapsedFrame: collapsedFrame
    )
  }

  static func shouldExpandCollapsedNotch(
    eventType: NSEvent.EventType,
    positionMode: PositionMode,
    isExpanded: Bool,
    hasHoldPayload: Bool,
    mouseLocation: NSPoint,
    collapsedFrame: NSRect
  ) -> Bool {
    guard positionMode == .notch, !isExpanded else {
      return false
    }

    guard hasHoldPayload else {
      return false
    }

    guard eventType == .leftMouseDragged || eventType == .rightMouseDragged else {
      return false
    }

    return collapsedFrame.contains(mouseLocation)
  }

  private static func hasFreshHoldPayload(
    in pasteboard: NSPasteboard?,
    baselineChangeCount: Int?
  ) -> Bool {
    guard let pasteboard else {
      return false
    }

    if let baselineChangeCount, pasteboard.changeCount == baselineChangeCount {
      return false
    }

    return HoldDropPayloadDetector.hasHoldPayload(in: pasteboard)
  }
}
