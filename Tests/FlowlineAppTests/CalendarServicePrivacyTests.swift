import Testing
@testable import FlowlineApp

@MainActor
@Test func calendarServiceTargetsTheCalendarPrivacyPaneWhenAccessWasDenied() {
  #expect(CalendarService.privacySettingsURL.absoluteString.contains("Privacy_Calendars"))
}
