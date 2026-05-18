import Foundation

public enum FlowlineModule: String, CaseIterable, Sendable {
  case context
  case music
  case calendar
  case shelf
}

public enum FlowlineModulePlacement: String, Sendable {
  case left
  case right
}

public enum FlowlineModuleRejectionReason: Sendable {
  case maximumEnabled
  case sideSlotUnavailable
}

public struct FlowlineModulePreferences: Equatable, Sendable {
  public var context: Bool
  public var music: Bool
  public var calendar: Bool
  public var shelf: Bool

  public init(context: Bool, music: Bool, calendar: Bool, shelf: Bool) {
    self.context = context
    self.music = music
    self.calendar = calendar
    self.shelf = shelf
  }

  public static let defaults = FlowlineModulePreferences(
    context: false,
    music: true,
    calendar: false,
    shelf: true
  )

  public var enabledCount: Int {
    FlowlineModule.allCases.reduce(0) { count, module in
      count + (isEnabled(module) ? 1 : 0)
    }
  }

  public func isEnabled(_ module: FlowlineModule) -> Bool {
    switch module {
    case .context:
      return context
    case .music:
      return music
    case .calendar:
      return calendar
    case .shelf:
      return shelf
    }
  }

  public mutating func set(_ module: FlowlineModule, enabled: Bool) {
    switch module {
    case .context:
      context = enabled
    case .music:
      music = enabled
    case .calendar:
      calendar = enabled
    case .shelf:
      shelf = enabled
    }
  }
}

public enum FlowlineModuleSelection {
  public static let maximumEnabledCount = 2

  public static func canEnable(_ module: FlowlineModule, in preferences: FlowlineModulePreferences) -> Bool {
    rejectionReason(for: module, in: preferences) == nil
  }

  public static func rejectionReason(
    for module: FlowlineModule,
    in preferences: FlowlineModulePreferences
  ) -> FlowlineModuleRejectionReason? {
    guard !preferences.isEnabled(module) else {
      return nil
    }

    var nextPreferences = preferences
    nextPreferences.set(module, enabled: true)

    if nextPreferences.enabledCount > maximumEnabledCount {
      return .maximumEnabled
    }

    if sidePlacements(in: nextPreferences).count < nextPreferences.enabledCount {
      return .sideSlotUnavailable
    }

    return nil
  }

  public static func isValid(_ preferences: FlowlineModulePreferences) -> Bool {
    preferences.enabledCount <= maximumEnabledCount
      && sidePlacements(in: preferences).count == preferences.enabledCount
  }

  public static func supportedPlacements(for module: FlowlineModule) -> [FlowlineModulePlacement] {
    switch module {
    case .context:
      return [.left]
    case .shelf:
      return [.left, .right]
    case .music:
      return [.right]
    case .calendar:
      return [.right, .left]
    }
  }

  public static func placement(
    for module: FlowlineModule,
    in preferences: FlowlineModulePreferences
  ) -> FlowlineModulePlacement? {
    guard preferences.isEnabled(module) else {
      return nil
    }

    return sidePlacements(in: preferences)[module]
  }

  public static func sidePlacements(in preferences: FlowlineModulePreferences) -> [FlowlineModule: FlowlineModulePlacement] {
    var placements: [FlowlineModule: FlowlineModulePlacement] = [:]
    var occupied: Set<FlowlineModulePlacement> = []

    for module in FlowlineModule.allCases where preferences.isEnabled(module) {
      guard let placement = firstAvailablePlacement(for: module, occupied: occupied) else {
        continue
      }

      placements[module] = placement
      occupied.insert(placement)
    }

    return placements
  }

  private static func firstAvailablePlacement(
    for module: FlowlineModule,
    occupied: Set<FlowlineModulePlacement>
  ) -> FlowlineModulePlacement? {
    supportedPlacements(for: module).first { !occupied.contains($0) }
  }
}
