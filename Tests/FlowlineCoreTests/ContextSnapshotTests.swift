import Testing
@testable import FlowlineCore

@Test func buildsFallbackSnapshotWhenPermissionsAreMissing() throws {
  let snapshot = ContextSnapshot(
    activeApp: ActiveAppContext(name: "Code", bundleIdentifier: "com.microsoft.VSCode", windowTitle: nil),
    git: nil,
    nextEvent: nil,
    shelfItems: [],
    permissions: PermissionState(accessibility: .denied, calendar: .notDetermined)
  )

  #expect(snapshot.primaryTitle == "Code")
  #expect(snapshot.primaryDetail == "Developer context ready")
  #expect(snapshot.statusItems == ["Accessibility"])
}
