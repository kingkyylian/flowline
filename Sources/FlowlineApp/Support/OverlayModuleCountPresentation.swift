import FlowlineCore

enum OverlayModuleCountPresentation {
  static func label(for preferences: FlowlineModulePreferences) -> String {
    "\(visibleCount(for: preferences))/\(FlowlineModuleSelection.maximumEnabledCount) + Limits"
  }

  static func visibleCount(for preferences: FlowlineModulePreferences) -> Int {
    min(
      FlowlineModuleSelection.maximumEnabledCount,
      preferences.enabledCount
    )
  }
}
