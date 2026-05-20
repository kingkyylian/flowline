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

@Test func ciRunsPublishPreflightAgainstFullGitHistory() throws {
  let workflow = try String(
    contentsOfFile: ".github/workflows/ci.yml",
    encoding: .utf8
  )

  #expect(workflow.contains("fetch-depth: 0"))
  #expect(workflow.contains("script/publish_preflight.sh"))
}

@Test func ciAvoidsProductionCompilerRejectedIsolatedDeinitFlags() throws {
  let workflow = try String(
    contentsOfFile: ".github/workflows/ci.yml",
    encoding: .utf8
  )
  let isolatedDeinitSources = [
    "Sources/FlowlineApp/App/OverlayController.swift",
    "Sources/FlowlineApp/Services/ActiveAppMonitor.swift",
    "Sources/FlowlineApp/Services/CalendarService.swift",
    "Sources/FlowlineApp/Services/MusicControlService.swift",
    "Sources/FlowlineApp/Services/ShelfService.swift",
    "Sources/FlowlineApp/Stores/AppState.swift"
  ]

  #expect(!workflow.contains("enable-experimental-feature"))
  #expect(!workflow.contains("IsolatedDeinit"))
  for path in isolatedDeinitSources {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    #expect(!source.contains("isolated deinit"))
  }
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

@Test func notarizeReleaseFailsBeforeBuildWhenNotaryCredentialsAreMissing() throws {
  let fakeBin = try temporaryDirectory()
  let buildMarker = fakeBin.appendingPathComponent("swift-was-called")
  let identity = "Developer ID Application: Flowline Test (TEAM123456)"

  let fakeSecurity = fakeBin.appendingPathComponent("security")
  try """
  #!/usr/bin/env bash
  echo '  1) ABCDEF123456 "\(identity)"'
  """.write(to: fakeSecurity, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSecurity.path)

  let fakeSwift = fakeBin.appendingPathComponent("swift")
  try """
  #!/usr/bin/env bash
  touch "\(buildMarker.path)"
  echo "swift build should not run before notary credentials are validated" >&2
  exit 77
  """.write(to: fakeSwift, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwift.path)

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["bash", "script/package_release.sh", "--notarize"]
  process.environment = [
    "PATH": "\(fakeBin.path):/usr/bin:/bin:/usr/sbin:/sbin",
    "FLOWLINE_DEVELOPER_ID_IDENTITY": identity
  ]

  let outputPipe = Pipe()
  process.standardOutput = outputPipe
  process.standardError = outputPipe

  try process.run()
  process.waitUntilExit()

  let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  #expect(process.terminationStatus == 2)
  #expect(output.contains("notarization requires FLOWLINE_NOTARY_PROFILE or Apple ID credentials"))
  #expect(!FileManager.default.fileExists(atPath: buildMarker.path))
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

@Test func secretScanRejectsGoogleOAuthClientSecretsBeforePublish() throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  let googleOAuthSecret = "GO" + "CSPX-" + "abcdefghijklmnopqrstuvwxyz1234"
  try """
  let leakedSecret = "\(googleOAuthSecret)"
  """.write(to: source, atomically: true, encoding: .utf8)

  let result = try runSecretScan(in: repository)

  #expect(result.status == 2)
  #expect(result.output.contains("possible Google OAuth client secret"))
  #expect(result.output.contains("Probe.swift"))
  #expect(!result.output.contains(googleOAuthSecret))
}

@Test func secretScanRejectsGoogleOAuthClientSecretsInIgnoredFilesBeforePublish() throws {
  let repository = try temporaryGitRepository()
  let ignoreFile = repository.appendingPathComponent(".gitignore")
  try ".env\n".write(to: ignoreFile, atomically: true, encoding: .utf8)

  let ignoredEnv = repository.appendingPathComponent(".env")
  let googleOAuthSecret = "GO" + "CSPX-" + "abcdefghijklmnopqrstuvwxyz1234"
  try """
  LEAKED_SECRET=\(googleOAuthSecret)
  """.write(to: ignoredEnv, atomically: true, encoding: .utf8)

  let result = try runSecretScan(in: repository)

  #expect(result.status == 2)
  #expect(result.output.contains("possible Google OAuth client secret"))
  #expect(result.output.contains(".env"))
  #expect(!result.output.contains(googleOAuthSecret))
}

@Test func secretScanRejectsGoogleOAuthClientIDsBeforePublish() throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  let googleOAuthClientID = "123456789012-" + "abcdefghijklmnopqrstuvwxyz123456.apps.googleusercontent.com"
  try """
  let leakedClientID = "\(googleOAuthClientID)"
  """.write(to: source, atomically: true, encoding: .utf8)

  let result = try runSecretScan(in: repository)

  #expect(result.status == 2)
  #expect(result.output.contains("possible Google OAuth client ID"))
  #expect(result.output.contains("Probe.swift"))
  #expect(!result.output.contains(googleOAuthClientID))
}

@Test func secretScanRejectsOpenAIAPIKeysBeforePublish() throws {
  let openAIKey = "sk-" + "proj-" + "abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  try assertSecretScanRejects(
    leakedValue: openAIKey,
    expectedLabel: "possible OpenAI API key"
  )
}

@Test func secretScanRejectsAnthropicAPIKeysBeforePublish() throws {
  let anthropicKey = "sk-" + "ant-" + "abcdefghijklmnopqrstuvwxyz1234567890"
  try assertSecretScanRejects(
    leakedValue: anthropicKey,
    expectedLabel: "possible Anthropic API key"
  )
}

@Test func secretScanRejectsGitHubTokensBeforePublish() throws {
  let githubToken = "gh" + "p_" + "abcdefghijklmnopqrstuvwxyz1234567890ABCD"
  try assertSecretScanRejects(
    leakedValue: githubToken,
    expectedLabel: "possible GitHub token"
  )
}

@Test func secretScanRejectsSlackTokensBeforePublish() throws {
  let slackToken = "xox" + "b-" + "123456789012-123456789012-abcdefghijklmnopqrstuvwxyz"
  try assertSecretScanRejects(
    leakedValue: slackToken,
    expectedLabel: "possible Slack token"
  )
}

@Test func secretScanRejectsAWSAccessKeysBeforePublish() throws {
  let awsAccessKey = "AK" + "IA" + "ABCDEFGHIJKLMNOP"
  try assertSecretScanRejects(
    leakedValue: awsAccessKey,
    expectedLabel: "possible AWS access key"
  )
}

@Test func secretScanRejectsGenericSensitiveAssignmentsBeforePublish() throws {
  let repository = try temporaryGitRepository()
  let envFile = repository.appendingPathComponent(".env")
  let genericSecret = "abcdefghijklmnopqrstuvwxyz" + "1234567890"
  try """
  CLIENT_SECRET=\(genericSecret)
  """.write(to: envFile, atomically: true, encoding: .utf8)

  let result = try runSecretScan(in: repository)

  #expect(result.status == 2)
  #expect(result.output.contains("possible generic sensitive assignment"))
  #expect(result.output.contains(".env"))
  #expect(!result.output.contains(genericSecret))
}

@Test func secretScanRejectsSecretsInReachableGitHistoryBeforePublish() throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  let googleOAuthSecret = "GO" + "CSPX-" + "abcdefghijklmnopqrstuvwxyz1234"
  try """
  let leakedSecret = "\(googleOAuthSecret)"
  """.write(to: source, atomically: true, encoding: .utf8)
  try runProcess("/usr/bin/git", ["add", "Probe.swift"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "Add leaked probe"],
    in: repository
  )
  try FileManager.default.removeItem(at: source)
  try runProcess("/usr/bin/git", ["add", "-A"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "Remove leaked probe"],
    in: repository
  )

  let result = try runSecretScan(in: repository)

  #expect(result.status == 2)
  #expect(result.output.contains("possible Google OAuth client secret"))
  #expect(result.output.contains("Probe.swift"))
  #expect(!result.output.contains(googleOAuthSecret))
}

private struct ProcessResult {
  let status: Int32
  let output: String
}

private func assertSecretScanRejects(
  leakedValue: String,
  expectedLabel: String
) throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  try """
  let leakedValue = "\(leakedValue)"
  """.write(to: source, atomically: true, encoding: .utf8)

  let result = try runSecretScan(in: repository)

  #expect(result.status == 2)
  #expect(result.output.contains(expectedLabel))
  #expect(result.output.contains("Probe.swift"))
  #expect(!result.output.contains(leakedValue))
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

private func runSecretScan(in directory: URL, pathPrefix: String? = nil) throws -> ProcessResult {
  let script = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("script/secret_scan.sh")
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
  var path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
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
