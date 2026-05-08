import Foundation

public struct ShelfItem: Identifiable, Equatable, Sendable {
  public enum Kind: String, Sendable {
    case text
    case link
    case file
  }

  public var id: UUID
  public var kind: Kind
  public var title: String
  public var value: String
  public var url: URL?
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    kind: Kind,
    title: String,
    value: String,
    url: URL?,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.value = value
    self.url = url
    self.createdAt = createdAt
  }
}
