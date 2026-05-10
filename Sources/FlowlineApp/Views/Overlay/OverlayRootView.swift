import FlowlineCore
import SwiftUI
import UniformTypeIdentifiers

struct OverlayRootView: View {
  @ObservedObject var state: AppState
  @State private var expandedContentVisible = false
  @State private var revealTask: Task<Void, Never>?

  var body: some View {
    content
    .padding(contentInsets)
    .frame(width: rootWidth, height: rootHeight, alignment: .top)
    .background(backgroundView)
    .overlay(overlayView)
    .shadow(color: .black.opacity(shadowOpacity), radius: state.isExpanded ? 12 : 5, y: 3)
    .animation(.smooth(duration: 0.22), value: state.isExpanded)
    .animation(.smooth(duration: 0.16), value: state.isHovering)
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.smooth(duration: 0.20)) {
        state.isHovering = hovering
      }
    }
    .onTapGesture {
      guard !state.isExpanded else {
        return
      }

      withAnimation(.smooth(duration: 0.20)) {
        state.isExpanded = true
      }
    }
    .help("Click to toggle Flowline")
    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
      providers.forEach { provider in
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
          guard let url else {
            return
          }

          Task { @MainActor in
            state.addShelfFiles([url])
          }
        }
      }

      return true
    }
    .onAppear {
      expandedContentVisible = state.isExpanded
    }
    .onChange(of: state.isExpanded) { _, isExpanded in
      updateExpandedContentVisibility(isExpanded: isExpanded)
    }
    .onChange(of: state.positionMode) { _, _ in
      updateExpandedContentVisibility(isExpanded: state.isExpanded)
    }
  }

  @ViewBuilder
  private var content: some View {
    if state.isExpanded {
      ExpandedBarView(state: state)
        .opacity(shouldDelayExpandedContent ? (expandedContentVisible ? 1 : 0) : 1)
        .allowsHitTesting(!shouldDelayExpandedContent || expandedContentVisible)
        .animation(.smooth(duration: 0.16), value: expandedContentVisible)
    } else {
      CollapsedPillView(
        snapshot: state.snapshot,
        aiUsage: state.aiUsage,
        width: state.positionMode == .notch ? notchCollapsedWidth : NotchMetrics.companionFallbackWidth,
        isHovering: state.isHovering,
        positionMode: state.positionMode,
        showsUsageMetrics: true
      )
    }
  }

  @ViewBuilder
  private var backgroundView: some View {
    switch state.positionMode {
    case .companion:
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white.opacity(state.isExpanded ? 0.58 : 0.44))
        }
    case .notch:
      FlowlineNotchShape(bottomRadius: state.isExpanded ? 24 : 16)
        .fill(Color.black)
        .frame(width: notchSurfaceWidth, height: notchSurfaceHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }


  @ViewBuilder
  private var overlayView: some View {
    switch state.positionMode {
    case .companion:
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .stroke(Color.black.opacity(borderOpacity), lineWidth: 1)
    case .notch:
      ZStack(alignment: .top) {
        if state.isExpanded {
          FlowlineNotchShape(bottomRadius: 24)
            .stroke(Color.white.opacity(0.02), lineWidth: 1)
            .frame(width: notchSurfaceWidth, height: notchSurfaceHeight)
        } else if state.isHovering {
          FlowlineNotchShape(bottomRadius: 18)
            .stroke(Color.white.opacity(0.02), lineWidth: 1)
            .frame(width: notchSurfaceWidth, height: notchSurfaceHeight)
        }

        if state.isExpanded {
          CollapsedPillView(
            snapshot: state.snapshot,
            aiUsage: state.aiUsage,
            width: state.physicalNotchWidth,
            isHovering: state.isHovering,
            positionMode: .notch,
            showsUsageMetrics: false
          )
          .allowsHitTesting(false)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }

  private var borderOpacity: Double {
    switch state.positionMode {
    case .companion:
      if state.isExpanded {
        return 0.84
      }

      return state.isHovering ? 0.92 : 0.42
    case .notch:
      if state.isExpanded {
        return 0.18
      }

      return state.isHovering ? 0.22 : 0.08
    }
  }

  private var shadowOpacity: Double {
    switch state.positionMode {
    case .companion:
      return state.isExpanded ? 0.14 : 0.10
    case .notch:
      return state.isExpanded ? 0.20 : 0.0
    }
  }

  private var contentInsets: EdgeInsets {
    if !state.isExpanded {
      return EdgeInsets()
    }

    if state.positionMode == .notch {
      return EdgeInsets(
        top: NotchMetrics.expandedContentTopInset,
        leading: 12,
        bottom: NotchMetrics.expandedContentBottomInset,
        trailing: 12
      )
    }

    return EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
  }

  private var shouldDelayExpandedContent: Bool {
    state.positionMode == .notch && state.isExpanded
  }

  private var rootWidth: CGFloat? {
    guard state.positionMode == .notch else {
      return nil
    }

    return NotchMetrics.windowWidth
  }

  private var rootHeight: CGFloat? {
    guard state.positionMode == .notch else {
      return nil
    }

    return NotchMetrics.expandedHeight
  }

  private var notchSurfaceWidth: CGFloat {
    if state.isExpanded {
      return NotchMetrics.expandedWidth
    }

    return notchCollapsedWidth
  }

  private var notchCollapsedWidth: CGFloat {
    state.isHovering ? NotchMetrics.hoverWidth : state.physicalNotchWidth
  }

  private var notchSurfaceHeight: CGFloat {
    if state.isExpanded {
      return NotchMetrics.expandedHeight
    }

    return state.physicalNotchHeight
  }

  private func updateExpandedContentVisibility(isExpanded: Bool) {
    revealTask?.cancel()

    guard isExpanded else {
      expandedContentVisible = false
      return
    }

    guard state.positionMode == .notch else {
      expandedContentVisible = true
      return
    }

    expandedContentVisible = false
    revealTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(105))
      guard !Task.isCancelled, state.isExpanded, state.positionMode == .notch else {
        return
      }

      expandedContentVisible = true
    }
  }
}
