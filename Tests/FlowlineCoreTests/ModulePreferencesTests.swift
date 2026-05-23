import Testing
@testable import FlowlineCore

@Test func defaultModulesPreferMusicAndDeferCalendar() throws {
  let modules = FlowlineModulePreferences.defaults

  #expect(!modules.context)
  #expect(modules.music)
  #expect(!modules.calendar)
  #expect(modules.shelf)
}

@Test func moduleSelectionRejectsThirdOptionalModule() throws {
  let modules = FlowlineModulePreferences(
    context: true,
    music: true,
    calendar: false,
    shelf: false
  )

  #expect(!FlowlineModuleSelection.canEnable(.calendar, in: modules))
  #expect(FlowlineModuleSelection.rejectionReason(for: .calendar, in: modules) == .maximumEnabled)
}

@Test func modulesAdvertiseSupportedSidePlacements() throws {
  #expect(FlowlineModuleSelection.supportedPlacements(for: .context) == [.left])
  #expect(FlowlineModuleSelection.supportedPlacements(for: .music) == [.right])
  #expect(FlowlineModuleSelection.supportedPlacements(for: .calendar) == [.right, .left])
  #expect(FlowlineModuleSelection.supportedPlacements(for: .shelf) == [.left])
}

@Test func modulePlacementUsesOnlySideSlotsWithCalendarOnTheSide() throws {
  let modules = FlowlineModulePreferences(
    context: true,
    music: false,
    calendar: true,
    shelf: false
  )

  #expect(FlowlineModuleSelection.placement(for: .context, in: modules) == .left)
  #expect(FlowlineModuleSelection.placement(for: .calendar, in: modules) == .right)
}

@Test func modulePlacementKeepsHoldOnlyInTheLeftColumn() throws {
  let leftHold = FlowlineModulePreferences(context: false, music: true, calendar: false, shelf: true)
  let unavailableHold = FlowlineModulePreferences(context: true, music: false, calendar: false, shelf: true)

  #expect(FlowlineModuleSelection.placement(for: .shelf, in: leftHold) == .left)
  #expect(FlowlineModuleSelection.placement(for: .shelf, in: unavailableHold) == nil)
  #expect(FlowlineModuleSelection.placement(for: .context, in: unavailableHold) == .left)
  #expect(!FlowlineModuleSelection.isValid(unavailableHold))
}
