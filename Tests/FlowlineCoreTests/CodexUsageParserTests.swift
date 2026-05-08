import Foundation
import Testing
@testable import FlowlineCore

@Test func parsesCodexUsagePercentLeftValues() throws {
  let data = """
    {
      "rate_limit": {
        "primary_window": {
          "used_percent": 8
        },
        "secondary_window": {
          "used_percent": 13
        }
      }
    }
    """.data(using: .utf8)!

  let snapshot = try CodexUsageParser.parse(data)

  #expect(snapshot.sessionPercentLeft == 92)
  #expect(snapshot.weeklyPercentLeft == 87)
}

@Test func parsesCodexProviderUsageWindows() throws {
  let data = """
    {
      "rate_limit": {
        "primary_window": {
          "used_percent": 39,
          "reset_at": 1778174910
        },
        "secondary_window": {
          "used_percent": 22,
          "reset_at": 1778553994
        }
      }
    }
    """.data(using: .utf8)!

  let usage = try CodexUsageParser.parseProvider(data)

  #expect(usage.provider == .codex)
  #expect(usage.primary?.label == "Session")
  #expect(usage.primary?.percentLeft == 61)
  #expect(usage.secondary?.label == "Weekly")
  #expect(usage.secondary?.percentLeft == 78)
  #expect(usage.primary?.resetsAt == Date(timeIntervalSince1970: 1_778_174_910))
}

@Test func parsesClaudeUsagePercentLeftValues() throws {
  let data = """
    {
      "five_hour": {
        "utilization": 1.0,
        "resets_at": "2026-05-07T14:40:00.600050+00:00"
      },
      "seven_day": {
        "utilization": 88.0,
        "resets_at": "2026-05-07T17:00:00.600072+00:00"
      }
    }
    """.data(using: .utf8)!

  let usage = try ClaudeUsageParser.parse(data)

  #expect(usage.provider == .claude)
  #expect(usage.primary?.label == "5h")
  #expect(usage.primary?.percentLeft == 99)
  #expect(usage.secondary?.label == "7d")
  #expect(usage.secondary?.percentLeft == 12)
}

@Test func parsesGeminiQuotaRemainingFraction() throws {
  let data = """
    {
      "buckets": [
        {
          "resetTime": "2026-05-08T14:37:39Z",
          "tokenType": "REQUESTS",
          "modelId": "gemini-2.5-flash",
          "remainingFraction": 1
        },
        {
          "resetTime": "2026-05-08T14:37:39Z",
          "tokenType": "REQUESTS",
          "modelId": "gemini-2.5-pro",
          "remainingFraction": 0.64
        }
      ]
    }
    """.data(using: .utf8)!

  let usage = try GeminiUsageParser.parse(data)

  #expect(usage.provider == .gemini)
  #expect(usage.primary?.label == "Daily")
  #expect(usage.primary?.percentLeft == 64)
}

@Test func clampsCodexUsagePercentLeftValues() throws {
  let data = """
    {
      "rate_limit": {
        "primary_window": {
          "used_percent": -4
        },
        "secondary_window": {
          "used_percent": 105
        }
      }
    }
    """.data(using: .utf8)!

  let snapshot = try CodexUsageParser.parse(data)

  #expect(snapshot.sessionPercentLeft == 100)
  #expect(snapshot.weeklyPercentLeft == 0)
}
