import Foundation
import Testing
@testable import FlowlineCore

@Test func scannerReturnsOnlyNewScreenshotFiles() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }

  let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
  let screenshot = directory.appendingPathComponent("Screen Shot 2026-05-10 at 23.40.00.png")
  let turkishScreenshot = directory.appendingPathComponent("Ekran Resmi 2026-05-10 23.41.00.png")
  let photo = directory.appendingPathComponent("vacation-photo.jpg")
  let oldScreenshot = directory.appendingPathComponent("Screenshot 2026-05-09.png")

  try Data("ss".utf8).write(to: screenshot)
  try Data("ss".utf8).write(to: turkishScreenshot)
  try Data("photo".utf8).write(to: photo)
  try Data("old".utf8).write(to: oldScreenshot)

  try fileManager.setAttributes([.modificationDate: startedAt.addingTimeInterval(2)], ofItemAtPath: screenshot.path)
  try fileManager.setAttributes([.modificationDate: startedAt.addingTimeInterval(3)], ofItemAtPath: turkishScreenshot.path)
  try fileManager.setAttributes([.modificationDate: startedAt.addingTimeInterval(4)], ofItemAtPath: photo.path)
  try fileManager.setAttributes([.modificationDate: startedAt.addingTimeInterval(-20)], ofItemAtPath: oldScreenshot.path)

  var scanner = ScreenshotFileScanner(startedAt: startedAt, scanGrace: 0)
  let urls = scanner.scan(in: [directory], now: startedAt.addingTimeInterval(5), fileManager: fileManager)

  #expect(urls.map(\.lastPathComponent) == [
    "Screen Shot 2026-05-10 at 23.40.00.png",
    "Ekran Resmi 2026-05-10 23.41.00.png"
  ])
}

@Test func scannerDoesNotReturnSameScreenshotTwice() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }

  let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-10.png")

  try Data("ss".utf8).write(to: screenshot)
  try fileManager.setAttributes([.modificationDate: startedAt.addingTimeInterval(1)], ofItemAtPath: screenshot.path)

  var scanner = ScreenshotFileScanner(startedAt: startedAt, scanGrace: 0)
  _ = scanner.scan(in: [directory], now: startedAt.addingTimeInterval(2), fileManager: fileManager)
  let secondScan = scanner.scan(in: [directory], now: startedAt.addingTimeInterval(3), fileManager: fileManager)

  #expect(secondScan.isEmpty)
}

@Test func scannerReturnsUnseenScreenshotWithOldModificationDateAfterSeedingExistingFiles() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }

  let startedAt = Date()
  let existing = directory.appendingPathComponent("Screenshot 2026-05-17 existing.png")
  try Data("old".utf8).write(to: existing)
  try fileManager.setAttributes(
    [.modificationDate: startedAt.addingTimeInterval(-60)],
    ofItemAtPath: existing.path
  )

  var scanner = ScreenshotFileScanner(startedAt: startedAt, scanGrace: 2)
  scanner.seedSeenFiles(in: [directory], fileManager: fileManager)

  let screenshot = directory.appendingPathComponent("Screenshot 2026-05-17 delayed.png")
  try Data("ss".utf8).write(to: screenshot)
  try fileManager.setAttributes(
    [.modificationDate: startedAt.addingTimeInterval(-30)],
    ofItemAtPath: screenshot.path
  )

  let urls = scanner.scan(
    in: [directory],
    now: startedAt.addingTimeInterval(0.1),
    fileManager: fileManager,
    includeUnseenBeforeCutoff: true
  )

  #expect(urls.map(\.lastPathComponent) == ["Screenshot 2026-05-17 delayed.png"])
}
