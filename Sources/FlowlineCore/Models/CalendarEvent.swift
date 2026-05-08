import Foundation

public struct CalendarEvent: Identifiable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var startDate: Date
  public var meetingURL: URL?

  public init(id: String, title: String, startDate: Date, meetingURL: URL?) {
    self.id = id
    self.title = title
    self.startDate = startDate
    self.meetingURL = meetingURL
  }
}
