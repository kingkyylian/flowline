import Foundation
import Testing
@testable import FlowlineApp
import FlowlineCore

@Test func calendarModulePresentationShowsOffState() {
  #expect(
    CalendarModulePresentation.settingsDetail(
      isEnabled: false,
      permission: .granted,
      nextEvent: nil
    ) == "Meeting actions"
  )

  #expect(
    CalendarModulePresentation.chip(
      isEnabled: false,
      permission: .granted,
      nextEvent: nil
    ) == nil
  )
}

@Test func calendarModulePresentationShowsPermissionState() {
  let chip = CalendarModulePresentation.chip(
    isEnabled: true,
    permission: .notDetermined,
    nextEvent: nil
  )

  #expect(CalendarModulePresentation.settingsDetail(isEnabled: true, permission: .notDetermined, nextEvent: nil) == "Needs permission")
  #expect(chip?.label == "ASK")
  #expect(chip?.tone == .warning)
}

@Test func calendarModulePresentationShowsIdleState() {
  let chip = CalendarModulePresentation.chip(
    isEnabled: true,
    permission: .granted,
    nextEvent: nil
  )

  #expect(CalendarModulePresentation.settingsDetail(isEnabled: true, permission: .granted, nextEvent: nil) == "No event")
  #expect(chip?.label == "IDLE")
  #expect(chip?.tone == .secondary)
}

@Test func calendarModulePresentationShowsNextEventTime() {
  let event = CalendarEvent(
    id: "event",
    title: "Design review",
    startDate: Date(timeIntervalSince1970: 1_800_000_000),
    meetingURL: URL(string: "https://meet.google.com/abc-defg-hij")
  )
  let chip = CalendarModulePresentation.chip(
    isEnabled: true,
    permission: .granted,
    nextEvent: event
  )

  #expect(CalendarModulePresentation.settingsDetail(isEnabled: true, permission: .granted, nextEvent: event).hasPrefix("Next "))
  #expect(chip?.label == CalendarModulePresentation.compactTime(for: event.startDate))
  #expect(chip?.tone == .active)
}
