import AppKit
import FlowlineCore
import Testing
@testable import FlowlineApp

@Test func expandedHoldDropTargetCoversFullLeftColumn() {
  let preferences = FlowlineModulePreferences(context: false, music: true, calendar: false, shelf: true)

  #expect(OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: 20, y: 20), preferences: preferences))
  #expect(OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: 20, y: NotchMetrics.expandedHeight - 8), preferences: preferences))
  #expect(OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: NotchMetrics.contextColumnWidth + 28, y: 72), preferences: preferences))
}

@Test func expandedHoldDropTargetRejectsMusicColumn() {
  let preferences = FlowlineModulePreferences(context: false, music: true, calendar: false, shelf: true)

  #expect(!OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: NotchMetrics.expandedWidth - 40, y: 72), preferences: preferences))
}

@Test func expandedHoldDropTargetMovesToRightWhenHoldUsesRightSlot() {
  let preferences = FlowlineModulePreferences(context: true, music: false, calendar: false, shelf: true)

  #expect(!OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: 20, y: 72), preferences: preferences))
  #expect(OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: NotchMetrics.expandedWidth - 40, y: 72), preferences: preferences))
}

@Test func expandedHoldDropTargetRejectsWhenHoldIsDisabled() {
  let preferences = FlowlineModulePreferences(context: true, music: false, calendar: false, shelf: false)

  #expect(!OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: 20, y: 72), preferences: preferences))
  #expect(!OverlayHoldDropTarget.containsExpandedHoldDrop(NSPoint(x: NotchMetrics.expandedWidth - 40, y: 72), preferences: preferences))
}
