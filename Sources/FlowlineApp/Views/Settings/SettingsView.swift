import FlowlineCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject var state: AppState
  @State private var selectedCategory: SettingsCategory = .permissions

  var body: some View {
    HStack(spacing: 0) {
      SettingsSidebar(selection: $selectedCategory)

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text(selectedCategory.title)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(SettingsTheme.primaryText)
            .textCase(.uppercase)

          detailContent
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
    }
    .background(SettingsTheme.background)
  }

  @ViewBuilder
  private var detailContent: some View {
    switch selectedCategory {
    case .permissions:
      permissionsContent
    case .modules:
      modulesContent
    case .behavior:
      behaviorContent
    }
  }

  private var permissionsContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      PermissionHealthHeader(
        title: permissionHealthTitle,
        subtitle: "Required access for the notch layer"
      )

      SettingsBlock(title: "Privacy") {
        PermissionRow(
          title: "Accessibility",
          requirement: "Required",
          status: state.snapshot.permissions.accessibility,
          deniedLabel: "Needs access",
          actionTitle: "Open Settings",
          action: state.requestAccessibilityPermission
        )

        if state.calendarModuleEnabled {
          SettingsDivider()

          PermissionRow(
            title: "Calendar",
            requirement: "Optional",
            status: state.snapshot.permissions.calendar,
            actionTitle: "Allow",
            action: state.requestCalendarPermission
          )
        }
      }
    }
  }

  private var modulesContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      SettingsBlock(title: "Overlay modules") {
        ModuleStatusRow(
          title: "Context",
          detail: "Active app and developer state",
          value: "Core"
        )

        SettingsDivider()

        ModuleToggleRow(
          title: "Music",
          detail: "Now playing and media keys",
          isOn: $state.musicModuleEnabled
        )

        SettingsDivider()

        ModuleToggleRow(
          title: "Calendar",
          detail: "Next event and meeting actions",
          isOn: $state.calendarModuleEnabled
        )

        SettingsDivider()

        ModuleToggleRow(
          title: "Shelf",
          detail: "Session items and dropped files",
          isOn: $state.shelfModuleEnabled
        )
      }
    }
  }

  private var behaviorContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      SettingsBlock(title: "Behavior") {
        SettingsRow(title: "Launch at login") {
          SquareToggle(isOn: $state.launchAtLogin)
        }

        SettingsDivider()

        SettingsRow(title: "Show over fullscreen") {
          SquareToggle(isOn: $state.showOverFullscreen)
        }

        SettingsDivider()

        SettingsRow(title: "Expand") {
          Keycap("Option Space")
        }
      }
    }
  }

  private var permissionHealthTitle: String {
    state.snapshot.permissions.accessibility == .granted ? "All required permissions active" : "1 permission needed"
  }

}

private enum SettingsCategory: String, CaseIterable, Identifiable {
  case permissions
  case modules
  case behavior

  var id: String { rawValue }

  var title: String {
    switch self {
    case .permissions:
      return "Permissions"
    case .modules:
      return "Modules"
    case .behavior:
      return "Behavior"
    }
  }

  var symbol: String {
    switch self {
    case .permissions:
      return "hand.raised"
    case .modules:
      return "square.grid.2x2"
    case .behavior:
      return "switch.2"
    }
  }
}

private enum SettingsTheme {
  static let background = Color(red: 0.025, green: 0.025, blue: 0.026)
  static let sidebar = Color.black.opacity(0.28)
  static let line = Color.white.opacity(0.11)
  static let primaryText = Color.white.opacity(0.94)
  static let secondaryText = Color.white.opacity(0.58)
  static let tertiaryText = Color.white.opacity(0.36)
  static let accent = Color.white.opacity(0.82)
  static let danger = Color(red: 1.0, green: 0.26, blue: 0.30)
  static let success = Color(red: 0.43, green: 0.86, blue: 0.50)
  static let monoLabel = Font.system(size: 11, weight: .semibold, design: .monospaced)
  static let monoValue = Font.system(size: 12, weight: .semibold, design: .monospaced)
}

private struct SettingsSidebar: View {
  @Binding var selection: SettingsCategory

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 2) {
        Text("FLOWLINE")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(SettingsTheme.primaryText)

        Text("SETTINGS")
          .font(SettingsTheme.monoLabel)
          .foregroundStyle(SettingsTheme.secondaryText)
      }
      .padding(.horizontal, 18)
      .padding(.top, 22)

      VStack(spacing: 4) {
        ForEach(SettingsCategory.allCases) { category in
          Button {
            selection = category
          } label: {
            HStack(spacing: 10) {
              Image(systemName: category.symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)

              Text(category.title.uppercased())
                .font(SettingsTheme.monoLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

              Spacer(minLength: 0)
            }
            .foregroundStyle(selection == category ? SettingsTheme.primaryText : SettingsTheme.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
              Rectangle()
                .fill(selection == category ? SettingsTheme.accent : Color.clear)
                .frame(width: 2)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 10)

      Spacer()
    }
    .frame(width: 166)
    .background(SettingsTheme.sidebar)
  }
}

private struct SettingsBlock<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(SettingsTheme.monoLabel)
        .foregroundStyle(SettingsTheme.secondaryText)

      VStack(spacing: 0) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct PermissionHealthHeader: View {
  let title: String
  let subtitle: String

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(title.hasPrefix("1") ? SettingsTheme.danger : SettingsTheme.success)
        .frame(width: 9, height: 9)

      VStack(alignment: .leading, spacing: 2) {
        Text(title.uppercased())
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(SettingsTheme.primaryText)

        Text(subtitle.uppercased())
          .font(SettingsTheme.monoLabel)
          .foregroundStyle(SettingsTheme.tertiaryText)
      }

      Spacer()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct SettingsRow<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    HStack(spacing: 12) {
      Text(title.uppercased())
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(SettingsTheme.primaryText)
        .lineLimit(1)

      Spacer(minLength: 10)

      content
    }
    .frame(minHeight: 48)
    .padding(.horizontal, 12)
  }
}

private struct SettingsDivider: View {
  var body: some View {
    EmptyView()
  }
}

private struct ModuleStatusRow: View {
  let title: String
  let detail: String
  let value: String

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title.uppercased())
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(SettingsTheme.primaryText)
          .lineLimit(1)

        Text(detail.uppercased())
          .font(SettingsTheme.monoLabel)
          .foregroundStyle(SettingsTheme.tertiaryText)
          .lineLimit(1)
      }

      Spacer(minLength: 12)

      Text(value.uppercased())
        .font(SettingsTheme.monoValue)
        .foregroundStyle(SettingsTheme.secondaryText)
        .lineLimit(1)
    }
    .frame(minHeight: 54)
    .padding(.horizontal, 12)
  }
}

private struct ModuleToggleRow: View {
  let title: String
  let detail: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title.uppercased())
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(SettingsTheme.primaryText)
          .lineLimit(1)

        Text(detail.uppercased())
          .font(SettingsTheme.monoLabel)
          .foregroundStyle(SettingsTheme.tertiaryText)
          .lineLimit(1)
      }

      Spacer(minLength: 12)

      SquareToggle(isOn: $isOn)
    }
    .frame(minHeight: 54)
    .padding(.horizontal, 12)
  }
}

private struct PermissionRow: View {
  let title: String
  let requirement: String
  let status: PermissionAccess
  var deniedLabel = "Disabled"
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    SettingsRow(title: title) {
      HStack(spacing: 10) {
        Text(requirement.uppercased())
          .font(SettingsTheme.monoValue)
          .foregroundStyle(SettingsTheme.tertiaryText)

        HStack(spacing: 7) {
          Image(systemName: systemImage)
            .font(.system(size: 13, weight: .bold))

          Text(label.uppercased())
            .font(SettingsTheme.monoValue)
        }
        .foregroundStyle(foreground)

        if status != .granted {
          Button(actionTitle.uppercased(), action: action)
            .buttonStyle(OutlineButtonStyle())
            .help("Open macOS permission prompt for \(title)")
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var label: String {
    switch status {
    case .granted:
      return "Granted"
    case .denied:
      return deniedLabel
    case .notDetermined:
      return "Not asked"
    }
  }

  private var systemImage: String {
    switch status {
    case .granted:
      return "checkmark.circle.fill"
    case .denied:
      return "xmark.circle.fill"
    case .notDetermined:
      return "circle.dashed"
    }
  }

  private var foreground: Color {
    switch status {
    case .granted:
      return SettingsTheme.success
    case .denied:
      return SettingsTheme.danger
    case .notDetermined:
      return SettingsTheme.secondaryText
    }
  }
}

private struct SquareToggle: View {
  @Binding var isOn: Bool

  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .fill(isOn ? SettingsTheme.accent : Color.white.opacity(0.18))
          .frame(width: 24, height: 24)

        if isOn {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.black)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Toggle")
    .accessibilityValue(isOn ? "On" : "Off")
  }
}

private struct Keycap: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text.uppercased())
      .font(SettingsTheme.monoValue)
      .foregroundStyle(SettingsTheme.secondaryText)
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(Color.black.opacity(0.20))
      .overlay {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .stroke(SettingsTheme.line, lineWidth: 1)
      }
      .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
  }
}

private struct OutlineButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(SettingsTheme.monoValue)
      .foregroundStyle(SettingsTheme.primaryText)
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(configuration.isPressed ? SettingsTheme.accent.opacity(0.18) : Color.white.opacity(0.07))
      .overlay {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .stroke(SettingsTheme.line, lineWidth: 1)
      }
      .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
  }
}
