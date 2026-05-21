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

@Test func ciUsesNode24CompatibleCheckoutAction() throws {
  let workflow = try String(
    contentsOfFile: ".github/workflows/ci.yml",
    encoding: .utf8
  )

  #expect(workflow.contains("actions/checkout@v5"))
  #expect(!workflow.contains("actions/checkout@v4"))
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

@Test func ciSwiftAcceptsDraggingInfoTestDoubleConformance() throws {
  let source = try String(
    contentsOfFile: "Tests/FlowlineAppTests/OverlayHostingViewHoldDropTests.swift",
    encoding: .utf8
  )

  #expect(!source.contains("@MainActor NSDraggingInfo"))
  #expect(source.contains("@preconcurrency NSDraggingInfo"))
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

@Test func notarizeReleaseRejectsBlankAppleIDCredentialsBeforeBuild() throws {
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
  echo "swift build should not run before Apple ID notary credentials are validated" >&2
  exit 77
  """.write(to: fakeSwift, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwift.path)

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["bash", "script/package_release.sh", "--notarize"]
  process.environment = [
    "PATH": "\(fakeBin.path):/usr/bin:/bin:/usr/sbin:/sbin",
    "FLOWLINE_DEVELOPER_ID_IDENTITY": identity,
    "APPLE_ID": "developer@example.invalid",
    "APPLE_TEAM_ID": "   ",
    "APPLE_APP_SPECIFIC_PASSWORD": "not-a-real-password"
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

@Test func notarizeReleaseRejectsInvalidAppleTeamIDBeforeBuild() throws {
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
  echo "swift build should not run before Apple Team ID is validated" >&2
  exit 77
  """.write(to: fakeSwift, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwift.path)

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["bash", "script/package_release.sh", "--notarize"]
  process.environment = [
    "PATH": "\(fakeBin.path):/usr/bin:/bin:/usr/sbin:/sbin",
    "FLOWLINE_DEVELOPER_ID_IDENTITY": identity,
    "APPLE_ID": "developer@example.invalid",
    "APPLE_TEAM_ID": "TEAM 12345",
    "APPLE_APP_SPECIFIC_PASSWORD": "not-a-real-password"
  ]

  let outputPipe = Pipe()
  process.standardOutput = outputPipe
  process.standardError = outputPipe

  try process.run()
  process.waitUntilExit()

  let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  #expect(process.terminationStatus == 2)
  #expect(output.contains("APPLE_TEAM_ID is invalid"))
  #expect(!FileManager.default.fileExists(atPath: buildMarker.path))
}

@Test func releasePackagingRejectsInvalidMetadataBeforeBuild() throws {
  let probes = [
    (variable: "FLOWLINE_BUNDLE_ID", value: "dev.kyylian.flowline<bad>"),
    (variable: "FLOWLINE_VERSION", value: "1.0<bad>"),
    (variable: "FLOWLINE_BUILD", value: "1&bad")
  ]

  for probe in probes {
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
    echo "swift build should not run before release metadata is validated" >&2
    exit 77
    """.write(to: fakeSwift, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeSwift.path)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["bash", "script/package_release.sh", "--archive"]
    var environment = [
      "PATH": "\(fakeBin.path):/usr/bin:/bin:/usr/sbin:/sbin",
      "FLOWLINE_DEVELOPER_ID_IDENTITY": identity
    ]
    environment[probe.variable] = probe.value
    process.environment = environment

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    #expect(process.terminationStatus == 2)
    #expect(output.contains("\(probe.variable) is invalid"))
    #expect(!FileManager.default.fileExists(atPath: buildMarker.path))
  }
}

@Test func releaseArchiveLintsPlistAndBuildsBundleWithMetadata() throws {
  let fixture = try ReleasePackagingFixture()
  let bundleID = "dev.kyylian.flowline.tests"
  let version = "1.2.3"
  let build = "4.5.6"
  let plutilMarker = fixture.fakeBin.appendingPathComponent("plutil-args")
  let codesignMarker = fixture.fakeBin.appendingPathComponent("codesign-args")

  try fixture.installPlutil(marker: plutilMarker)
  try fixture.installCodesign(marker: codesignMarker)
  let result = try fixture.runPackageRelease(
    "--archive",
    environment: [
      "FLOWLINE_BUNDLE_ID": bundleID,
      "FLOWLINE_VERSION": version,
      "FLOWLINE_BUILD": build
    ]
  )

  let bundle = fixture.bundle
  let plistURL = bundle.appendingPathComponent("Contents/Info.plist")
  let plistData = try Data(contentsOf: plistURL)
  let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]

  #expect(result.status == 0)
  #expect(result.output.contains("Release archive: \(fixture.zipPath(version: version).path)"))
  #expect(FileManager.default.fileExists(atPath: plutilMarker.path))
  #expect((try String(contentsOf: plutilMarker, encoding: .utf8)).contains(plistURL.path))
  #expect((try String(contentsOf: codesignMarker, encoding: .utf8)).contains(fixture.identity))
  #expect(FileManager.default.fileExists(atPath: bundle.appendingPathComponent("Contents/MacOS/Flowline").path))
  #expect(FileManager.default.fileExists(atPath: fixture.zipPath(version: version).path))
  #expect(plist?["CFBundleIdentifier"] as? String == bundleID)
  #expect(plist?["CFBundleShortVersionString"] as? String == version)
  #expect(plist?["CFBundleVersion"] as? String == build)
  #expect(plist?["LSUIElement"] as? Bool == true)
}

@Test func notarizedReleaseAssessesStapledBundleBeforeFinalZip() throws {
  let fixture = try ReleasePackagingFixture()
  let version = "2.0.0"
  let notaryProfile = "flowline-notary-test"

  try fixture.installDitto(recordEvents: true)
  try fixture.installXcrunForProfileNotarization(version: version, notaryProfile: notaryProfile)
  try fixture.installSpctl()

  let result = try fixture.runPackageRelease(
    "--notarize",
    environment: [
      "FLOWLINE_VERSION": version,
      "FLOWLINE_NOTARY_PROFILE": notaryProfile
    ]
  )

  let zipPath = fixture.zipPath(version: version)
  let events = try String(contentsOf: fixture.eventsMarker, encoding: .utf8)
  let eventLines = events.split(separator: "\n").map(String.init)

  #expect(result.status == 0)
  #expect(result.output.contains("Release archive: \(zipPath.path)"))
  #expect(eventLines == [
    "ditto \(zipPath.path)",
    "xcrun notarytool submit \(zipPath.path) --keychain-profile \(notaryProfile) --wait",
    "xcrun stapler staple \(fixture.bundle.path)",
    "spctl --assess --type execute --verbose \(fixture.bundle.path)",
    "ditto \(zipPath.path)"
  ])
  #expect(FileManager.default.fileExists(atPath: zipPath.path))
}

@Test func notarizedReleaseSubmitsAppleIDCredentialsWhenProfileIsNotConfigured() throws {
  let fixture = try ReleasePackagingFixture()
  let version = "2.1.0"
  let appleID = "developer@example.invalid"
  let teamID = "TEAM123456"
  let appSpecificPassword = "not-a-real-password"

  try fixture.installDitto(recordEvents: true)
  try fixture.installXcrunForAppleIDNotarization(
    version: version,
    appleID: appleID,
    teamID: teamID,
    password: appSpecificPassword
  )
  try fixture.installSpctl()

  let result = try fixture.runPackageRelease(
    "--notarize",
    environment: [
      "FLOWLINE_VERSION": version,
      "APPLE_ID": appleID,
      "APPLE_TEAM_ID": teamID,
      "APPLE_APP_SPECIFIC_PASSWORD": appSpecificPassword
    ]
  )

  let zipPath = fixture.zipPath(version: version)
  let events = try String(contentsOf: fixture.eventsMarker, encoding: .utf8)
  let eventLines = events.split(separator: "\n").map(String.init)

  #expect(result.status == 0)
  #expect(result.output.contains("Release archive: \(zipPath.path)"))
  #expect(eventLines == [
    "ditto \(zipPath.path)",
    "xcrun notarytool submit \(zipPath.path) --apple-id \(appleID) --team-id \(teamID) --password \(appSpecificPassword) --wait",
    "xcrun stapler staple \(fixture.bundle.path)",
    "spctl --assess --type execute --verbose \(fixture.bundle.path)",
    "ditto \(zipPath.path)"
  ])
  #expect(FileManager.default.fileExists(atPath: zipPath.path))
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

private struct ReleasePackagingFixture {
  let project: URL
  let fakeBin: URL
  let packageScript: URL
  let identity = "Developer ID Application: Flowline Test (TEAM123456)"
  let eventsMarker: URL

  var bundle: URL {
    project.appendingPathComponent("dist/release/Flowline.app", isDirectory: true)
  }

  init() throws {
    project = try temporaryDirectory()
    fakeBin = try temporaryDirectory()
    eventsMarker = fakeBin.appendingPathComponent("release-events")

    let scriptDirectory = project.appendingPathComponent("script", isDirectory: true)
    let resourcesDirectory = project.appendingPathComponent("Resources", isDirectory: true)
    try FileManager.default.createDirectory(at: scriptDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)

    let sourceScript = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("script/package_release.sh")
    packageScript = scriptDirectory.appendingPathComponent("package_release.sh")
    try FileManager.default.copyItem(at: sourceScript, to: packageScript)
    try Data([0x69, 0x63, 0x6e, 0x73]).write(
      to: resourcesDirectory.appendingPathComponent("Flowline.icns")
    )

    try installSecurity()
    try installSwiftBuild()
    try installPlutil()
    try installCodesign()
    try installDitto()
  }

  func zipPath(version: String) -> URL {
    project.appendingPathComponent("dist/release/Flowline-\(version).zip")
  }

  func installDitto(recordEvents: Bool = false) throws {
    let eventLine = recordEvents
      ? "printf 'ditto %s\\n' \"$destination\" >> \"\(eventsMarker.path)\""
      : ""

    try installExecutable(
      named: "ditto",
      contents: """
      #!/usr/bin/env bash
      destination=""
      for arg in "$@"; do destination="$arg"; done
      \(eventLine)
      touch "$destination"
      """
    )
  }

  func installXcrunForProfileNotarization(version: String, notaryProfile: String) throws {
    let zipPath = zipPath(version: version)

    try installExecutable(
      named: "xcrun",
      contents: """
      #!/usr/bin/env bash
      printf 'xcrun %s\\n' "$*" >> "\(eventsMarker.path)"
      if [[ "$1" == "notarytool" ]]; then
        test "$2" = "submit"
        test "$3" = "\(zipPath.path)"
        test "$4" = "--keychain-profile"
        test "$5" = "\(notaryProfile)"
        test "$6" = "--wait"
        test -f "$3"
      elif [[ "$1" == "stapler" ]]; then
        test "$2" = "staple"
        test "$3" = "\(bundle.path)"
        test -d "$3"
      else
        exit 88
      fi
      """
    )
  }

  func installXcrunForAppleIDNotarization(
    version: String,
    appleID: String,
    teamID: String,
    password: String
  ) throws {
    let zipPath = zipPath(version: version)

    try installExecutable(
      named: "xcrun",
      contents: """
      #!/usr/bin/env bash
      printf 'xcrun %s\\n' "$*" >> "\(eventsMarker.path)"
      if [[ "$1" == "notarytool" ]]; then
        test "$2" = "submit"
        test "$3" = "\(zipPath.path)"
        test "$4" = "--apple-id"
        test "$5" = "\(appleID)"
        test "$6" = "--team-id"
        test "$7" = "\(teamID)"
        test "$8" = "--password"
        test "$9" = "\(password)"
        test "${10}" = "--wait"
        test -f "$3"
      elif [[ "$1" == "stapler" ]]; then
        test "$2" = "staple"
        test "$3" = "\(bundle.path)"
        test -d "$3"
      else
        exit 88
      fi
      """
    )
  }

  func installSpctl() throws {
    try installExecutable(
      named: "spctl",
      contents: """
      #!/usr/bin/env bash
      printf 'spctl %s\\n' "$*" >> "\(eventsMarker.path)"
      test "$1" = "--assess"
      test "$2" = "--type"
      test "$3" = "execute"
      test "$4" = "--verbose"
      test "$5" = "\(bundle.path)"
      test -d "$5"
      """
    )
  }

  func runPackageRelease(
    _ mode: String,
    environment overrides: [String: String] = [:]
  ) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["bash", packageScript.path, mode]
    process.currentDirectoryURL = project

    var environment = [
      "PATH": "\(fakeBin.path):/usr/bin:/bin:/usr/sbin:/sbin",
      "FLOWLINE_DEVELOPER_ID_IDENTITY": identity
    ]
    for (key, value) in overrides {
      environment[key] = value
    }
    process.environment = environment

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ProcessResult(status: process.terminationStatus, output: output)
  }

  private func installSecurity() throws {
    try installExecutable(
      named: "security",
      contents: """
      #!/usr/bin/env bash
      echo '  1) ABCDEF123456 "\(identity)"'
      """
    )
  }

  private func installSwiftBuild() throws {
    try installExecutable(
      named: "swift",
      contents: """
      #!/usr/bin/env bash
      mkdir -p .build/release
      printf '#!/usr/bin/env bash\\n' > .build/release/Flowline
      chmod +x .build/release/Flowline
      """
    )
  }

  func installPlutil(marker: URL? = nil) throws {
    let eventLine = marker
      .map { "printf '%s\\n' \"$@\" > \"\($0.path)\"" } ?? ""

    try installExecutable(
      named: "plutil",
      contents: """
      #!/usr/bin/env bash
      \(eventLine)
      test "$1" = "-lint"
      test -f "$2"
      """
    )
  }

  func installCodesign(marker: URL? = nil) throws {
    let eventLine = marker
      .map { "printf 'call\\n' >> \"\($0.path)\"\nfor arg in \"$@\"; do printf '%s\\n' \"$arg\" >> \"\($0.path)\"; done" } ?? ""

    try installExecutable(
      named: "codesign",
      contents: """
      #!/usr/bin/env bash
      \(eventLine)
      """
    )
  }

  private func installExecutable(named name: String, contents: String) throws {
    let executable = fakeBin.appendingPathComponent(name)
    try contents.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
  }
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
