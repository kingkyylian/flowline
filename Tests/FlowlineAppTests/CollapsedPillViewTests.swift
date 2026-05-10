import Testing
@testable import FlowlineApp

@Test func collapsedUsageMetricsRemainVisibleUntilHover() {
  #expect(CollapsedPillUsageMetricsStyle.opacity(isHovering: false) > 0)
  #expect(CollapsedPillUsageMetricsStyle.opacity(isHovering: false) < CollapsedPillUsageMetricsStyle.opacity(isHovering: true))
}
