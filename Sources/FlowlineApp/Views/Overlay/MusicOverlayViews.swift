import FlowlineCore
import SwiftUI

struct NotchMusicNowPlaying: View {
  let playback: MusicPlaybackSnapshot?
  let previous: () -> Void
  let togglePlayPause: () -> Void
  let next: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 7) {
        MusicArtworkMark(playback: playback, size: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(playback?.displayTitle ?? "No track playing")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(FlowlineDesign.foreground(for: .notch))
            .lineLimit(1)
            .minimumScaleFactor(0.78)

          Text(playback?.displayArtist ?? "Spotify / Music")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(FlowlineDesign.secondary(for: .notch))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
      }

      MusicTimelineRow(playback: playback, positionMode: .notch)

      HStack(spacing: 7) {
        FlowlineIconButton(
          title: "Previous track",
          systemImage: "backward.end.fill",
          positionMode: .notch,
          action: previous
        )

        FlowlineIconButton(
          title: "Play or pause",
          systemImage: playback?.isPlaying == true ? "pause.fill" : "play.fill",
          positionMode: .notch,
          action: togglePlayPause
        )

        FlowlineIconButton(
          title: "Next track",
          systemImage: "forward.end.fill",
          positionMode: .notch,
          action: next
        )

        Spacer(minLength: 0)
      }
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

      HStack(spacing: 6) {
        FlowlineIconButton(
          title: "Previous track",
          systemImage: "backward.end.fill",
          positionMode: positionMode,
          action: previous
        )

        FlowlineIconButton(
          title: "Play or pause",
          systemImage: playback?.isPlaying == true ? "pause.fill" : "play.fill",
          positionMode: positionMode,
          action: togglePlayPause
        )

        FlowlineIconButton(
          title: "Next track",
          systemImage: "forward.end.fill",
          positionMode: positionMode,
          action: next
        )
      }
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
        .fill(background)

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
    .overlay {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
  }

  private var background: LinearGradient {
    let isPlaying = playback?.isPlaying == true
    return LinearGradient(
      colors: [
        Color.white.opacity(isPlaying ? 0.22 : 0.12),
        Color.white.opacity(isPlaying ? 0.08 : 0.04),
        Color.black.opacity(0.35)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
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
    .frame(height: 3)
    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
  }
}

private struct MusicTimelineRow: View {
  let playback: MusicPlaybackSnapshot?
  let positionMode: PositionMode

  var body: some View {
    TimelineView(.periodic(from: Date(), by: 1)) { context in
      HStack(spacing: 7) {
        MusicProgressBar(progress: playback?.progress(at: context.date) ?? 0, positionMode: positionMode)

        Text(playback?.timeText(at: context.date) ?? "--:--")
          .font(.system(size: positionMode == .notch ? 9 : 10, weight: .medium, design: .monospaced))
          .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .frame(width: positionMode == .notch ? 66 : 76, alignment: .trailing)
      }
    }
    .frame(height: 10)
  }
}
