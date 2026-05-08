import Foundation
import ServiceManagement

enum LaunchAtLoginService {
  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  static func setEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      assertionFailure("Launch at login update failed: \(error.localizedDescription)")
    }
  }
}
