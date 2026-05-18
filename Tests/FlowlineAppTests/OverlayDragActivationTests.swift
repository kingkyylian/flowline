import AppKit
import Testing
@testable import FlowlineApp
import FlowlineCore

@Test func expandsCollapsedNotchWhenHoldPayloadDragMovesIntoActivationFrame() throws {
  let frame = NSRect(x: 500, y: 850, width: 240, height: 44)

  #expect(
    OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: .leftMouseDragged,
      positionMode: .notch,
      isExpanded: false,
      hasHoldPayload: true,
      mouseLocation: NSPoint(x: 620, y: 870),
      collapsedFrame: frame
    )
  )
}

@MainActor
@Test func doesNotExpandCollapsedNotchForStaleGlobalDragPasteboardPayload() throws {
  let frame = NSRect(x: 500, y: 850, width: 240, height: 44)
  let pasteboard = NSPasteboard.withUniqueName()
  pasteboard.clearContents()
  pasteboard.declareTypes([.string], owner: nil)
  pasteboard.setString("previous terminal selection", forType: .string)

  #expect(
    !OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: .leftMouseDragged,
      positionMode: .notch,
      isExpanded: false,
      dragPasteboard: pasteboard,
      dragPasteboardBaselineChangeCount: pasteboard.changeCount,
      mouseLocation: NSPoint(x: 620, y: 870),
      collapsedFrame: frame
    )
  )
}

@MainActor
@Test func expandsCollapsedNotchForFreshGlobalDragPasteboardPayload() throws {
  let frame = NSRect(x: 500, y: 850, width: 240, height: 44)
  let pasteboard = NSPasteboard.withUniqueName()
  pasteboard.clearContents()
  let baselineChangeCount = pasteboard.changeCount
  pasteboard.declareTypes([.string], owner: nil)
  pasteboard.setString("fresh dragged text", forType: .string)

  #expect(
    OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: .leftMouseDragged,
      positionMode: .notch,
      isExpanded: false,
      dragPasteboard: pasteboard,
      dragPasteboardBaselineChangeCount: baselineChangeCount,
      mouseLocation: NSPoint(x: 620, y: 870),
      collapsedFrame: frame
    )
  )
}

@Test func doesNotExpandCollapsedNotchForPlainWindowDrag() throws {
  let frame = NSRect(x: 500, y: 850, width: 240, height: 44)

  #expect(
    !OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: .leftMouseDragged,
      positionMode: .notch,
      isExpanded: false,
      hasHoldPayload: false,
      mouseLocation: NSPoint(x: 620, y: 870),
      collapsedFrame: frame
    )
  )
}

@Test func doesNotExpandCollapsedNotchForPlainMouseMove() throws {
  let frame = NSRect(x: 500, y: 850, width: 240, height: 44)

  #expect(
    !OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: .mouseMoved,
      positionMode: .notch,
      isExpanded: false,
      hasHoldPayload: true,
      mouseLocation: NSPoint(x: 620, y: 870),
      collapsedFrame: frame
    )
  )
}

@Test func doesNotExpandCollapsedNotchWhenDragIsOutsideActivationFrame() throws {
  let frame = NSRect(x: 500, y: 850, width: 240, height: 44)

  #expect(
    !OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: .leftMouseDragged,
      positionMode: .notch,
      isExpanded: false,
      hasHoldPayload: true,
      mouseLocation: NSPoint(x: 100, y: 870),
      collapsedFrame: frame
    )
  )
}
