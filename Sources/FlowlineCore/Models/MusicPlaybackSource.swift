import Foundation

public enum MusicPlaybackSource: CaseIterable, Sendable {
  case spotify
  case appleMusic

  public var displayName: String {
    switch self {
    case .spotify:
      return "Spotify"
    case .appleMusic:
      return "Apple Music"
    }
  }

  public var bundleIdentifier: String {
    switch self {
    case .spotify:
      return "com.spotify.client"
    case .appleMusic:
      return "com.apple.Music"
    }
  }

  public var appleScriptApplicationName: String {
    switch self {
    case .spotify:
      return "Spotify"
    case .appleMusic:
      return "Music"
    }
  }

  public func normalizedDuration(_ rawDuration: TimeInterval) -> TimeInterval {
    switch self {
    case .spotify:
      return rawDuration / 1000
    case .appleMusic:
      return rawDuration
    }
  }
}
