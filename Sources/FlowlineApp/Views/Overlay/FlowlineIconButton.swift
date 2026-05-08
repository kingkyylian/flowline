import SwiftUI

struct FlowlineIconButton: View {
  let title: String
  let systemImage: String
  let positionMode: PositionMode
  var role: ButtonRole?
  let action: () -> Void

  var body: some View {
    Button(role: role, action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .medium))
        .frame(width: FlowlineDesign.Metrics.iconButtonSize, height: FlowlineDesign.Metrics.iconButtonSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(foreground)
    .background(FlowlineDesign.iconButtonBackground(for: positionMode))
    .overlay {
      Rectangle()
        .stroke(FlowlineDesign.separator(for: positionMode), lineWidth: 1)
    }
    .help(title)
    .accessibilityLabel(title)
  }

  private var foreground: Color {
    role == .destructive ? Color(nsColor: .systemRed) : FlowlineDesign.foreground(for: positionMode)
  }
}
