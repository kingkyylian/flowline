import AppKit
import FlowlineCore
import Testing
@testable import FlowlineApp

@MainActor
@Test func overlayHostingViewImportsExpandedHoldTextDropAndMarksLanding() throws {
  try withOverlayHoldDropHarness { harness in
    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("overlay hold smoke drop", forType: .string)

    let drag = OverlayHoldDropDraggingInfo(
      pasteboard: pasteboard,
      location: NSPoint(x: 20, y: 72)
    )

    #expect(harness.view.draggingEntered(drag) == .copy)
    #expect(harness.state.isHoldDropTargeted)

    #expect(harness.view.performDragOperation(drag))
    #expect(!harness.state.isHoldDropTargeted)
    #expect(harness.state.holdDropLandingTick == 1)

    let item = try #require(harness.state.snapshot.shelfItems.first)
    #expect(item.kind == .text)
    #expect(item.title == "overlay hold smoke drop")
  }
}

@MainActor
@Test func overlayHostingViewImportsExpandedHoldFinderFileDropAndMarksLanding() throws {
  try withOverlayHoldDropHarness { harness in
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
    try Data("overlay finder file".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.writeObjects([file as NSURL])
    let drag = OverlayHoldDropDraggingInfo(
      pasteboard: pasteboard,
      location: NSPoint(x: 20, y: 72)
    )

    #expect(harness.view.draggingEntered(drag) == .copy)
    #expect(harness.view.performDragOperation(drag))
    #expect(harness.state.holdDropLandingTick == 1)

    let item = try #require(harness.state.snapshot.shelfItems.first)
    #expect(item.kind == .file)
    #expect(item.title == file.lastPathComponent)
    #expect(item.url == file)
  }
}

@MainActor
private final class OverlayHoldDropHarness {
  let state: AppState
  let view: OverlayHostingView

  init() {
    let shelfService = ShelfService(
      screenshotDirectoriesProvider: { [] },
      screenshotStashDirectoryProvider: { FileManager.default.temporaryDirectory },
      pasteboardProvider: { NSPasteboard.withUniqueName() },
      screenshotTextRecognizer: nil
    )
    state = AppState(shelfService: shelfService)
    state.isExpanded = true
    view = OverlayHostingView(state: state)
    view.frame = NSRect(
      x: 0,
      y: 0,
      width: NotchMetrics.expandedWidth,
      height: NotchMetrics.expandedHeight
    )
  }
}

@MainActor
private func withOverlayHoldDropHarness(_ body: (OverlayHoldDropHarness) throws -> Void) rethrows {
  let defaults = UserDefaults.standard
  let keys = [
    "module.workspace.enabled",
    "module.music.enabled",
    "module.calendar.enabled",
    "module.shelf.enabled"
  ]
  let previousValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
  defaults.set(false, forKey: "module.workspace.enabled")
  defaults.set(true, forKey: "module.music.enabled")
  defaults.set(false, forKey: "module.calendar.enabled")
  defaults.set(true, forKey: "module.shelf.enabled")
  defer {
    for (key, value) in previousValues {
      if let value {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  try body(OverlayHoldDropHarness())
}

@MainActor
private final class OverlayHoldDropDraggingInfo: NSObject, @MainActor NSDraggingInfo {
  let draggingPasteboard: NSPasteboard
  let draggingLocation: NSPoint
  var draggingFormation: NSDraggingFormation = .default
  var animatesToDestination = false
  var numberOfValidItemsForDrop = 1

  init(pasteboard: NSPasteboard, location: NSPoint) {
    self.draggingPasteboard = pasteboard
    self.draggingLocation = location
  }

  var draggingDestinationWindow: NSWindow? {
    nil
  }

  var draggingSourceOperationMask: NSDragOperation {
    .copy
  }

  var draggedImageLocation: NSPoint {
    draggingLocation
  }

  var draggedImage: NSImage? {
    NSImage(size: NSSize(width: 1, height: 1))
  }

  var draggingSource: Any? {
    nil
  }

  var draggingSequenceNumber: Int {
    1
  }

  var springLoadingHighlight: NSSpringLoadingHighlight {
    .none
  }

  func slideDraggedImage(to screenPoint: NSPoint) {}

  override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
    nil
  }

  func enumerateDraggingItems(
    options enumOpts: NSDraggingItemEnumerationOptions = [],
    for view: NSView?,
    classes classArray: [AnyClass],
    searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
    using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
  ) {}

  func resetSpringLoading() {}
}
