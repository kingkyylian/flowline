import FlowlineCore
import Foundation
import Testing
@testable import FlowlineApp

@Test func refreshWorkerSelectsFirstRunningController() async throws {
  let stopped = FakeMusicPlayerController(source: .spotify, isRunningValue: false, snapshot: nil)
  let runningSnapshot = MusicPlaybackSnapshot(
    source: "Apple Music",
    title: "Track",
    artist: "Artist",
    isPlaying: true,
    elapsed: 12,
    duration: 120
  )
  let running = FakeMusicPlayerController(source: .appleMusic, isRunningValue: true, snapshot: runningSnapshot)
  let worker = MusicPlaybackRefreshWorker(controllers: [stopped, running])

  let snapshot = await worker.refresh()

  #expect(snapshot == runningSnapshot)
  #expect(await worker.run(command: .nextTrack))
}

@Test func refreshWorkerClearsActiveControllerWhenNothingRuns() async {
  let running = FakeMusicPlayerController(source: .spotify, isRunningValue: true, snapshot: nil, commandResult: true)
  let stopped = FakeMusicPlayerController(source: .appleMusic, isRunningValue: false, snapshot: nil)
  let worker = MusicPlaybackRefreshWorker(controllers: [running])

  _ = await worker.refresh()
  #expect(await worker.run(command: .nextTrack))

  await worker.replaceControllersForTesting([stopped])
  let snapshot = await worker.refresh()

  #expect(snapshot == nil)
  #expect(await worker.run(command: .nextTrack) == false)
}

@Test func refreshWorkerRunsCommandOnFirstRunningControllerWhenNoSnapshotExists() async {
  let stopped = FakeMusicPlayerController(source: .spotify, isRunningValue: false, snapshot: nil)
  let running = FakeMusicPlayerController(source: .appleMusic, isRunningValue: true, snapshot: nil, commandResult: true)
  let worker = MusicPlaybackRefreshWorker(controllers: [stopped, running])

  #expect(await worker.run(command: .togglePlayPause))
}

@Test func mapsMusicPlayerCommandsToAppleScriptCommands() {
  #expect(MusicPlayerCommand.previousTrack.appleScriptCommand == "previous track")
  #expect(MusicPlayerCommand.play.appleScriptCommand == "play")
  #expect(MusicPlayerCommand.pause.appleScriptCommand == "pause")
  #expect(MusicPlayerCommand.togglePlayPause.appleScriptCommand == "playpause")
  #expect(MusicPlayerCommand.nextTrack.appleScriptCommand == "next track")
}

@MainActor
@Test func musicControlTogglesCurrentPlayerStateWithoutTrustingStaleSnapshot() async throws {
  let snapshot = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "Remote track",
    artist: "Remote artist",
    isPlaying: true,
    elapsed: 12,
    duration: 180
  )
  let controller = RecordingMusicPlayerController(source: .spotify, snapshot: snapshot)
  let worker = MusicPlaybackRefreshWorker(controllers: [controller])
  let service = MusicControlService(worker: worker)

  service.refresh()
  try await waitUntil { service.snapshot != nil }

  service.togglePlayPause()
  try await waitUntil { !controller.commands.isEmpty }

  #expect(controller.commands == [.togglePlayPause])
}

private struct FakeMusicPlayerController: MusicPlayerControlling {
  let source: MusicPlaybackSource
  let isRunningValue: Bool
  let snapshot: MusicPlaybackSnapshot?
  var commandResult = true

  func isRunning() -> Bool {
    isRunningValue
  }

  func playbackSnapshot() -> MusicPlaybackSnapshot? {
    snapshot
  }

  func run(command: MusicPlayerCommand) -> Bool {
    commandResult
  }
}

private final class RecordingMusicPlayerController: MusicPlayerControlling, @unchecked Sendable {
  let source: MusicPlaybackSource
  let snapshot: MusicPlaybackSnapshot?
  private let lock = NSLock()
  private var recordedCommands: [MusicPlayerCommand] = []

  init(source: MusicPlaybackSource, snapshot: MusicPlaybackSnapshot?) {
    self.source = source
    self.snapshot = snapshot
  }

  var commands: [MusicPlayerCommand] {
    lock.withLock {
      recordedCommands
    }
  }

  func isRunning() -> Bool {
    true
  }

  func playbackSnapshot() -> MusicPlaybackSnapshot? {
    snapshot
  }

  func run(command: MusicPlayerCommand) -> Bool {
    lock.withLock {
      recordedCommands.append(command)
    }
    return true
  }
}

@MainActor
private func waitUntil(
  timeout: TimeInterval = 3.0,
  predicate: @escaping () -> Bool
) async throws {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if predicate() {
      return
    }

    try await Task.sleep(for: .milliseconds(10))
  }

  throw WaitTimeoutError()
}

private struct WaitTimeoutError: Error {}
