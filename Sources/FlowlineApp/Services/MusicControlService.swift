import AppKit
import FlowlineCore

@MainActor
final class MusicControlService: ObservableObject {
  @Published private(set) var snapshot: MusicPlaybackSnapshot?

  private let controllers: [any MusicPlayerControlling] = MusicPlaybackSource.allCases.map {
    AppleScriptMusicPlayerController(source: $0)
  }
  private var timer: Timer?
  private var activePlayer: (any MusicPlayerControlling)?

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
  }

  isolated deinit {
    timer?.invalidate()
  }

  func previousTrack() {
    if let activePlayer, activePlayer.run(command: .previousTrack) {
      refresh()
      return
    }

    postMediaKey(18)
  }

  func togglePlayPause() {
    if let activePlayer, activePlayer.run(command: .togglePlayPause) {
      refresh()
      return
    }

    postMediaKey(16)
  }

  func nextTrack() {
    if let activePlayer, activePlayer.run(command: .nextTrack) {
      refresh()
      return
    }

    postMediaKey(17)
  }

  func refresh() {
    for controller in controllers {
      guard controller.isRunning() else {
        continue
      }

      activePlayer = controller
      snapshot = controller.playbackSnapshot()
      return
    }

    activePlayer = nil
    snapshot = nil
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
