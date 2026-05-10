import Testing
@testable import FlowlineCore

@Test func defaultModulesPreferMusicAndDeferCalendar() throws {
  let modules = FlowlineModulePreferences.defaults

  #expect(!modules.context)
  #expect(modules.music)
  #expect(!modules.calendar)
  #expect(modules.shelf)
}
