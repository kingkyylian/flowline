import Foundation

public struct ShelfStore: Sendable {
  public private(set) var items: [ShelfItem]
  private let limit: Int
  private let retention: TimeInterval
  private let sensitiveRetention: TimeInterval

  public init(
    limit: Int = 10,
    items: [ShelfItem] = [],
    retention: TimeInterval = 900,
    sensitiveRetention: TimeInterval = 60
  ) {
    self.limit = limit
    self.retention = retention
    self.sensitiveRetention = sensitiveRetention
    self.items = Array(items.prefix(limit))
  }

  @discardableResult
  public mutating func addText(_ text: String, now: Date = Date()) -> ShelfItem? {
    pruneExpired(now: now)

    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }

    let classification = classify(trimmed)
    return add(
      ShelfItem(
        kind: classification.kind,
        title: classification.title,
        value: trimmed,
        url: classification.url,
        createdAt: now,
        expiresAt: now.addingTimeInterval(classification.kind == .sensitive ? sensitiveRetention : retention)
      )
    )
  }

  @discardableResult
  public mutating func addFile(_ url: URL, now: Date = Date()) -> ShelfItem? {
    pruneExpired(now: now)

    guard !Self.isImageFile(url) || Self.isScreenshotFile(url) else {
      return nil
    }

    let kind: ShelfItem.Kind = Self.isScreenshotFile(url) ? .screenshot : .file
    return add(
      ShelfItem(
        kind: kind,
        title: url.lastPathComponent,
        value: url.path,
        url: url,
        createdAt: now,
        expiresAt: now.addingTimeInterval(retention)
      )
    )
  }

  @discardableResult
  public mutating func addScreenshotFile(_ url: URL, now: Date = Date()) -> ShelfItem? {
    pruneExpired(now: now)

    return add(
      ShelfItem(
        kind: .screenshot,
        title: url.lastPathComponent,
        value: url.path,
        url: url,
        createdAt: now,
        expiresAt: now.addingTimeInterval(retention)
      )
    )
  }

  @discardableResult
  public mutating func updateOCRText(_ text: String, for id: ShelfItem.ID) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let index = items.firstIndex(where: { $0.id == id }),
          items[index].kind == .screenshot else {
      return false
    }

    items[index].ocrText = trimmed
    return true
  }

  @discardableResult
  public mutating func pruneExpired(now: Date = Date()) -> [ShelfItem] {
    let expiredItems = items.filter { item in
      guard let expiresAt = item.expiresAt else {
        return false
      }

      return expiresAt <= now
    }

    guard !expiredItems.isEmpty else {
      return []
    }

    let expiredIDs = Set(expiredItems.map(\.id))
    items.removeAll { expiredIDs.contains($0.id) }
    return expiredItems
  }

  public mutating func cycle() {
    guard items.count > 1 else {
      return
    }

    items.append(items.removeFirst())
  }

  public mutating func remove(id: ShelfItem.ID) {
    items.removeAll { $0.id == id }
  }

  public mutating func clear() {
    items.removeAll()
  }

  private mutating func add(_ item: ShelfItem) -> ShelfItem? {
    guard limit > 0 else {
      return nil
    }

    items.removeAll { $0.kind == item.kind && $0.value == item.value }
    items.insert(item, at: 0)

    if items.count > limit {
      items.removeSubrange(limit..<items.count)
    }

    return item
  }

  private func classify(_ value: String) -> (kind: ShelfItem.Kind, title: String, url: URL?) {
    let codeTitle = codeTitle(for: value)

    if codeTitle == nil, containsSecretMarker(value) {
      return (.sensitive, "Sensitive clip", nil)
    }

    if let url = webURL(for: value), let host = url.host(), !host.isEmpty {
      return (.link, host, url)
    }

    if let codeTitle {
      return (.code, codeTitle, nil)
    }

    if isLikelyOpaqueSecret(value) {
      return (.sensitive, "Sensitive clip", nil)
    }

    return (.text, String(value.prefix(80)), nil)
  }

  private func webURL(for value: String) -> URL? {
    guard let url = URL(string: value),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = url.host(),
          !host.isEmpty else {
      return nil
    }

    return url
  }

  private func codeTitle(for value: String) -> String? {
    guard isLikelyCode(value) else {
      return nil
    }

    let title = value
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty && !$0.hasPrefix("```") }
      .map { String($0.prefix(80)) }

    return title ?? "Code block"
  }

  private func isLikelyCode(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("```") {
      return true
    }

    let lines = trimmed
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard lines.count >= 3 else {
      return false
    }

    let scoredLines = lines.prefix(80)
    let score = scoredLines.reduce(0) { total, line in
      total + (lineLooksLikeCode(line) ? 1 : 0)
    }

    if lines.count >= 12 {
      return score >= 4
    }

    return score >= 2
  }

  private func lineLooksLikeCode(_ line: String) -> Bool {
    let lowercased = line.lowercased()
    let keywords = [
      "import ", "from ", "func ", "function ", "class ", "struct ", "enum ",
      "let ", "var ", "const ", "def ", "return ", "if ", "for ", "while ",
      "switch ", "case ", "try ", "catch ", "await ", "async ", "public ",
      "private ", "package ", "using ", "namespace ", "#include"
    ]

    if keywords.contains(where: { lowercased.hasPrefix($0) || lowercased.contains(" \($0)") }) {
      return true
    }

    let syntaxMarkers = ["{", "}", ";", "=>", "->", "</", "/>", "==", "!=", "&&", "||"]
    return syntaxMarkers.contains { line.contains($0) }
  }

  public static func isScreenshotFile(_ url: URL) -> Bool {
    let filename = url.deletingPathExtension().lastPathComponent.lowercased()
    let screenshotMarkers = [
      "screen shot",
      "screenshot",
      "ekran resmi",
      "screen capture",
      "screencapture"
    ]

    return isImageFile(url) && screenshotMarkers.contains { filename.contains($0) }
  }

  static func isImageFile(_ url: URL) -> Bool {
    let imageExtensions: Set<String> = [
      "png",
      "jpg",
      "jpeg",
      "heic",
      "heif",
      "tif",
      "tiff",
      "gif",
      "webp",
      "bmp"
    ]

    return imageExtensions.contains(url.pathExtension.lowercased())
  }

  private func containsSecretMarker(_ value: String) -> Bool {
    let lowercased = value.lowercased()
    let secretTerms = ["password", "passwd", "token", "secret", "api_key", "apikey", "bearer ", "otp"]

    if secretTerms.contains(where: { lowercased.contains($0) }) {
      return true
    }

    if lowercased.hasPrefix("sk-") || lowercased.hasPrefix("ghp_") || lowercased.hasPrefix("xoxb-") {
      return true
    }

    return false
  }

  private func isLikelyOpaqueSecret(_ value: String) -> Bool {
    guard value.count >= 12, !value.contains(where: \.isWhitespace) else {
      return false
    }

    var hasLowercase = false
    var hasUppercase = false
    var hasDigit = false
    var hasSymbol = false

    for scalar in value.unicodeScalars {
      if CharacterSet.lowercaseLetters.contains(scalar) {
        hasLowercase = true
      } else if CharacterSet.uppercaseLetters.contains(scalar) {
        hasUppercase = true
      } else if CharacterSet.decimalDigits.contains(scalar) {
        hasDigit = true
      } else {
        hasSymbol = true
      }
    }

    let categoryCount = [hasLowercase, hasUppercase, hasDigit, hasSymbol].filter { $0 }.count
    return categoryCount >= 3
  }
}
