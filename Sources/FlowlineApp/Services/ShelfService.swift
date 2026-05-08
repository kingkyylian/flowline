import AppKit
import Combine
import FlowlineCore

@MainActor
final class ShelfService: ObservableObject {
  @Published private(set) var items: [ShelfItem] = []

  private var store = ShelfStore(limit: 10)
  private var timer: Timer?
  private var lastChangeCount = NSPasteboard.general.changeCount

  func start() {
    guard timer == nil else {
      return
    }

    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.pollPasteboard()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  isolated deinit {
    timer?.invalidate()
  }

  func addFiles(_ urls: [URL]) {
    urls.forEach { store.addFile($0) }
    items = store.items
  }

  func remove(id: ShelfItem.ID) {
    store.remove(id: id)
    items = store.items
  }

  func clear() {
    store.clear()
    items = store.items
  }

  private func pollPasteboard() {
    let pasteboard = NSPasteboard.general
    guard pasteboard.changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = pasteboard.changeCount

    if let text = pasteboard.string(forType: .string) {
      store.addText(text)
      items = store.items
    }
  }
}
