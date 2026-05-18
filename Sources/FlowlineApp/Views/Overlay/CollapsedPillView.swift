import FlowlineCore
import SwiftUI

enum CollapsedPillUsageMetricsStyle {
  static func opacity(isHovering: Bool) -> Double {
    isHovering ? 0.88 : 0.56
  }
}

struct CollapsedPillView: View {
  let snapshot: ContextSnapshot
  let aiUsage: AIUsageSnapshot?
  let width: Double
  let isHovering: Bool
  let positionMode: PositionMode
  let showsUsageMetrics: Bool

  var body: some View {
    if positionMode == .notch {
      notchBody
    } else {
      companionBody
    }
  }

  private var notchBody: some View {
    ZStack {
      HStack(spacing: 16) {
        Circle()
          .fill(statusColor)
          .frame(width: 5, height: 5)
          .help(statusHelp)
          .accessibilityLabel(statusHelp)

        collapsedIcon

        Circle()
          .fill(secondaryDotColor)
          .frame(width: 5, height: 5)
      }
      .frame(width: 70)

      if showsUsageMetrics && hasUsage {
        ZStack {
          if let weeklyPercent = codexUsage?.secondary?.percentLeft {
            NotchMetric(percent: weeklyPercent)
            .offset(x: isHovering ? -100 : -42)
          }

          if let sessionPercent = codexUsage?.primary?.percentLeft {
            NotchMetric(percent: sessionPercent)
            .offset(x: isHovering ? 100 : 42)
          }
        }
        .frame(width: width, height: NotchMetrics.collapsedHeight)
        .opacity(CollapsedPillUsageMetricsStyle.opacity(isHovering: isHovering))
      }
    }
    .frame(width: width, height: NotchMetrics.collapsedHeight, alignment: .center)
    .opacity(isHovering ? 1.0 : 0.70)
    .animation(.smooth(duration: 0.16), value: isHovering)
  }

  private struct NotchMetric: View {
    let percent: Int

    var body: some View {
      Text("%\(percent)")
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(width: 36)
    }

    private var color: Color {
      if percent <= 10 {
        return Color(nsColor: .systemRed).opacity(0.92)
      }

      if percent == 100 {
        return Color(nsColor: .systemGreen).opacity(0.92)
      }

      return Color.white.opacity(0.76)
    }
  }

  private var hasUsage: Bool {
    codexUsage?.secondary?.percentLeft != nil || codexUsage?.primary?.percentLeft != nil
  }

  private var codexUsage: AIProviderUsage? {
    aiUsage?.provider(.codex)
  }

  private var companionBody: some View {
    HStack(spacing: 10) {
      Rectangle()
        .fill(statusColor)
        .frame(width: 7, height: 7)
        .help(statusHelp)
        .accessibilityLabel(statusHelp)

      companionIcon

      Text(title)
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(foreground)
        .lineLimit(1)

      Spacer(minLength: 0)

      if let git = snapshot.git {
        Text(git.isDirty ? "DIRTY" : "CLEAN")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(foreground.opacity(0.52))
          .lineLimit(1)
      }

      Image(systemName: "chevron.down")
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(foreground.opacity(isHovering ? 0.72 : 0.28))
        .frame(width: 10)
    }
    .padding(.horizontal, 12)
    .frame(width: width, height: 40)
    .background(isHovering ? Color.primary.opacity(0.04) : Color.clear)
  }

  @ViewBuilder
  private var collapsedIcon: some View {
    if let iconName {
      Image(systemName: iconName)
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Color.white.opacity(isHovering ? 0.70 : 0.30))
    } else {
      FlowlineMarkView(
        size: FlowlineMarkMetrics.collapsedSize,
        opacity: isHovering ? 0.78 : 0.34
      )
      .foregroundStyle(.white)
    }
  }

  @ViewBuilder
  private var companionIcon: some View {
    if let iconName {
      Image(systemName: iconName)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(foreground.opacity(0.58))
        .frame(width: 14)
    } else {
      FlowlineMarkView(size: FlowlineMarkMetrics.collapsedSize, opacity: 0.58)
        .foregroundStyle(foreground)
        .frame(width: 14)
    }
  }

  private var iconName: String? {
    if snapshot.activeApp.isDeveloperApp {
      return "chevron.left.forwardslash.chevron.right"
    }

    if snapshot.nextEvent != nil {
      return "calendar"
    }

    return nil
  }

  private var statusColor: Color {
    if !snapshot.statusItems.isEmpty {
      return FlowlineDesign.warning(for: positionMode)
    }

    return FlowlineDesign.success(for: positionMode)
  }

  private var secondaryDotColor: Color {
    if !snapshot.shelfItems.isEmpty {
      return Color.white.opacity(isHovering ? 0.52 : 0.36)
    }

    if snapshot.nextEvent != nil {
      return FlowlineDesign.warning(for: positionMode).opacity(isHovering ? 0.9 : 0.58)
    }

    return Color.white.opacity(isHovering ? 0.24 : 0.14)
  }

  private var statusHelp: String {
    snapshot.statusItems.isEmpty ? "Ready" : snapshot.statusItems.joined(separator: ", ")
  }

  private var title: String {
    snapshot.compactLine
  }

  private var foreground: Color {
    FlowlineDesign.foreground(for: positionMode)
  }
}
