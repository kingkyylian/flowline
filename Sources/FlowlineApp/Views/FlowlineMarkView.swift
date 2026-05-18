import SwiftUI

enum FlowlineMarkMetrics {
  static let menuBarSize: CGFloat = 18
  static let collapsedSize: CGFloat = 13
  static let strokeWidth: CGFloat = 2.4
  static let armOuterXRatio: CGFloat = 0.27
  static let leftJointXRatio: CGFloat = 0.47
  static let rightJointXRatio: CGFloat = 0.53
  static let armTopYRatio: CGFloat = 0.28
  static let armJointYRatio: CGFloat = 0.50
  static let stemStartYRatio: CGFloat = 0.58
  static let stemEndYRatio: CGFloat = 0.80
}

struct FlowlineMarkView: View {
  var size = FlowlineMarkMetrics.menuBarSize
  var opacity = 0.78

  var body: some View {
    FlowlineMarkBrokenYPath()
      .stroke(style: StrokeStyle(
        lineWidth: FlowlineMarkMetrics.strokeWidth,
        lineCap: .round,
        lineJoin: .round
      ))
    .frame(width: size, height: size)
    .opacity(opacity)
  }
}

private struct FlowlineMarkBrokenYPath: Shape {
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
    path.move(to: p(FlowlineMarkMetrics.armOuterXRatio, FlowlineMarkMetrics.armTopYRatio))
    path.addLine(to: p(FlowlineMarkMetrics.leftJointXRatio, FlowlineMarkMetrics.armJointYRatio))
    path.move(to: p(1 - FlowlineMarkMetrics.armOuterXRatio, FlowlineMarkMetrics.armTopYRatio))
    path.addLine(to: p(FlowlineMarkMetrics.rightJointXRatio, FlowlineMarkMetrics.armJointYRatio))
    path.move(to: p(0.50, FlowlineMarkMetrics.stemStartYRatio))
    path.addLine(to: p(0.50, FlowlineMarkMetrics.stemEndYRatio))
    return path
  }
}
