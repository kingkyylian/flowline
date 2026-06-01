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
    roundedRect: rectFromTop(x: 0, y: 0, width: 1024, height: 1024),
    xRadius: 228 * scale,
    yRadius: 228 * scale
  )

  NSGraphicsContext.saveGraphicsState()
  body.addClip()
  NSGradient(colors: [
    color(0x061323),
    color(0x073b4b),
    color(0x0b756d),
    color(0x211b58)
  ])?.draw(in: rectFromTop(x: 0, y: 0, width: 1024, height: 1024), angle: -38)
  drawBackgroundCurrents(scale: scale, point: p)
  NSGraphicsContext.restoreGraphicsState()

  body.lineWidth = 5 * scale
  color(0xbffff4, alpha: 0.10).setStroke()
  body.stroke()

  drawFlowRibbon(scale: scale, point: p)
}

func drawBackgroundCurrents(scale: CGFloat, point p: (CGFloat, CGFloat) -> NSPoint) {
  let lowerCurrent = NSBezierPath()
  lowerCurrent.move(to: p(44, 760))
  lowerCurrent.curve(
    to: p(980, 342),
    controlPoint1: p(244, 652),
    controlPoint2: p(404, 366)
  )
  drawStroke(lowerCurrent, width: 212 * scale, color: color(0x020912, alpha: 0.30))

  let upperCurrent = NSBezierPath()
  upperCurrent.move(to: p(0, 324))
  upperCurrent.curve(
    to: p(1024, 704),
    controlPoint1: p(250, 210),
    controlPoint2: p(626, 360)
  )
  drawStroke(upperCurrent, width: 154 * scale, color: color(0x6fffe9, alpha: 0.10))

  let warmCurrent = NSBezierPath()
  warmCurrent.move(to: p(590, 80))
  warmCurrent.curve(
    to: p(1110, 502),
    controlPoint1: p(682, 238),
    controlPoint2: p(820, 360)
  )
  drawStroke(warmCurrent, width: 146 * scale, color: color(0xffbc6b, alpha: 0.10))
}

func drawFlowRibbon(scale: CGFloat, point p: (CGFloat, CGFloat) -> NSPoint) {
  let body = flowRibbonContinuousPath(point: p)
  drawStroke(body, width: 148 * scale, color: color(0x010812, alpha: 0.34))
  drawStroke(body, width: 120 * scale, color: color(0x062c3f, alpha: 0.44))
  drawStroke(body, width: 100 * scale, color: color(0x41ffe2, alpha: 0.16))
  drawGradientStroke(
    body,
    width: 78 * scale,
    colors: [
      color(0x84ffe9),
      color(0xf2fff7),
      color(0xffc56e)
    ],
    locations: [0, 0.50, 1],
    start: p(282, 552),
    end: p(742, 444)
  )
  drawStroke(body, width: 18 * scale, color: color(0xffffff, alpha: 0.18))
}

func flowRibbonContinuousPath(point p: (CGFloat, CGFloat) -> NSPoint) -> NSBezierPath {
  let path = NSBezierPath()
  path.move(to: p(282, 552))
  path.curve(
    to: p(512, 488),
    controlPoint1: p(362, 361),
    controlPoint2: p(454, 372)
  )
  path.curve(
    to: p(742, 444),
    controlPoint1: p(570, 603),
    controlPoint2: p(666, 591)
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

func drawGradientStroke(
  _ path: NSBezierPath,
  width: CGFloat,
  colors: [NSColor],
  locations: [CGFloat],
  start: NSPoint,
  end: NSPoint
) {
  guard
    let context = NSGraphicsContext.current?.cgContext,
    let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: colors.map(\.cgColor) as CFArray,
      locations: locations
    )
  else {
    return
  }

  context.saveGState()
  context.addPath(path.cgPath)
  context.setLineWidth(width)
  context.setLineCap(.round)
  context.setLineJoin(.round)
  context.replacePathWithStrokedPath()
  context.clip()
  context.drawLinearGradient(
    gradient,
    start: CGPoint(x: start.x, y: start.y),
    end: CGPoint(x: end.x, y: end.y),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
  )
  context.restoreGState()
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
