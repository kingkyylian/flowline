import FlowlineCore
import Testing
@testable import FlowlineApp

@Test func notchSlotLayoutDoesNotShowHoldWhenHoldModuleIsDisabled() {
  let layout = NotchModuleSlotLayout.layout(
    for: FlowlineModulePreferences(context: false, music: false, calendar: false, shelf: false)
  )

  #expect(layout.left == nil)
  #expect(layout.right == nil)
}

@Test func notchSlotLayoutShowsHoldOnlyOnceWhenBothSideModulesAreOff() {
  let layout = NotchModuleSlotLayout.layout(
    for: FlowlineModulePreferences(context: false, music: false, calendar: false, shelf: true)
  )

  #expect(layout.left == .shelf)
  #expect(layout.right == nil)
}

@Test func notchSlotLayoutDoesNotMoveHoldToRightWhenWorkspaceUsesLeftSlot() {
  let layout = NotchModuleSlotLayout.layout(
    for: FlowlineModulePreferences(context: true, music: false, calendar: false, shelf: true)
  )

  #expect(layout.left == .context)
  #expect(layout.right == nil)
}

@Test func notchSlotLayoutPlacesCalendarOnRightWhenWorkspaceUsesLeftSlot() {
  let layout = NotchModuleSlotLayout.layout(
    for: FlowlineModulePreferences(context: true, music: false, calendar: true, shelf: false)
  )

  #expect(layout.left == .context)
  #expect(layout.right == .calendar)
}

@Test func notchSlotLayoutPlacesCalendarOnLeftWhenMusicUsesRightSlot() {
  let layout = NotchModuleSlotLayout.layout(
    for: FlowlineModulePreferences(context: false, music: true, calendar: true, shelf: false)
  )

  #expect(layout.left == .calendar)
  #expect(layout.right == .music)
}
