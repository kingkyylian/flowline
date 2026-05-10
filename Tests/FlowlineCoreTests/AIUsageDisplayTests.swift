import Foundation
import Testing
@testable import FlowlineCore

@Test func ordersKnownAIUsageByMostConstrainedLimitAndKeepsMissingProvidersVisible() {
  let snapshot = AIUsageSnapshot(
    providers: [
      AIProviderUsage(
        provider: .codex,
        primary: AIUsageWindow(label: "Session", percentLeft: 73),
        secondary: AIUsageWindow(label: "Weekly", percentLeft: 44)
      ),
      AIProviderUsage(
        provider: .claude,
        primary: AIUsageWindow(label: "5h", percentLeft: 12),
        secondary: AIUsageWindow(label: "7d", percentLeft: 80)
      )
    ],
    updatedAt: Date(timeIntervalSince1970: 0)
  )

  let rows = AIUsageDisplayRows.rows(for: snapshot)

  #expect(rows.map(\.provider) == [.claude, .codex, .gemini])
  #expect(rows[2].primary?.percentLeft == nil)
  #expect(rows[2].secondary?.percentLeft == nil)
}

@Test func showsDefaultAIUsageRowsWhenNoUsageSnapshotExists() {
  let rows = AIUsageDisplayRows.rows(for: nil)

  #expect(rows.map(\.provider) == [.codex, .claude, .gemini])
  #expect(rows.allSatisfy { $0.primary?.percentLeft == nil })
}
