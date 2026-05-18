import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  private static let contentSize = NSSize(width: 600, height: 360)

  init(state: AppState) {
    let controller = NSHostingController(
      rootView: SettingsView(state: state)
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    )
    let window = NSWindow(contentViewController: controller)

    window.title = "Flowline Settings"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.setContentSize(Self.contentSize)
    window.contentMinSize = Self.contentSize
    window.contentMaxSize = Self.contentSize
    window.isReleasedWhenClosed = false
    window.tabbingMode = .disallowed

    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  func showAndActivate() {
    guard let window else {
      return
    }

    if !window.isVisible {
      window.center()
    }

    showWindow(nil)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
