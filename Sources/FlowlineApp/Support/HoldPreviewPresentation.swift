import Foundation
import FlowlineCore

enum HoldPreviewPresentation {
  static let maxThumbnailLines = 3
  static let maxThumbnailCharactersPerLine = 18
  static let maxPeekLines = 5
  static let maxPeekCharactersPerLine = 42
  static let maxInlinePreviewLines = 4
  static let maxInlinePreviewCharactersPerLine = 28
  static let maxTitleCharacters = 42

  struct Summary: Equatable, Sendable {
    let title: String
    let detail: String?
  }

  static func lines(for value: String) -> [String] {
    lines(
      for: value,
      maxLines: maxThumbnailLines,
      maxCharactersPerLine: maxThumbnailCharactersPerLine
    )
  }

  static func thumbnailLines(for item: ShelfItem) -> [String] {
    guard canPreviewText(for: item.kind) else {
      return []
    }

    return lines(for: item.value)
  }

  static func peekLines(for item: ShelfItem) -> [String] {
    guard canPreviewText(for: item.kind) else {
      return []
    }

    return lines(
      for: item.value,
      maxLines: maxPeekLines,
      maxCharactersPerLine: maxPeekCharactersPerLine
    )
  }

  static func inlinePreviewLines(for item: ShelfItem) -> [String] {
    if item.kind == .screenshot {
      guard let ocrText = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines),
            !ocrText.isEmpty else {
        return []
      }

      return lines(
        for: ocrText,
        maxLines: maxInlinePreviewLines,
        maxCharactersPerLine: maxInlinePreviewCharactersPerLine
      )
    }

    guard canPreviewText(for: item.kind) else {
      return []
    }

    return lines(
      for: item.value,
      maxLines: maxInlinePreviewLines,
      maxCharactersPerLine: maxInlinePreviewCharactersPerLine
    )
  }

  static func title(for item: ShelfItem) -> String {
    guard canPreviewText(for: item.kind),
          let firstLine = meaningfulLines(for: item.value).first else {
      return item.title
    }

    return truncated(firstLine, maxCharactersPerLine: maxTitleCharacters)
  }

  static func summary(for item: ShelfItem) -> Summary {
    switch item.kind {
    case .text:
      Summary(
        title: "TEXT",
        detail: HoldItemMetadataPresentation.detail(for: item)
      )
    case .code:
      Summary(
        title: "CODE",
        detail: HoldItemMetadataPresentation.detail(for: item)
      )
    case .link:
      Summary(title: "LINK", detail: item.url?.host() ?? title(for: item))
    case .file, .screenshot, .sensitive:
      Summary(title: title(for: item), detail: nil)
    }
  }

  static func tooltipText(for item: ShelfItem) -> String {
    let lines = peekLines(for: item)
    return lines.isEmpty ? title(for: item) : lines.joined(separator: "\n")
  }

  private static func lines(
    for value: String,
    maxLines: Int,
    maxCharactersPerLine: Int
  ) -> [String] {
    meaningfulLines(for: value)
      .prefix(maxLines)
      .map { truncated($0, maxCharactersPerLine: maxCharactersPerLine) }
  }

  private static func meaningfulLines(for value: String) -> [String] {
    value
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { line in
        line
          .replacingOccurrences(of: "\t", with: "  ")
          .trimmingCharacters(in: .whitespacesAndNewlines)
      }
      .filter { !$0.isEmpty }
      .filter { !$0.hasPrefix("```") }
  }

  private static func truncated(_ line: String, maxCharactersPerLine: Int) -> String {
    guard line.count > maxCharactersPerLine else {
      return line
    }

    let endIndex = line.index(line.startIndex, offsetBy: maxCharactersPerLine - 3)
    return "\(line[..<endIndex])..."
  }

  private static func canPreviewText(for kind: ShelfItem.Kind) -> Bool {
    switch kind {
    case .text, .code:
      return true
    case .link, .file, .screenshot, .sensitive:
      return false
    }
  }
}
