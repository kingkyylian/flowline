import Foundation

public enum PermissionAccess: String, Equatable, Sendable {
  case notDetermined
  case granted
  case denied
}

public struct PermissionState: Equatable, Sendable {
  public var accessibility: PermissionAccess
  public var calendar: PermissionAccess

  public init(accessibility: PermissionAccess, calendar: PermissionAccess) {
    self.accessibility = accessibility
    self.calendar = calendar
  }
}
