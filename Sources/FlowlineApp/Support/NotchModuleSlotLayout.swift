import FlowlineCore

enum NotchModuleSlot: Equatable, Sendable {
  case context
  case calendar
  case music
  case shelf
}

struct NotchModuleSlotLayout: Equatable, Sendable {
  let left: NotchModuleSlot?
  let right: NotchModuleSlot?

  static func layout(for preferences: FlowlineModulePreferences) -> NotchModuleSlotLayout {
    NotchModuleSlotLayout(
      left: module(at: .left, for: preferences),
      right: module(at: .right, for: preferences)
    )
  }

  private static func module(
    at placement: FlowlineModulePlacement,
    for preferences: FlowlineModulePreferences
  ) -> NotchModuleSlot? {
    let placements = FlowlineModuleSelection.sidePlacements(in: preferences)
    guard let module = FlowlineModule.allCases.first(where: { placements[$0] == placement }) else {
      return nil
    }

    switch module {
    case .context:
      return .context
    case .calendar:
      return .calendar
    case .music:
      return .music
    case .shelf:
      return .shelf
    }
  }
}
