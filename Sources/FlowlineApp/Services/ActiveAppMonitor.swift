import AppKit
import Combine
import FlowlineCore

@MainActor
final class ActiveAppMonitor: ObservableObject {
  @Published private(set) var context = ActiveAppContext(
    name: "Flowline",
    bundleIdentifier: nil,
    windowTitle: nil
  )

  private var observers: [NSObjectProtocol] = []
  private var timer: Timer?

  func start() {
    refresh()

    guard timer == nil, observers.isEmpty else {
      return
    }

    observers.append(
      NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.refresh()
        }
      }
    )

    timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil

    observers.forEach {
      NSWorkspace.shared.notificationCenter.removeObserver($0)
    }
    observers.removeAll()
  }

  deinit {
    MainActor.assumeIsolated {
      timer?.invalidate()
      observers.forEach {
        NSWorkspace.shared.notificationCenter.removeObserver($0)
      }
    }
  }

  private func refresh() {
    guard let app = NSWorkspace.shared.frontmostApplication else {
      return
    }

    let nextContext = ActiveAppContext(
      name: app.localizedName ?? "Unknown App",
      bundleIdentifier: app.bundleIdentifier,
      windowTitle: PermissionService.accessibilityStatus == .granted ? WindowTitleReader.title(for: app) : nil
    )

    guard nextContext != context else {
      return
    }

    context = nextContext
  }
}
