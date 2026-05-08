import Foundation

public enum URLDetectors {
  private static let meetingHosts = [
    "zoom.us",
    "meet.google.com",
    "teams.microsoft.com"
  ]
  private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

  public static func firstMeetingURL(in text: String) -> URL? {
    guard let detector = linkDetector else {
      return nil
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = detector.matches(in: text, options: [], range: range)

    return matches
      .compactMap(\.url)
      .first { isMeetingURL($0) }
  }

  public static func isMeetingURL(_ url: URL) -> Bool {
    guard let host = url.host()?.lowercased() else {
      return false
    }

    return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
  }
}
