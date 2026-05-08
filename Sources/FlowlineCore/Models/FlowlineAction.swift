import Foundation

public struct FlowlineAction: Identifiable, Equatable, Sendable {
  public enum Kind: String, Sendable {
    case open
    case joinMeeting
    case revealFile
    case clearShelf
    case requestPermission
  }

  public var id: String
  public var title: String
  public var systemImage: String
  public var kind: Kind
  public var url: URL?

  public init(id: String, title: String, systemImage: String, kind: Kind, url: URL? = nil) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.kind = kind
    self.url = url
  }
}
