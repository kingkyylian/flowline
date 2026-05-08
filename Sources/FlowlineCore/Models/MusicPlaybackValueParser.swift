import Foundation

public enum MusicPlaybackValueParser {
  public static func timeInterval(_ rawValue: String) -> TimeInterval {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

    if let value = TimeInterval(trimmed) {
      return value
    }

    let normalizedDecimal = trimmed.replacingOccurrences(of: ",", with: ".")
    if let value = TimeInterval(normalizedDecimal) {
      return value
    }

    let formatter = NumberFormatter()
    formatter.locale = .current
    formatter.numberStyle = .decimal

    if let number = formatter.number(from: trimmed) {
      return number.doubleValue
    }

    return 0
  }
}
