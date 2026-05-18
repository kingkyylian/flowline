import FlowlineCore
import Foundation

enum AIUsageResetPresentation {
  static func compactLabel(for usage: AIProviderUsage, now: Date = Date()) -> String? {
    guard let window = constrainedWindow(for: usage),
          let resetsAt = window.resetsAt else {
      return nil
    }

    return compactDuration(until: resetsAt, now: now)
  }

  static func helpText(for usage: AIProviderUsage, now: Date = Date()) -> String? {
    guard let window = constrainedWindow(for: usage),
          let resetsAt = window.resetsAt else {
      return nil
    }

    return "\(window.label) resets in \(longDuration(until: resetsAt, now: now))"
  }

  private static func constrainedWindow(for usage: AIProviderUsage) -> AIUsageWindow? {
    [usage.primary, usage.secondary]
      .compactMap { $0 }
      .filter { $0.resetsAt != nil }
      .sorted { lhs, rhs in
        switch (lhs.percentLeft, rhs.percentLeft) {
        case let (lhsPercent?, rhsPercent?) where lhsPercent != rhsPercent:
          return lhsPercent < rhsPercent
        case (.some, nil):
          return true
        case (nil, .some):
          return false
        default:
          return (lhs.resetsAt ?? .distantFuture) < (rhs.resetsAt ?? .distantFuture)
        }
      }
      .first
  }

  private static func compactDuration(until date: Date, now: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24

    if days > 0 {
      return "\(days)d"
    }

    if hours > 0 {
      return "\(hours)h"
    }

    if minutes > 0 {
      return "\(minutes)m"
    }

    return "now"
  }

  private static func longDuration(until date: Date, now: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24

    if days > 0 {
      let remainingHours = hours % 24
      return remainingHours > 0 ? "\(days)d \(remainingHours)h" : "\(days)d"
    }

    if hours > 0 {
      let remainingMinutes = minutes % 60
      return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
    }

    if minutes > 0 {
      return "\(minutes)m"
    }

    return "now"
  }
}
