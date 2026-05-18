import AppKit
import FlowlineCore
import SwiftUI

@MainActor
final class OverlayHostingView: NSHostingView<OverlayRootView> {
  private let state: AppState

  init(state: AppState) {
    self.state = state
    super.init(rootView: OverlayRootView(state: state))
    registerForDraggedTypes(HoldDropTypes.pasteboardTypes)
  }

  @available(*, unavailable)
  required init(rootView: OverlayRootView) {
    fatalError("Use init(state:)")
  }

  @available(*, unavailable)
  required dynamic init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard state.positionMode == .notch else {
      return super.hitTest(point)
    }

    let size = state.isExpanded
      ? NSSize(width: NotchMetrics.expandedWidth, height: NotchMetrics.expandedHeight)
      : NSSize(width: state.physicalNotchWidth, height: state.physicalNotchHeight)

    let hitFrame = NSRect(
      x: (bounds.width - size.width) / 2,
      y: bounds.height - size.height,
      width: size.width,
      height: size.height
    ).insetBy(dx: state.isExpanded ? -4 : 0, dy: state.isExpanded ? -4 : 0)

    guard hitFrame.contains(point) else {
      return nil
    }

    return super.hitTest(point)
  }

  override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    guard canAcceptHoldDrop(sender), acceptsHoldDrag(at: convert(sender.draggingLocation, from: nil)) else {
      state.setHoldDropTargeted(false)
      return []
    }

    expandForHoldDrag()
    state.setHoldDropTargeted(true)
    return .copy
  }

  override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
    guard canAcceptHoldDrop(sender) else {
      return []
    }

    let point = convert(sender.draggingLocation, from: nil)
    if !state.isExpanded, acceptsCollapsedNotchDrag(at: point) {
      expandForHoldDrag()
      state.setHoldDropTargeted(true)
      return .copy
    }

    let acceptsDrop = acceptsExpandedHoldDrop(at: point)
    state.setHoldDropTargeted(acceptsDrop)
    return acceptsDrop ? .copy : []
  }

  override func draggingExited(_ sender: (any NSDraggingInfo)?) {
    state.setHoldDropTargeted(false)
  }

  override func draggingEnded(_ sender: any NSDraggingInfo) {
    state.setHoldDropTargeted(false)
  }

  override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    canAcceptHoldDrop(sender)
  }

  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    let point = convert(sender.draggingLocation, from: nil)
    guard canAcceptHoldDrop(sender),
          state.isExpanded ? acceptsExpandedHoldDrop(at: point) : acceptsCollapsedNotchDrag(at: point) else {
      return false
    }

    expandForHoldDrag()
    let imported = importHoldDrop(sender)
    if imported {
      state.markHoldDropLanded()
    } else {
      state.setHoldDropTargeted(false)
    }
    return imported
  }

  private func expandForHoldDrag() {
    guard state.positionMode == .notch else {
      return
    }

    state.isExpanded = true
    state.isHovering = false
  }

  private func canAcceptHoldDrop(_ sender: any NSDraggingInfo) -> Bool {
    guard state.shelfModuleEnabled else {
      return false
    }

    return HoldDropPayloadDetector.hasHoldPayload(in: sender.draggingPasteboard)
  }

  private func importHoldDrop(_ sender: any NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard

    switch importRoute(for: pasteboard) {
    case .filePromise:
      return receiveFilePromises(from: pasteboard)
    case .fileURL:
      return importFileURLs(from: pasteboard)
    case .webURL:
      return importWebURLs(from: pasteboard)
    case .imageData:
      return importImageData(from: pasteboard)
    case .text:
      return importText(from: pasteboard)
    case nil:
      return false
    }
  }

  private func importRoute(for pasteboard: NSPasteboard) -> HoldDropImportRoute? {
    HoldDropPayloadDetector.importRoute(in: pasteboard)
  }

  private func receiveFilePromises(from pasteboard: NSPasteboard) -> Bool {
    guard let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
          !receivers.isEmpty else {
      return false
    }

    let destination = promisedFileDestination()
    try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    receivers.forEach { receiver in
      receiver.receivePromisedFiles(
        atDestination: destination,
        options: [:],
        operationQueue: .main
      ) { [weak state] fileURL, error in
        guard error == nil else {
          return
        }

        Task { @MainActor in
          state?.addShelfScreenshots([fileURL])
        }
      }
    }

    return true
  }

  private func importFileURLs(from pasteboard: NSPasteboard) -> Bool {
    let urls = HoldDropPayloadDetector.fileURLs(in: pasteboard)
    guard !urls.isEmpty else {
      return false
    }

    state.addShelfFiles(urls)
    return true
  }

  private func importWebURLs(from pasteboard: NSPasteboard) -> Bool {
    let webURLs = HoldDropPayloadDetector.webURLs(in: pasteboard)
    guard !webURLs.isEmpty else {
      return false
    }

    webURLs.forEach { state.addShelfText($0.absoluteString) }
    return true
  }

  private func importText(from pasteboard: NSPasteboard) -> Bool {
    guard let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }

    state.addShelfText(text)
    return true
  }

  private func importImageData(from pasteboard: NSPasteboard) -> Bool {
    guard let data = HoldImageDataReader.pngData(from: pasteboard) else {
      return false
    }

    let destination = promisedFileDestination().appendingPathComponent("Dropped Screenshot \(Self.dropTimestamp.string(from: Date())).png")
    do {
      try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: destination, options: .atomic)
      state.addShelfScreenshots([destination])
      return true
    } catch {
      return false
    }
  }

  private func promisedFileDestination() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("Flowline", isDirectory: true)
      .appendingPathComponent("HoldDrops", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
  }

  private func acceptsHoldDrag(at point: NSPoint) -> Bool {
    if state.isExpanded {
      return acceptsExpandedHoldDrop(at: point)
    }

    return acceptsCollapsedNotchDrag(at: point)
  }

  private func acceptsCollapsedNotchDrag(at point: NSPoint) -> Bool {
    guard state.positionMode == .notch else {
      return bounds.contains(point)
    }

    let size = NSSize(width: max(state.physicalNotchWidth, NotchMetrics.hoverWidth), height: state.physicalNotchHeight + 10)
    let frame = NSRect(
      x: (bounds.width - size.width) / 2,
      y: bounds.height - size.height,
      width: size.width,
      height: size.height
    )

    return frame.contains(point)
  }

  private func acceptsExpandedHoldDrop(at point: NSPoint) -> Bool {
    guard state.positionMode == .notch else {
      return bounds.contains(point)
    }

    return OverlayHoldDropTarget.containsExpandedHoldDrop(point, preferences: modulePreferences)
  }

  private var modulePreferences: FlowlineModulePreferences {
    FlowlineModulePreferences(
      context: state.workspaceModuleEnabled,
      music: state.musicModuleEnabled,
      calendar: state.calendarModuleEnabled,
      shelf: state.shelfModuleEnabled
    )
  }

  private static let dropTimestamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
    return formatter
  }()
}
