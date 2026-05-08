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
  let shortTrack = MusicPlaybackSnapshot(
    source: "Spotify",
    title: "Track",
    artist: "Artist",
    isPlaying: true,
    elapsed: 65.9,
    duration: 185
  )

  let longTrack = MusicPlaybackSnapshot(
    source: "Music",
    title: "Set",
    artist: "Artist",
    isPlaying: true,
    elapsed: 3671,
    duration: 3910
  )

  #expect(shortTrack.timeText == "1:05 / 3:05")
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

@Test func parsesLocalizedMusicPlaybackNumbers() throws {
  #expect(MusicPlaybackValueParser.timeInterval("12.5") == 12.5)
  #expect(MusicPlaybackValueParser.timeInterval("12,5") == 12.5)
  #expect(MusicPlaybackValueParser.timeInterval(" 165000 ") == 165000)
}
