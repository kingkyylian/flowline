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
    HStack(alignment: .top, spacing: 8) {
      NotchWorkspaceColumn(snapshot: state.snapshot)
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
      .frame(
        width: NotchMetrics.agentColumnWidth,
        height: NotchMetrics.expandedContentHeight - NotchMetrics.centerColumnDrop,
        alignment: .top
      )
      .padding(.top, NotchMetrics.centerColumnDrop)

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
      .frame(
        width: NotchMetrics.utilityColumnWidth,
        height: NotchMetrics.expandedContentHeight - NotchMetrics.utilityColumnDrop,
        alignment: .top
      )
      .padding(.top, NotchMetrics.utilityColumnDrop)
      .offset(x: NotchMetrics.utilityColumnShiftX)
    }
    .frame(width: NotchMetrics.expandedContentWidth, height: NotchMetrics.expandedContentHeight)
    .background {
      Rectangle()
        .fill(FlowlineDesign.notchModuleFill())
    }
  }
}

private struct NotchWorkspaceColumn: View {
  let snapshot: ContextSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PanelHeader(title: "WORKSPACE", systemImage: "folder", positionMode: .notch)

      Text(title)
        .font(FlowlineDesign.Typography.notchTitle)
        .foregroundStyle(FlowlineDesign.foreground(for: .notch))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .help(title)

      Text(detail)
        .font(FlowlineDesign.Typography.subtitle)
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .help(detail)

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        NotchSignal(color: statusColor, label: statusLabel)

        if !footerDetail.isEmpty {
          Text(footerDetail)
            .font(FlowlineDesign.Typography.metadata)
            .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
      }
    }
    .padding(FlowlineDesign.Metrics.notchColumnPadding)
  }

  private var title: String {
    if let repositoryName = snapshot.git?.repositoryName, !repositoryName.isEmpty {
      return repositoryName
    }

    if snapshot.primaryTitle != snapshot.activeApp.name {
      return snapshot.primaryTitle
    }

    if let event = snapshot.nextEvent {
      return event.title
    }

    return snapshot.activeApp.name
  }

  private var detail: String {
    if let git = snapshot.git {
      return "\(snapshot.activeApp.name) · \(git.branch)"
    }

    if let event = snapshot.nextEvent {
      return "Next \(event.startDate.formatted(date: .omitted, time: .shortened))"
    }

    if snapshot.primaryTitle != snapshot.activeApp.name {
      return snapshot.activeApp.name
    }

    return snapshot.activeApp.isDeveloperApp ? "repo pending" : "local workspace"
  }

  private var footerDetail: String {
    if !snapshot.statusItems.isEmpty {
      return ""
    }

    if snapshot.git != nil {
      return "repo"
    }

    return "local"
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
        .padding(.bottom, 2)

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
    HStack(spacing: 4) {
      Text(usage.provider.displayName)
        .font(FlowlineDesign.Typography.metadata)
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .frame(width: 42, alignment: .leading)
        .lineLimit(1)
        .minimumScaleFactor(0.82)

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
        .frame(width: 10, alignment: .leading)
        .lineLimit(1)

      Text(percentText)
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .monospacedDigit()
        .frame(width: 30, alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }
    .frame(width: 44, height: 16)
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
