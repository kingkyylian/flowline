import FlowlineCore
import Foundation

enum CalendarModuleTone: Equatable, Sendable {
  case active
  case secondary
  case warning
}

struct CalendarModuleChip: Equatable, Sendable {
  var label: String
  var tone: CalendarModuleTone
  var help: String
}

enum CalendarModulePresentation {
  static func settingsDetail(
    isEnabled: Bool,
    permission: PermissionAccess,
    nextEvent: CalendarEvent?
  ) -> String {
    guard isEnabled else {
      return "Meeting actions"
    }

    guard permission == .granted else {
      return "Needs permission"
    }

    guard let nextEvent else {
      return "No event"
    }

    return "Next \(compactTime(for: nextEvent.startDate))"
  }

  static func chip(
    isEnabled: Bool,
    permission: PermissionAccess,
    nextEvent: CalendarEvent?
  ) -> CalendarModuleChip? {
    guard isEnabled else {
      return nil
    }

    guard permission == .granted else {
      return CalendarModuleChip(label: "ASK", tone: .warning, help: "Calendar permission needed")
    }

    guard let nextEvent else {
      return CalendarModuleChip(label: "IDLE", tone: .secondary, help: "Calendar on, no upcoming event")
    }

    return CalendarModuleChip(
      label: compactTime(for: nextEvent.startDate),
      tone: .active,
      help: nextEvent.title
    )
  }

  static func compactTime(for date: Date) -> String {
    compactTimeFormatter.string(from: date)
  }

  private static let compactTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
  }()
}
