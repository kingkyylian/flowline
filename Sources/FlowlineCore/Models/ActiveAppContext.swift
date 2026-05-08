import Foundation

public struct ActiveAppContext: Equatable, Sendable {
  public var name: String
  public var bundleIdentifier: String?
  public var windowTitle: String?

  public init(name: String, bundleIdentifier: String?, windowTitle: String?) {
    self.name = name
    self.bundleIdentifier = bundleIdentifier
    self.windowTitle = windowTitle
  }

  public var isDeveloperApp: Bool {
    guard let bundleIdentifier else {
      return false
    }

    return [
      "com.microsoft.VSCode",
      "com.apple.dt.Xcode",
      "com.apple.Terminal",
      "com.googlecode.iterm2",
      "com.mitchellh.ghostty",
      "com.todesktop.230313mzl4w4u92",
      "dev.warp.Warp-Stable"
    ].contains(bundleIdentifier)
  }
}
