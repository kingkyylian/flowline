import AppKit
import Combine
import FlowlineCore
import Foundation

@MainActor
final class AppState: ObservableObject {
  @Published var snapshot: ContextSnapshot = .empty
  @Published var isExpanded = false
  @Published var isHovering = false
  @Published var actions: [FlowlineAction] = []
  @Published var agentProviders: [String] = []
  @Published var aiUsage: AIUsageSnapshot?
  @Published var musicPlayback: MusicPlaybackSnapshot?
  @Published var physicalNotchWidth = NotchMetrics.fallbackPhysicalWidth
  @Published var physicalNotchHeight = NotchMetrics.collapsedHeight
  @Published private(set) var positionMode: PositionMode = .notch
  @Published var musicModuleEnabled = AppState.defaultBool(forKey: UserDefaultsKey.musicModuleEnabled, fallback: FlowlineModulePreferences.defaults.music) {
    didSet {
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
      UserDefaults.standard.set(calendarModuleEnabled, forKey: UserDefaultsKey.calendarModuleEnabled)
      refreshSnapshot()
    }
  }
  @Published var shelfModuleEnabled = AppState.defaultBool(forKey: UserDefaultsKey.shelfModuleEnabled, fallback: FlowlineModulePreferences.defaults.shelf) {
    didSet {
      UserDefaults.standard.set(shelfModuleEnabled, forKey: UserDefaultsKey.shelfModuleEnabled)
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
  @Published var showOverFullscreen = false

  private let activeAppMonitor = ActiveAppMonitor()
  private let gitService = GitContextService()
  private let calendarService = CalendarService()
  private let shelfService = ShelfService()
  private let agentProviderService = AgentProviderService()
  private let aiUsageService = AIUsageService()
  private let musicService = MusicControlService()
  private var permissionRefreshTask: Task<Void, Never>?
  private var cancellables: Set<AnyCancellable> = []

  isolated deinit {
    permissionRefreshTask?.cancel()
    activeAppMonitor.stop()
    calendarService.stop()
    shelfService.stop()
    aiUsageService.stop()
    musicService.stop()
  }

  func start() {
    bindServices()
    activeAppMonitor.start()
    calendarService.start()
    shelfService.start()
    aiUsageService.start()
    if musicModuleEnabled {
      musicService.start()
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
    refreshSnapshot()
  }

  func addShelfFiles(_ urls: [URL]) {
    shelfService.addFiles(urls)
    refreshSnapshot()
  }

  func removeShelfItem(id: ShelfItem.ID) {
    shelfService.remove(id: id)
    refreshSnapshot()
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
      .sink { [weak self] _ in self?.refreshSnapshot() }
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

  private func refreshSnapshot() {
    let active = activeAppMonitor.context
    let git = active.isDeveloperApp ? gitService.statusForFrontmostContext(active) : nil
    let permissionState = PermissionState(
      accessibility: PermissionService.accessibilityStatus,
      calendar: calendarModuleEnabled ? calendarService.permission : .notDetermined
    )

    snapshot = ContextSnapshot(
      activeApp: active,
      git: git,
      nextEvent: calendarModuleEnabled ? calendarService.nextEvent : nil,
      shelfItems: shelfModuleEnabled ? shelfService.items : [],
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
  static let musicModuleEnabled = "module.music.enabled"
  static let calendarModuleEnabled = "module.calendar.enabled"
  static let shelfModuleEnabled = "module.shelf.enabled"
}
