import Foundation
import Testing
@testable import FlowlineApp
import FlowlineCore

@Test func resetPresentationUsesMostConstrainedWindow() {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let usage = AIProviderUsage(
    provider: .codex,
    primary: AIUsageWindow(
      label: "Session",
      percentLeft: 70,
      resetsAt: now.addingTimeInterval(3 * 60 * 60)
    ),
    secondary: AIUsageWindow(
      label: "Weekly",
      percentLeft: 19,
      resetsAt: now.addingTimeInterval((13 * 60 + 50) * 60)
    )
  )

  #expect(AIUsageResetPresentation.compactLabel(for: usage, now: now) == "13h")
  #expect(AIUsageResetPresentation.helpText(for: usage, now: now) == "Weekly resets in 13h 50m")
}

@Test func resetPresentationUsesMinutesWhenUnderOneHour() {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let usage = AIProviderUsage(
    provider: .codex,
    primary: AIUsageWindow(
      label: "Session",
      percentLeft: 8,
      resetsAt: now.addingTimeInterval(41 * 60)
    )
  )

  #expect(AIUsageResetPresentation.compactLabel(for: usage, now: now) == "41m")
  #expect(AIUsageResetPresentation.helpText(for: usage, now: now) == "Session resets in 41m")
}

@Test func resetPresentationOmitsMissingResetDates() {
  let usage = AIProviderUsage(
    provider: .gemini,
    primary: AIUsageWindow(label: "Daily", percentLeft: 64)
  )

  #expect(AIUsageResetPresentation.compactLabel(for: usage) == nil)
  #expect(AIUsageResetPresentation.helpText(for: usage) == nil)
}
