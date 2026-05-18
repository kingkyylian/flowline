import AppKit

enum HoldDropTypes {
  static let pasteboardTypes: [NSPasteboard.PasteboardType] = {
    var types: [NSPasteboard.PasteboardType] = [
      .fileURL,
      .URL,
      .string,
      HoldItemDragProvider.terminalFilenamesPasteboardType
    ]

    types.append(contentsOf: HoldImageDataReader.imagePasteboardTypes)
    types.append(contentsOf: NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    return types
  }()
}
