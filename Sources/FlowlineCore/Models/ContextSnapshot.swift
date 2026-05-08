import Foundation

public struct ContextSnapshot: Equatable, Sendable {
  public var activeApp: ActiveAppContext
  public var git: GitStatus?
  public var nextEvent: CalendarEvent?
  public var shelfItems: [ShelfItem]
  public var permissions: PermissionState

  public init(
    activeApp: ActiveAppContext,
    git: GitStatus?,
    nextEvent: CalendarEvent?,
    shelfItems: [ShelfItem],
    permissions: PermissionState
  ) {
    self.activeApp = activeApp
    self.git = git
    self.nextEvent = nextEvent
    self.shelfItems = shelfItems
    self.permissions = permissions
  }

  public static let empty = ContextSnapshot(
    activeApp: ActiveAppContext(name: "Flowline", bundleIdentifier: nil, windowTitle: nil),
    git: nil,
    nextEvent: nil,
    shelfItems: [],
    permissions: PermissionState(accessibility: .notDetermined, calendar: .notDetermined)
  )

  public var primaryTitle: String {
    if let windowTitle = activeApp.windowTitle, !windowTitle.isEmpty {
      return windowTitle
    }

    return activeApp.name
  }

  public var primaryDetail: String {
    if let git {
      return git.isDirty ? "\(git.branch) with changes" : git.branch
    }

    if let nextEvent {
      return "Next: \(nextEvent.title)"
    }

    return activeApp.isDeveloperApp ? "Developer context ready" : "Local context"
  }

  public var compactLine: String {
    var parts = [activeApp.name]

    if let git {
      parts.append(git.branch)
    } else if let windowTitle = activeApp.windowTitle, !windowTitle.isEmpty {
      parts.append(windowTitle)
    } else if activeApp.isDeveloperApp {
      parts.append("Developer")
    }

    return parts.joined(separator: " · ")
  }

  public var statusItems: [String] {
    var items: [String] = []

    if permissions.accessibility != .granted {
      items.append("Accessibility")
    }

    if permissions.calendar == .denied {
      items.append("Calendar")
    }

    return items
  }
}
