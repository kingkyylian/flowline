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

    MenuBarExtra("Flowline", systemImage: "point.3.connected.trianglepath.dotted") {
      Button("Toggle Flowline") {
        appDelegate.toggleOverlay()
      }
      .keyboardShortcut(" ", modifiers: [.option])

      SettingsLink {
        Text("Settings")
      }

      Divider()

      Button("Quit") {
        NSApp.terminate(nil)
      }
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let state = AppState()
  private var overlayController: OverlayController?
  private var shortcutMonitor: Any?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    overlayController = OverlayController(state: state)
    overlayController?.show()
    state.start()
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
