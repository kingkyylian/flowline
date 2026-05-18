import FlowlineCore
import Testing
@testable import FlowlineApp

@Test func settingsUsesFocusedCategoriesWithoutChangingThePanelLanguage() {
  #expect(SettingsPanelCategory.allCases.map(\.title) == [
    "General",
    "Hold",
    "Modules",
    "Shortcuts",
    "About"
  ])
}

@Test func settingsAboutInfoReadsReleaseMetadataAndGithubURL() throws {
  let info = SettingsPresentation.aboutInfo(from: [
    "CFBundleName": "Flowline",
    "CFBundleShortVersionString": "0.2.0",
    "CFBundleVersion": "42",
    "CFBundleIdentifier": "dev.kyylian.flowline"
  ])

  #expect(info.appName == "Flowline")
  #expect(info.versionLabel == "0.2.0 (42)")
  #expect(info.bundleIdentifier == "dev.kyylian.flowline")
  #expect(info.githubURL.absoluteString == "https://github.com/kyylian/flowline")
  #expect(info.licenseName == "MIT")
  #expect(info.licenseURL.absoluteString == "https://github.com/kyylian/flowline/blob/main/LICENSE")
  #expect(info.updateModeLabel == "Manual")
  #expect(info.releasesURL.absoluteString == "https://github.com/kyylian/flowline/releases")
}

@Test func settingsModulePreviewKeepsFixedLimitsInTheCenter() {
  let items = SettingsPresentation.modulePreviewItems(for: .defaults)

  #expect(items.map(\.title) == ["HOLD", "LIMITS", "MUSIC"])
  #expect(items.map(\.slot) == [.left, .center, .right])
  #expect(items.map(\.isActive) == [true, true, true])
}

@Test func settingsModulePreviewMarksEmptySideSlotsAsOpen() {
  let preferences = FlowlineModulePreferences(
    context: false,
    music: false,
    calendar: false,
    shelf: false
  )

  let items = SettingsPresentation.modulePreviewItems(for: preferences)

  #expect(items.map(\.title) == ["OPEN", "LIMITS", "OPEN"])
  #expect(items.map(\.isActive) == [false, true, false])
}

@Test func settingsModuleLayersSeparateLeftAndRightRows() {
  let sections = SettingsPresentation.moduleLayerSections()

  #expect(sections.map(\.title) == ["Left layer", "Right layer"])
  #expect(sections.map { $0.items.map(\.module) } == [
    [.context, .shelf],
    [.music, .calendar]
  ])
  #expect(sections.map { $0.items.map(\.detail) } == [
    ["Left only", "Left first"],
    ["Right only", "Right first"]
  ])
}

@Test func settingsPermissionsShowOnlyAccessNeededByActiveModules() {
  let preferences = FlowlineModulePreferences(
    context: true,
    music: true,
    calendar: false,
    shelf: true
  )

  let items = SettingsPresentation.permissionItems(
    accessibility: .granted,
    calendar: .notDetermined,
    preferences: preferences,
    holdAutoCaptureScreenshots: true
  )

  #expect(items.map(\.title) == [
    "Accessibility",
    "Automation",
    "Screenshot folder"
  ])
  #expect(items.map(\.statusLabel) == [
    "Granted",
    "On demand",
    "On demand"
  ])
  #expect(items.map(\.action) == [
    .requestAccessibility,
    nil,
    nil
  ])
}

@Test func settingsPermissionsIncludeCalendarOnlyWhenCalendarModuleIsEnabled() {
  let disabled = SettingsPresentation.permissionItems(
    accessibility: .granted,
    calendar: .denied,
    preferences: FlowlineModulePreferences(
      context: true,
      music: false,
      calendar: false,
      shelf: false
    ),
    holdAutoCaptureScreenshots: true
  )

  let enabled = SettingsPresentation.permissionItems(
    accessibility: .granted,
    calendar: .denied,
    preferences: FlowlineModulePreferences(
      context: true,
      music: false,
      calendar: true,
      shelf: false
    ),
    holdAutoCaptureScreenshots: true
  )

  #expect(disabled.map(\.title) == ["Accessibility"])
  #expect(enabled.map(\.title) == ["Accessibility", "Calendar"])
  #expect(enabled.last?.action == .requestCalendar)
}

@Test func settingsPermissionHealthCountsOnlyActionableDeniedAccess() {
  let preferences = FlowlineModulePreferences(
    context: true,
    music: true,
    calendar: true,
    shelf: true
  )

  let items = SettingsPresentation.permissionItems(
    accessibility: .denied,
    calendar: .notDetermined,
    preferences: preferences,
    holdAutoCaptureScreenshots: true
  )

  let health = SettingsPresentation.permissionHealth(for: items)

  #expect(health.title == "2 permissions needed")
  #expect(health.isReady == false)
}
