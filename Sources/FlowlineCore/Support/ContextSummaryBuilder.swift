import Foundation

public enum ContextSummaryBuilder {
  public static func build(snapshot: ContextSnapshot, aiUsage: AIUsageSnapshot?) -> String {
    var lines = [
      "App: \(snapshot.activeApp.name)",
      "Window: \(snapshot.primaryTitle)"
    ]

    if let git = snapshot.git {
      lines.append("Git: \(git.branch) \(git.isDirty ? "dirty" : "clean")")
    }

    if let aiUsage {
      for usage in aiUsage.providers {
        let windows = [usage.primary, usage.secondary]
          .compactMap { window -> String? in
            guard let window, let percent = window.percentLeft else {
              return nil
            }

            return "\(window.label) \(percent)% left"
          }
          .joined(separator: ", ")

        if !windows.isEmpty {
          lines.append("\(usage.provider.displayName): \(windows)")
        }
      }
    }

    if !snapshot.shelfItems.isEmpty {
      lines.append("Hold: \(snapshot.shelfItems.map(\.title).joined(separator: ", "))")
    }

    return lines.joined(separator: "\n")
  }
}
