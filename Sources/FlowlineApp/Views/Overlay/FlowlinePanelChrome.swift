import SwiftUI

struct PanelHeader: View {
  let title: String
  let systemImage: String
  let positionMode: PositionMode

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: systemImage)
        .font(.system(size: 10, weight: .medium))
      Text(title)
        .font(FlowlineDesign.Typography.header)
    }
    .foregroundStyle(FlowlineDesign.secondary(for: positionMode))
    .accessibilityElement(children: .combine)
  }
}

private struct FlowlinePanelStyle: ViewModifier {
  let positionMode: PositionMode

  func body(content: Content) -> some View {
    content
      .background(FlowlineDesign.panelFill(for: positionMode))
      .overlay {
        Rectangle()
          .fill(FlowlineDesign.panelScrim(for: positionMode))
      }
      .overlay {
        Rectangle()
          .stroke(FlowlineDesign.separator(for: positionMode), lineWidth: 1)
      }
  }
}

extension View {
  func flowlinePanel(positionMode: PositionMode) -> some View {
    modifier(FlowlinePanelStyle(positionMode: positionMode))
  }
}
