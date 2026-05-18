import AppKit
import Combine
import EventKit
import FlowlineCore
import Foundation

@MainActor
final class CalendarService: ObservableObject {
  static let privacySettingsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
  )!

  @Published private(set) var nextEvent: CalendarEvent?
  @Published private(set) var permission: PermissionAccess = .notDetermined

  private let store = EKEventStore()
  private var timer: Timer?

  func start() {
    refreshPermission()
    refreshNextEvent()

    guard timer == nil else {
      return
    }

    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refreshNextEvent()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  isolated deinit {
    timer?.invalidate()
  }

  func requestAccess() {
    refreshPermission()

    guard permission != .granted else {
      return
    }

    if permission == .denied {
      NSWorkspace.shared.open(Self.privacySettingsURL)
      return
    }

    if #available(macOS 14.0, *) {
      store.requestFullAccessToEvents { [weak self] _, _ in
        Task { @MainActor in
          self?.refreshPermission()
          self?.refreshNextEvent()
        }
      }
    } else {
      store.requestAccess(to: .event) { [weak self] _, _ in
        Task { @MainActor in
          self?.refreshPermission()
          self?.refreshNextEvent()
        }
      }
    }
  }

  private func refreshPermission() {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .authorized, .fullAccess:
      permission = .granted
    case .notDetermined:
      permission = .notDetermined
    default:
      permission = .denied
    }
  }

  private func refreshNextEvent() {
    guard permission == .granted else {
      nextEvent = nil
      return
    }

    let now = Date()
    let end = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
    let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)

    nextEvent = store.events(matching: predicate)
      .filter { !$0.isAllDay && $0.endDate > now }
      .min { $0.startDate < $1.startDate }
      .map {
        CalendarEvent(
          id: $0.eventIdentifier,
          title: $0.title,
          startDate: $0.startDate,
          meetingURL: URLDetectors.firstMeetingURL(in: [$0.location, $0.notes].compactMap { $0 }.joined(separator: "\n"))
        )
      }
  }
}
