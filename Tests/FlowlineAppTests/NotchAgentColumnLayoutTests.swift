import Testing
import SwiftUI
@testable import FlowlineApp

@Test func notchAgentColumnHidesActionsWhenUsageRowsAreVisible() {
  #expect(!NotchAgentColumnLayout.showsActions(
    hasUsageRows: true,
    showsUtilityActions: true,
    hasContextualActions: true
  ))
}

@Test func notchAgentColumnKeepsActionsWhenUsageRowsAreEmpty() {
  #expect(NotchAgentColumnLayout.showsActions(
    hasUsageRows: false,
    showsUtilityActions: true,
    hasContextualActions: false
  ))

  #expect(NotchAgentColumnLayout.showsActions(
    hasUsageRows: false,
    showsUtilityActions: false,
    hasContextualActions: true
  ))
}

@Test func notchAgentColumnMovesLimitsCloserToMusicWithoutOverlappingIt() {
  #expect(NotchMetrics.centerColumnShiftX == -26)

  let agentLeftEdge = (NotchMetrics.expandedContentWidth - NotchMetrics.agentColumnWidth) / 2
    + NotchMetrics.centerColumnShiftX
  let agentRightEdge = agentLeftEdge + NotchMetrics.agentColumnWidth
  let musicContentLeftEdge = NotchMetrics.expandedContentWidth
    - NotchMetrics.utilityColumnWidth
    + Double(NotchUtilityMusicLayout.leadingInset())

  #expect(agentRightEdge <= musicContentLeftEdge)
}

@Test func usageProviderNamesUseFixedReadableScale() {
  #expect(NotchAgentColumnLayout.usageProviderLabelWidth == 40)
  #expect(NotchAgentColumnLayout.usageProviderLabelFontSize == 10.2)
  #expect(NotchAgentColumnLayout.usageProviderLabelMinimumScaleFactor == 1)
}

@Test func usageRowsScaleUpProportionallyAndStillFitAgentColumn() {
  #expect(NotchAgentColumnLayout.headerLift == 12)
  #expect(NotchAgentColumnLayout.usageRowComponentSpacing == 4)
  #expect(NotchAgentColumnLayout.usageWindowLabelFontSize == 8.2)
  #expect(NotchAgentColumnLayout.usagePercentFontSize == 9.5)
  #expect(NotchAgentColumnLayout.usageResetLabelFontSize == 9)
  #expect(NotchAgentColumnLayout.usageChipHeight == 17)

  let contentWidth = CGFloat(NotchMetrics.agentColumnWidth)
    - (FlowlineDesign.Metrics.notchColumnPadding * 2)
  let occupiedWidth = NotchAgentColumnLayout.usageProviderLabelWidth
    + (NotchAgentColumnLayout.usageChipWidth * 2)
    + NotchAgentColumnLayout.usageResetChipWidth
    + (NotchAgentColumnLayout.usageRowComponentSpacing * 3)

  #expect(occupiedWidth <= contentWidth)
}
