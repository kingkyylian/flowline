import FlowlineCore
import Foundation

enum SettingsPanelCategory: String, CaseIterable, Identifiable {
  case general
  case hold
  case modules
  case shortcuts
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general:
      return "General"
    case .hold:
      return "Hold"
    case .modules:
      return "Modules"
    case .shortcuts:
      return "Shortcuts"
    case .about:
      return "About"
    }
  }

  var symbol: String {
    switch self {
    case .general:
      return "switch.2"
    case .hold:
      return "tray"
    case .modules:
      return "square.grid.2x2"
    case .shortcuts:
      return "command"
    case .about:
      return "info.circle"
    }
  }
}

struct SettingsModulePreviewItem: Equatable {
  enum Slot: Hashable {
    case left
    case center
    case right
  }

  let slot: Slot
  let title: String
  let symbol: String
  let isActive: Bool
}

enum SettingsModuleLayer: String, Identifiable {
  case left
  case right

  var id: String { rawValue }

  var title: String {
    switch self {
    case .left:
      return "Left layer"
    case .right:
      return "Right layer"
    }
  }
}

struct SettingsModuleLayerItem: Equatable, Identifiable {
  let module: FlowlineModule
  let title: String
  let detail: String

  var id: FlowlineModule { module }
}

struct SettingsModuleLayerSection: Equatable, Identifiable {
  let layer: SettingsModuleLayer
  let title: String
  let items: [SettingsModuleLayerItem]

  var id: SettingsModuleLayer { layer }
}

enum SettingsPermissionAction: Equatable {
  case requestAccessibility
  case requestCalendar
}

enum SettingsPermissionTone: Equatable {
  case success
  case danger
  case neutral
}

struct SettingsPermissionItem: Equatable {
  let title: String
  let requirement: String
  let statusLabel: String
  let symbol: String
  let tone: SettingsPermissionTone
  let action: SettingsPermissionAction?
}

struct SettingsPermissionHealth: Equatable {
  let title: String
  let subtitle: String
  let isReady: Bool
}

struct SettingsAboutInfo: Equatable {
  let appName: String
  let version: String
  let build: String
  let bundleIdentifier: String
  let githubURL: URL
  let releasesURL: URL
  let licenseURL: URL
  let licenseName: String
  let updateModeLabel: String

  var versionLabel: String {
    "\(version) (\(build))"
  }
}

enum SettingsPresentation {
  static let githubURL = URL(string: "https://github.com/kingkyylian/flowline")!
  static let releasesURL = URL(string: "https://github.com/kingkyylian/flowline/releases")!
  static let licenseURL = URL(string: "https://github.com/kingkyylian/flowline/blob/main/LICENSE")!

  static func modulePreviewItems(
    for preferences: FlowlineModulePreferences
  ) -> [SettingsModulePreviewItem] {
    let placements = FlowlineModuleSelection.sidePlacements(in: preferences)

    return [
      previewItem(for: .left, placements: placements),
      SettingsModulePreviewItem(
        slot: .center,
        title: "LIMITS",
        symbol: "gauge.medium",
        isActive: true
      ),
      previewItem(for: .right, placements: placements)
    ]
  }

  static func moduleLayerSections() -> [SettingsModuleLayerSection] {
    [
      SettingsModuleLayerSection(
        layer: .left,
        title: SettingsModuleLayer.left.title,
        items: [
          SettingsModuleLayerItem(module: .context, title: "Workspace", detail: "Left only"),
          SettingsModuleLayerItem(module: .shelf, title: "Hold", detail: "Left only")
        ]
      ),
      SettingsModuleLayerSection(
        layer: .right,
        title: SettingsModuleLayer.right.title,
        items: [
          SettingsModuleLayerItem(module: .music, title: "Music", detail: "Right only"),
          SettingsModuleLayerItem(module: .calendar, title: "Calendar", detail: "Right first")
        ]
      )
    ]
  }

  static func permissionItems(
    accessibility: PermissionAccess,
    calendar: PermissionAccess,
    preferences: FlowlineModulePreferences,
    holdAutoCaptureScreenshots: Bool
  ) -> [SettingsPermissionItem] {
    var items = [
      accessPermissionItem(
        title: "Accessibility",
        requirement: "Required",
        status: accessibility,
        deniedLabel: "Needs access",
        action: .requestAccessibility
      )
    ]

    if preferences.calendar {
      items.append(
        accessPermissionItem(
          title: "Calendar",
          requirement: "Module",
          status: calendar,
          deniedLabel: "Needs access",
          action: .requestCalendar
        )
      )
    }

    if preferences.music {
      items.append(
        SettingsPermissionItem(
          title: "Automation",
          requirement: "Module",
          statusLabel: "On demand",
          symbol: "arrow.triangle.2.circlepath",
          tone: .neutral,
          action: nil
        )
      )
    }

    if preferences.shelf && holdAutoCaptureScreenshots {
      items.append(
        SettingsPermissionItem(
          title: "Screenshot folder",
          requirement: "Hold",
          statusLabel: "On demand",
          symbol: "folder",
          tone: .neutral,
          action: nil
        )
      )
    }

    return items
  }

  static func permissionHealth(for items: [SettingsPermissionItem]) -> SettingsPermissionHealth {
    let neededCount = items.filter { $0.action != nil && $0.tone != .success }.count

    guard neededCount > 0 else {
      return SettingsPermissionHealth(
        title: "Core permissions ready",
        subtitle: "Active module access",
        isReady: true
      )
    }

    let label = neededCount == 1 ? "1 permission needed" : "\(neededCount) permissions needed"
    return SettingsPermissionHealth(
      title: label,
      subtitle: "Active module access",
      isReady: false
    )
  }

  static func currentAboutInfo(bundle: Bundle = .main) -> SettingsAboutInfo {
    aboutInfo(from: bundle.infoDictionary ?? [:])
  }

  static func aboutInfo(from infoDictionary: [String: Any]) -> SettingsAboutInfo {
    SettingsAboutInfo(
      appName: stringValue(for: "CFBundleName", in: infoDictionary, fallback: "Flowline"),
      version: stringValue(for: "CFBundleShortVersionString", in: infoDictionary, fallback: "0.1.0"),
      build: stringValue(for: "CFBundleVersion", in: infoDictionary, fallback: "1"),
      bundleIdentifier: stringValue(for: "CFBundleIdentifier", in: infoDictionary, fallback: "dev.kyylian.flowline"),
      githubURL: githubURL,
      releasesURL: releasesURL,
      licenseURL: licenseURL,
      licenseName: "MIT",
      updateModeLabel: "Manual"
    )
  }

  private static func previewItem(
    for slot: SettingsModulePreviewItem.Slot,
    placements: [FlowlineModule: FlowlineModulePlacement]
  ) -> SettingsModulePreviewItem {
    let placement = slot == .left ? FlowlineModulePlacement.left : .right
    guard let module = FlowlineModule.allCases.first(where: { placements[$0] == placement }) else {
      return SettingsModulePreviewItem(
        slot: slot,
        title: "OPEN",
        symbol: "plus",
        isActive: false
      )
    }

    return SettingsModulePreviewItem(
      slot: slot,
      title: title(for: module),
      symbol: symbol(for: module),
      isActive: true
    )
  }

  private static func title(for module: FlowlineModule) -> String {
    switch module {
    case .context:
      return "WORK"
    case .music:
      return "MUSIC"
    case .calendar:
      return "CAL"
    case .shelf:
      return "HOLD"
    }
  }

  private static func symbol(for module: FlowlineModule) -> String {
    switch module {
    case .context:
      return "terminal"
    case .music:
      return "waveform"
    case .calendar:
      return "calendar"
    case .shelf:
      return "tray"
    }
  }

  private static func accessPermissionItem(
    title: String,
    requirement: String,
    status: PermissionAccess,
    deniedLabel: String,
    action: SettingsPermissionAction
  ) -> SettingsPermissionItem {
    SettingsPermissionItem(
      title: title,
      requirement: requirement,
      statusLabel: statusLabel(for: status, deniedLabel: deniedLabel),
      symbol: symbol(for: status),
      tone: tone(for: status),
      action: action
    )
  }

  private static func statusLabel(for status: PermissionAccess, deniedLabel: String) -> String {
    switch status {
    case .granted:
      return "Granted"
    case .denied:
      return deniedLabel
    case .notDetermined:
      return "Not asked"
    }
  }

  private static func symbol(for status: PermissionAccess) -> String {
    switch status {
    case .granted:
      return "checkmark.circle.fill"
    case .denied:
      return "xmark.circle.fill"
    case .notDetermined:
      return "circle.dashed"
    }
  }

  private static func tone(for status: PermissionAccess) -> SettingsPermissionTone {
    switch status {
    case .granted:
      return .success
    case .denied:
      return .danger
    case .notDetermined:
      return .neutral
    }
  }

  private static func stringValue(
    for key: String,
    in infoDictionary: [String: Any],
    fallback: String
  ) -> String {
    guard let value = infoDictionary[key] as? String,
          !value.isEmpty else {
      return fallback
    }

    return value
  }
}
