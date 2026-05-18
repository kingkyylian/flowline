import AppKit
import ApplicationServices

enum WindowTitleReader {
  static func title(for app: NSRunningApplication) -> String? {
    title(forProcessIdentifier: app.processIdentifier)
  }

  static func title(forProcessIdentifier processIdentifier: pid_t) -> String? {
    let applicationElement = AXUIElementCreateApplication(processIdentifier)
    return title(fromApplicationElement: applicationElement)
  }

  private static func title(fromApplicationElement applicationElement: AXUIElement) -> String? {
    guard let focusedWindow = focusedWindow(from: applicationElement) else {
      return nil
    }

    return stringAttribute(kAXTitleAttribute, from: focusedWindow)
  }

  private static func focusedWindow(from applicationElement: AXUIElement) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
      applicationElement,
      kAXFocusedWindowAttribute as CFString,
      &value
    ) == .success,
      let value,
      CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }

    return (value as! AXUIElement)
  }

  private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }

    return value as? String
  }
}
