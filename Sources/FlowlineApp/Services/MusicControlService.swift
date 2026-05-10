import Combine
import FlowlineCore
import Foundation

@MainActor
final class MusicControlService: ObservableObject {
  @Published private(set) var snapshot: MusicPlaybackSnapshot?

  private let worker = MusicPlaybackRefreshWorker()
  private var timer: Timer?
  private var refreshTask: Task<Void, Never>?
  private var commandRefreshTask: Task<Void, Never>?

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
    commandRefreshTask?.cancel()
    commandRefreshTask = nil
  }

  isolated deinit {
    timer?.invalidate()
    refreshTask?.cancel()
    commandRefreshTask?.cancel()
  }

  func previousTrack() {
    run(command: .previousTrack)
  }

  func togglePlayPause() {
    let command: MusicPlayerCommand
    if let snapshot {
      command = snapshot.isPlaying ? .pause : .play
    } else {
      command = .togglePlayPause
    }

    snapshot = snapshot?.toggledPlayback(at: Date())
    run(command: command)
  }

  func nextTrack() {
    run(command: .nextTrack)
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

  private func run(command: MusicPlayerCommand) {
    let worker = worker
    Task { @MainActor [weak self] in
      _ = await worker.run(command: command)
      guard let self else {
        return
      }

      self.scheduleRefreshAfterCommand()
    }
  }

  private func scheduleRefreshAfterCommand() {
    commandRefreshTask?.cancel()
    commandRefreshTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled, let self else {
        return
      }

      self.refresh()
      self.commandRefreshTask = nil
    }
  }
}
