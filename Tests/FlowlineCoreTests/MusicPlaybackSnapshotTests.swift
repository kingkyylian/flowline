import Foundation
import Testing
@testable import FlowlineCore

@Test func clampsMusicPlaybackProgress() throws {
  let overrun = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "Track",
    artist: "Artist",
    isPlaying: true,
    elapsed: 125,
    duration: 100
  )

  let negative = MusicPlaybackSnapshot(
    source: "Music",
    title: "Track",
    artist: "Artist",
    isPlaying: false,
    elapsed: -10,
    duration: 100
  )

  #expect(overrun.progress == 1)
  #expect(negative.progress == 0)
}

@Test func fallsBackToSourceWhenMusicArtistIsMissing() throws {
  let snapshot = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "",
    artist: "",
    isPlaying: false,
    elapsed: 0,
    duration: 0
  )

  #expect(snapshot.displayTitle == "Nothing playing")
  #expect(snapshot.displayArtist == "Spotify")
}

@Test func formatsMusicPlaybackTime() throws {
  let capturedAt = Date(timeIntervalSinceReferenceDate: 100)
  let shortTrack = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "Track",
    artist: "Artist",
    isPlaying: true,
    elapsed: 65.9,
    duration: 185,
    capturedAt: capturedAt
  )

  let longTrack = MusicPlaybackSnapshot(
    source: "Music",
    title: "Set",
    artist: "Artist",
    isPlaying: true,
    elapsed: 3671,
    duration: 3910
  )

  #expect(shortTrack.timeText(at: capturedAt) == "1:05 / 3:05")
  #expect(shortTrack.elapsedText(at: capturedAt) == "1:05")
  #expect(shortTrack.durationText == "3:05")
  #expect(longTrack.timeText == "1:01:11 / 1:05:10")
}

@Test func estimatesLiveMusicPlaybackTimeWhilePlaying() throws {
  let capturedAt = Date(timeIntervalSinceReferenceDate: 100)
  let snapshot = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "Track",
    artist: "Artist",
    isPlaying: true,
    elapsed: 10,
    duration: 185,
    capturedAt: capturedAt
  )

  let fiveSecondsLater = capturedAt.addingTimeInterval(5)

  #expect(snapshot.elapsed(at: fiveSecondsLater) == 15)
  #expect(snapshot.timeText(at: fiveSecondsLater) == "0:15 / 3:05")
}

@Test func keepsPausedMusicPlaybackTimeStable() throws {
  let capturedAt = Date(timeIntervalSinceReferenceDate: 100)
  let snapshot = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "Track",
    artist: "Artist",
    isPlaying: false,
    elapsed: 10,
    duration: 185,
    capturedAt: capturedAt
  )

  let fiveSecondsLater = capturedAt.addingTimeInterval(5)

  #expect(snapshot.elapsed(at: fiveSecondsLater) == 10)
  #expect(snapshot.timeText(at: fiveSecondsLater) == "0:10 / 3:05")
}

@Test func togglesMusicPlaybackStateAtCurrentLiveTime() throws {
  let capturedAt = Date(timeIntervalSinceReferenceDate: 100)
  let toggleDate = capturedAt.addingTimeInterval(5)
  let playing = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "Track",
    artist: "Artist",
    isPlaying: true,
    elapsed: 10,
    duration: 185,
    capturedAt: capturedAt
  )

  let paused = playing.toggledPlayback(at: toggleDate)

  #expect(!paused.isPlaying)
  #expect(paused.elapsed == 15)
  #expect(paused.capturedAt == toggleDate)
  #expect(paused.elapsed(at: toggleDate.addingTimeInterval(10)) == 15)
  #expect(paused.toggledPlayback(at: toggleDate).isPlaying)
}

@Test func parsesLocalizedMusicPlaybackNumbers() throws {
  #expect(MusicPlaybackValueParser.timeInterval("12.5") == 12.5)
  #expect(MusicPlaybackValueParser.timeInterval("12,5") == 12.5)
  #expect(MusicPlaybackValueParser.timeInterval(" 165000 ") == 165000)
}

@Test func parsesSpotifyPlaybackSnapshotOutput() throws {
  let output = "MR. MOONDIAL\nQuevedo\nBUENAS NOCHES\n165000\n12,5\nplaying"
  let snapshot = try #require(MusicPlaybackSnapshotParser.parse(output, source: .spotify))

  #expect(snapshot.source == "Spotify")
  #expect(snapshot.title == "MR. MOONDIAL")
  #expect(snapshot.artist == "Quevedo")
  #expect(snapshot.album == "BUENAS NOCHES")
  #expect(snapshot.isPlaying)
  #expect(snapshot.elapsed == 12.5)
  #expect(snapshot.duration == 165)
}

@Test func parsesAppleMusicPlaybackSnapshotOutput() throws {
  let output = "Song\nArtist\nAlbum\n185\n42.25\npaused"
  let snapshot = try #require(MusicPlaybackSnapshotParser.parse(output, source: .appleMusic))

  #expect(snapshot.source == "Apple Music")
  #expect(snapshot.title == "Song")
  #expect(snapshot.artist == "Artist")
  #expect(snapshot.duration == 185)
  #expect(snapshot.elapsed == 42.25)
  #expect(!snapshot.isPlaying)
}
