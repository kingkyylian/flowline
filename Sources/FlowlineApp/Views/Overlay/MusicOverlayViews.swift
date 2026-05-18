import FlowlineCore
import SwiftUI

struct NotchMusicNowPlaying: View {
  let playback: MusicPlaybackSnapshot?
  let previous: () -> Void
  let togglePlayPause: () -> Void
  let next: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .center, spacing: 8) {
        MusicArtworkMark(playback: playback, size: 26)

        VStack(alignment: .leading, spacing: 2) {
          Text(playback?.displayTitle ?? "No track playing")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(FlowlineDesign.foreground(for: .notch))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .help(playback?.displayTitle ?? "No track playing")

          Text(playback?.displayArtist ?? "Spotify / Music")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(FlowlineDesign.secondary(for: .notch))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .help(playback?.displayArtist ?? "Spotify / Music")
        }
      }

      MusicTimelineRow(playback: playback, positionMode: .notch)
        .frame(width: NotchMetrics.musicTimelineWidth, alignment: .leading)

      MusicTransportControls(
        playback: playback,
        positionMode: .notch,
        previous: previous,
        togglePlayPause: togglePlayPause,
        next: next
      )
      .frame(width: NotchMetrics.musicTimelineWidth, alignment: .center)
    }
  }
}

struct MusicPanel: View {
  let playback: MusicPlaybackSnapshot?
  let positionMode: PositionMode
  let previous: () -> Void
  let togglePlayPause: () -> Void
  let next: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      PanelHeader(title: "MUSIC", systemImage: "music.note", positionMode: positionMode)

      HStack(spacing: 10) {
        MusicArtworkMark(playback: playback, size: 42)

        VStack(alignment: .leading, spacing: 3) {
          Text(playback?.displayTitle ?? "Media controls")
            .font(FlowlineDesign.Typography.title)
            .foregroundStyle(FlowlineDesign.foreground(for: positionMode))
            .lineLimit(1)

          Text(playback?.displayArtist ?? "System playback")
            .font(FlowlineDesign.Typography.subtitle)
            .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
            .lineLimit(1)

          Text(playback?.source.uppercased() ?? "SPOTIFY / MUSIC")
            .font(FlowlineDesign.Typography.metadata)
            .foregroundStyle(FlowlineDesign.tertiary(for: positionMode))
            .lineLimit(1)
        }
      }

      MusicTimelineRow(playback: playback, positionMode: positionMode)

      Spacer()

      MusicTransportControls(
        playback: playback,
        positionMode: positionMode,
        previous: previous,
        togglePlayPause: togglePlayPause,
        next: next
      )
    }
    .padding(FlowlineDesign.Metrics.panelPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .flowlinePanel(positionMode: positionMode)
  }
}

private struct MusicArtworkMark: View {
  let playback: MusicPlaybackSnapshot?
  let size: CGFloat

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(Color.black)

      VStack(spacing: 3) {
        ForEach(0..<4, id: \.self) { index in
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white.opacity(opacity(for: index)))
            .frame(width: CGFloat(10 + index * 4), height: 2)
        }
      }

      Image(systemName: playback?.isPlaying == true ? "music.note" : "play.fill")
        .font(.system(size: size > 32 ? 13 : 9, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.88))
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
  }

  private func opacity(for index: Int) -> Double {
    guard playback?.isPlaying == true else {
      return 0.20
    }

    return [0.32, 0.68, 0.44, 0.82][index]
  }
}

private struct MusicProgressBar: View {
  let progress: Double
  let positionMode: PositionMode
  var height: CGFloat = 3

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(FlowlineDesign.separator(for: positionMode))

        Rectangle()
          .fill(FlowlineDesign.foreground(for: positionMode).opacity(0.72))
          .frame(width: max(2, proxy.size.width * progress))
      }
    }
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
  }
}

private struct MusicTimelineRow: View {
  let playback: MusicPlaybackSnapshot?
  let positionMode: PositionMode

  var body: some View {
    TimelineView(.periodic(from: Date(), by: 1)) { context in
      VStack(spacing: 3) {
        MusicProgressBar(
          progress: playback?.progress(at: context.date) ?? 0,
          positionMode: positionMode,
          height: positionMode == .notch ? 4 : 3
        )

        HStack(spacing: 8) {
          Text(playback?.elapsedText(at: context.date) ?? "0:00")
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(playback?.durationText ?? "--:--")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: positionMode == .notch ? 9 : 10, weight: .medium, design: .monospaced))
        .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
      }
    }
    .frame(height: positionMode == .notch ? 18 : 16)
  }
}

private struct MusicTransportControls: View {
  let playback: MusicPlaybackSnapshot?
  let positionMode: PositionMode
  let previous: () -> Void
  let togglePlayPause: () -> Void
  let next: () -> Void

  var body: some View {
    HStack(spacing: positionMode == .notch ? 24 : 10) {
      MusicTransportButton(
        title: "Previous track",
        systemImage: "backward.end.fill",
        positionMode: positionMode,
        action: previous
      )

      MusicTransportButton(
        title: "Play or pause",
        systemImage: playback?.isPlaying == true ? "pause.fill" : "play.fill",
        positionMode: positionMode,
        isPrimary: true,
        action: togglePlayPause
      )

      MusicTransportButton(
        title: "Next track",
        systemImage: "forward.end.fill",
        positionMode: positionMode,
        action: next
      )
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.horizontal, positionMode == .notch ? 0 : 10)
    .padding(.vertical, positionMode == .notch ? 2 : 6)
    .background(positionMode == .notch ? Color.clear : Color.white.opacity(0.055))
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

private struct MusicTransportButton: View {
  let title: String
  let systemImage: String
  let positionMode: PositionMode
  var isPrimary = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: isPrimary ? 13 : 12, weight: .semibold))
        .frame(width: buttonWidth, height: buttonHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(FlowlineDesign.foreground(for: positionMode))
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .help(title)
    .accessibilityLabel(title)
  }

  private var buttonWidth: CGFloat {
    if isPrimary {
      return positionMode == .notch ? 42 : 48
    }

    return positionMode == .notch ? 32 : 36
  }

  private var buttonHeight: CGFloat {
    positionMode == .notch ? NotchUtilityMusicLayout.transportButtonHeight : 32
  }

  private var background: Color {
    positionMode == .notch ? Color.clear : Color.white.opacity(isPrimary ? 0.055 : 0.018)
  }
}
