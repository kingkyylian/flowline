import Foundation

public struct FlowlineModulePreferences: Equatable, Sendable {
  public var context: Bool
  public var music: Bool
  public var calendar: Bool
  public var shelf: Bool

  public init(context: Bool, music: Bool, calendar: Bool, shelf: Bool) {
    self.context = context
    self.music = music
    self.calendar = calendar
    self.shelf = shelf
  }

  public static let defaults = FlowlineModulePreferences(
    context: false,
    music: true,
    calendar: false,
    shelf: true
  )
}
