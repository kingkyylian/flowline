import AppKit

enum HoldImageDataReader {
  static let jpegPasteboardType = NSPasteboard.PasteboardType("public.jpeg")
  static let imagePasteboardTypes: [NSPasteboard.PasteboardType] = [
    .png,
    .tiff,
    jpegPasteboardType
  ]

  static func hasImageData(in pasteboard: NSPasteboard) -> Bool {
    pngData(from: pasteboard) != nil
  }

  static func pngData(from pasteboard: NSPasteboard) -> Data? {
    if let pngData = pasteboard.data(forType: .png) {
      return pngData
    }

    if let tiffData = pasteboard.data(forType: .tiff),
       let pngData = pngData(fromBitmapData: tiffData) {
      return pngData
    }

    if let jpegData = pasteboard.data(forType: jpegPasteboardType),
       let pngData = pngData(fromBitmapData: jpegData) {
      return pngData
    }

    guard let image = NSImage(pasteboard: pasteboard) else {
      return nil
    }

    return pngData(from: image)
  }

  private static func pngData(fromBitmapData data: Data) -> Data? {
    guard let bitmap = NSBitmapImageRep(data: data) else {
      return nil
    }

    return bitmap.representation(using: .png, properties: [:])
  }

  private static func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation else {
      return nil
    }

    return pngData(fromBitmapData: tiffData)
  }
}
