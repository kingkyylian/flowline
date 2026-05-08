import Foundation

public struct ShelfStore: Sendable {
  public private(set) var items: [ShelfItem]
  private let limit: Int

  public init(limit: Int = 10, items: [ShelfItem] = []) {
    self.limit = limit
    self.items = Array(items.prefix(limit))
  }

  public mutating func addText(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }

    let url = URL(string: trimmed)
    add(
      ShelfItem(
        kind: url == nil ? .text : .link,
        title: title(for: trimmed, url: url),
        value: trimmed,
        url: url
      )
    )
  }

  public mutating func addFile(_ url: URL) {
    add(
      ShelfItem(
        kind: .file,
        title: url.lastPathComponent,
        value: url.path,
        url: url
      )
    )
  }

  public mutating func remove(id: ShelfItem.ID) {
    items.removeAll { $0.id == id }
  }

  public mutating func clear() {
    items.removeAll()
  }

  private mutating func add(_ item: ShelfItem) {
    items.removeAll { $0.kind == item.kind && $0.value == item.value }
    items.insert(item, at: 0)

    if items.count > limit {
      items.removeSubrange(limit..<items.count)
    }
  }

  private func title(for value: String, url: URL?) -> String {
    if let host = url?.host(), !host.isEmpty {
      return host
    }

    return String(value.prefix(80))
  }
}
