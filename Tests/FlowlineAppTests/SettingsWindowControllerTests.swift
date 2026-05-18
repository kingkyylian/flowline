import AppKit
import Testing
@testable import FlowlineApp

@MainActor
@Test func settingsWindowControllerBuildsAStableSettingsWindow() throws {
  let controller = SettingsWindowController(state: AppState())
  let window = try #require(controller.window)

  #expect(window.title == "Flowline Settings")
  #expect(window.isReleasedWhenClosed == false)
  #expect(window.styleMask.contains(.titled))
  #expect(window.styleMask.contains(.closable))
  #expect(window.styleMask.contains(.miniaturizable))
  #expect(!window.styleMask.contains(.resizable))
  #expect(window.contentViewController != nil)
  #expect(window.contentMinSize == NSSize(width: 600, height: 360))
  #expect(window.contentMaxSize == NSSize(width: 600, height: 360))
}
