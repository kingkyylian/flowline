import SwiftUI

enum FlowlineMarkMetrics {
  static let menuBarSize: CGFloat = 18
  static let collapsedSize: CGFloat = 13
  static let strokeWidth: CGFloat = 2.25
  static let startXRatio: CGFloat = 0.18
  static let startYRatio: CGFloat = 0.58
  static let firstControlXRatio: CGFloat = 0.29
  static let firstControlYRatio: CGFloat = 0.26
  static let secondControlXRatio: CGFloat = 0.42
  static let secondControlYRatio: CGFloat = 0.27
  static let centerXRatio: CGFloat = 0.50
  static let centerYRatio: CGFloat = 0.48
  static let thirdControlXRatio: CGFloat = 0.58
  static let thirdControlYRatio: CGFloat = 0.69
  static let fourthControlXRatio: CGFloat = 0.72
  static let fourthControlYRatio: CGFloat = 0.66
  static let endXRatio: CGFloat = 0.82
  static let endYRatio: CGFloat = 0.42
}

struct FlowlineMarkView: View {
  var size = FlowlineMarkMetrics.menuBarSize
  var opacity = 0.78

  var body: some View {
    FlowlineMarkRibbonPath()
      .stroke(style: StrokeStyle(
        lineWidth: FlowlineMarkMetrics.strokeWidth,
        lineCap: .round,
        lineJoin: .round
      ))
    .frame(width: size, height: size)
    .opacity(opacity)
  }
}

private struct FlowlineMarkRibbonPath: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height)
    let origin = CGPoint(
      x: rect.midX - scale / 2,
      y: rect.midY - scale / 2
    )

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }

    var path = Path()
    path.move(to: p(FlowlineMarkMetrics.startXRatio, FlowlineMarkMetrics.startYRatio))
    path.addCurve(
      to: p(FlowlineMarkMetrics.centerXRatio, FlowlineMarkMetrics.centerYRatio),
      control1: p(FlowlineMarkMetrics.firstControlXRatio, FlowlineMarkMetrics.firstControlYRatio),
      control2: p(FlowlineMarkMetrics.secondControlXRatio, FlowlineMarkMetrics.secondControlYRatio)
    )
    path.addCurve(
      to: p(FlowlineMarkMetrics.endXRatio, FlowlineMarkMetrics.endYRatio),
      control1: p(FlowlineMarkMetrics.thirdControlXRatio, FlowlineMarkMetrics.thirdControlYRatio),
      control2: p(FlowlineMarkMetrics.fourthControlXRatio, FlowlineMarkMetrics.fourthControlYRatio)
    )
    return path
  }
}
