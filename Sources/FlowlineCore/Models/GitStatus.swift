import Foundation

public struct GitStatus: Equatable, Sendable {
  public var branch: String
  public var isDirty: Bool
  public var repositoryName: String?

  public init(branch: String, isDirty: Bool, repositoryName: String? = nil) {
    self.branch = branch
    self.isDirty = isDirty
    self.repositoryName = repositoryName
  }
}
