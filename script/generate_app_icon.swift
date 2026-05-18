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
    roundedRect: rectFromTop(x: 112, y: 88, width: 800, height: 848),
    xRadius: 184 * scale,
    yRadius: 184 * scale
  )

  NSGraphicsContext.saveGraphicsState()
  let bodyShadow = NSShadow()
  bodyShadow.shadowColor = color(0x000000, alpha: 0.34)
  bodyShadow.shadowOffset = NSSize(width: 0, height: -32 * scale)
  bodyShadow.shadowBlurRadius = 34 * scale
  bodyShadow.set()
  NSGradient(colors: [
    color(0x303846),
    color(0x111821),
    color(0x0a0e14)
  ])?.draw(in: body, angle: -52)
  NSGraphicsContext.restoreGraphicsState()

  body.lineWidth = 10 * scale
  color(0xffffff, alpha: 0.16).setStroke()
  body.stroke()

  let glint = NSBezierPath()
  glint.move(to: p(208, 340))
  glint.curve(to: p(617, 175), controlPoint1: p(308, 218), controlPoint2: p(453, 160))
  glint.curve(to: p(837, 274), controlPoint1: p(709, 184), controlPoint2: p(781, 219))
  glint.lineWidth = 44 * scale
  glint.lineCapStyle = .round
  color(0xffffff, alpha: 0.08).setStroke()
  glint.stroke()

  drawSegment(from: p(289, 319), to: p(444, 482), width: 84 * scale, color: color(0x5cc8b2, alpha: 0.20))
  drawSegment(from: p(735, 319), to: p(580, 482), width: 84 * scale, color: color(0xd8ad67, alpha: 0.18))

  NSGraphicsContext.saveGraphicsState()
  let markShadow = NSShadow()
  markShadow.shadowColor = color(0x000000, alpha: 0.38)
  markShadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
  markShadow.shadowBlurRadius = 16 * scale
  markShadow.set()

  let markColor = color(0xebf5fb)
  drawSegment(from: p(289, 319), to: p(444, 482), width: 76 * scale, color: markColor)
  drawSegment(from: p(735, 319), to: p(580, 482), width: 76 * scale, color: markColor)
  drawSegment(from: p(512, 560), to: p(512, 742), width: 76 * scale, color: markColor)
  NSGraphicsContext.restoreGraphicsState()

  drawCircle(center: p(444, 482), radius: 20 * scale, color: color(0xf6fbff, alpha: 0.72))
  drawCircle(center: p(580, 482), radius: 20 * scale, color: color(0xf6fbff, alpha: 0.72))
  drawCircle(center: p(512, 560), radius: 18 * scale, color: color(0xf6fbff, alpha: 0.58))
}

func drawSegment(from start: NSPoint, to end: NSPoint, width: CGFloat, color: NSColor) {
  let path = NSBezierPath()
  path.move(to: start)
  path.line(to: end)
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
