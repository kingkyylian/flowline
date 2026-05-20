import AppKit
import Testing
@testable import FlowlineApp

@MainActor
@Test func appStateTracksHoldDropTargetAndLandingFeedback() {
  let state = AppState()

  #expect(!state.isHoldDropTargeted)
  #expect(state.holdDropLandingTick == 0)

  state.setHoldDropTargeted(true)
  #expect(state.isHoldDropTargeted)

  state.markHoldDropLanded()
  #expect(!state.isHoldDropTargeted)
  #expect(state.holdDropLandingTick == 1)
}

@MainActor
@Test func appStatePersistsModuleToggleChanges() {
  let defaults = UserDefaults.standard
  let keys = [
    "module.workspace.enabled",
    "module.music.enabled",
    "module.calendar.enabled",
    "module.shelf.enabled"
  ]
  let previousValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
  defer {
    for key in keys {
      if let value = previousValues[key] {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  defaults.set(false, forKey: "module.workspace.enabled")
  defaults.set(true, forKey: "module.music.enabled")
  defaults.set(false, forKey: "module.calendar.enabled")
  defaults.set(true, forKey: "module.shelf.enabled")
  let shelfService = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
    pasteboardProvider: { NSPasteboard.withUniqueName() },
    screenshotTextRecognizer: nil
  )
  let state = AppState(shelfService: shelfService)
  defer {
    shelfService.stop()
  }

  state.setModule(.shelf, enabled: false)

  #expect(!state.shelfModuleEnabled)
  #expect(!defaults.bool(forKey: "module.shelf.enabled"))
  #expect(state.canEnableModule(.context))
  #expect(state.canEnableModule(.calendar))

  state.setModule(.shelf, enabled: true)

  #expect(state.shelfModuleEnabled)
  #expect(defaults.bool(forKey: "module.shelf.enabled"))
}

@MainActor
@Test func appStateRejectsModuleToggleWhenSideSlotsAreFull() {
  let defaults = UserDefaults.standard
  let keys = [
    "module.workspace.enabled",
    "module.music.enabled",
    "module.calendar.enabled",
    "module.shelf.enabled"
  ]
  let previousValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
  defer {
    for key in keys {
      if let value = previousValues[key] {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  defaults.set(false, forKey: "module.workspace.enabled")
  defaults.set(true, forKey: "module.music.enabled")
  defaults.set(false, forKey: "module.calendar.enabled")
  defaults.set(true, forKey: "module.shelf.enabled")
  let state = AppState(
    shelfService: ShelfService(
      screenshotDirectoriesProvider: { [] },
      screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
      pasteboardProvider: { NSPasteboard.withUniqueName() },
      screenshotTextRecognizer: nil
    )
  )

  state.setModule(.context, enabled: true)
  state.setModule(.calendar, enabled: true)

  #expect(!state.workspaceModuleEnabled)
  #expect(!state.calendarModuleEnabled)
  #expect(!defaults.bool(forKey: "module.workspace.enabled"))
  #expect(!defaults.bool(forKey: "module.calendar.enabled"))
  #expect(state.moduleStatusLabel(for: .context) == "max")
  #expect(state.moduleStatusLabel(for: .calendar) == "max")
}

@MainActor
@Test func appStatePublishesAutoCapturedClipboardTextIntoSnapshot() async throws {
  let pasteboard = NSPasteboard.withUniqueName()
  let shelfService = ShelfService(
    screenshotDirectoriesProvider: { [] },
    screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
    pasteboardProvider: { pasteboard },
    autoCaptureOptions: ShelfAutoCaptureOptions(screenshots: false, clipboardText: false),
    screenshotTextRecognizer: nil
  )
  let state = AppState(shelfService: shelfService)
  let defaults = UserDefaults.standard
  let keys = [
    "module.workspace.enabled",
    "module.music.enabled",
    "module.calendar.enabled",
    "module.shelf.enabled",
    "hold.autoCapture.screenshots",
    "hold.autoCapture.clipboardText"
  ]
  let previousValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
  defer {
    shelfService.stop()
    for key in keys {
      if let value = previousValues[key] {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  state.workspaceModuleEnabled = false
  state.musicModuleEnabled = false
  state.calendarModuleEnabled = false
  state.shelfModuleEnabled = true
  state.holdAutoCaptureScreenshots = false
  state.holdAutoCaptureClipboardText = true
  state.start()

  pasteboard.clearContents()
  pasteboard.setString("appstate clipboard probe", forType: .string)

  let deadline = Date().addingTimeInterval(0.45)
  while Date() < deadline {
    if state.snapshot.shelfItems.first?.title == "appstate clipboard probe" {
      break
    }

    try await Task.sleep(for: .milliseconds(20))
  }

  #expect(state.snapshot.shelfItems.first?.title == "appstate clipboard probe")
}
