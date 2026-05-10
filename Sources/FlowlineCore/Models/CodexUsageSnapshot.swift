import Foundation

public enum AIProvider: String, Equatable, Sendable {
  case codex
  case claude
  case gemini

  public var displayName: String {
    switch self {
    case .codex:
      return "Codex"
    case .claude:
      return "Claude"
    case .gemini:
      return "Gemini"
    }
  }
}

public struct AIUsageWindow: Equatable, Sendable {
  public var label: String
  public var percentLeft: Int?
  public var resetsAt: Date?

  public init(label: String, percentLeft: Int?, resetsAt: Date? = nil) {
    self.label = label
    self.percentLeft = percentLeft
    self.resetsAt = resetsAt
  }
}

public struct AIProviderUsage: Equatable, Identifiable, Sendable {
  public var provider: AIProvider
  public var primary: AIUsageWindow?
  public var secondary: AIUsageWindow?

  public var id: AIProvider {
    provider
  }

  public init(provider: AIProvider, primary: AIUsageWindow?, secondary: AIUsageWindow? = nil) {
    self.provider = provider
    self.primary = primary
    self.secondary = secondary
  }
}

public struct AIUsageSnapshot: Equatable, Sendable {
  public var providers: [AIProviderUsage]
  public var updatedAt: Date

  public init(providers: [AIProviderUsage], updatedAt: Date) {
    self.providers = providers
    self.updatedAt = updatedAt
  }

  public func provider(_ provider: AIProvider) -> AIProviderUsage? {
    providers.first { $0.provider == provider }
  }
}

public enum AIUsageDisplayRows {
  public static let defaultProviderOrder: [AIProvider] = [.codex, .claude, .gemini]

  public static func rows(for snapshot: AIUsageSnapshot?) -> [AIProviderUsage] {
    let indexedOrder = Dictionary(
      uniqueKeysWithValues: defaultProviderOrder.enumerated().map { ($0.element, $0.offset) }
    )
    let rows = defaultProviderOrder.map { provider in
      snapshot?.provider(provider) ?? placeholderUsage(for: provider)
    }

    return rows.sorted { lhs, rhs in
      switch (constrainedPercentLeft(for: lhs), constrainedPercentLeft(for: rhs)) {
      case let (lhsPercent?, rhsPercent?) where lhsPercent != rhsPercent:
        return lhsPercent < rhsPercent
      case (.some, nil):
        return true
      case (nil, .some):
        return false
      default:
        return indexedOrder[lhs.provider, default: Int.max] < indexedOrder[rhs.provider, default: Int.max]
      }
    }
  }

  public static func rows(for snapshot: AIUsageSnapshot) -> [AIProviderUsage] {
    rows(for: Optional(snapshot))
  }

  private static func constrainedPercentLeft(for usage: AIProviderUsage) -> Int? {
    [usage.primary?.percentLeft, usage.secondary?.percentLeft].compactMap { $0 }.min()
  }

  private static func placeholderUsage(for provider: AIProvider) -> AIProviderUsage {
    switch provider {
    case .codex:
      return AIProviderUsage(
        provider: provider,
        primary: AIUsageWindow(label: "Session", percentLeft: nil),
        secondary: AIUsageWindow(label: "Weekly", percentLeft: nil)
      )
    case .claude:
      return AIProviderUsage(
        provider: provider,
        primary: AIUsageWindow(label: "5h", percentLeft: nil),
        secondary: AIUsageWindow(label: "7d", percentLeft: nil)
      )
    case .gemini:
      return AIProviderUsage(
        provider: provider,
        primary: AIUsageWindow(label: "Daily", percentLeft: nil)
      )
    }
  }
}

public struct CodexUsageSnapshot: Equatable, Sendable {
  public var sessionPercentLeft: Int?
  public var weeklyPercentLeft: Int?

  public init(sessionPercentLeft: Int?, weeklyPercentLeft: Int?) {
    self.sessionPercentLeft = sessionPercentLeft
    self.weeklyPercentLeft = weeklyPercentLeft
  }
}

public enum CodexUsageParser {
  public static func parse(_ data: Data) throws -> CodexUsageSnapshot {
    let response = try JSONDecoder().decode(Response.self, from: data)

    return CodexUsageSnapshot(
      sessionPercentLeft: percentLeft(from: response.rateLimit.primaryWindow?.usedPercent),
      weeklyPercentLeft: percentLeft(from: response.rateLimit.secondaryWindow?.usedPercent)
    )
  }

  public static func parseProvider(_ data: Data) throws -> AIProviderUsage {
    let response = try JSONDecoder().decode(Response.self, from: data)

    return AIProviderUsage(
      provider: .codex,
      primary: AIUsageWindow(
        label: "Session",
        percentLeft: percentLeft(from: response.rateLimit.primaryWindow?.usedPercent),
        resetsAt: date(fromUnixTimestamp: response.rateLimit.primaryWindow?.resetAt)
      ),
      secondary: AIUsageWindow(
        label: "Weekly",
        percentLeft: percentLeft(from: response.rateLimit.secondaryWindow?.usedPercent),
        resetsAt: date(fromUnixTimestamp: response.rateLimit.secondaryWindow?.resetAt)
      )
    )
  }

  public static func parseSessionEventProvider(_ data: Data) throws -> AIProviderUsage? {
    let event = try JSONDecoder().decode(SessionEvent.self, from: data)
    guard let rateLimits = event.payload.rateLimits, rateLimits.limitID == "codex" else {
      return nil
    }

    return AIProviderUsage(
      provider: .codex,
      primary: AIUsageWindow(
        label: "Session",
        percentLeft: percentLeft(from: rateLimits.primary?.usedPercent),
        resetsAt: date(fromUnixTimestamp: rateLimits.primary?.resetsAt)
      ),
      secondary: AIUsageWindow(
        label: "Weekly",
        percentLeft: percentLeft(from: rateLimits.secondary?.usedPercent),
        resetsAt: date(fromUnixTimestamp: rateLimits.secondary?.resetsAt)
      )
    )
  }

  private static func percentLeft(from usedPercent: Double?) -> Int? {
    guard let usedPercent else {
      return nil
    }

    return min(100, max(0, Int((100.0 - usedPercent).rounded())))
  }

  private static func date(fromUnixTimestamp timestamp: Double?) -> Date? {
    guard let timestamp else {
      return nil
    }

    return Date(timeIntervalSince1970: timestamp)
  }

  private struct Response: Decodable {
    var rateLimit: RateLimit

    enum CodingKeys: String, CodingKey {
      case rateLimit = "rate_limit"
    }
  }

  private struct RateLimit: Decodable {
    var primaryWindow: Window?
    var secondaryWindow: Window?

    enum CodingKeys: String, CodingKey {
      case primaryWindow = "primary_window"
      case secondaryWindow = "secondary_window"
    }
  }

  private struct Window: Decodable {
    var usedPercent: Double
    var resetAt: Double?

    enum CodingKeys: String, CodingKey {
      case usedPercent = "used_percent"
      case resetAt = "reset_at"
    }
  }

  private struct SessionEvent: Decodable {
    var payload: SessionPayload
  }

  private struct SessionPayload: Decodable {
    var rateLimits: SessionRateLimits?

    enum CodingKeys: String, CodingKey {
      case rateLimits = "rate_limits"
    }
  }

  private struct SessionRateLimits: Decodable {
    var limitID: String?
    var primary: SessionWindow?
    var secondary: SessionWindow?

    enum CodingKeys: String, CodingKey {
      case limitID = "limit_id"
      case primary
      case secondary
    }
  }

  private struct SessionWindow: Decodable {
    var usedPercent: Double?
    var resetsAt: Double?

    enum CodingKeys: String, CodingKey {
      case usedPercent = "used_percent"
      case resetsAt = "resets_at"
    }
  }
}

public enum ClaudeUsageParser {
  public static func parse(_ data: Data) throws -> AIProviderUsage {
    let response = try JSONDecoder().decode(Response.self, from: data)

    return AIProviderUsage(
      provider: .claude,
      primary: window(label: "5h", usage: response.fiveHour),
      secondary: window(label: "7d", usage: response.sevenDay)
    )
  }

  private static func window(label: String, usage: UsageWindow?) -> AIUsageWindow? {
    guard let usage else {
      return nil
    }

    return AIUsageWindow(
      label: label,
      percentLeft: percentLeft(fromUtilization: usage.utilization),
      resetsAt: DateParsers.date(fromISO8601: usage.resetsAt)
    )
  }

  private static func percentLeft(fromUtilization utilization: Double?) -> Int? {
    guard let utilization else {
      return nil
    }

    return min(100, max(0, Int((100.0 - utilization).rounded())))
  }

  private struct Response: Decodable {
    var fiveHour: UsageWindow?
    var sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
      case fiveHour = "five_hour"
      case sevenDay = "seven_day"
    }
  }

  private struct UsageWindow: Decodable {
    var utilization: Double?
    var resetsAt: String?

    enum CodingKeys: String, CodingKey {
      case utilization
      case resetsAt = "resets_at"
    }
  }
}

public enum GeminiUsageParser {
  public static func parse(_ data: Data) throws -> AIProviderUsage {
    let response = try JSONDecoder().decode(Response.self, from: data)
    let requestBuckets = response.buckets.filter { $0.tokenType == "REQUESTS" }
    let remainingFraction = requestBuckets.compactMap(\.remainingFraction).min()
    let resetDate = requestBuckets
      .compactMap { DateParsers.date(fromISO8601: $0.resetTime) }
      .min()

    return AIProviderUsage(
      provider: .gemini,
      primary: AIUsageWindow(
        label: "Daily",
        percentLeft: percentLeft(fromRemainingFraction: remainingFraction),
        resetsAt: resetDate
      )
    )
  }

  private static func percentLeft(fromRemainingFraction fraction: Double?) -> Int? {
    guard let fraction else {
      return nil
    }

    return min(100, max(0, Int((fraction * 100.0).rounded())))
  }

  private struct Response: Decodable {
    var buckets: [Bucket]
  }

  private struct Bucket: Decodable {
    var tokenType: String?
    var remainingFraction: Double?
    var resetTime: String?
  }
}

private enum DateParsers {
  static func date(fromISO8601 value: String?) -> Date? {
    guard let value else {
      return nil
    }

    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let plainFormatter = ISO8601DateFormatter()
    plainFormatter.formatOptions = [.withInternetDateTime]

    return fractionalFormatter.date(from: value) ?? plainFormatter.date(from: value)
  }
}
