import FlowlineCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject var state: AppState
  @State private var selectedCategory: SettingsPanelCategory = .general

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
    case .general:
      generalContent
    case .hold:
      holdContent
    case .modules:
      modulesContent
    case .shortcuts:
      shortcutsContent
    case .about:
      aboutContent
    }
  }

  private var generalContent: some View {
    let items = permissionItems
    let permissionHealth = SettingsPresentation.permissionHealth(for: items)

    return VStack(alignment: .leading, spacing: 14) {
      PermissionHealthHeader(
        title: permissionHealth.title,
        subtitle: permissionHealth.subtitle,
        isReady: permissionHealth.isReady
      )

      SettingsBlock(title: "Privacy") {
        ForEach(items, id: \.title) { item in
          PermissionRow(
            item: item,
            action: permissionAction(for: item.action)
          )
        }
      }

      SettingsBlock(title: "Behavior") {
        SettingsRow(title: "Launch at login") {
          SquareToggle(isOn: $state.launchAtLogin)
        }

        SettingsDivider()

        SettingsRow(title: "Show over fullscreen") {
          SquareToggle(isOn: $state.showOverFullscreen)
        }
      }
    }
  }

  private var holdContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      SettingsBlock(title: "Hold capture") {
        SettingsRow(title: "Screenshots") {
          SquareToggle(isOn: $state.holdAutoCaptureScreenshots)
        }

        SettingsDivider()

        SettingsRow(title: "Clipboard text") {
          SquareToggle(isOn: $state.holdAutoCaptureClipboardText)
        }
      }
    }
  }

  private var modulesContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      SettingsBlock(title: "Layout preview \(state.overlayModuleCountLabel)") {
        SettingsLayoutPreview(items: SettingsPresentation.modulePreviewItems(for: modulePreferences))
      }

      ForEach(SettingsPresentation.moduleLayerSections()) { section in
        SettingsBlock(title: section.title) {
          ForEach(section.items) { item in
            ModuleToggleRow(
              title: item.title,
              detail: item.detail,
              status: state.moduleStatusLabel(for: item.module),
              isDisabled: moduleToggleIsDisabled(item.module),
              isOn: moduleBinding(item.module)
            )

            if item.id != section.items.last?.id {
              SettingsDivider()
            }
          }
        }
      }
    }
  }

  private var shortcutsContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      SettingsBlock(title: "Keyboard") {
        SettingsRow(title: "Expand") {
          Keycap("Option Space")
        }
      }
    }
  }

  private var aboutContent: some View {
    let info = SettingsPresentation.currentAboutInfo()

    return VStack(alignment: .leading, spacing: 14) {
      SettingsBlock(title: info.appName) {
        ModuleStatusRow(
          title: "Version",
          detail: "Release build",
          value: info.versionLabel
        )

        SettingsDivider()

        ModuleStatusRow(
          title: "Bundle ID",
          detail: "Application identifier",
          value: info.bundleIdentifier
        )

        SettingsDivider()

        ModuleStatusRow(
          title: "License",
          detail: "Open source",
          value: info.licenseName
        )

        SettingsDivider()

        ModuleStatusRow(
          title: "Updates",
          detail: "GitHub releases",
          value: info.updateModeLabel
        )
      }

      SettingsBlock(title: "Project") {
        AboutLinkRow(
          title: "GitHub",
          detail: "Source",
          url: info.githubURL,
          open: state.open
        )

        SettingsDivider()

        AboutLinkRow(
          title: "Releases",
          detail: "Downloads",
          url: info.releasesURL,
          open: state.open
        )

        SettingsDivider()

        AboutLinkRow(
          title: "License",
          detail: info.licenseName,
          url: info.licenseURL,
          open: state.open
        )
      }
    }
  }

  private var permissionItems: [SettingsPermissionItem] {
    SettingsPresentation.permissionItems(
      accessibility: state.snapshot.permissions.accessibility,
      calendar: state.snapshot.permissions.calendar,
      preferences: modulePreferences,
      holdAutoCaptureScreenshots: state.holdAutoCaptureScreenshots
    )
  }

  private var modulePreferences: FlowlineModulePreferences {
    FlowlineModulePreferences(
      context: state.workspaceModuleEnabled,
      music: state.musicModuleEnabled,
      calendar: state.calendarModuleEnabled,
      shelf: state.shelfModuleEnabled
    )
  }

  private func moduleBinding(_ module: FlowlineModule) -> Binding<Bool> {
    Binding(
      get: { state.isModuleEnabled(module) },
      set: { state.setModule(module, enabled: $0) }
    )
  }

  private func moduleToggleIsDisabled(_ module: FlowlineModule) -> Bool {
    !state.isModuleEnabled(module) && !state.canEnableModule(module)
  }

  private func permissionAction(for action: SettingsPermissionAction?) -> (() -> Void)? {
    switch action {
    case .requestAccessibility:
      return state.requestAccessibilityPermission
    case .requestCalendar:
      return state.requestCalendarPermission
    case nil:
      return nil
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
  @Binding var selection: SettingsPanelCategory

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
        ForEach(SettingsPanelCategory.allCases) { category in
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
  let isReady: Bool

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(isReady ? SettingsTheme.success : SettingsTheme.danger)
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
        .minimumScaleFactor(0.72)
    }
    .frame(minHeight: 54)
    .padding(.horizontal, 12)
  }
}

private struct AboutLinkRow: View {
  let title: String
  let detail: String
  let url: URL
  let open: (URL) -> Void

  var body: some View {
    SettingsRow(title: title) {
      HStack(spacing: 10) {
        Text(detail.uppercased())
          .font(SettingsTheme.monoValue)
          .foregroundStyle(SettingsTheme.tertiaryText)
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        Button("OPEN") {
          open(url)
        }
        .buttonStyle(OutlineButtonStyle())
        .help(url.absoluteString)
      }
    }
  }
}

private struct ModuleToggleRow: View {
  let title: String
  let detail: String
  let status: String
  let isDisabled: Bool
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

      Text(status.uppercased())
        .font(SettingsTheme.monoValue)
        .foregroundStyle(isDisabled ? SettingsTheme.tertiaryText : SettingsTheme.secondaryText)
        .frame(width: 40, alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.74)

      SquareToggle(isOn: $isOn, isDisabled: isDisabled)
    }
    .frame(minHeight: 54)
    .padding(.horizontal, 12)
  }
}

private struct PermissionRow: View {
  let item: SettingsPermissionItem
  let action: (() -> Void)?

  var body: some View {
    SettingsRow(title: item.title) {
      HStack(spacing: 10) {
        Text(item.requirement.uppercased())
          .font(SettingsTheme.monoValue)
          .foregroundStyle(SettingsTheme.tertiaryText)

        HStack(spacing: 7) {
          Image(systemName: item.symbol)
            .font(.system(size: 13, weight: .bold))

          Text(item.statusLabel.uppercased())
            .font(SettingsTheme.monoValue)
        }
        .foregroundStyle(foreground)

        if let action, item.tone != .success {
          Button(actionTitle.uppercased(), action: action)
            .buttonStyle(OutlineButtonStyle())
            .help("Open macOS permission prompt for \(item.title)")
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var actionTitle: String {
    guard item.statusLabel == "Not asked" else {
      return "Open"
    }

    switch item.action {
    case .requestCalendar:
      return "Allow"
    case .requestAccessibility, nil:
      return "Open"
    }
  }

  private var foreground: Color {
    switch item.tone {
    case .success:
      return SettingsTheme.success
    case .danger:
      return SettingsTheme.danger
    case .neutral:
      return SettingsTheme.secondaryText
    }
  }
}

private struct SquareToggle: View {
  @Binding var isOn: Bool
  var isDisabled = false

  var body: some View {
    Button {
      guard !isDisabled else {
        return
      }

      isOn.toggle()
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .fill(isOn ? SettingsTheme.accent : Color.white.opacity(isDisabled ? 0.08 : 0.18))
          .frame(width: 24, height: 24)

        if isOn {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.black)
        }
      }
    }
    .buttonStyle(.plain)
    .opacity(isDisabled ? 0.58 : 1)
    .accessibilityLabel("Toggle")
    .accessibilityValue(isDisabled ? "Unavailable" : (isOn ? "On" : "Off"))
  }
}

private struct SettingsLayoutPreview: View {
  let items: [SettingsModulePreviewItem]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(items, id: \.slot) { item in
        SettingsPreviewSlot(item: item)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct SettingsPreviewSlot: View {
  let item: SettingsModulePreviewItem

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: item.symbol)
        .font(.system(size: item.slot == .center ? 15 : 13, weight: .semibold))
        .foregroundStyle(item.isActive ? SettingsTheme.primaryText : SettingsTheme.tertiaryText)

      Text(item.title)
        .font(SettingsTheme.monoLabel)
        .foregroundStyle(item.isActive ? SettingsTheme.secondaryText : SettingsTheme.tertiaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .frame(width: item.slot == .center ? 96 : 78, height: 56)
    .background(Color.white.opacity(item.isActive ? 0.055 : 0.024))
    .overlay {
      RoundedRectangle(cornerRadius: 3, style: .continuous)
        .stroke(
          SettingsTheme.line,
          style: StrokeStyle(lineWidth: 1, dash: item.isActive ? [] : [4, 4])
        )
    }
    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
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
