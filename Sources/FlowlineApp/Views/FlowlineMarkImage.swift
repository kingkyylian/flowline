import AppKit

enum FlowlineMarkImage {
  static var menuBarIcon: NSImage {
    let size = NSSize(
      width: FlowlineMarkMetrics.menuBarSize,
      height: FlowlineMarkMetrics.menuBarSize
    )
    let image = NSImage(size: size)
    image.lockFocus()

    NSColor.black.setStroke()

    let path = NSBezierPath()
    path.lineWidth = FlowlineMarkMetrics.strokeWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: pointFromTop(
      FlowlineMarkMetrics.armOuterXRatio,
      FlowlineMarkMetrics.armTopYRatio,
      size: size
    ))
    path.line(to: pointFromTop(
      FlowlineMarkMetrics.leftJointXRatio,
      FlowlineMarkMetrics.armJointYRatio,
      size: size
    ))
    path.move(to: pointFromTop(
      1 - FlowlineMarkMetrics.armOuterXRatio,
      FlowlineMarkMetrics.armTopYRatio,
      size: size
    ))
    path.line(to: pointFromTop(
      FlowlineMarkMetrics.rightJointXRatio,
      FlowlineMarkMetrics.armJointYRatio,
      size: size
    ))
    path.move(to: pointFromTop(
      0.50,
      FlowlineMarkMetrics.stemStartYRatio,
      size: size
    ))
    path.line(to: pointFromTop(
      0.50,
      FlowlineMarkMetrics.stemEndYRatio,
      size: size
    ))
    path.stroke()

    image.unlockFocus()
    image.isTemplate = true
    return image
  }

  private static func pointFromTop(_ x: CGFloat, _ y: CGFloat, size: NSSize) -> NSPoint {
    NSPoint(x: x * size.width, y: (1 - y) * size.height)
  }
}
