import AppKit
import ApplicationServices
import FlowlineCore

enum PermissionService {
  static var accessibilityStatus: PermissionAccess {
    AXIsProcessTrusted() ? .granted : .denied
  }

  static func requestAccessibilityPermission() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)

    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }
}
