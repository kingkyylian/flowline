import FlowlineCore
import Testing
@testable import FlowlineApp

@Test func overlayModuleCountIncludesFixedLimitsModule() {
  let preferences = FlowlineModulePreferences(
    context: false,
    music: true,
    calendar: false,
    shelf: true
  )

  #expect(OverlayModuleCountPresentation.label(for: preferences) == "2/2 + Limits")
}

@Test func overlayModuleCountShowsFixedLimitsWhenOptionalModulesAreOff() {
  let preferences = FlowlineModulePreferences(
    context: false,
    music: false,
    calendar: false,
    shelf: false
  )

  #expect(OverlayModuleCountPresentation.label(for: preferences) == "0/2 + Limits")
}

@Test func overlayModuleCountCapsAtSideSlotCapacity() {
  let preferences = FlowlineModulePreferences(
    context: true,
    music: true,
    calendar: true,
    shelf: false
  )

  #expect(OverlayModuleCountPresentation.label(for: preferences) == "2/2 + Limits")
}
