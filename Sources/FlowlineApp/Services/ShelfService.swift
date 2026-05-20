import AppKit
import Combine
import Darwin
import FlowlineCore

struct ShelfAutoCaptureOptions: Equatable {
  var screenshots: Bool
  var clipboardText: Bool

  static let defaults = ShelfAutoCaptureOptions(screenshots: true, clipboardText: false)
}

@MainActor
final class ShelfService: ObservableObject {
  static let pasteboardPollInterval: TimeInterval = 0.1
  static let screenshotPollInterval: TimeInterval = 1.0
  static let screenshotEventRescanDelays: [TimeInterval] = [0.08, 0.20, 0.45]

  @Published private(set) var items: [ShelfItem] = []

  private var store: ShelfStore
  private var pasteboardTimer: Timer?
  private var screenshotPollTimer: Timer?
  private var lastChangeCount: Int
  private var screenshotScanner = ScreenshotFileScanner()
  private let screenshotDirectoriesProvider: () -> [URL]
  private let screenshotStashDirectoryProvider: () -> URL
  private let pasteboardProvider: () -> NSPasteboard
  private let screenshotTextRecognizer: (any ScreenshotTextRecognizing)?
  private let nowProvider: () -> Date
  private var autoCaptureOptions: ShelfAutoCaptureOptions
  private var screenshotDirectoryWatchers: [DispatchSourceFileSystemObject] = []
  private var screenshotDirectoryFileDescriptors: [CInt] = []
  private var screenshotOCRTasks: [ShelfItem.ID: Task<Void, Never>] = [:]
  private var screenshotEventRescanTasks: [Task<Void, Never>] = []
  private var canCaptureUnseenScreenshotsBeforeCutoff = false

  init(
    screenshotDirectoriesProvider: (() -> [URL])? = nil,
    screenshotStashDirectoryProvider: (() -> URL)? = nil,
    pasteboardProvider: (() -> NSPasteboard)? = nil,
    autoCaptureOptions: ShelfAutoCaptureOptions = .defaults,
    screenshotTextRecognizer: (any ScreenshotTextRecognizing)? = VisionScreenshotTextRecognizer(),
    retention: TimeInterval = 900,
    nowProvider: (() -> Date)? = nil
  ) {
    self.store = ShelfStore(limit: 10, retention: retention)
    self.screenshotDirectoriesProvider = screenshotDirectoriesProvider ?? Self.defaultScreenshotDirectories
    self.screenshotStashDirectoryProvider = screenshotStashDirectoryProvider ?? Self.defaultScreenshotStashDirectory
    self.pasteboardProvider = pasteboardProvider ?? { NSPasteboard.general }
    self.screenshotTextRecognizer = screenshotTextRecognizer
    self.nowProvider = nowProvider ?? Date.init
    self.autoCaptureOptions = autoCaptureOptions
    self.lastChangeCount = self.pasteboardProvider().changeCount
  }

  func start() {
    guard pasteboardTimer == nil, screenshotPollTimer == nil else {
      return
    }

    screenshotScanner = ScreenshotFileScanner(startedAt: nowProvider())
    if autoCaptureOptions.screenshots {
      seedExistingScreenshotFiles()
      startScreenshotDirectoryWatchers()
    }
    pasteboardTimer = scheduledTimer(withTimeInterval: Self.pasteboardPollInterval) { [weak self] in
      Task { @MainActor in
        self?.pollPasteboardAndPublish()
      }
    }
    screenshotPollTimer = scheduledTimer(withTimeInterval: Self.screenshotPollInterval) { [weak self] in
      Task { @MainActor in
        self?.scanScreenshotFilesAndPublish()
      }
    }
  }

  func stop() {
    pasteboardTimer?.invalidate()
    pasteboardTimer = nil
    screenshotPollTimer?.invalidate()
    screenshotPollTimer = nil
    stopScreenshotDirectoryWatchers()
    cancelScreenshotEventRescans()
    cancelAllOCRTasks()
    canCaptureUnseenScreenshotsBeforeCutoff = false
  }

  isolated deinit {
    pasteboardTimer?.invalidate()
    screenshotPollTimer?.invalidate()
    screenshotDirectoryWatchers.forEach { $0.cancel() }
    screenshotEventRescanTasks.forEach { $0.cancel() }
    screenshotOCRTasks.values.forEach { $0.cancel() }
  }

  func addFiles(_ urls: [URL]) {
    let now = nowProvider()
    pruneExpiredItems(now: now)
    urls.forEach { url in
      if let item = store.addFile(url, now: now), item.kind == .screenshot {
        scheduleOCRIfNeeded(for: item)
      }
    }
    items = store.items
  }

  func addText(_ text: String) {
    let now = nowProvider()
    pruneExpiredItems(now: now)
    store.addText(text, now: now)
    items = store.items
  }

  func addScreenshotFiles(_ urls: [URL]) {
    let now = nowProvider()
    pruneExpiredItems(now: now)
    urls.forEach { url in
      if let item = store.addScreenshotFile(stashScreenshot(url), now: now) {
        scheduleOCRIfNeeded(for: item)
      }
    }
    items = store.items
  }

  func cycle() {
    store.cycle()
    items = store.items
  }

  func remove(id: ShelfItem.ID) {
    cancelOCRTask(for: id)
    if let item = store.items.first(where: { $0.id == id }) {
      deleteStashedFileIfNeeded(for: item)
    }

    store.remove(id: id)
    items = store.items
  }

  func export(id: ShelfItem.ID) {
    cancelOCRTask(for: id)
    store.remove(id: id)
    items = store.items
  }

  func clear() {
    cancelAllOCRTasks()
    store.items.forEach(deleteStashedFileIfNeeded)
    store.clear()
    items = store.items
  }

  func refreshHoldSourcesForTesting() {
    pollHoldSources()
  }

  func markPasteboardWriteHandled() {
    lastChangeCount = pasteboardProvider().changeCount
  }

  func updateAutoCaptureOptions(_ options: ShelfAutoCaptureOptions) {
    guard autoCaptureOptions != options else {
      return
    }

    let screenshotsChanged = autoCaptureOptions.screenshots != options.screenshots
    autoCaptureOptions = options
    markPasteboardWriteHandled()

    guard isRunning, screenshotsChanged else {
      return
    }

    if options.screenshots {
      screenshotScanner = ScreenshotFileScanner(startedAt: nowProvider())
      seedExistingScreenshotFiles()
      startScreenshotDirectoryWatchers()
    } else {
      canCaptureUnseenScreenshotsBeforeCutoff = false
      stopScreenshotDirectoryWatchers()
      cancelScreenshotEventRescans()
    }
  }

  private func pollHoldSources() {
    let now = nowProvider()
    let previousItems = store.items
    pruneExpiredItems(now: now)
    pollPasteboard(now: now)
    pollScreenshotFiles(now: now)

    if store.items != previousItems {
      items = store.items
    }
  }

  private func pollPasteboardAndPublish() {
    let now = nowProvider()
    let previousItems = store.items
    pruneExpiredItems(now: now)
    pollPasteboard(now: now)

    if store.items != previousItems {
      items = store.items
    }
  }

  private func scanScreenshotFilesAndPublish() {
    guard autoCaptureOptions.screenshots else {
      return
    }

    let now = nowProvider()
    let previousItems = store.items
    pruneExpiredItems(now: now)
    pollScreenshotFiles(now: now)

    if store.items != previousItems {
      items = store.items
    }
  }

  private func pruneExpiredItems(now: Date) {
    let expiredItems = store.pruneExpired(now: now)
    expiredItems.forEach { item in
      cancelOCRTask(for: item.id)
      deleteStashedFileIfNeeded(for: item)
    }
  }

  private func pollPasteboard(now: Date) {
    let pasteboard = pasteboardProvider()
    guard pasteboard.changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = pasteboard.changeCount

    if autoCaptureOptions.screenshots,
       let url = stashClipboardScreenshot(from: pasteboard, now: now) {
      if let item = store.addScreenshotFile(url, now: now) {
        scheduleOCRIfNeeded(for: item)
      }
    } else if autoCaptureOptions.clipboardText,
              let text = pasteboard.string(forType: .string) {
      store.addText(text, now: now)
    }
  }

  private func pollScreenshotFiles(now: Date) {
    guard autoCaptureOptions.screenshots else {
      return
    }

    let urls = screenshotScanner.scan(
      in: screenshotDirectories(),
      now: now,
      includeUnseenBeforeCutoff: canCaptureUnseenScreenshotsBeforeCutoff
    )
    urls.forEach { url in
      if let item = store.addScreenshotFile(stashScreenshot(url), now: now) {
        scheduleOCRIfNeeded(for: item)
      }
    }
  }

  private func scheduleOCRIfNeeded(for item: ShelfItem) {
    guard item.kind == .screenshot,
          item.ocrText == nil,
          let url = item.url,
          let screenshotTextRecognizer else {
      return
    }

    cancelOCRTask(for: item.id)
    screenshotOCRTasks[item.id] = Task { [weak self, screenshotTextRecognizer] in
      let text = await screenshotTextRecognizer.recognizeText(in: url)
      guard !Task.isCancelled else {
        return
      }

      await MainActor.run {
        self?.applyOCRText(text, to: item.id)
      }
    }
  }

  private func applyOCRText(_ text: String?, to id: ShelfItem.ID) {
    screenshotOCRTasks[id] = nil
    guard let text else {
      return
    }

    if store.updateOCRText(text, for: id) {
      items = store.items
    }
  }

  private func cancelOCRTask(for id: ShelfItem.ID) {
    screenshotOCRTasks[id]?.cancel()
    screenshotOCRTasks[id] = nil
  }

  private func cancelAllOCRTasks() {
    screenshotOCRTasks.values.forEach { $0.cancel() }
    screenshotOCRTasks.removeAll()
  }

  private func screenshotDirectories() -> [URL] {
    screenshotDirectoriesProvider()
  }

  private func seedExistingScreenshotFiles() {
    screenshotScanner.seedSeenFiles(in: screenshotDirectories())
    canCaptureUnseenScreenshotsBeforeCutoff = true
  }

  private func startScreenshotDirectoryWatchers() {
    stopScreenshotDirectoryWatchers()

    let directories = Set(screenshotDirectories().map { $0.standardizedFileURL })
    directories.forEach { directory in
      let descriptor = open(directory.path, O_EVTONLY)
      guard descriptor >= 0 else {
        return
      }

      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: descriptor,
        eventMask: [.write, .extend, .attrib, .rename],
        queue: .main
      )

      source.setEventHandler { [weak self] in
        Task { @MainActor in
          self?.handleScreenshotDirectoryEvent()
        }
      }

      source.setCancelHandler {
        close(descriptor)
      }

      screenshotDirectoryFileDescriptors.append(descriptor)
      screenshotDirectoryWatchers.append(source)
      source.resume()
    }
  }

  private func handleScreenshotDirectoryEvent() {
    scanScreenshotFilesAndPublish()
    scheduleScreenshotEventRescans()
  }

  private func scheduleScreenshotEventRescans() {
    cancelScreenshotEventRescans()
    screenshotEventRescanTasks = Self.screenshotEventRescanDelays.map { delay in
      Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(Int((delay * 1000).rounded())))
        guard !Task.isCancelled else {
          return
        }

        await MainActor.run {
          self?.scanScreenshotFilesAndPublish()
        }
      }
    }
  }

  private func cancelScreenshotEventRescans() {
    screenshotEventRescanTasks.forEach { $0.cancel() }
    screenshotEventRescanTasks.removeAll()
  }

  private func stopScreenshotDirectoryWatchers() {
    screenshotDirectoryWatchers.forEach { $0.cancel() }
    screenshotDirectoryWatchers.removeAll()
    screenshotDirectoryFileDescriptors.removeAll()
  }

  private func scheduledTimer(withTimeInterval interval: TimeInterval, handler: @escaping @Sendable () -> Void) -> Timer {
    let timer = Timer(timeInterval: interval, repeats: true) { _ in
      handler()
    }
    RunLoop.main.add(timer, forMode: .common)
    return timer
  }

  private var isRunning: Bool {
    pasteboardTimer != nil || screenshotPollTimer != nil
  }

  private static func defaultScreenshotDirectories() -> [URL] {
    var directories = [
      FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    ]

    if let configuredLocation = configuredScreenshotLocation() {
      directories.append(URL(fileURLWithPath: (configuredLocation as NSString).expandingTildeInPath, isDirectory: true))
    }

    return directories
  }

  private func stashScreenshot(_ url: URL) -> URL {
    let fileManager = FileManager.default
    let stashDirectory = screenshotStashDirectoryProvider()

    do {
      try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
      let destination = availableDestination(for: url.lastPathComponent, in: stashDirectory, fileManager: fileManager)
      try fileManager.moveItem(at: url, to: destination)
      return destination
    } catch {
      return url
    }
  }

  private func stashClipboardScreenshot(from pasteboard: NSPasteboard, now: Date) -> URL? {
    guard let pngData = HoldImageDataReader.pngData(from: pasteboard) else {
      return nil
    }

    let stashDirectory = screenshotStashDirectoryProvider()
    let filename = "Clipboard Screenshot \(Self.clipboardScreenshotTimestamp.string(from: now)).png"
    let fileManager = FileManager.default

    do {
      try fileManager.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
      let destination = availableDestination(for: filename, in: stashDirectory, fileManager: fileManager)
      try pngData.write(to: destination, options: .atomic)
      return destination
    } catch {
      return nil
    }
  }

  private func availableDestination(for filename: String, in directory: URL, fileManager: FileManager) -> URL {
    let baseURL = directory.appendingPathComponent(filename)
    guard fileManager.fileExists(atPath: baseURL.path) else {
      return baseURL
    }

    let source = URL(fileURLWithPath: filename)
    let name = source.deletingPathExtension().lastPathComponent
    let pathExtension = source.pathExtension

    for index in 2...999 {
      let candidateName = pathExtension.isEmpty ? "\(name) \(index)" : "\(name) \(index).\(pathExtension)"
      let candidate = directory.appendingPathComponent(candidateName)
      if !fileManager.fileExists(atPath: candidate.path) {
        return candidate
      }
    }

    return directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
  }

  private func deleteStashedFileIfNeeded(for item: ShelfItem) {
    guard item.kind == .screenshot,
          let url = item.url,
          isStashedScreenshotURL(url) else {
      return
    }

    try? FileManager.default.removeItem(at: url)
  }

  private func isStashedScreenshotURL(_ url: URL) -> Bool {
    let stashDirectory = screenshotStashDirectoryProvider().standardizedFileURL
    let stashPath = stashDirectory.path.hasSuffix("/") ? stashDirectory.path : "\(stashDirectory.path)/"
    return url.standardizedFileURL.path.hasPrefix(stashPath)
  }

  private static func defaultScreenshotStashDirectory() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

    return base
      .appendingPathComponent("Flowline", isDirectory: true)
      .appendingPathComponent("Hold", isDirectory: true)
      .appendingPathComponent("Screenshots", isDirectory: true)
  }

  private static let clipboardScreenshotTimestamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
    return formatter
  }()

  private static func configuredScreenshotLocation() -> String? {
    if let location = CFPreferencesCopyAppValue(
      "location" as CFString,
      "com.apple.screencapture" as CFString
    ) as? String, !location.isEmpty {
      return location
    }

    if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
       !location.isEmpty {
      return location
    }

    return nil
  }
}
