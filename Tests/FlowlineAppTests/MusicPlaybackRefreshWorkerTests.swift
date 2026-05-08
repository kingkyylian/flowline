import FlowlineCore
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
