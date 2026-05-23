import AppKit
import Combine
import FlowlineCore
import Foundation

@MainActor
final class AppState: ObservableObject {
  @Published var snapshot: ContextSnapshot = .empty
  @Published var isExpanded = false
  @Published var isHovering = false
  @Published var isHoldDropTargeted = false
  @Published private(set) var holdDropLandingTick = 0
  @Published var actions: [FlowlineAction] = []
  @Published var agentProviders: [String] = []
  @Published var aiUsage: AIUsageSnapshot?
  @Published var musicPlayback: MusicPlaybackSnapshot?
  @Published var physicalNotchWidth = NotchMetrics.fallbackPhysicalWidth
  @Published var physicalNotchHeight = NotchMetrics.collapsedHeight
  @Published private(set) var positionMode: PositionMode = .notch
  @Published var workspaceModuleEnabled = AppState.defaultBool(forKey: UserDefaultsKey.workspaceModuleEnabled, fallback: FlowlineModulePreferences.defaults.context) {
    didSet {
      guard applyModuleSelectionPolicy(for: .context, isEnabled: workspaceModuleEnabled) else {
        return
      }

      UserDefaults.standard.set(workspaceModuleEnabled, forKey: UserDefaultsKey.workspaceModuleEnabled)
    }
  }
  @Published var musicModuleEnabled = AppState.defaultBool(forKey: UserDefaultsKey.musicModuleEnabled, fallback: FlowlineModulePreferences.defaults.music) {
    didSet {
      guard applyModuleSelectionPolicy(for: .music, isEnabled: musicModuleEnabled) else {
        return
      }

      UserDefaults.standard.set(musicModuleEnabled, forKey: UserDefaultsKey.musicModuleEnabled)

      if musicModuleEnabled {
        musicService.start()
      } else {
        musicService.stop()
        musicPlayback = nil
      }
    }
  }
  @Published var calendarModuleEnabled = AppState.defaultBool(forKey: UserDefaultsKey.calendarModuleEnabled, fallback: FlowlineModulePreferences.defaults.calendar) {
    didSet {
      guard applyModuleSelectionPolicy(for: .calendar, isEnabled: calendarModuleEnabled) else {
        return
      }

      UserDefaults.standard.set(calendarModuleEnabled, forKey: UserDefaultsKey.calendarModuleEnabled)
      if calendarModuleEnabled {
        calendarService.start()
      } else {
        calendarService.stop()
      }
      refreshSnapshot()
    }
  }
  @Published var shelfModuleEnabled = AppState.defaultBool(forKey: UserDefaultsKey.shelfModuleEnabled, fallback: FlowlineModulePreferences.defaults.shelf) {
    didSet {
      guard applyModuleSelectionPolicy(for: .shelf, isEnabled: shelfModuleEnabled) else {
        return
      }

      UserDefaults.standard.set(shelfModuleEnabled, forKey: UserDefaultsKey.shelfModuleEnabled)
      if shelfModuleEnabled {
        applyHoldAutoCaptureOptions()
        shelfService.start()
      } else {
        shelfService.stop()
        shelfService.clear()
      }
      refreshSnapshot()
    }
  }
  @Published var launchAtLogin = LaunchAtLoginService.isEnabled {
    didSet {
      guard oldValue != launchAtLogin else {
        return
      }

      LaunchAtLoginService.setEnabled(launchAtLogin)
    }
  }
  @Published var showOverFullscreen = AppState.defaultBool(forKey: UserDefaultsKey.showOverFullscreen, fallback: false) {
    didSet {
      UserDefaults.standard.set(showOverFullscreen, forKey: UserDefaultsKey.showOverFullscreen)
    }
  }
  @Published var holdAutoCaptureScreenshots = AppState.defaultBool(
    forKey: UserDefaultsKey.holdAutoCaptureScreenshots,
    fallback: ShelfAutoCaptureOptions.defaults.screenshots
  ) {
    didSet {
      UserDefaults.standard.set(
        holdAutoCaptureScreenshots,
        forKey: UserDefaultsKey.holdAutoCaptureScreenshots
      )
      applyHoldAutoCaptureOptions()
    }
  }
  @Published var holdAutoCaptureClipboardText = AppState.defaultBool(
    forKey: UserDefaultsKey.holdAutoCaptureClipboardText,
    fallback: ShelfAutoCaptureOptions.defaults.clipboardText
  ) {
    didSet {
      UserDefaults.standard.set(
        holdAutoCaptureClipboardText,
        forKey: UserDefaultsKey.holdAutoCaptureClipboardText
      )
      applyHoldAutoCaptureOptions()
    }
  }

  private let activeAppMonitor = ActiveAppMonitor()
  private let gitService = GitContextService()
  private let calendarService = CalendarService()
  private let shelfService: ShelfService
  private let agentProviderService = AgentProviderService()
  private let aiUsageService = AIUsageService()
  private let musicService = MusicControlService()
  private var permissionRefreshTask: Task<Void, Never>?
  private var cancellables: Set<AnyCancellable> = []

  init(shelfService: ShelfService = ShelfService()) {
    self.shelfService = shelfService
  }

  deinit {
    MainActor.assumeIsolated {
      permissionRefreshTask?.cancel()
      activeAppMonitor.stop()
      calendarService.stop()
      shelfService.stop()
      aiUsageService.stop()
      musicService.stop()
    }
  }

  func start() {
    normalizeModuleSelection()
    bindServices()
    activeAppMonitor.start()
    aiUsageService.start()
    if musicModuleEnabled {
      musicService.start()
    }
    if calendarModuleEnabled {
      calendarService.start()
    }
    if shelfModuleEnabled {
      applyHoldAutoCaptureOptions()
      shelfService.start()
    }
    agentProviders = agentProviderService.enabledProviders()
    refreshSnapshot()
    beginPermissionRefresh()
  }

  func requestAccessibilityPermission() {
    PermissionService.requestAccessibilityPermission()
    refreshSnapshot()
    beginPermissionRefresh()
  }

  func requestCalendarPermission() {
    calendarService.requestAccess()
  }

  func clearShelf() {
    shelfService.clear()
    refreshSnapshot(refreshGit: false)
  }

  func setHoldDropTargeted(_ targeted: Bool) {
    guard isHoldDropTargeted != targeted else {
      return
    }

    isHoldDropTargeted = targeted
  }

  func markHoldDropLanded() {
    isHoldDropTargeted = false
    holdDropLandingTick += 1
  }

  var enabledOverlayModuleCount: Int {
    modulePreferences.enabledCount
  }

  var overlayModuleCountLabel: String {
    OverlayModuleCountPresentation.label(for: modulePreferences)
  }

  func isModuleEnabled(_ module: FlowlineModule) -> Bool {
    modulePreferences.isEnabled(module)
  }

  func canEnableModule(_ module: FlowlineModule) -> Bool {
    guard !modulePreferences.isEnabled(module) else {
      return true
    }

    return FlowlineModuleSelection.canEnable(module, in: modulePreferences)
      || canEnableModuleByClosingConflicts(module)
  }

  func moduleStatusLabel(for module: FlowlineModule) -> String {
    let preferences = modulePreferences
    if let placement = FlowlineModuleSelection.placement(for: module, in: preferences) {
      return placement.rawValue
    }

    if !preferences.isEnabled(module), canEnableModule(module) {
      return "off"
    }

    switch FlowlineModuleSelection.rejectionReason(for: module, in: preferences) {
    case .maximumEnabled:
      return "max"
    case .sideSlotUnavailable:
      return "slot"
    case nil:
      return "off"
    }
  }

  func setModule(_ module: FlowlineModule, enabled: Bool) {
    guard !enabled || canEnableModule(module) else {
      return
    }

    switch module {
    case .context:
      workspaceModuleEnabled = enabled
    case .music:
      musicModuleEnabled = enabled
    case .calendar:
      calendarModuleEnabled = enabled
    case .shelf:
      shelfModuleEnabled = enabled
    }
  }

  func copyShelfItem(_ item: ShelfItem) {
    HoldPasteboardWriter.write(item, to: NSPasteboard.general)
    shelfService.markPasteboardWriteHandled()
  }

  func copyShelfOCRText(_ item: ShelfItem) {
    if HoldPasteboardWriter.writeOCRText(item, to: NSPasteboard.general) {
      shelfService.markPasteboardWriteHandled()
    }
  }

  func cycleShelfItems() {
    shelfService.cycle()
    refreshSnapshot(refreshGit: false)
  }

  func addShelfFiles(_ urls: [URL]) {
    shelfService.addFiles(urls)
    refreshSnapshot(refreshGit: false)
  }

  func addShelfText(_ text: String) {
    shelfService.addText(text)
    refreshSnapshot(refreshGit: false)
  }

  func addShelfScreenshots(_ urls: [URL]) {
    shelfService.addScreenshotFiles(urls)
    refreshSnapshot(refreshGit: false)
  }

  func removeShelfItem(id: ShelfItem.ID) {
    shelfService.remove(id: id)
    refreshSnapshot(refreshGit: false)
  }

  func exportShelfItem(_ item: ShelfItem) -> NSItemProvider {
    let provider = HoldItemDragProvider.provider(for: item)
    shelfService.export(id: item.id)
    refreshSnapshot(refreshGit: false)
    return provider
  }

  func refreshAIUsage() {
    aiUsageService.refreshNow()
  }

  func musicPreviousTrack() {
    musicService.previousTrack()
  }

  func musicTogglePlayPause() {
    musicService.togglePlayPause()
  }

  func musicNextTrack() {
    musicService.nextTrack()
  }

  func updatePhysicalNotch(width: Double, height: Double) {
    let roundedWidth = max(1, width.rounded())
    let roundedHeight = max(1, height.rounded())

    guard physicalNotchWidth != roundedWidth || physicalNotchHeight != roundedHeight else {
      return
    }

    physicalNotchWidth = roundedWidth
    physicalNotchHeight = roundedHeight
  }

  func updatePositionMode(_ mode: PositionMode) {
    guard positionMode != mode else {
      return
    }

    positionMode = mode
  }

  func copyContextSummary() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(
      ContextSummaryBuilder.build(snapshot: snapshot, aiUsage: aiUsage),
      forType: .string
    )
  }

  func open(_ url: URL) {
    NSWorkspace.shared.open(url)
  }

  func perform(_ action: FlowlineAction) {
    switch action.kind {
    case .open, .joinMeeting, .revealFile:
      if let url = action.url {
        open(url)
      }
    case .clearShelf:
      clearShelf()
    case .requestPermission:
      requestAccessibilityPermission()
    }
  }

  private func bindServices() {
    guard cancellables.isEmpty else {
      return
    }

    activeAppMonitor.$context
      .sink { [weak self] _ in self?.refreshSnapshot() }
      .store(in: &cancellables)

    calendarService.$nextEvent
      .sink { [weak self] _ in self?.refreshSnapshot() }
      .store(in: &cancellables)

    calendarService.$permission
      .sink { [weak self] _ in self?.refreshSnapshot() }
      .store(in: &cancellables)

    shelfService.$items
      .sink { [weak self] items in self?.refreshSnapshot(refreshGit: false, shelfItems: items) }
      .store(in: &cancellables)

    aiUsageService.$snapshot
      .sink { [weak self] snapshot in self?.aiUsage = snapshot }
      .store(in: &cancellables)

    musicService.$snapshot
      .sink { [weak self] snapshot in self?.musicPlayback = snapshot }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      .sink { [weak self] _ in self?.refreshSnapshot() }
      .store(in: &cancellables)
  }

  private func beginPermissionRefresh() {
    guard permissionRefreshTask == nil else {
      return
    }

    permissionRefreshTask = Task { @MainActor [weak self] in
      var lastAccessibilityStatus = PermissionService.accessibilityStatus

      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, let self else {
          return
        }

        let currentAccessibilityStatus = PermissionService.accessibilityStatus
        guard currentAccessibilityStatus != lastAccessibilityStatus ||
              snapshot.permissions.accessibility != currentAccessibilityStatus else {
          continue
        }

        lastAccessibilityStatus = currentAccessibilityStatus
        refreshSnapshot()
      }
    }
  }

  private var modulePreferences: FlowlineModulePreferences {
    FlowlineModulePreferences(
      context: workspaceModuleEnabled,
      music: musicModuleEnabled,
      calendar: calendarModuleEnabled,
      shelf: shelfModuleEnabled
    )
  }

  private var holdAutoCaptureOptions: ShelfAutoCaptureOptions {
    ShelfAutoCaptureOptions(
      screenshots: holdAutoCaptureScreenshots,
      clipboardText: holdAutoCaptureClipboardText
    )
  }

  private func applyHoldAutoCaptureOptions() {
    shelfService.updateAutoCaptureOptions(holdAutoCaptureOptions)
  }

  private func applyModuleSelectionPolicy(for module: FlowlineModule, isEnabled: Bool) -> Bool {
    guard isEnabled, !FlowlineModuleSelection.isValid(modulePreferences) else {
      return true
    }

    if closeModuleConflicts(for: module) {
      return true
    }

    setModule(module, enabled: false)
    return false
  }

  private func normalizeModuleSelection() {
    guard !FlowlineModuleSelection.isValid(modulePreferences) else {
      return
    }

    if enabledOverlayModuleCount > FlowlineModuleSelection.maximumEnabledCount {
      setModule(.calendar, enabled: false)
    }

    if workspaceModuleEnabled && shelfModuleEnabled {
      setModule(.shelf, enabled: false)
    }

    if !FlowlineModuleSelection.isValid(modulePreferences) {
      setModule(.context, enabled: false)
    }
  }

  private func canEnableModuleByClosingConflicts(_ module: FlowlineModule) -> Bool {
    adjustedPreferencesByClosingConflicts(for: module).map(FlowlineModuleSelection.isValid) ?? false
  }

  private func closeModuleConflicts(for module: FlowlineModule) -> Bool {
    guard let adjusted = adjustedPreferencesByClosingConflicts(for: module),
          FlowlineModuleSelection.isValid(adjusted) else {
      return false
    }

    if module == .context, shelfModuleEnabled {
      setModule(.shelf, enabled: false)
    }

    return true
  }

  private func adjustedPreferencesByClosingConflicts(
    for module: FlowlineModule
  ) -> FlowlineModulePreferences? {
    guard module == .context, shelfModuleEnabled else {
      return nil
    }

    var adjusted = modulePreferences
    adjusted.set(.context, enabled: true)
    adjusted.set(.shelf, enabled: false)
    return adjusted
  }

  private func refreshSnapshot(refreshGit: Bool = true, shelfItems: [ShelfItem]? = nil) {
    let active = activeAppMonitor.context
    let previousGit = snapshot.activeApp == active ? snapshot.git : nil
    let git = active.isDeveloperApp
      ? (refreshGit ? gitService.statusForFrontmostContext(active) : previousGit)
      : nil
    let permissionState = PermissionState(
      accessibility: PermissionService.accessibilityStatus,
      calendar: calendarModuleEnabled ? calendarService.permission : .notDetermined
    )

    snapshot = ContextSnapshot(
      activeApp: active,
      git: git,
      nextEvent: calendarModuleEnabled ? calendarService.nextEvent : nil,
      shelfItems: shelfModuleEnabled ? (shelfItems ?? shelfService.items) : [],
      permissions: permissionState
    )
    actions = ActionBuilder.actions(for: snapshot)
  }

  private static func defaultBool(forKey key: String, fallback: Bool) -> Bool {
    guard UserDefaults.standard.object(forKey: key) != nil else {
      return fallback
    }

    return UserDefaults.standard.bool(forKey: key)
  }

}

private enum UserDefaultsKey {
  static let workspaceModuleEnabled = "module.workspace.enabled"
  static let musicModuleEnabled = "module.music.enabled"
  static let calendarModuleEnabled = "module.calendar.enabled"
  static let shelfModuleEnabled = "module.shelf.enabled"
  static let showOverFullscreen = "behavior.showOverFullscreen"
  static let holdAutoCaptureScreenshots = "hold.autoCapture.screenshots"
  static let holdAutoCaptureClipboardText = "hold.autoCapture.clipboardText"
}
