import Foundation

public enum MusicPlaybackSnapshotParser {
  public static func parse(
    _ output: String,
    source: MusicPlaybackSource,
    capturedAt: Date = Date()
  ) -> MusicPlaybackSnapshot? {
    let parts = output
      .components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    guard parts.count >= 6 else {
      return nil
    }

    let rawDuration = MusicPlaybackValueParser.timeInterval(parts[3])
    let rawElapsed = MusicPlaybackValueParser.timeInterval(parts[4])

    return MusicPlaybackSnapshot(
      source: source.displayName,
      title: parts[0],
      artist: parts[1],
      album: parts[2].isEmpty ? nil : parts[2],
      isPlaying: parts[5].localizedCaseInsensitiveContains("playing"),
      elapsed: rawElapsed,
      duration: source.normalizedDuration(rawDuration),
      capturedAt: capturedAt
    )
  }
}
