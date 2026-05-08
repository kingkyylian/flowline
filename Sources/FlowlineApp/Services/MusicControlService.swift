import AppKit
import FlowlineCore

@MainActor
final class MusicControlService: ObservableObject {
  @Published private(set) var snapshot: MusicPlaybackSnapshot?

  private let worker = MusicPlaybackRefreshWorker()
  private var timer: Timer?
  private var refreshTask: Task<Void, Never>?

  func start() {
    refresh()

    guard timer == nil else {
      return
    }

    timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    refreshTask?.cancel()
    refreshTask = nil
  }

  isolated deinit {
    timer?.invalidate()
    refreshTask?.cancel()
  }

  func previousTrack() {
    run(command: .previousTrack, fallbackKeyCode: 18)
  }

  func togglePlayPause() {
    run(command: .togglePlayPause, fallbackKeyCode: 16)
  }

  func nextTrack() {
    run(command: .nextTrack, fallbackKeyCode: 17)
  }

  func refresh() {
    guard refreshTask == nil else {
      return
    }

    let worker = worker
    refreshTask = Task { @MainActor [weak self] in
      let snapshot = await worker.refresh()
      guard let self else {
        return
      }

      defer {
        self.refreshTask = nil
      }

      guard !Task.isCancelled else {
        return
      }

      self.snapshot = snapshot
    }
  }

  private func run(command: MusicPlayerCommand, fallbackKeyCode: Int) {
    let worker = worker
    Task { @MainActor [weak self] in
      let didRun = await worker.run(command: command)
      guard let self else {
        return
      }

      if didRun {
        self.refresh()
      } else {
        self.postMediaKey(fallbackKeyCode)
      }
    }
  }

  private func postMediaKey(_ keyCode: Int) {
    postMediaKey(keyCode, isDown: true)
    postMediaKey(keyCode, isDown: false)
  }

  private func postMediaKey(_ keyCode: Int, isDown: Bool) {
    let keyState = isDown ? 0xA00 : 0xB00
    let data1 = (keyCode << 16) | keyState

    guard
      let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(keyState)),
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        subtype: 8,
        data1: data1,
        data2: -1
      ),
      let cgEvent = event.cgEvent
    else {
      return
    }

    cgEvent.post(tap: .cghidEventTap)
  }
}
