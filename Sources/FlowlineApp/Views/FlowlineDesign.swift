import SwiftUI

enum FlowlineDesign {
  enum Metrics {
    static let panelSpacing: CGFloat = 10
    static let panelPadding: CGFloat = 12
    static let iconButtonSize: CGFloat = 26
    static let shelfRowHeight: CGFloat = 24
    static let notchColumnPadding: CGFloat = 10
  }

  enum Typography {
    static let header = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let title = Font.system(size: 17, weight: .semibold, design: .monospaced)
    static let subtitle = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let metadata = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let notchTitle = Font.system(size: 15, weight: .semibold, design: .monospaced)
    static let notchMetric = Font.system(size: 21, weight: .semibold, design: .monospaced)
  }

  static func foreground(for mode: PositionMode) -> Color {
    mode == .notch ? .white : .primary
  }

  static func secondary(for mode: PositionMode) -> Color {
    mode == .notch ? Color.white.opacity(0.62) : .secondary
  }

  static func tertiary(for mode: PositionMode) -> Color {
    mode == .notch ? Color.white.opacity(0.38) : Color.secondary.opacity(0.72)
  }

  static func panelFill(for mode: PositionMode) -> Material {
    mode == .notch ? .thinMaterial : .thinMaterial
  }

  static func panelScrim(for mode: PositionMode) -> Color {
    mode == .notch ? Color.black.opacity(0.86) : Color.white.opacity(0.36)
  }

  static func separator(for mode: PositionMode) -> Color {
    (mode == .notch ? Color.white : Color.primary).opacity(mode == .notch ? 0.075 : 0.16)
  }

  static func warning(for mode: PositionMode) -> Color {
    mode == .notch ? Color(red: 1.0, green: 0.83, blue: 0.18) : Color(nsColor: .systemOrange)
  }

  static func success(for mode: PositionMode) -> Color {
    mode == .notch ? Color(red: 0.58, green: 0.94, blue: 0.62) : Color(nsColor: .systemGreen)
  }

  static func iconButtonBackground(for mode: PositionMode) -> Color {
    mode == .notch ? Color.clear : Color.primary.opacity(0.055)
  }

  static func notchModuleFill() -> Color {
    Color.black
  }
}
