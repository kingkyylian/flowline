import AppKit
import FlowlineCore

protocol MusicPlayerControlling: Sendable {
  var source: MusicPlaybackSource { get }

  func isRunning() -> Bool
  func playbackSnapshot() -> MusicPlaybackSnapshot?
  func run(command: MusicPlayerCommand) -> Bool
}

enum MusicPlayerCommand {
  case previousTrack
  case togglePlayPause
  case nextTrack

  var appleScriptCommand: String {
    switch self {
    case .previousTrack:
      return "previous track"
    case .togglePlayPause:
      return "playpause"
    case .nextTrack:
      return "next track"
    }
  }
}

struct AppleScriptMusicPlayerController: MusicPlayerControlling {
  let source: MusicPlaybackSource

  func isRunning() -> Bool {
    NSWorkspace.shared.runningApplications.contains { app in
      app.bundleIdentifier == source.bundleIdentifier
    }
  }

  func playbackSnapshot() -> MusicPlaybackSnapshot? {
    let script = """
    tell application "\(source.appleScriptApplicationName)"
      if it is not running then return ""
      if player state is stopped then return ""
      set trackName to name of current track
      set artistName to artist of current track
      set albumName to album of current track
      set durationValue to duration of current track
      set positionValue to player position
      set stateValue to player state as string
      return trackName & linefeed & artistName & linefeed & albumName & linefeed & durationValue & linefeed & positionValue & linefeed & stateValue
    end tell
    """

    let result = executeScript(script)
    guard result.error == nil else {
      return MusicPlaybackSnapshot(
        source: source.displayName,
        title: "Allow Automation",
        artist: "Needed for track details",
        isPlaying: false,
        elapsed: 0,
        duration: 0
      )
    }

    guard let output = result.output, !output.isEmpty else {
      return MusicPlaybackSnapshot(
        source: source.displayName,
        title: "Start playback",
        artist: source.displayName,
        isPlaying: false,
        elapsed: 0,
        duration: 0
      )
    }

    return MusicPlaybackSnapshotParser.parse(output, source: source)
  }

  func run(command: MusicPlayerCommand) -> Bool {
    runScript("""
    tell application "\(source.appleScriptApplicationName)"
      if it is running then \(command.appleScriptCommand)
    end tell
    """) != nil
  }

  private func runScript(_ source: String) -> String? {
    let result = executeScript(source)
    guard result.error == nil else {
      return nil
    }

    return result.output
  }

  private func executeScript(_ source: String) -> (output: String?, error: NSDictionary?) {
    var error: NSDictionary?
    guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
      return (nil, error)
    }

    return (output.stringValue, error)
  }
}
