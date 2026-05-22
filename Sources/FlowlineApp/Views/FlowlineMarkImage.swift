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
      FlowlineMarkMetrics.startXRatio,
      FlowlineMarkMetrics.startYRatio,
      size: size
    ))
    path.curve(
      to: pointFromTop(
        FlowlineMarkMetrics.centerXRatio,
        FlowlineMarkMetrics.centerYRatio,
        size: size
      ),
      controlPoint1: pointFromTop(
        FlowlineMarkMetrics.firstControlXRatio,
        FlowlineMarkMetrics.firstControlYRatio,
        size: size
      ),
      controlPoint2: pointFromTop(
        FlowlineMarkMetrics.secondControlXRatio,
        FlowlineMarkMetrics.secondControlYRatio,
        size: size
      )
    )
    path.curve(
      to: pointFromTop(
        FlowlineMarkMetrics.endXRatio,
        FlowlineMarkMetrics.endYRatio,
        size: size
      ),
      controlPoint1: pointFromTop(
        FlowlineMarkMetrics.thirdControlXRatio,
        FlowlineMarkMetrics.thirdControlYRatio,
        size: size
      ),
      controlPoint2: pointFromTop(
        FlowlineMarkMetrics.fourthControlXRatio,
        FlowlineMarkMetrics.fourthControlYRatio,
        size: size
      )
    )
    path.stroke()

    image.unlockFocus()
    image.isTemplate = true
    return image
  }

  private static func pointFromTop(_ x: CGFloat, _ y: CGFloat, size: NSSize) -> NSPoint {
    NSPoint(x: x * size.width, y: (1 - y) * size.height)
  }
}
