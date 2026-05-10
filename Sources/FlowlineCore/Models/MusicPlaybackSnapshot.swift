import Foundation

public struct MusicPlaybackSnapshot: Equatable, Sendable {
  public var source: String
  public var title: String
  public var artist: String
  public var album: String?
  public var isPlaying: Bool
  public var elapsed: TimeInterval
  public var duration: TimeInterval
  public var capturedAt: Date

  public init(
    source: String,
    title: String,
    artist: String,
    album: String? = nil,
    isPlaying: Bool,
    elapsed: TimeInterval,
    duration: TimeInterval,
    capturedAt: Date = Date()
  ) {
    self.source = source
    self.title = title
    self.artist = artist
    self.album = album
    self.isPlaying = isPlaying
    self.elapsed = elapsed
    self.duration = duration
    self.capturedAt = capturedAt
  }

  public var displayTitle: String {
    title.isEmpty ? "Nothing playing" : title
  }

  public var displayArtist: String {
    artist.isEmpty ? source : artist
  }

  public var progress: Double {
    progress(at: Date())
  }

  public var timeText: String {
    timeText(at: Date())
  }

  public func elapsed(at date: Date) -> TimeInterval {
    let baseElapsed = max(0, elapsed)
    guard isPlaying else {
      return baseElapsed
    }

    let liveElapsed = baseElapsed + max(0, date.timeIntervalSince(capturedAt))
    guard duration > 0 else {
      return liveElapsed
    }

    return min(liveElapsed, duration)
  }

  public func progress(at date: Date) -> Double {
    guard duration > 0 else {
      return 0
    }

    return min(max(elapsed(at: date) / duration, 0), 1)
  }

  public func timeText(at date: Date) -> String {
    guard duration > 0 else {
      let liveElapsed = elapsed(at: date)
      return liveElapsed > 0 ? Self.format(seconds: liveElapsed) : "--:--"
    }

    return "\(Self.format(seconds: elapsed(at: date))) / \(Self.format(seconds: duration))"
  }

  public func elapsedText(at date: Date) -> String {
    let liveElapsed = elapsed(at: date)
    return liveElapsed > 0 ? Self.format(seconds: liveElapsed) : "0:00"
  }

  public var durationText: String {
    duration > 0 ? Self.format(seconds: duration) : "--:--"
  }

  public func withPlaybackState(_ isPlaying: Bool, at date: Date) -> Self {
    var copy = self
    copy.elapsed = elapsed(at: date)
    copy.isPlaying = isPlaying
    copy.capturedAt = date
    return copy
  }

  public func toggledPlayback(at date: Date) -> Self {
    withPlaybackState(!isPlaying, at: date)
  }

  private static func format(seconds: TimeInterval) -> String {
    let totalSeconds = Int(max(0, seconds).rounded(.down))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%d:%02d", minutes, seconds)
  }
}
