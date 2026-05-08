import Testing
import Foundation
@testable import FlowlineCore

@Test func extractsFirstMeetingURLFromText() throws {
  let text = "Sprint sync: https://meet.google.com/abc-defg-hij then notes https://example.com"

  let url = URLDetectors.firstMeetingURL(in: text)

  #expect(url?.absoluteString == "https://meet.google.com/abc-defg-hij")
}

@Test func detectsZoomTeamsAndGoogleMeetHosts() throws {
  let samples = [
    "Join https://kyylian.zoom.us/j/123456789",
    "Call https://teams.microsoft.com/l/meetup-join/abc",
    "Meet https://meet.google.com/aaa-bbbb-ccc"
  ]

  let urls = samples.compactMap(URLDetectors.firstMeetingURL)

  #expect(urls.count == 3)
}

@Test func ignoresNonMeetingURLs() throws {
  let text = "Open https://github.com/kyylian/flowline"

  let url = URLDetectors.firstMeetingURL(in: text)

  #expect(url == nil)
}
