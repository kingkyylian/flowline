import Foundation

public struct GitStatus: Equatable, Sendable {
  public var branch: String
  public var isDirty: Bool

  public init(branch: String, isDirty: Bool) {
    self.branch = branch
    self.isDirty = isDirty
  }
}
