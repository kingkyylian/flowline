import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Flowline.iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: outputDirectory)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let icons: [(pixels: Int, name: String)] = [
  (16, "icon_16x16.png"),
  (32, "icon_16x16@2x.png"),
  (32, "icon_32x32.png"),
  (64, "icon_32x32@2x.png"),
  (128, "icon_128x128.png"),
  (256, "icon_128x128@2x.png"),
  (256, "icon_256x256.png"),
  (512, "icon_256x256@2x.png"),
  (512, "icon_512x512.png"),
  (1024, "icon_512x512@2x.png")
]

for icon in icons {
  let data = try renderIcon(pixels: icon.pixels)
  try data.write(to: outputDirectory.appendingPathComponent(icon.name), options: .atomic)
}

func renderIcon(pixels: Int) throws -> Data {
  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: [.alphaFirst],
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else {
    throw IconGenerationError.bitmapCreationFailed
  }

  rep.size = NSSize(width: pixels, height: pixels)

  guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    throw IconGenerationError.graphicsContextCreationFailed
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context.shouldAntialias = true
  context.imageInterpolation = .high

  let scale = CGFloat(pixels) / 1024
  drawIcon(scale: scale)

  NSGraphicsContext.restoreGraphicsState()

  guard let data = rep.representation(using: .png, properties: [:]) else {
    throw IconGenerationError.pngEncodingFailed
  }

  return data
}

func drawIcon(scale: CGFloat) {
  func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: x * scale, y: (1024 - y) * scale)
  }

  func rectFromTop(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(
      x: x * scale,
      y: (1024 - y - height) * scale,
      width: width * scale,
      height: height * scale
    )
  }

  NSColor.clear.setFill()
  NSRect(x: 0, y: 0, width: 1024 * scale, height: 1024 * scale).fill()

  let body = NSBezierPath(
    roundedRect: rectFromTop(x: 104, y: 84, width: 816, height: 856),
    xRadius: 196 * scale,
    yRadius: 196 * scale
  )

  NSGraphicsContext.saveGraphicsState()
  let bodyShadow = NSShadow()
  bodyShadow.shadowColor = color(0x000000, alpha: 0.34)
  bodyShadow.shadowOffset = NSSize(width: 0, height: -32 * scale)
  bodyShadow.shadowBlurRadius = 34 * scale
  bodyShadow.set()
  NSGradient(colors: [
    color(0x28333b),
    color(0x10151b),
    color(0x07090d)
  ])?.draw(in: body, angle: -52)
  NSGraphicsContext.restoreGraphicsState()

  body.lineWidth = 9 * scale
  color(0xffffff, alpha: 0.14).setStroke()
  body.stroke()

  let topRail = NSBezierPath(
    roundedRect: rectFromTop(x: 186, y: 164, width: 652, height: 126),
    xRadius: 63 * scale,
    yRadius: 63 * scale
  )
  NSGradient(colors: [
    color(0xffffff, alpha: 0.15),
    color(0x5ee0d1, alpha: 0.06)
  ])?.draw(in: topRail, angle: -90)

  let notch = NSBezierPath(
    roundedRect: rectFromTop(x: 407, y: 192, width: 210, height: 82),
    xRadius: 41 * scale,
    yRadius: 41 * scale
  )
  color(0x05080c, alpha: 0.34).setFill()
  notch.fill()

  NSGraphicsContext.saveGraphicsState()
  let ribbonShadow = NSShadow()
  ribbonShadow.shadowColor = color(0x000000, alpha: 0.46)
  ribbonShadow.shadowOffset = NSSize(width: 0, height: -20 * scale)
  ribbonShadow.shadowBlurRadius = 20 * scale
  ribbonShadow.set()
  drawFlowRibbon(scale: scale, point: p)
  NSGraphicsContext.restoreGraphicsState()

  drawCircle(center: p(238, 598), radius: 22 * scale, color: color(0x8df2e5, alpha: 0.78))
  drawCircle(center: p(512, 500), radius: 27 * scale, color: color(0xf6fbff, alpha: 0.86))
  drawCircle(center: p(792, 410), radius: 22 * scale, color: color(0xf1d39b, alpha: 0.82))
}

func drawFlowRibbon(scale: CGFloat, point p: (CGFloat, CGFloat) -> NSPoint) {
  let glow = flowRibbonPath(point: p)
  drawStroke(glow, width: 136 * scale, color: color(0x4fd9cc, alpha: 0.18))

  let leftAura = flowRibbonLeftPath(point: p)
  drawStroke(leftAura, width: 104 * scale, color: color(0x68e7d9, alpha: 0.26))

  let rightAura = flowRibbonRightPath(point: p)
  drawStroke(rightAura, width: 104 * scale, color: color(0xdcb56c, alpha: 0.22))

  drawStroke(leftAura, width: 82 * scale, color: color(0xcdfaf3))
  drawStroke(rightAura, width: 82 * scale, color: color(0xfff1d2))

  let highlight = flowRibbonPath(point: p)
  drawStroke(highlight, width: 28 * scale, color: color(0xffffff, alpha: 0.40))
}

func flowRibbonPath(point p: (CGFloat, CGFloat) -> NSPoint) -> NSBezierPath {
  let path = flowRibbonLeftPath(point: p)
  path.append(flowRibbonRightPath(point: p))
  return path
}

func flowRibbonLeftPath(point p: (CGFloat, CGFloat) -> NSPoint) -> NSBezierPath {
  let path = NSBezierPath()
  path.move(to: p(238, 598))
  path.curve(
    to: p(512, 500),
    controlPoint1: p(318, 304),
    controlPoint2: p(438, 292)
  )
  return path
}

func flowRibbonRightPath(point p: (CGFloat, CGFloat) -> NSPoint) -> NSBezierPath {
  let path = NSBezierPath()
  path.move(to: p(512, 500))
  path.curve(
    to: p(792, 410),
    controlPoint1: p(592, 710),
    controlPoint2: p(704, 682)
  )
  return path
}

func drawStroke(_ path: NSBezierPath, width: CGFloat, color: NSColor) {
  path.lineWidth = width
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  color.setStroke()
  path.stroke()
}

func drawCircle(center: NSPoint, radius: CGFloat, color: NSColor) {
  let rect = NSRect(
    x: center.x - radius,
    y: center.y - radius,
    width: radius * 2,
    height: radius * 2
  )
  color.setFill()
  NSBezierPath(ovalIn: rect).fill()
}

func color(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
  NSColor(
    srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
    green: CGFloat((hex >> 8) & 0xff) / 255,
    blue: CGFloat(hex & 0xff) / 255,
    alpha: alpha
  )
}

enum IconGenerationError: Error {
  case bitmapCreationFailed
  case graphicsContextCreationFailed
  case pngEncodingFailed
}
