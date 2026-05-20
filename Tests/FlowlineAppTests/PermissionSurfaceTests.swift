import Foundation
import Testing

@Test func buildScriptsDescribeDesktopScreenshotFolderAccess() throws {
  for path in [
    "script/build_and_run.sh",
    "script/package_release.sh"
  ] {
    let script = try String(contentsOfFile: path, encoding: .utf8)

    #expect(script.contains("NSDesktopFolderUsageDescription"))
  }
}

@Test func windowTitleReaderAvoidsScreenCaptureWindowListAPIs() throws {
  let source = try String(
    contentsOfFile: "Sources/FlowlineApp/Services/WindowTitleReader.swift",
    encoding: .utf8
  )

  #expect(!source.contains("CGWindowListCopyWindowInfo"))
  #expect(!source.contains("kCGWindowName"))
}

@Test func releasePreflightFailsBeforeBuildWhenDeveloperIDIdentityIsMissing() throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["bash", "script/package_release.sh", "--preflight"]
  process.environment = [
    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
    "FLOWLINE_DEVELOPER_ID_IDENTITY": "Developer ID Application: Missing Flowline Cert (NOPE123456)"
  ]

  let outputPipe = Pipe()
  process.standardOutput = outputPipe
  process.standardError = outputPipe

  try process.run()
  process.waitUntilExit()

  let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  #expect(process.terminationStatus == 2)
  #expect(output.contains("Developer ID Application identity is not installed"))
}

@Test func publishPreflightFailsWhenOriginRemoteIsMissing() throws {
  let repository = try temporaryGitRepository()

  let result = try runPublishPreflight(in: repository)

  #expect(result.status == 2)
  #expect(result.output.contains("git remote origin is not configured"))
}

@Test func publishPreflightFailsWhenOriginRepositoryIsNotReachableOnGitHub() throws {
  let repository = try temporaryGitRepository()
  try runProcess("/usr/bin/git", ["remote", "add", "origin", "https://github.com/example/missing-flowline.git"], in: repository)

  let fakeBin = try temporaryDirectory()
  let fakeGh = fakeBin.appendingPathComponent("gh")
  try """
  #!/usr/bin/env bash
  exit 1
  """.write(to: fakeGh, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeGh.path)

  let result = try runPublishPreflight(
    in: repository,
    pathPrefix: fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("GitHub repository is not reachable: example/missing-flowline"))
}

private struct ProcessResult {
  let status: Int32
  let output: String
}

private func runPublishPreflight(in directory: URL, pathPrefix: String? = nil) throws -> ProcessResult {
  let script = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("script/publish_preflight.sh")
  return try runProcess(
    "/usr/bin/env",
    ["bash", script.path],
    in: directory,
    pathPrefix: pathPrefix
  )
}

@discardableResult
private func runProcess(
  _ executable: String,
  _ arguments: [String],
  in directory: URL,
  pathPrefix: String? = nil
) throws -> ProcessResult {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.currentDirectoryURL = directory
  var path = "/usr/bin:/bin:/usr/sbin:/sbin"
  if let pathPrefix {
    path = "\(pathPrefix):\(path)"
  }
  process.environment = ["PATH": path]

  let outputPipe = Pipe()
  process.standardOutput = outputPipe
  process.standardError = outputPipe

  try process.run()
  process.waitUntilExit()

  let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  return ProcessResult(status: process.terminationStatus, output: output)
}

private func temporaryGitRepository() throws -> URL {
  let directory = try temporaryDirectory()
  try runProcess("/usr/bin/git", ["init", "-b", "main"], in: directory)
  return directory
}

private func temporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("FlowlineTests", isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}
