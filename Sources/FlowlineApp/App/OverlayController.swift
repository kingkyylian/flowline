import AppKit
import Combine
import FlowlineCore
import SwiftUI

@MainActor
final class OverlayController {
  private let state: AppState
  private let panel: NSPanel
  private var screenObserver: NSObjectProtocol?
  private var mouseMonitor: Any?
  private var collapsedHoverGlobalMonitor: Any?
  private var collapsedHoverLocalMonitor: Any?
  private var dragPasteboardBaselineChangeCount = NSPasteboard(name: .drag).changeCount
  private var cancellables: Set<AnyCancellable> = []

  init(state: AppState) {
    self.state = state

    panel = NSPanel(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: NotchMetrics.windowWidth,
        height: NotchMetrics.expandedHeight
      ),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .statusBar
    panel.isOpaque = false
    panel.hasShadow = false
    panel.backgroundColor = .clear
    panel.hidesOnDeactivate = false
    panel.animationBehavior = .none
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
    panel.contentView = OverlayHostingView(state: state)

    Publishers.CombineLatest(
      state.$isExpanded.removeDuplicates(),
      state.$positionMode.removeDuplicates()
    )
    .sink { [weak self] isExpanded, positionMode in
      self?.positionPanel()
      self?.updateMouseMonitor(isExpanded: isExpanded)
      self?.updateCollapsedHoverMonitor(isExpanded: isExpanded, positionMode: positionMode)
    }
    .store(in: &cancellables)

    state.$showOverFullscreen
      .removeDuplicates()
      .sink { [weak self] showOverFullscreen in
        self?.updateCollectionBehavior(showOverFullscreen: showOverFullscreen)
      }
      .store(in: &cancellables)

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.positionPanel()
      }
    }
  }

  deinit {
    MainActor.assumeIsolated {
      if let screenObserver {
        NotificationCenter.default.removeObserver(screenObserver)
      }

      if let mouseMonitor {
        NSEvent.removeMonitor(mouseMonitor)
      }
      if let collapsedHoverGlobalMonitor {
        NSEvent.removeMonitor(collapsedHoverGlobalMonitor)
      }
      if let collapsedHoverLocalMonitor {
        NSEvent.removeMonitor(collapsedHoverLocalMonitor)
      }
    }
  }

  func show() {
    positionPanel()
    panel.orderFrontRegardless()
  }

  func toggleExpanded() {
    state.isExpanded.toggle()
  }

  func setExpanded(_ expanded: Bool) {
    guard state.isExpanded != expanded else {
      return
    }

    state.isExpanded = expanded
  }

  private func updateMouseMonitor(isExpanded: Bool) {
    if isExpanded {
      guard mouseMonitor == nil else {
        return
      }

      mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
        Task { @MainActor in
          self?.collapseIfMouseIsOutside()
        }
      }
    } else if let mouseMonitor {
      NSEvent.removeMonitor(mouseMonitor)
      self.mouseMonitor = nil
    }
  }

  private func collapseIfMouseIsOutside() {
    guard state.isExpanded else {
      return
    }

    let hitFrame = panel.frame.insetBy(dx: -6, dy: -6)
    guard !hitFrame.contains(NSEvent.mouseLocation) else {
      return
    }

    state.isExpanded = false
  }

  private func positionPanel() {
    let positionMode = displayPositionMode(for: targetScreen)
    state.updatePositionMode(positionMode)
    positionPanel(positionMode: positionMode)
  }

  private func positionPanel(positionMode: PositionMode) {
    panel.setFrame(
      frame(for: windowSize(positionMode: positionMode), positionMode: positionMode),
      display: true
    )
    updateCollapsedHoverState()
  }

  private func updateCollapsedHoverMonitor(isExpanded: Bool, positionMode: PositionMode) {
    guard positionMode == .notch, !isExpanded else {
      stopCollapsedHoverMonitor()
      if positionMode == .notch {
        state.isHovering = false
      }
      return
    }

    if collapsedHoverGlobalMonitor == nil {
      refreshDragPasteboardBaseline()
      collapsedHoverGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
        matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseUp, .rightMouseUp]
      ) { [weak self] event in
        Task { @MainActor in
          self?.updateCollapsedHoverState(for: NSEvent.mouseLocation, eventType: event.type)
        }
      }
    }

    if collapsedHoverLocalMonitor == nil {
      collapsedHoverLocalMonitor = NSEvent.addLocalMonitorForEvents(
        matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseUp, .rightMouseUp]
      ) { [weak self] event in
        Task { @MainActor in
          self?.updateCollapsedHoverState(for: NSEvent.mouseLocation, eventType: event.type)
        }
        return event
      }
    }

    updateCollapsedHoverState()
  }

  private func stopCollapsedHoverMonitor() {
    if let collapsedHoverGlobalMonitor {
      NSEvent.removeMonitor(collapsedHoverGlobalMonitor)
      self.collapsedHoverGlobalMonitor = nil
    }

    if let collapsedHoverLocalMonitor {
      NSEvent.removeMonitor(collapsedHoverLocalMonitor)
      self.collapsedHoverLocalMonitor = nil
    }
  }

  private func updateCollapsedHoverState() {
    guard state.positionMode == .notch, !state.isExpanded else {
      return
    }

    updateCollapsedHoverState(for: NSEvent.mouseLocation, eventType: .mouseMoved)
  }

  private func updateCollapsedHoverState(for mouseLocation: NSPoint, eventType: NSEvent.EventType) {
    guard state.positionMode == .notch, !state.isExpanded else {
      return
    }

    if eventType != .leftMouseDragged && eventType != .rightMouseDragged {
      refreshDragPasteboardBaseline()
    }

    let activationFrame = collapsedNotchDragActivationFrame
    if OverlayDragActivation.shouldExpandCollapsedNotch(
      eventType: eventType,
      positionMode: state.positionMode,
      isExpanded: state.isExpanded,
      dragPasteboard: currentDragPasteboard(for: eventType),
      dragPasteboardBaselineChangeCount: dragPasteboardBaselineChangeCount,
      mouseLocation: mouseLocation,
      collapsedFrame: activationFrame
    ) {
      state.isExpanded = true
      state.isHovering = false
      return
    }

    let isHovering = collapsedNotchScreenFrame.contains(mouseLocation)
    guard state.isHovering != isHovering else {
      return
    }

    state.isHovering = isHovering
  }

  private func currentDragPasteboard(for eventType: NSEvent.EventType) -> NSPasteboard? {
    guard eventType == .leftMouseDragged || eventType == .rightMouseDragged else {
      return nil
    }

    return NSPasteboard(name: .drag)
  }

  private func refreshDragPasteboardBaseline() {
    dragPasteboardBaselineChangeCount = NSPasteboard(name: .drag).changeCount
  }

  private func windowSize(positionMode: PositionMode) -> NSSize {
    return positionMode == .notch
      ? NSSize(width: NotchMetrics.windowWidth, height: NotchMetrics.expandedHeight)
      : NSSize(width: state.isExpanded ? 760 : NotchMetrics.companionFallbackWidth, height: state.isExpanded ? 154 : 40)
  }

  private func updateCollectionBehavior(showOverFullscreen: Bool) {
    var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary]
    if showOverFullscreen {
      behavior.insert(.fullScreenAuxiliary)
    }

    panel.collectionBehavior = behavior
  }

  private func frame(for size: NSSize, positionMode: PositionMode) -> NSRect {
    let screen = targetScreen
    let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

    switch positionMode {
    case .companion:
      return companionFrame(for: size, screen: screen, fallbackFrame: frame)
    case .notch:
      updatePhysicalNotch(for: screen)
      let x = notchCenterX(for: screen) - size.width / 2
      let y = frame.maxY - size.height

      return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
  }

  private func companionFrame(for size: NSSize, screen: NSScreen?, fallbackFrame: NSRect) -> NSRect {
    let visibleFrame = screen?.visibleFrame ?? fallbackFrame
    let margin: CGFloat = 10
    let x = visibleFrame.maxX - size.width - margin
    let y = visibleFrame.maxY - size.height - margin

    return NSRect(
      origin: NSPoint(
        x: max(visibleFrame.minX + margin, x),
        y: max(visibleFrame.minY + margin, y)
      ),
      size: size
    )
  }

  private var targetScreen: NSScreen? {
    return NSScreen.main ?? NSScreen.screens.first
  }

  private var collapsedNotchScreenFrame: NSRect {
    NSRect(
      x: panel.frame.midX - state.physicalNotchWidth / 2,
      y: panel.frame.maxY - state.physicalNotchHeight,
      width: state.physicalNotchWidth,
      height: state.physicalNotchHeight
    )
  }

  private var collapsedNotchDragActivationFrame: NSRect {
    let width = NotchMetrics.expandedWidth
    let height = state.physicalNotchHeight + 44

    return NSRect(
      x: panel.frame.midX - width / 2,
      y: panel.frame.maxY - height,
      width: width,
      height: height
    )
  }

  private func displayPositionMode(for screen: NSScreen?) -> PositionMode {
    guard let screen else {
      return .companion
    }

    return DisplayNotchGeometry.hasCameraHousing(
      screenFrame: screen.frame,
      auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
      auxiliaryTopRightArea: screen.auxiliaryTopRightArea
    ) ? .notch : .companion
  }

  private func notchCenterX(for screen: NSScreen?) -> CGFloat {
    guard let screen else {
      return 720
    }

    return DisplayNotchGeometry.centerX(
      screenFrame: screen.frame,
      auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
      auxiliaryTopRightArea: screen.auxiliaryTopRightArea
    )
  }

  private func updatePhysicalNotch(for screen: NSScreen?) {
    guard
      let screen,
      let housingFrame = DisplayNotchGeometry.housingFrame(
        screenFrame: screen.frame,
        auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
        auxiliaryTopRightArea: screen.auxiliaryTopRightArea
      )
    else {
      state.updatePhysicalNotch(
        width: NotchMetrics.fallbackPhysicalWidth,
        height: NotchMetrics.collapsedHeight
      )
      return
    }

    state.updatePhysicalNotch(width: housingFrame.width, height: housingFrame.height)
  }
}
