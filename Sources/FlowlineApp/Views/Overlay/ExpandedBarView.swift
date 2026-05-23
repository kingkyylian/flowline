import AppKit
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
    ZStack(alignment: .topLeading) {
      if let leftSlot = slotLayout.left {
        leftColumn(for: leftSlot)
        .frame(
          width: NotchMetrics.contextColumnWidth,
          height: NotchMetrics.expandedContentHeight,
          alignment: .top
        )
        .position(
          x: NotchMetrics.contextColumnWidth / 2,
          y: NotchMetrics.expandedContentHeight / 2
        )
      }

      NotchAgentColumn(
        snapshot: state.snapshot,
        providers: state.agentProviders,
        usage: state.aiUsage,
        actions: state.actions,
        showsUtilityActions: state.workspaceModuleEnabled,
        perform: state.perform,
        refreshUsage: state.refreshAIUsage,
        copyContext: state.copyContextSummary
      )
      .frame(
        width: NotchMetrics.agentColumnWidth,
        height: NotchMetrics.expandedContentHeight - NotchMetrics.centerColumnDrop,
        alignment: .top
      )
      .position(
        x: centerColumnX + NotchMetrics.centerColumnShiftX + NotchMetrics.agentColumnWidth / 2,
        y: NotchMetrics.centerColumnDrop + (NotchMetrics.expandedContentHeight - NotchMetrics.centerColumnDrop) / 2
      )

      if let rightSlot = slotLayout.right {
        rightColumn(for: rightSlot)
          .frame(
            width: NotchMetrics.utilityColumnWidth,
            height: NotchMetrics.expandedContentHeight - NotchMetrics.utilityColumnDrop,
            alignment: .top
          )
          .position(
            x: utilityColumnX + NotchMetrics.utilityColumnWidth / 2,
            y: NotchMetrics.utilityColumnDrop + (NotchMetrics.expandedContentHeight - NotchMetrics.utilityColumnDrop) / 2
          )
      }
    }
    .frame(width: NotchMetrics.expandedContentWidth, height: NotchMetrics.expandedContentHeight)
    .background {
      Rectangle()
        .fill(FlowlineDesign.notchModuleFill())
    }
  }

  @ViewBuilder
  private func leftColumn(for slot: NotchModuleSlot) -> some View {
    switch slot {
    case .context:
      NotchWorkspaceColumn(snapshot: state.snapshot)
    case .calendar:
      NotchCalendarColumn(
        placement: .left,
        snapshot: state.snapshot,
        requestAccess: state.requestCalendarPermission,
        open: state.open
      )
    case .shelf:
      NotchHoldColumn(
        isEnabled: true,
        items: state.snapshot.shelfItems,
        copy: state.copyShelfItem,
        copyOCR: state.copyShelfOCRText,
        cycle: state.cycleShelfItems,
        remove: state.removeShelfItem,
        export: state.exportShelfItem,
        isDropTargeted: state.isHoldDropTargeted,
        landingTick: state.holdDropLandingTick
      )
    case .music:
      EmptyView()
    }
  }

  @ViewBuilder
  private func rightColumn(for slot: NotchModuleSlot) -> some View {
    switch slot {
    case .calendar:
      NotchCalendarColumn(
        placement: .right,
        snapshot: state.snapshot,
        requestAccess: state.requestCalendarPermission,
        open: state.open
      )
    case .music:
      NotchUtilityColumn(
        playback: state.musicPlayback,
        previous: state.musicPreviousTrack,
        togglePlayPause: state.musicTogglePlayPause,
        next: state.musicNextTrack
      )
    case .shelf:
      EmptyView()
    case .context:
      EmptyView()
    }
  }

  private var slotLayout: NotchModuleSlotLayout {
    NotchModuleSlotLayout.layout(
      for: FlowlineModulePreferences(
        context: state.workspaceModuleEnabled,
        music: state.musicModuleEnabled,
        calendar: state.calendarModuleEnabled,
        shelf: state.shelfModuleEnabled
      )
    )
  }

  private var centerColumnX: Double {
    (NotchMetrics.expandedContentWidth - NotchMetrics.agentColumnWidth) / 2
  }

  private var utilityColumnX: Double {
    NotchMetrics.expandedContentWidth - NotchMetrics.utilityColumnWidth
  }
}

private struct NotchHoldColumn: View {
  let isEnabled: Bool
  let items: [ShelfItem]
  let copy: (ShelfItem) -> Void
  let copyOCR: (ShelfItem) -> Void
  let cycle: () -> Void
  let remove: (ShelfItem.ID) -> Void
  let export: (ShelfItem) -> NSItemProvider
  let isDropTargeted: Bool
  let landingTick: Int

  var body: some View {
    VStack(alignment: .leading, spacing: NotchHoldTrayLayout.bodySpacing) {
      holdTray
        .frame(
          width: NotchHoldTrayLayout.actionRowWidth,
          height: NotchHoldTrayLayout.trayHeight,
          alignment: .leading
        )
        .padding(.top, NotchHoldTrayLayout.trayTopOffset(hasVisibleItem: hasVisibleItem))

      if let item = items.first, isEnabled {
        actionRow(for: item)
      } else {
        Spacer(minLength: 0)
      }
    }
    .padding(.horizontal, NotchHoldTrayLayout.contentHorizontalPadding)
    .padding(.top, NotchHoldTrayLayout.contentTopPadding)
    .padding(.bottom, NotchHoldTrayLayout.contentBottomPadding)
    .overlay(alignment: .topLeading) {
      PanelHeader(title: "HOLD", systemImage: "tray.full", positionMode: .notch)
        .padding(.leading, NotchHoldHeaderLayout.leadingInset)
        .padding(.top, 8)
        .offset(
          x: NotchHoldHeaderLayout.headerShiftX,
          y: -NotchHoldHeaderLayout.headerLift
        )
    }
  }

  private func actionRow(for item: ShelfItem) -> some View {
    HStack(spacing: 0) {
      ForEach(HoldActionPresentation.actions(for: item, itemCount: items.count)) { action in
        ZStack {
          NotchHoldActionButton(
            label: action.label,
            title: action.title,
            systemImage: action.systemImage,
            role: action.isDestructive ? .destructive : nil,
            action: { perform(action.kind, item: item) }
          )
        }
        .frame(maxWidth: .infinity)
      }
    }
    .frame(
      width: NotchHoldTrayLayout.actionRowWidth,
      height: NotchHoldTrayLayout.actionButtonSize
    )
    .offset(y: NotchHoldTrayLayout.actionRowOffsetY)
  }

  private var hasVisibleItem: Bool {
    isEnabled && items.first != nil
  }

  private func perform(_ action: HoldActionPresentation.Kind, item: ShelfItem) {
    switch action {
    case .copy:
      copy(item)
    case .copyOCR:
      copyOCR(item)
    case .next:
      cycle()
    case .delete:
      remove(item.id)
    }
  }

  @ViewBuilder
  private var holdTray: some View {
    if let item = items.first, isEnabled {
      holdDropTray
        .onDrag { export(item) }
    } else {
      holdDropTray
    }
  }

  private var holdDropTray: some View {
    NotchHoldDropTray(
      isEnabled: isEnabled,
      item: items.first,
      itemCount: items.count,
      expiryLabel: expiryLabel,
      isTargeted: isDropTargeted,
      landingTick: landingTick
    )
  }

  private func expiryLabel(_ item: ShelfItem) -> String? {
    guard let expiresAt = item.expiresAt else {
      return nil
    }

    let seconds = max(0, Int(expiresAt.timeIntervalSinceNow.rounded(.up)))
    if seconds <= 60 {
      return "\(seconds)s"
    }

    return "\(seconds / 60)m"
  }
}

private struct NotchHoldDropTray: View {
  let isEnabled: Bool
  let item: ShelfItem?
  let itemCount: Int
  let expiryLabel: (ShelfItem) -> String?
  let isTargeted: Bool
  let landingTick: Int
  @State private var isLanding = false
  @State private var isPeeking = false
  @State private var landingTask: Task<Void, Never>?

  var body: some View {
    ZStack(alignment: .topTrailing) {
      trayBackground

      trayContent
        .padding(.horizontal, NotchHoldTrayLayout.trayHorizontalPadding)
        .scaleEffect(isRecessed ? NotchHoldTrayLayout.recessedContentScale : 1)
        .offset(y: isRecessed ? NotchHoldTrayLayout.recessedContentDropY : 0)
        .animation(.snappy(duration: 0.12), value: isRecessed)

      if shouldShowStackBadge {
        NotchHoldStackBadge(count: itemCount)
          .padding(.top, NotchHoldTrayLayout.stackBadgeTopInset)
          .padding(.trailing, NotchHoldTrayLayout.stackBadgeTrailingInset)
      }
    }
    .frame(maxWidth: .infinity, minHeight: NotchHoldTrayLayout.trayHeight, maxHeight: NotchHoldTrayLayout.trayHeight)
    .contentShape(Rectangle())
    .overlay {
      if NotchHoldTrayLayout.showsOuterBorder {
        Rectangle()
          .stroke(borderColor, lineWidth: 1)
      }
    }
    .overlay(alignment: .top) {
      if isRecessed {
        Rectangle()
          .fill(Color.black.opacity(NotchHoldTrayLayout.recessedRimOpacity * depthProgress))
          .frame(height: 1)
      }
    }
    .overlay(alignment: .leading) {
      if isRecessed {
        Rectangle()
          .fill(Color.black.opacity(NotchHoldTrayLayout.recessedRimOpacity * 0.72 * depthProgress))
          .frame(width: 1)
      }
    }
    .overlay(alignment: .bottom) {
      if isRecessed {
        Rectangle()
          .fill(Color.white.opacity(NotchHoldTrayLayout.recessedHighlightOpacity * depthProgress))
          .frame(height: 1)
      }
    }
    .overlay(alignment: .trailing) {
      if isRecessed {
        Rectangle()
          .fill(Color.white.opacity(NotchHoldTrayLayout.recessedHighlightOpacity * 0.62 * depthProgress))
          .frame(width: 1)
      }
    }
    .shadow(color: .black.opacity(isRecessed ? 0.30 : 0), radius: isRecessed ? 3 : 0, y: isRecessed ? -1 : 0)
    .animation(.smooth(duration: 0.16), value: isTargeted)
    .animation(.smooth(duration: 0.14), value: isPeeking)
    .onHover { hovering in
      isPeeking = hovering && item != nil
    }
    .help(compactHelpText)
    .accessibilityLabel(helpText)
    .onChange(of: landingTick) { _, tick in
      triggerLandingFeedback(tick)
    }
    .onDisappear {
      landingTask?.cancel()
    }
  }

  @ViewBuilder
  private var trayContent: some View {
    if let item, isEnabled {
      if isPeeking, shouldShowInlinePreview(for: item) {
        NotchHoldInlinePreview(item: item)
      } else if item.kind == .screenshot {
        NotchHoldScreenshotPreview(
          item: item,
          title: summary(for: item).title,
          detail: summaryDetail(for: item)
        )
      } else if item.kind == .text || item.kind == .code {
        NotchHoldTextCardPreview(
          item: item,
          title: summary(for: item).title,
          detail: summaryDetail(for: item)
        )
      } else {
        NotchHoldSymbolCardPreview(
          item: item,
          title: summary(for: item).title,
          detail: summaryDetail(for: item)
        )
      }
    } else {
      HStack(spacing: NotchHoldTrayLayout.previewTextSpacing) {
        VStack(alignment: .center, spacing: NotchHoldTrayLayout.emptyStackSpacing) {
          HStack(alignment: .center, spacing: NotchHoldTrayLayout.emptyHeadlineSpacing) {
            Image(systemName: isEnabled ? "arrow.down.to.line.compact" : "tray.slash")
              .font(.system(size: NotchHoldTrayLayout.emptyIconSize, weight: .medium))
              .foregroundStyle(iconColor)
              .frame(width: NotchHoldTrayLayout.emptyIconFrameWidth)

            Text(isEnabled ? NotchHoldTrayLayout.emptyTitle : "Disabled")
              .font(.system(size: NotchHoldTrayLayout.titleFontSize, weight: .semibold, design: .monospaced))
              .foregroundStyle(FlowlineDesign.foreground(for: .notch))
              .lineLimit(isEnabled ? 2 : 1)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
          }

          Text(isEnabled ? NotchHoldTrayLayout.emptySubtitle : "Enable in settings")
            .font(.system(size: NotchHoldTrayLayout.metadataFontSize, weight: .medium, design: .monospaced))
            .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: NotchHoldTrayLayout.emptyContentOffsetY)
      }
    }
  }

  @ViewBuilder
  private var trayBackground: some View {
    ZStack {
      Rectangle()
        .fill(baseBackground)

      if isRecessed {
        Rectangle()
          .fill(Color.black.opacity(NotchHoldTrayLayout.recessedDepthOpacity * depthProgress))
      }
    }
  }

  private var baseBackground: Color {
    let lift = isTargeted ? 0.018 : 0
    return Color.white.opacity((item == nil ? 0.025 : 0.045) + lift)
  }

  private var borderColor: Color {
    return FlowlineDesign.separator(for: .notch)
  }

  private var iconColor: Color {
    FlowlineDesign.tertiary(for: .notch)
  }

  private var isRecessed: Bool {
    isTargeted || isLanding
  }

  private var depthProgress: Double {
    isLanding ? 1 : (isTargeted ? 0.82 : 0)
  }

  private func triggerLandingFeedback(_ tick: Int) {
    guard tick > 0 else {
      return
    }

    landingTask?.cancel()
    withAnimation(.snappy(duration: 0.08)) {
      isLanding = true
    }

    landingTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(NotchHoldTrayLayout.dropLandingDurationMilliseconds))
      guard !Task.isCancelled else {
        return
      }

      withAnimation(.smooth(duration: 0.18)) {
        isLanding = false
      }
    }
  }

  private var helpText: String {
    guard isEnabled else {
      return "Hold disabled"
    }

    guard let item else {
      return "Drop text, links, files, or screenshots into Hold"
    }

    return HoldPreviewPresentation.tooltipText(for: item)
  }

  private var compactHelpText: String {
    guard isEnabled else {
      return "Hold disabled"
    }

    guard let item else {
      return "Drop text, links, files, or screenshots into Hold"
    }

    return title(for: item)
  }

  private func title(for item: ShelfItem) -> String {
    HoldPreviewPresentation.title(for: item)
  }

  private func summary(for item: ShelfItem) -> HoldPreviewPresentation.Summary {
    HoldPreviewPresentation.summary(for: item)
  }

  private func summaryDetail(for item: ShelfItem) -> String {
    summary(for: item).detail ?? meta(for: item)
  }

  private func shouldShowInlinePreview(for item: ShelfItem) -> Bool {
    !HoldPreviewPresentation.inlinePreviewLines(for: item).isEmpty
  }

  private func meta(for item: ShelfItem) -> String {
    HoldItemMetadataPresentation.label(for: item, expiry: expiryLabel(item))
  }

  private var shouldShowStackBadge: Bool {
    isEnabled && item != nil && itemCount > 1
  }
}

private struct NotchHoldInlinePreview: View {
  let item: ShelfItem

  var body: some View {
    VStack(alignment: .leading, spacing: NotchHoldTrayLayout.inlinePreviewLineSpacing) {
      ForEach(Array(HoldPreviewPresentation.inlinePreviewLines(for: item).enumerated()), id: \.offset) { _, line in
        Text(line)
          .font(.system(size: NotchHoldTrayLayout.inlinePreviewFontSize, weight: .semibold, design: .monospaced))
          .foregroundStyle(FlowlineDesign.secondary(for: .notch))
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.vertical, NotchHoldTrayLayout.inlinePreviewVerticalPadding)
    .frame(
      maxWidth: .infinity,
      minHeight: NotchHoldTrayLayout.inlinePreviewHeight,
      maxHeight: NotchHoldTrayLayout.inlinePreviewHeight,
      alignment: .leading
    )
    .offset(y: NotchHoldTrayLayout.inlinePreviewOffsetY)
    .clipped()
  }
}

private struct NotchHoldScreenshotPreview: View {
  let item: ShelfItem
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: NotchHoldTrayLayout.screenshotPreviewCaptionSpacing) {
      ZStack {
        if let image {
          Image(nsImage: image)
            .resizable()
            .scaledToFill()
        } else {
          Image(systemName: "photo")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(FlowlineDesign.secondary(for: .notch))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity, minHeight: NotchHoldTrayLayout.previewMediaHeight, maxHeight: NotchHoldTrayLayout.previewMediaHeight)
      .clipped()
      .background(Color.white.opacity(0.035))
      .clipShape(RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous)
          .stroke(FlowlineDesign.separator(for: .notch).opacity(0.7), lineWidth: 1)
      }

      NotchHoldPreviewCaption(
        kind: "SS",
        detail: title
      )
    }
    .frame(maxWidth: .infinity, minHeight: NotchHoldTrayLayout.previewHeight, maxHeight: NotchHoldTrayLayout.previewHeight)
    .offset(y: NotchHoldTrayLayout.previewOffsetY)
    .help(title)
    .accessibilityLabel("\(title), \(detail)")
  }

  private var image: NSImage? {
    guard let url = item.url else {
      return nil
    }

    return NSImage(contentsOf: url)
  }
}

private struct NotchHoldTextCardPreview: View {
  let item: ShelfItem
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: NotchHoldTrayLayout.previewCaptionSpacing) {
      ZStack(alignment: .topLeading) {
        Rectangle()
          .fill(Color.white.opacity(0.035))

        VStack(alignment: .leading, spacing: NotchHoldTrayLayout.textCardPreviewLineSpacing) {
          ForEach(Array(previewLines.enumerated()), id: \.offset) { _, line in
            Text(line)
              .font(.system(
                size: NotchHoldTrayLayout.textCardPreviewLineFontSize,
                weight: .semibold,
                design: .monospaced
              ))
              .foregroundStyle(FlowlineDesign.secondary(for: .notch).opacity(0.68))
              .lineLimit(1)
              .truncationMode(.tail)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          Spacer(minLength: 0)
        }
        .padding(NotchHoldTrayLayout.textCardPreviewContentPadding)
      }
      .frame(maxWidth: .infinity, minHeight: NotchHoldTrayLayout.previewMediaHeight, maxHeight: NotchHoldTrayLayout.previewMediaHeight)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous)
          .stroke(FlowlineDesign.separator(for: .notch).opacity(0.65), lineWidth: 1)
      }

      NotchHoldPreviewCaption(
        kind: title,
        detail: detail
      )
    }
    .frame(maxWidth: .infinity, minHeight: NotchHoldTrayLayout.previewHeight, maxHeight: NotchHoldTrayLayout.previewHeight)
    .offset(y: NotchHoldTrayLayout.previewOffsetY)
    .help(detail)
    .accessibilityLabel("\(title), \(detail)")
  }

  private var previewLines: [String] {
    HoldPreviewPresentation.inlinePreviewLines(for: item)
  }
}

private struct NotchHoldSymbolCardPreview: View {
  let item: ShelfItem
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: NotchHoldTrayLayout.previewCaptionSpacing) {
      ZStack {
        Rectangle()
          .fill(Color.white.opacity(0.035))

        if item.kind == .file {
          NotchHoldFileMark()
        } else {
          Image(systemName: iconName)
            .font(.system(
              size: NotchHoldTrayLayout.iconCardSymbolFontSize,
              weight: .medium
            ))
            .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        }
      }
      .frame(maxWidth: .infinity, minHeight: NotchHoldTrayLayout.previewMediaHeight, maxHeight: NotchHoldTrayLayout.previewMediaHeight)
      .clipShape(RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous)
          .stroke(FlowlineDesign.separator(for: .notch).opacity(0.65), lineWidth: 1)
      }

      NotchHoldPreviewCaption(
        kind: title,
        detail: detail
      )
    }
    .frame(maxWidth: .infinity, minHeight: NotchHoldTrayLayout.previewHeight, maxHeight: NotchHoldTrayLayout.previewHeight)
    .offset(y: NotchHoldTrayLayout.previewOffsetY)
    .help(detail)
    .accessibilityLabel("\(title), \(detail)")
  }

  private var iconName: String {
    switch item.kind {
    case .text:
      return "text.alignleft"
    case .code:
      return "curlybraces"
    case .link:
      return "link"
    case .file:
      return "doc"
    case .screenshot:
      return "camera.viewfinder"
    case .sensitive:
      return "lock"
    }
  }
}

private struct NotchHoldPreviewCaption: View {
  let kind: String
  let detail: String

  var body: some View {
    HStack(spacing: 4) {
      Text(kind)
        .font(.system(
          size: NotchHoldTrayLayout.textCardPreviewBadgeFontSize,
          weight: .semibold,
          design: .monospaced
        ))
        .foregroundStyle(FlowlineDesign.foreground(for: .notch))
        .lineLimit(1)

      Text(detail)
        .font(.system(
          size: NotchHoldTrayLayout.textCardPreviewDetailFontSize,
          weight: .medium,
          design: .monospaced
        ))
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .lineLimit(1)
        .minimumScaleFactor(0.72)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, NotchHoldTrayLayout.previewCaptionHorizontalInset)
  }
}

private struct NotchHoldStackBadge: View {
  let count: Int

  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "square.stack.3d.up")
        .font(.system(size: NotchHoldTrayLayout.stackBadgeIconFontSize, weight: .semibold))

      Text("\(count)")
        .font(.system(size: NotchHoldTrayLayout.stackBadgeFontSize, weight: .semibold, design: .monospaced))
        .monospacedDigit()
    }
    .foregroundStyle(FlowlineDesign.foreground(for: .notch))
    .frame(width: NotchHoldTrayLayout.stackBadgeWidth, height: NotchHoldTrayLayout.stackBadgeHeight)
    .background(Color.black.opacity(0.46))
    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .stroke(FlowlineDesign.separator(for: .notch).opacity(0.72), lineWidth: 1)
    }
    .help("\(count) Hold items")
    .accessibilityLabel("\(count) Hold items")
  }
}

private struct NotchHoldActionButton: View {
  let label: String
  let title: String
  let systemImage: String
  var role: ButtonRole?
  let action: () -> Void

  var body: some View {
    Button(role: role, action: action) {
      VStack(spacing: NotchHoldTrayLayout.actionButtonContentSpacing) {
        Image(systemName: systemImage)
          .font(.system(size: NotchHoldTrayLayout.actionIconFontSize, weight: .medium))

        Text(label)
          .font(.system(size: NotchHoldTrayLayout.actionLabelFontSize, weight: .semibold, design: .monospaced))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(width: NotchHoldTrayLayout.actionButtonSize, height: NotchHoldTrayLayout.actionButtonSize)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(foreground)
    .background(FlowlineDesign.iconButtonBackground(for: .notch))
    .overlay {
      if NotchHoldTrayLayout.showsActionButtonBorder {
        Rectangle()
          .stroke(FlowlineDesign.separator(for: .notch), lineWidth: 1)
      }
    }
    .help(title)
    .accessibilityLabel(title)
  }

  private var foreground: Color {
    role == .destructive ? Color(nsColor: .systemRed) : FlowlineDesign.foreground(for: .notch)
  }
}

private struct NotchHoldPreview: View {
  let item: ShelfItem

  var body: some View {
    Group {
      if item.kind == .screenshot, let image {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else if showsTextPreview {
        VStack(alignment: .leading, spacing: NotchHoldTrayLayout.textPreviewLineSpacing) {
          ForEach(Array(previewLines.enumerated()), id: \.offset) { _, line in
            Text(line)
              .font(.system(
                size: NotchHoldTrayLayout.textPreviewFontSize,
                weight: .semibold,
                design: .monospaced
              ))
              .foregroundStyle(FlowlineDesign.secondary(for: .notch))
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          Spacer(minLength: 0)
        }
        .padding(NotchHoldTrayLayout.textPreviewPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      } else if item.kind == .file {
        NotchHoldFileMark()
      } else {
        Image(systemName: iconName)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(FlowlineDesign.secondary(for: .notch))
      }
    }
    .frame(width: NotchHoldTrayLayout.previewWidth, height: NotchHoldTrayLayout.previewHeight)
    .clipped()
    .background(Color.white.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: NotchHoldTrayLayout.previewCornerRadius, style: .continuous)
        .stroke(FlowlineDesign.separator(for: .notch), lineWidth: 1)
    }
    .offset(y: NotchHoldTrayLayout.previewOffsetY)
  }

  private var image: NSImage? {
    guard let url = item.url else {
      return nil
    }

    return NSImage(contentsOf: url)
  }

  private var showsTextPreview: Bool {
    switch item.kind {
    case .text, .code:
      return !previewLines.isEmpty
    case .link, .file, .screenshot, .sensitive:
      return false
    }
  }

  private var previewLines: [String] {
    HoldPreviewPresentation.thumbnailLines(for: item)
  }

  private var iconName: String {
    switch item.kind {
    case .text:
      return "text.alignleft"
    case .code:
      return "curlybraces"
    case .link:
      return "link"
    case .file:
      return "doc"
    case .screenshot:
      return "camera.viewfinder"
    case .sensitive:
      return "lock"
    }
  }
}

private struct NotchHoldFileMark: View {
  var body: some View {
    ZStack {
      RoundedRectangle(
        cornerRadius: NotchHoldTrayLayout.fileMarkCornerRadius,
        style: .continuous
      )
      .stroke(
        FlowlineDesign.secondary(for: .notch),
        lineWidth: NotchHoldTrayLayout.fileMarkStrokeWidth
      )
      .frame(
        width: NotchHoldTrayLayout.fileMarkWidth,
        height: NotchHoldTrayLayout.fileMarkHeight
      )

      VStack(spacing: 5) {
        Rectangle()
          .fill(FlowlineDesign.secondary(for: .notch))
          .frame(
            width: NotchHoldTrayLayout.fileMarkDetailWidth,
            height: NotchHoldTrayLayout.fileMarkStrokeWidth
          )

        Spacer(minLength: 0)
      }
      .padding(.top, 8)
      .frame(
        width: NotchHoldTrayLayout.fileMarkWidth,
        height: NotchHoldTrayLayout.fileMarkHeight
      )
    }
  }
}

private struct NotchWorkspaceColumn: View {
  let snapshot: ContextSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PanelHeader(title: "WORKSPACE", systemImage: "folder", positionMode: .notch)
        .offset(
          x: NotchWorkspaceHeaderLayout.headerShiftX,
          y: -NotchWorkspaceHeaderLayout.headerLift
        )

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

private struct NotchCalendarColumn: View {
  let placement: FlowlineModulePlacement
  let snapshot: ContextSnapshot
  let requestAccess: () -> Void
  let open: (URL) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PanelHeader(title: "CALENDAR", systemImage: "calendar", positionMode: .notch)
        .offset(x: NotchCalendarLayout.headerShiftX(for: placement), y: -NotchCalendarLayout.headerLift)

      Text(title)
        .font(FlowlineDesign.Typography.notchTitle)
        .foregroundStyle(FlowlineDesign.foreground(for: .notch))
        .lineLimit(1)
        .minimumScaleFactor(0.76)
        .frame(width: contentWidth, alignment: .leading)
        .help(title)

      Text(detail)
        .font(FlowlineDesign.Typography.subtitle)
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .lineLimit(1)
        .minimumScaleFactor(0.76)
        .frame(width: contentWidth, alignment: .leading)
        .help(detail)

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        NotchSignal(color: statusColor, label: statusLabel)

        Spacer(minLength: 0)

        if snapshot.permissions.calendar != .granted {
          FlowlineIconButton(
            title: "Allow Calendar",
            systemImage: "hand.raised",
            positionMode: .notch,
            action: requestAccess
          )
        } else if let url = snapshot.nextEvent?.meetingURL {
          FlowlineIconButton(
            title: "Join meeting",
            systemImage: "video.fill",
            positionMode: .notch,
            action: { open(url) }
          )
        }
      }
      .frame(width: contentWidth, alignment: .leading)
    }
    .padding(.top, NotchCalendarLayout.verticalPadding)
    .padding(.bottom, NotchCalendarLayout.verticalPadding)
    .padding(.leading, NotchCalendarLayout.leadingInset(for: placement))
    .padding(.trailing, NotchCalendarLayout.trailingInset(for: placement))
  }

  private var title: String {
    guard snapshot.permissions.calendar == .granted else {
      return "Needs access"
    }

    guard let event = snapshot.nextEvent else {
      return "No event"
    }

    return event.title
  }

  private var detail: String {
    guard snapshot.permissions.calendar == .granted else {
      return "Allow meetings"
    }

    guard let event = snapshot.nextEvent else {
      return "Next 24h clear"
    }

    return "Next \(CalendarModulePresentation.compactTime(for: event.startDate))"
  }

  private var statusColor: Color {
    switch snapshot.permissions.calendar {
    case .granted:
      return snapshot.nextEvent == nil ? FlowlineDesign.tertiary(for: .notch) : FlowlineDesign.success(for: .notch)
    case .denied, .notDetermined:
      return FlowlineDesign.warning(for: .notch)
    }
  }

  private var statusLabel: String {
    guard snapshot.permissions.calendar == .granted else {
      return "ask"
    }

    return snapshot.nextEvent == nil ? "idle" : "ready"
  }

  private var contentWidth: CGFloat {
    NotchCalendarLayout.contentWidth(for: placement)
  }
}

private struct NotchAgentColumn: View {
  let snapshot: ContextSnapshot
  let providers: [String]
  let usage: AIUsageSnapshot?
  let actions: [FlowlineAction]
  let showsUtilityActions: Bool
  let perform: (FlowlineAction) -> Void
  let refreshUsage: () -> Void
  let copyContext: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PanelHeader(title: "LIMITS", systemImage: "gauge.with.dots.needle.33percent", positionMode: .notch)
        .padding(.bottom, 2)
        .offset(y: -NotchAgentColumnLayout.headerLift)

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

      if shouldShowActions {
        HStack(spacing: 6) {
          if showsUtilityActions {
            FlowlineIconButton(
              title: "Copy context",
              systemImage: "doc.on.doc",
              positionMode: .notch,
              action: copyContext
            )

            FlowlineIconButton(
              title: "Refresh limits (auto every 5m)",
              systemImage: "arrow.clockwise",
              positionMode: .notch,
              action: refreshUsage
            )
          }

          ForEach(visibleActions.prefix(showsUtilityActions ? 4 : 2)) { action in
            FlowlineIconButton(
              title: action.title,
              systemImage: action.systemImage,
              positionMode: .notch,
              action: { perform(action) }
            )
          }
        }
      }
    }
    .padding(FlowlineDesign.Metrics.notchColumnPadding)
  }

  private var usageRows: [AIProviderUsage] {
    AIUsageDisplayRows.rows(for: usage)
  }

  private var contextualActions: [FlowlineAction] {
    actions.filter { $0.kind != .clearShelf }
  }

  private var visibleActions: [FlowlineAction] {
    showsUtilityActions ? actions : contextualActions
  }

  private var shouldShowActions: Bool {
    NotchAgentColumnLayout.showsActions(
      hasUsageRows: !usageRows.isEmpty,
      showsUtilityActions: showsUtilityActions,
      hasContextualActions: !contextualActions.isEmpty
    )
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
    HStack(spacing: NotchAgentColumnLayout.usageRowComponentSpacing) {
      Text(usage.provider.displayName)
        .font(.system(
          size: NotchAgentColumnLayout.usageProviderLabelFontSize,
          weight: .medium,
          design: .monospaced
        ))
        .foregroundStyle(FlowlineDesign.secondary(for: .notch))
        .frame(width: NotchAgentColumnLayout.usageProviderLabelWidth, alignment: .leading)
        .lineLimit(1)
        .minimumScaleFactor(NotchAgentColumnLayout.usageProviderLabelMinimumScaleFactor)

      if let primary = usage.primary {
        NotchUsageChip(window: primary, color: primaryColor)
      }

      if let secondary = usage.secondary, secondary.percentLeft != nil {
        NotchUsageChip(window: secondary, color: FlowlineDesign.tertiary(for: .notch))
      }

      if let resetLabel = AIUsageResetPresentation.compactLabel(for: usage) {
        NotchUsageResetChip(
          label: resetLabel,
          title: AIUsageResetPresentation.helpText(for: usage) ?? "Limit reset"
        )
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
    HStack(spacing: NotchAgentColumnLayout.usageRowComponentSpacing) {
      Text(shortLabel)
        .font(.system(size: NotchAgentColumnLayout.usageWindowLabelFontSize, weight: .semibold, design: .monospaced))
        .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
        .frame(width: NotchAgentColumnLayout.usageWindowLabelWidth, alignment: .leading)
        .lineLimit(1)

      Text(percentText)
        .font(.system(size: NotchAgentColumnLayout.usagePercentFontSize, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .monospacedDigit()
        .frame(width: NotchAgentColumnLayout.usagePercentWidth, alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(NotchAgentColumnLayout.usagePercentMinimumScaleFactor)
    }
    .frame(width: NotchAgentColumnLayout.usageChipWidth, height: NotchAgentColumnLayout.usageChipHeight)
    .help("\(window.label) \(helpPercentText)")
    .accessibilityLabel("\(window.label) \(helpPercentText)")
  }

  private var percentText: String {
    guard let percent = window.percentLeft else {
      return "--"
    }

    return "\(percent)"
  }

  private var helpPercentText: String {
    guard let percent = window.percentLeft else {
      return "unknown"
    }

    return "\(percent)% left"
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

private struct NotchUsageResetChip: View {
  let label: String
  let title: String

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: NotchAgentColumnLayout.usageResetIconFontSize, weight: .medium))

      Text(label)
        .font(.system(size: NotchAgentColumnLayout.usageResetLabelFontSize, weight: .semibold, design: .monospaced))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(NotchAgentColumnLayout.usageResetLabelMinimumScaleFactor)
    }
    .foregroundStyle(FlowlineDesign.tertiary(for: .notch))
    .frame(
      width: NotchAgentColumnLayout.usageResetChipWidth,
      height: NotchAgentColumnLayout.usageResetChipHeight,
      alignment: .trailing
    )
    .help(title)
    .accessibilityLabel(title)
  }
}

private struct NotchUtilityColumn: View {
  let playback: MusicPlaybackSnapshot?
  let previous: () -> Void
  let togglePlayPause: () -> Void
  let next: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      PanelHeader(title: "MUSIC", systemImage: "music.note", positionMode: .notch)
        .offset(x: NotchUtilityMusicLayout.headerShiftX, y: -NotchUtilityMusicLayout.headerLift)

      NotchMusicNowPlaying(
        playback: playback,
        previous: previous,
        togglePlayPause: togglePlayPause,
        next: next
      )
      .frame(width: NotchMetrics.musicTimelineWidth, alignment: .leading)

      Spacer(minLength: 0)
    }
    .padding(.top, 8)
    .padding(.bottom, 8)
    .padding(.leading, NotchUtilityMusicLayout.leadingInset())
    .padding(.trailing, FlowlineDesign.Metrics.notchColumnPadding)
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
      PanelHeader(title: "HOLD", systemImage: "tray.full", positionMode: positionMode)

      if items.isEmpty {
        Text("Copy text or link")
          .font(FlowlineDesign.Typography.title)
          .foregroundStyle(FlowlineDesign.foreground(for: positionMode))
          .lineLimit(1)

        Text("Memory only")
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
    case .code:
      return "curlybraces"
    case .link:
      return "link"
    case .file:
      return "doc"
    case .screenshot:
      return "camera.viewfinder"
    case .sensitive:
      return "lock"
    }
  }
}
