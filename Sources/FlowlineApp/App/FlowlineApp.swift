import SwiftUI
import AppKit

@main
struct FlowlineApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(state: appDelegate.state)
        .frame(width: 600, height: 360)
    }
    .windowResizability(.contentSize)
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let state = AppState()
  private var overlayController: OverlayController?
  private var shortcutMonitor: Any?
  private var statusItem: NSStatusItem?
  private var settingsWindowController: SettingsWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    overlayController = OverlayController(state: state)
    overlayController?.show()
    state.start()
    installStatusItem()
    installShortcutMonitor()
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let shortcutMonitor {
      NSEvent.removeMonitor(shortcutMonitor)
    }
  }

  func toggleOverlay() {
    overlayController?.toggleExpanded()
  }

  private func installStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = FlowlineMarkImage.menuBarIcon
    item.button?.imagePosition = .imageOnly
    item.button?.toolTip = "Flowline"
    item.button?.setAccessibilityLabel("Flowline")
    item.menu = makeStatusMenu()
    statusItem = item
  }

  private func makeStatusMenu() -> NSMenu {
    let menu = NSMenu()

    let toggleItem = NSMenuItem(
      title: "Toggle Flowline",
      action: #selector(toggleOverlayFromStatusMenu),
      keyEquivalent: " "
    )
    toggleItem.keyEquivalentModifierMask = [.option]
    toggleItem.target = self
    menu.addItem(toggleItem)

    let settingsItem = NSMenuItem(
      title: "Settings",
      action: #selector(openSettingsFromStatusMenu),
      keyEquivalent: ","
    )
    settingsItem.keyEquivalentModifierMask = [.command]
    settingsItem.target = self
    menu.addItem(settingsItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit",
      action: #selector(quitFromStatusMenu),
      keyEquivalent: "q"
    )
    quitItem.keyEquivalentModifierMask = [.command]
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  @objc private func toggleOverlayFromStatusMenu() {
    toggleOverlay()
  }

  @objc private func openSettingsFromStatusMenu() {
    showSettingsWindow()
  }

  @objc private func quitFromStatusMenu() {
    NSApp.terminate(nil)
  }

  private func showSettingsWindow() {
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(state: state)
    }

    settingsWindowController?.showAndActivate()
  }

  private func installShortcutMonitor() {
    shortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option,
            event.keyCode == 49 else {
        return
      }

      Task { @MainActor in
        self?.toggleOverlay()
      }
    }
  }
}
