import FlowlineCore
import Foundation

enum HoldItemMetadataPresentation {
  static func label(for item: ShelfItem, expiry: String?) -> String {
    var parts = [prefix(for: item.kind)]

    if let detail = detail(for: item) {
      parts.append(detail)
    }

    if let expiry {
      parts.append(expiry)
    }

    return parts.joined(separator: " · ")
  }

  static func detail(for item: ShelfItem) -> String? {
    switch item.kind {
    case .code:
      let lines = max(1, lineCount(for: item.value))
      return "\(lines) \(lines == 1 ? "line" : "lines")"
    case .text:
      let lines = lineCount(for: item.value)
      if lines > 1 {
        return "\(lines) lines"
      }

      let characterCount = item.value.count
      return "\(compactCount(characterCount)) \(characterCount == 1 ? "char" : "chars")"
    case .screenshot:
      guard let ocrText = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines),
            !ocrText.isEmpty else {
        return nil
      }

      let words = wordCount(for: ocrText)
      return words > 0 ? "OCR \(words)w" : "OCR"
    case .link, .file, .sensitive:
      return nil
    }
  }

  private static func prefix(for kind: ShelfItem.Kind) -> String {
    switch kind {
    case .text:
      return "TEXT"
    case .code:
      return "CODE"
    case .link:
      return "LINK"
    case .file:
      return "FILE"
    case .screenshot:
      return "SS"
    case .sensitive:
      return "SECRET"
    }
  }

  private static func lineCount(for value: String) -> Int {
    guard !value.isEmpty else {
      return 0
    }

    return value.split(separator: "\n", omittingEmptySubsequences: false).count
  }

  private static func compactCount(_ count: Int) -> String {
    guard count >= 1_000 else {
      return "\(count)"
    }

    let value = Double(count) / 1_000
    let formatted = String(format: "%.1f", value)
    return "\(formatted.replacingOccurrences(of: ".0", with: ""))k"
  }

  private static func wordCount(for value: String) -> Int {
    value
      .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
      .count
  }
}
