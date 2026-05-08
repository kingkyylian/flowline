import AppKit
import ApplicationServices

enum WindowTitleReader {
  static func title(for app: NSRunningApplication) -> String? {
    guard let bundleIdentifier = app.bundleIdentifier else {
      return nil
    }

    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
      return nil
    }

    return windows.first { window in
      window[kCGWindowOwnerName as String] as? String == app.localizedName ||
        window[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier ||
        window[kCGWindowOwnerName as String] as? String == bundleIdentifier
    }?[kCGWindowName as String] as? String
  }
}
