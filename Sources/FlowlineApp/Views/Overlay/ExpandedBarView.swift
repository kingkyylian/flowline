import FlowlineCore
import SwiftUI

struct ExpandedBarView: View {
  @ObservedObject var state: AppState

  var body: some View {
    if state.positionMode == .notch {
      NotchCockpitView(state: state)
    } else {
      HStack(spacing: FlowlineDesign.Metrics.panelSpacing) {
        NowPanel(snapshot: state.snapshot, positionMode: state.positionMode)
        if state.musicModuleEnabled {
          MusicPanel(
            playback: state.musicPlayback,
            positionMode: state.positionMode,
            previous: state.musicPreviousTrack,
            togglePlayPause: state.musicTogglePlayPause,
            next: state.musicNextTrack
          )
        }
        AgentPanel(
          snapshot: state.snapshot,
          positionMode: state.positionMode,
          providers: state.agentProviders,
          actions: state.actions,
          perform: state.perform
        )
        if state.shelfModuleEnabled {
          ShelfPanel(
            items: state.snapshot.shelfItems,
            positionMode: state.positionMode,
            open: state.open,
            remove: state.removeShelfItem
          )
        }
      }
      .frame(width: 740, height: 134)
    }
  }
}

private struct NotchCockpitView: View {
  @ObservedObject var state: AppState

  var body: some View {
    HStack(spacing: 8) {
      NotchContextColumn(snapshot: state.snapshot)
        .frame(width: NotchMetrics.contextColumnWidth)

      NotchAgentColumn(
        snapshot: state.snapshot,
        providers: state.agentProviders,
        usage: state.aiUsage,
        actions: state.actions,
        perform: state.perform,
        refreshUsage: state.refreshAIUsage,
        copyContext: state.copyContextSummary
      )
      .frame(width: NotchMetrics.agentColumnWidth)

      NotchUtilityColumn(
        musicEnabled: state.musicModuleEnabled,
        shelfEnabled: state.shelfModuleEnabled,
        playback: state.musicPlayback,
        items: state.snapshot.shelfItems,
        open: state.open,
        remove: state.removeShelfItem,
        previous: state.musicPreviousTrack,
        togglePlayPause: state.musicTogglePlayPause,
        next: state.musicNextTrack
      )
      .frame(width: NotchMetrics.utilityColumnWidth)
    }
    .frame(width: NotchMetrics.expandedContentWidth, height: NotchMetrics.expandedContentHeight)
    .background {
      Rectangle()
        .fill(FlowlineDesign.notchModuleFill())
    }
    .overlay {
      Rectangle()
        .stroke(Color.white.opacity(0.055), lineWidth: 1)
    }
  }
}

private struct NotchContextColumn: View {
  let snapshot: ContextSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      PanelHeader(title: "CONTEXT", systemImage: "scope", positionMode: .notch)

      Text(snapshot.activeApp.name)
        .font(FlowlineDesign.Typography.notchTitle)
        .foregroundStyle(FlowlineDesign.foreground(for: .notch))
        .lineLimit(1)

      Text(snapshot.primaryTitle)
        .font(FlowlineDesign.Typography.subtitle)
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .lineLimit(1)

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        NotchSignal(color: statusColor, label: statusLabel)

        if let git = snapshot.git {
          Text(git.branch)
            .font(FlowlineDesign.Typography.metadata)
            .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
            .lineLimit(1)
        } else {
          Text(snapshot.activeApp.isDeveloperApp ? "repo pending" : "local")
            .font(FlowlineDesign.Typography.metadata)
            .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
            .lineLimit(1)
        }
      }
    }
    .padding(FlowlineDesign.Metrics.notchColumnPadding)
  }

  private var statusColor: Color {
    if !snapshot.statusItems.isEmpty {
      return FlowlineDesign.warning(for: .notch)
    }

    if let git = snapshot.git, git.isDirty {
      return FlowlineDesign.warning(for: .notch)
    }

    return FlowlineDesign.success(for: .notch)
  }

  private var statusLabel: String {
    if !snapshot.statusItems.isEmpty {
      return snapshot.statusItems.joined(separator: ", ")
    }

    if let git = snapshot.git {
      return git.isDirty ? "dirty" : "clean"
    }

    return "ready"
  }
}

private struct NotchAgentColumn: View {
  let snapshot: ContextSnapshot
  let providers: [String]
  let usage: AIUsageSnapshot?
  let actions: [FlowlineAction]
  let perform: (FlowlineAction) -> Void
  let refreshUsage: () -> Void
  let copyContext: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PanelHeader(title: "LIMITS", systemImage: "gauge.with.dots.needle.33percent", positionMode: .notch)

      if usageRows.isEmpty {
        Text(agentDetail)
          .font(FlowlineDesign.Typography.notchTitle)
          .foregroundStyle(FlowlineDesign.foreground(for: .notch))
          .lineLimit(1)

        Text(secondaryDetail)
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: .notch))
          .lineLimit(1)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(usageRows) { row in
            NotchUsageRow(usage: row)
          }
        }
      }

      Spacer(minLength: 0)

      HStack(spacing: 6) {
        FlowlineIconButton(
          title: "Copy context",
          systemImage: "doc.on.doc",
          positionMode: .notch,
          action: copyContext
        )

        FlowlineIconButton(
          title: "Refresh limits",
          systemImage: "arrow.clockwise",
          positionMode: .notch,
          action: refreshUsage
        )

        ForEach(actions.prefix(4)) { action in
          FlowlineIconButton(
            title: action.title,
            systemImage: action.systemImage,
            positionMode: .notch,
            action: { perform(action) }
          )
        }
      }
    }
    .padding(FlowlineDesign.Metrics.notchColumnPadding)
  }

  private var usageRows: [AIProviderUsage] {
    guard let usage else {
      return []
    }

    let orderedProviders: [AIProvider] = [.codex, .claude, .gemini]
    return orderedProviders.compactMap { usage.provider($0) }
  }

  private var agentDetail: String {
    if let git = snapshot.git {
      return git.isDirty ? "Changes in workspace" : "Workspace clean"
    }

    if snapshot.activeApp.isDeveloperApp {
      return "Developer context"
    }

    if snapshot.nextEvent != nil {
      return "Calendar context"
    }

    return "Flowline ready"
  }

  private var secondaryDetail: String {
    if !snapshot.statusItems.isEmpty {
      return snapshot.statusItems.joined(separator: " needs ")
    }

    if let event = snapshot.nextEvent {
      return "Next \(event.startDate.formatted(date: .omitted, time: .shortened))"
    }

    return "No network, no telemetry"
  }
}

private struct NotchUsageRow: View {
  let usage: AIProviderUsage

  var body: some View {
    HStack(spacing: 7) {
      Text(usage.provider.displayName)
        .font(FlowlineDesign.Typography.metadata)
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .frame(width: 44, alignment: .leading)
        .lineLimit(1)

      if let primary = usage.primary {
        NotchUsageChip(window: primary, color: primaryColor)
      }

      if let secondary = usage.secondary, secondary.percentLeft != nil {
        NotchUsageChip(window: secondary, color: FlowlineDesign.tertiary(for: .notch))
      }

      Spacer(minLength: 0)
    }
  }

  private var primaryColor: Color {
    guard let percent = usage.primary?.percentLeft else {
      return FlowlineDesign.tertiary(for: .notch)
    }

    if percent <= 15 {
      return Color(nsColor: .systemRed).opacity(0.9)
    }

    if percent <= 30 {
      return FlowlineDesign.warning(for: .notch)
    }

    return FlowlineDesign.secondary(for: .notch)
  }
}

private struct NotchUsageChip: View {
  let window: AIUsageWindow
  let color: Color

  var body: some View {
    HStack(spacing: 4) {
      Text(shortLabel)
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
        .frame(width: 14, alignment: .leading)
        .lineLimit(1)

      Text(percentText)
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .monospacedDigit()
        .frame(width: 34, alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }
    .padding(.horizontal, 6)
    .frame(width: 66, height: 16)
    .background(Color.white.opacity(0.035))
    .overlay {
      Rectangle()
        .stroke(Color.white.opacity(0.045), lineWidth: 1)
    }
    .help("\(window.label) \(percentText)")
    .accessibilityLabel("\(window.label) \(percentText)")
  }

  private var percentText: String {
    guard let percent = window.percentLeft else {
      return "--"
    }

    return "%\(percent)"
  }

  private var shortLabel: String {
    switch window.label {
    case "Session":
      return "S"
    case "Weekly":
      return "W"
    case "Daily":
      return "D"
    default:
      return window.label
    }
  }
}

private struct NotchUtilityColumn: View {
  let musicEnabled: Bool
  let shelfEnabled: Bool
  let playback: MusicPlaybackSnapshot?
  let items: [ShelfItem]
  let open: (URL) -> Void
  let remove: (ShelfItem.ID) -> Void
  let previous: () -> Void
  let togglePlayPause: () -> Void
  let next: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      PanelHeader(title: musicEnabled ? "MUSIC" : "SHELF", systemImage: musicEnabled ? "music.note" : "tray.full", positionMode: .notch)

      if musicEnabled {
        NotchMusicNowPlaying(
          playback: playback,
          previous: previous,
          togglePlayPause: togglePlayPause,
          next: next
        )
      }

      if shelfEnabled, !items.isEmpty {
        Text(items.isEmpty ? "Shelf empty" : "\(items.count) shelf item\(items.count == 1 ? "" : "s")")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: .notch))
          .lineLimit(1)

        NotchShelfRow(item: items[0], open: open, remove: remove)
      } else if !musicEnabled {
        Text("Modules disabled")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: .notch))
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, FlowlineDesign.Metrics.notchColumnPadding)
    .padding(.vertical, 8)
  }
}

private struct NotchMusicNowPlaying: View {
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

private struct NotchShelfColumn: View {
  let items: [ShelfItem]
  let open: (URL) -> Void
  let remove: (ShelfItem.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      PanelHeader(title: "SHELF", systemImage: "tray.full", positionMode: .notch)

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(items.count)")
          .font(FlowlineDesign.Typography.notchMetric)
          .foregroundStyle(FlowlineDesign.foreground(for: .notch))

        Text(items.count == 1 ? "item" : "items")
          .font(FlowlineDesign.Typography.metadata)
          .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
      }

      if items.isEmpty {
        Text("Drop files or copy text")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: .notch))
          .lineLimit(1)
      } else {
        VStack(alignment: .leading, spacing: 3) {
          ForEach(items.prefix(2)) { item in
            NotchShelfRow(item: item, open: open, remove: remove)
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding(FlowlineDesign.Metrics.notchColumnPadding)
  }
}

private struct NotchShelfRow: View {
  let item: ShelfItem
  let open: (URL) -> Void
  let remove: (ShelfItem.ID) -> Void

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: icon(for: item.kind))
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
        .frame(width: 13)

      Text(item.title)
        .font(FlowlineDesign.Typography.metadata)
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .lineLimit(1)

      Spacer(minLength: 0)

      if let url = item.url {
        Button(action: { open(url) }) {
          Image(systemName: "arrow.up.forward")
            .font(.system(size: 9, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
        .help("Open \(item.title)")
        .accessibilityLabel("Open \(item.title)")
      }

      Button(role: .destructive, action: { remove(item.id) }) {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .semibold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color(nsColor: .systemRed).opacity(0.86))
      .help("Remove \(item.title)")
      .accessibilityLabel("Remove \(item.title)")
    }
  }

  private func icon(for kind: ShelfItem.Kind) -> String {
    switch kind {
    case .text:
      return "text.alignleft"
    case .link:
      return "link"
    case .file:
      return "doc"
    }
  }
}

private struct NotchSignal: View {
  let color: Color
  let label: String

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(color)
        .frame(width: 5, height: 5)

      Text(label)
        .font(FlowlineDesign.Typography.metadata)
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .lineLimit(1)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct NowPanel: View {
  let snapshot: ContextSnapshot
  let positionMode: PositionMode

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      PanelHeader(title: "NOW", systemImage: "scope", positionMode: positionMode)

      Text(snapshot.activeApp.name)
        .font(FlowlineDesign.Typography.title)
        .foregroundStyle(FlowlineDesign.foreground(for: positionMode))
        .lineLimit(1)

      Text(snapshot.primaryDetail)
        .font(FlowlineDesign.Typography.subtitle)
        .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
        .lineLimit(2)

      Spacer()
    }
    .padding(FlowlineDesign.Metrics.panelPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .flowlinePanel(positionMode: positionMode)
  }
}

private struct AgentPanel: View {
  let snapshot: ContextSnapshot
  let positionMode: PositionMode
  let providers: [String]
  let actions: [FlowlineAction]
  let perform: (FlowlineAction) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      PanelHeader(title: "AGENT", systemImage: "terminal", positionMode: positionMode)

      Text(providers.prefix(3).joined(separator: " · "))
        .font(FlowlineDesign.Typography.title)
        .foregroundStyle(FlowlineDesign.foreground(for: positionMode))
        .lineLimit(1)

      if let git = snapshot.git {
        Text(git.isDirty ? "\(git.branch) has changes" : "\(git.branch) clean")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
          .lineLimit(1)
      } else if snapshot.activeApp.isDeveloperApp {
        Text("Waiting for repo context")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
          .lineLimit(1)
      } else if let event = snapshot.nextEvent {
        Text("Next: \(event.title)")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
          .lineLimit(1)
      } else {
        Text("Local-first cockpit")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
          .lineLimit(1)
      }

      if !snapshot.statusItems.isEmpty {
        HStack(spacing: 5) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 9, weight: .semibold))

          Text(snapshot.statusItems.joined(separator: " · "))
            .font(FlowlineDesign.Typography.metadata)
            .lineLimit(1)
        }
        .foregroundStyle(FlowlineDesign.warning(for: positionMode))
      }

      Spacer()

      HStack(spacing: 6) {
        ForEach(actions.prefix(3)) { action in
          FlowlineIconButton(
            title: action.title,
            systemImage: action.systemImage,
            positionMode: positionMode,
            action: { perform(action) }
          )
        }
      }
    }
    .padding(FlowlineDesign.Metrics.panelPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .flowlinePanel(positionMode: positionMode)
  }
}

private struct MusicPanel: View {
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

private struct ShelfPanel: View {
  let items: [ShelfItem]
  let positionMode: PositionMode
  let open: (URL) -> Void
  let remove: (ShelfItem.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      PanelHeader(title: "SHELF", systemImage: "tray.full", positionMode: positionMode)

      if items.isEmpty {
        Text("Drop files or copy text")
          .font(FlowlineDesign.Typography.title)
          .foregroundStyle(FlowlineDesign.foreground(for: positionMode))
          .lineLimit(1)

        Text("Session-only")
          .font(FlowlineDesign.Typography.subtitle)
          .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
      } else {
        ForEach(items.prefix(3)) { item in
          HStack(spacing: 6) {
            Image(systemName: icon(for: item.kind))
              .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
              .frame(width: 14)

            Text(item.title)
              .font(FlowlineDesign.Typography.subtitle.weight(.medium))
              .foregroundStyle(FlowlineDesign.foreground(for: positionMode))
              .lineLimit(1)

            Spacer()

            if let url = item.url {
              FlowlineIconButton(
                title: "Open \(item.title)",
                systemImage: "arrow.up.forward",
                positionMode: positionMode,
                action: { open(url) }
              )
            }

            FlowlineIconButton(
              title: "Remove \(item.title)",
              systemImage: "xmark",
              positionMode: positionMode,
              role: .destructive,
              action: { remove(item.id) }
            )
          }
          .frame(minHeight: FlowlineDesign.Metrics.shelfRowHeight)
        }
      }

      Spacer()
    }
    .padding(FlowlineDesign.Metrics.panelPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .flowlinePanel(positionMode: positionMode)
  }

  private func icon(for kind: ShelfItem.Kind) -> String {
    switch kind {
    case .text:
      return "text.alignleft"
    case .link:
      return "link"
    case .file:
      return "doc"
    }
  }
}

private struct PanelHeader: View {
  let title: String
  let systemImage: String
  let positionMode: PositionMode

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: systemImage)
        .font(.system(size: 10, weight: .medium))
      Text(title)
        .font(FlowlineDesign.Typography.header)
    }
    .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
    .accessibilityElement(children: .combine)
  }
}

private struct FlowlineIconButton: View {
  let title: String
  let systemImage: String
  let positionMode: PositionMode
  var role: ButtonRole?
  let action: () -> Void

  var body: some View {
    Button(role: role, action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .medium))
        .frame(width: FlowlineDesign.Metrics.iconButtonSize, height: FlowlineDesign.Metrics.iconButtonSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(foreground)
    .background(FlowlineDesign.iconButtonBackground(for: positionMode))
    .overlay {
      Rectangle()
        .stroke(FlowlineDesign.separator(for: positionMode), lineWidth: 1)
    }
    .help(title)
    .accessibilityLabel(title)
  }

  private var foreground: Color {
    role == .destructive ? Color(nsColor: .systemRed) : FlowlineDesign.foreground(for: positionMode)
  }
}

private struct FlowlinePanelStyle: ViewModifier {
  let positionMode: PositionMode

  func body(content: Content) -> some View {
    content
      .background(FlowlineDesign.panelFill(for: positionMode))
      .overlay {
        Rectangle()
          .fill(FlowlineDesign.panelScrim(for: positionMode))
      }
      .overlay {
        Rectangle()
          .stroke(FlowlineDesign.separator(for: positionMode), lineWidth: 1)
      }
  }
}

private extension View {
  func flowlinePanel(positionMode: PositionMode) -> some View {
    modifier(FlowlinePanelStyle(positionMode: positionMode))
  }
}
