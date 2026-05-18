import Testing
import CoreGraphics
import FlowlineCore
@testable import FlowlineApp

@Test func musicLayoutRightAlignsTimelineInsideUtilityColumn() {
  let inset = NotchUtilityMusicLayout.leadingInset(
    columnWidth: 232,
    contentWidth: 188,
    trailingInset: 10
  )

  #expect(inset == 34)
}

@Test func musicLayoutDoesNotGoNegativeWhenContentIsWide() {
  let inset = NotchUtilityMusicLayout.leadingInset(
    columnWidth: 180,
    contentWidth: 188,
    trailingInset: 10
  )

  #expect(inset == 0)
}

@Test func musicHeaderLiftsIntoTopNotchSpace() {
  #expect(NotchUtilityMusicLayout.headerLift == 22)
}

@Test func musicHeaderShiftsRightInsideTopNotchSpace() {
  #expect(NotchUtilityMusicLayout.headerShiftX == 20)
}

@Test func musicTransportDefinesSharedNotchButtonHeight() {
  #expect(NotchUtilityMusicLayout.transportButtonHeight == 24)
}

@Test func holdHeaderMatchesMusicHeaderLiftWithoutHorizontalShift() {
  #expect(NotchHoldHeaderLayout.headerLift == NotchUtilityMusicLayout.headerLift)
  #expect(NotchHoldHeaderLayout.headerShiftX == 0)
}

@Test func workspaceHeaderMatchesHoldHeaderHeight() {
  #expect(NotchWorkspaceHeaderLayout.headerLift == NotchHoldHeaderLayout.headerLift)
  #expect(NotchWorkspaceHeaderLayout.headerShiftX == NotchHoldHeaderLayout.headerShiftX)
}

@Test func holdHeaderUsesMusicSafeInsetOnRightColumn() {
  #expect(NotchHoldHeaderLayout.leadingInset(for: .right) == NotchUtilityMusicLayout.leadingInset())
  #expect(NotchHoldHeaderLayout.headerShiftX(for: .right) == NotchUtilityMusicLayout.headerShiftX)
}

@Test func holdHeaderKeepsStandardInsetOnLeftColumn() {
  #expect(NotchHoldHeaderLayout.leadingInset(for: .left) == FlowlineDesign.Metrics.notchColumnPadding)
  #expect(NotchHoldHeaderLayout.headerShiftX(for: .left) == 0)
}

@Test func calendarRightColumnMatchesMusicColumnRhythm() {
  #expect(NotchCalendarLayout.headerLift == NotchUtilityMusicLayout.headerLift)
  #expect(NotchCalendarLayout.headerShiftX(for: .right) == NotchUtilityMusicLayout.headerShiftX)
  #expect(NotchCalendarLayout.leadingInset(for: .right) == NotchUtilityMusicLayout.leadingInset())
  #expect(NotchCalendarLayout.trailingInset(for: .right) == FlowlineDesign.Metrics.notchColumnPadding)
  #expect(NotchCalendarLayout.contentWidth(for: .right) == CGFloat(NotchMetrics.musicTimelineWidth))
}

@Test func calendarLeftColumnStaysInsideContextColumn() {
  let padding = FlowlineDesign.Metrics.notchColumnPadding

  #expect(NotchCalendarLayout.headerShiftX(for: .left) == 0)
  #expect(NotchCalendarLayout.leadingInset(for: .left) == padding)
  #expect(NotchCalendarLayout.trailingInset(for: .left) == padding)
  #expect(
    NotchCalendarLayout.contentWidth(for: .left)
      == CGFloat(NotchMetrics.contextColumnWidth) - (padding * 2)
  )
}
