import AppKit
import FlowlineCore

@MainActor
final class MusicControlService: ObservableObject {
  @Published private(set) var snapshot: MusicPlaybackSnapshot?

  private var timer: Timer?
  private var activePlayer: MusicPlayerKind?

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
    if let activePlayer, runCommand("previous track", for: activePlayer) {
      refresh()
      return
    }

    postMediaKey(18)
  }

  func togglePlayPause() {
    if let activePlayer, runCommand("playpause", for: activePlayer) {
      refresh()
      return
    }

    postMediaKey(16)
  }

  func nextTrack() {
    if let activePlayer, runCommand("next track", for: activePlayer) {
      refresh()
      return
    }

    postMediaKey(17)
  }

  func refresh() {
    for player in MusicPlayerKind.allCases {
      guard isRunning(player) else {
        continue
      }

      activePlayer = player
      snapshot = playbackSnapshot(for: player)
      return
    }

    activePlayer = nil
    snapshot = nil
  }

  private func isRunning(_ player: MusicPlayerKind) -> Bool {
    NSWorkspace.shared.runningApplications.contains { app in
      app.bundleIdentifier == player.bundleIdentifier
    }
  }

  private func playbackSnapshot(for player: MusicPlayerKind) -> MusicPlaybackSnapshot? {
    let script = """
    tell application "\(player.applicationName)"
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
        source: player.displayName,
        title: "Allow Automation",
        artist: "Needed for track details",
        isPlaying: false,
        elapsed: 0,
        duration: 0
      )
    }

    guard let output = result.output, !output.isEmpty else {
      return MusicPlaybackSnapshot(
        source: player.displayName,
        title: "Start playback",
        artist: player.displayName,
        isPlaying: false,
        elapsed: 0,
        duration: 0
      )
    }

    let parts = output.components(separatedBy: "\n")
    guard parts.count >= 6 else {
      return nil
    }

    let rawDuration = MusicPlaybackValueParser.timeInterval(parts[3])
    let rawElapsed = MusicPlaybackValueParser.timeInterval(parts[4])

    return MusicPlaybackSnapshot(
      source: player.displayName,
      title: parts[0],
      artist: parts[1],
      album: parts[2].isEmpty ? nil : parts[2],
      isPlaying: parts[5].localizedCaseInsensitiveContains("playing"),
      elapsed: rawElapsed,
      duration: player.normalizedDuration(rawDuration)
    )
  }

  private func runCommand(_ command: String, for player: MusicPlayerKind) -> Bool {
    runScript("""
    tell application "\(player.applicationName)"
      if it is running then \(command)
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

private enum MusicPlayerKind: CaseIterable {
  case spotify
  case appleMusic

  var applicationName: String {
    switch self {
    case .spotify:
      return "Spotify"
    case .appleMusic:
      return "Music"
    }
  }

  var bundleIdentifier: String {
    switch self {
    case .spotify:
      return "com.spotify.client"
    case .appleMusic:
      return "com.apple.Music"
    }
  }

  var displayName: String {
    switch self {
    case .spotify:
      return "Spotify"
    case .appleMusic:
      return "Apple Music"
    }
  }

  func normalizedDuration(_ rawDuration: TimeInterval) -> TimeInterval {
    switch self {
    case .spotify:
      return rawDuration / 1000
    case .appleMusic:
      return rawDuration
    }
  }

}
