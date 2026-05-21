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
  let manifest = try String(contentsOf: fixture.manifestPath(version: version), encoding: .utf8)
  #expect(manifest.contains("flowline_release_manifest=1"))
  #expect(manifest.contains("archive_name=Flowline-\(version).zip"))
  #expect(manifest.contains("version=\(version)"))
  #expect(manifest.contains("build=\(build)"))
  #expect(manifest.contains("bundle_id=\(bundleID)"))
  #expect(manifest.contains("git_commit=unknown"))
  #expect(manifest.contains("sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
  #expect(manifest.contains("size_bytes=0"))
  #expect(manifest.contains("notarized=false"))
  #expect(plist?["CFBundleIdentifier"] as? String == bundleID)
  #expect(plist?["CFBundleShortVersionString"] as? String == version)
  #expect(plist?["CFBundleVersion"] as? String == build)
  #expect(plist?["LSUIElement"] as? Bool == true)
}

@Test func releaseArchiveManifestRecordsGitHubActionsProvenanceWhenAvailable() throws {
  let fixture = try ReleasePackagingFixture()
  let version = "1.2.3"

  let result = try fixture.runPackageRelease(
    "--archive",
    environment: [
      "FLOWLINE_VERSION": version,
      "GITHUB_REPOSITORY": "kingkyylian/flowline",
      "GITHUB_RUN_ID": "1234567890",
      "GITHUB_RUN_ATTEMPT": "2",
      "GITHUB_WORKFLOW": "Release",
      "GITHUB_SERVER_URL": "https://github.com"
    ]
  )

  let manifest = try String(contentsOf: fixture.manifestPath(version: version), encoding: .utf8)

  #expect(result.status == 0)
  #expect(manifest.contains("github_repository=kingkyylian/flowline"))
  #expect(manifest.contains("github_run_id=1234567890"))
  #expect(manifest.contains("github_run_attempt=2"))
  #expect(manifest.contains("github_workflow=Release"))
  #expect(manifest.contains("github_server_url=https://github.com"))
}

@Test func releaseArchiveManifestRecordsGitHubArtifactNameWhenAvailable() throws {
  let fixture = try ReleasePackagingFixture()
  let version = "1.2.3"
  let artifactName = "flowline-release-\(version)"

  let result = try fixture.runPackageRelease(
    "--archive",
    environment: [
      "FLOWLINE_VERSION": version,
      "GITHUB_ARTIFACT_NAME": artifactName
    ]
  )

  let manifest = try String(contentsOf: fixture.manifestPath(version: version), encoding: .utf8)

  #expect(result.status == 0)
  #expect(manifest.contains("github_artifact_name=\(artifactName)"))
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

@Test func publishPreflightFailsWhenLocalHeadIsNotPushedToOrigin() throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  try "let first = true\n".write(to: source, atomically: true, encoding: .utf8)
  try runProcess("/usr/bin/git", ["add", "Probe.swift"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "First commit"],
    in: repository
  )
  let remoteHead = try runProcess("/usr/bin/git", ["rev-parse", "HEAD"], in: repository)
    .output
    .trimmingCharacters(in: .whitespacesAndNewlines)

  try "let first = false\n".write(to: source, atomically: true, encoding: .utf8)
  try runProcess("/usr/bin/git", ["add", "Probe.swift"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "Second commit"],
    in: repository
  )
  try runProcess("/usr/bin/git", ["remote", "add", "origin", "https://github.com/kingkyylian/flowline.git"], in: repository)

  let fakeBin = try temporaryDirectory()
  let fakeRTK = fakeBin.appendingPathComponent("rtk")
  try """
  #!/usr/bin/env bash
  if [[ "$1" == "git" && "$2" == "ls-remote" && "$3" == "--exit-code" && "$4" == "origin" && "$5" == "HEAD" ]]; then
    printf '%s\\tHEAD\\n' "\(remoteHead)"
    exit 0
  fi

  exit 99
  """.write(to: fakeRTK, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeRTK.path)

  let result = try runPublishPreflight(
    in: repository,
    pathPrefix: fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("local HEAD is not pushed to origin"))
  #expect(result.output.contains(remoteHead))
}

@Test func publishPreflightFailsWhenReleaseTagAlreadyExistsOnOrigin() throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  try "let released = true\n".write(to: source, atomically: true, encoding: .utf8)
  try runProcess("/usr/bin/git", ["add", "Probe.swift"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "Release commit"],
    in: repository
  )
  let head = try runProcess("/usr/bin/git", ["rev-parse", "HEAD"], in: repository)
    .output
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let tag = "v1.2.3"
  try runProcess("/usr/bin/git", ["remote", "add", "origin", "https://github.com/kingkyylian/flowline.git"], in: repository)

  let fakeBin = try temporaryDirectory()
  let fakeRTK = fakeBin.appendingPathComponent("rtk")
  try """
  #!/usr/bin/env bash
  if [[ "$1" == "git" && "$2" == "ls-remote" && "$3" == "--exit-code" && "$4" == "origin" && "$5" == "HEAD" ]]; then
    printf '%s\\tHEAD\\n' "\(head)"
    exit 0
  fi

  if [[ "$1" == "git" && "$2" == "ls-remote" && "$3" == "--exit-code" && "$4" == "--tags" && "$5" == "origin" && "$6" == "refs/tags/\(tag)" ]]; then
    printf '%s\\trefs/tags/\(tag)\\n' "\(head)"
    exit 0
  fi

  exit 99
  """.write(to: fakeRTK, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeRTK.path)
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(for: archive, version: "1.2.3", gitCommit: head)

  let result = try runPublishPreflight(
    in: repository,
    arguments: ["--tag", tag, "--archive", archive.path],
    pathPrefix: fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release tag already exists on origin: \(tag)"))
}

@Test func publishPreflightRejectsInvalidReleaseTag() throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  try "let released = true\n".write(to: source, atomically: true, encoding: .utf8)
  try runProcess("/usr/bin/git", ["add", "Probe.swift"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "Release commit"],
    in: repository
  )
  let head = try runProcess("/usr/bin/git", ["rev-parse", "HEAD"], in: repository)
    .output
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let tag = "1.2.3"
  try runProcess("/usr/bin/git", ["remote", "add", "origin", "https://github.com/kingkyylian/flowline.git"], in: repository)

  let fakeBin = try temporaryDirectory()
  let fakeRTK = fakeBin.appendingPathComponent("rtk")
  try """
  #!/usr/bin/env bash
  if [[ "$1" == "git" && "$2" == "ls-remote" && "$3" == "--exit-code" && "$4" == "origin" && "$5" == "HEAD" ]]; then
    printf '%s\\tHEAD\\n' "\(head)"
    exit 0
  fi

  exit 99
  """.write(to: fakeRTK, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeRTK.path)

  let result = try runPublishPreflight(
    in: repository,
    arguments: ["--tag", tag],
    pathPrefix: fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release tag is invalid: \(tag)"))
}

@Test func publishPreflightFailsWhenReleaseTagAlreadyExistsLocally() throws {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  try "let released = true\n".write(to: source, atomically: true, encoding: .utf8)
  try runProcess("/usr/bin/git", ["add", "Probe.swift"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "Release commit"],
    in: repository
  )
  let head = try runProcess("/usr/bin/git", ["rev-parse", "HEAD"], in: repository)
    .output
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let tag = "v1.2.3"
  try runProcess("/usr/bin/git", ["tag", tag], in: repository)
  try runProcess("/usr/bin/git", ["remote", "add", "origin", "https://github.com/kingkyylian/flowline.git"], in: repository)

  let fakeBin = try temporaryDirectory()
  let fakeRTK = fakeBin.appendingPathComponent("rtk")
  try """
  #!/usr/bin/env bash
  if [[ "$1" == "git" && "$2" == "ls-remote" && "$3" == "--exit-code" && "$4" == "origin" && "$5" == "HEAD" ]]; then
    printf '%s\\tHEAD\\n' "\(head)"
    exit 0
  fi

  exit 2
  """.write(to: fakeRTK, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeRTK.path)
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(for: archive, version: "1.2.3", gitCommit: head)

  let result = try runPublishPreflight(
    in: repository,
    arguments: ["--tag", tag, "--archive", archive.path],
    pathPrefix: fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release tag already exists locally: \(tag)"))
}

@Test func publishPreflightRequiresReleaseArchiveWhenTagIsProvided() throws {
  let fixture = try releasePreflightFixture()

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release archive is required when using --tag"))
}

@Test func publishPreflightRejectsReleaseArchiveThatDoesNotMatchTag() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.4.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release archive does not match tag: expected Flowline-1.2.3.zip"))
}

@Test func publishPreflightRejectsEmptyReleaseArchive() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try Data().write(to: archive)

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release archive is empty: \(archive.path)"))
}

@Test func publishPreflightAcceptsMatchingReleaseArchiveForReleaseTag() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(for: archive, version: "1.2.3", gitCommit: fixture.head)

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 0)
  #expect(result.output.contains("Publish preflight passed for kingkyylian/flowline"))
}

@Test func publishPreflightRejectsLocalManifestWhenCIArtifactIsRequired() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(for: archive, version: "1.2.3", gitCommit: fixture.head)

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release manifest is not from GitHub Actions"))
}

@Test func publishPreflightRejectsCIManifestWhenWorkflowRunHeadDoesNotMatch() throws {
  let runID = "1234567890"
  let fixture = try releasePreflightFixture(
    githubRun: .init(
      id: runID,
      head: String(repeating: "0", count: 40),
      status: "completed",
      conclusion: "success"
    )
  )
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    githubRepository: "kingkyylian/flowline",
    githubRunID: runID
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("GitHub Actions run head does not match HEAD"))
  #expect(result.output.contains(fixture.head))
}

@Test func publishPreflightRejectsCIManifestWhenWorkflowRunDidNotSucceed() throws {
  let runID = "1234567890"
  let fixture = try releasePreflightFixture(
    githubRun: .init(
      id: runID,
      head: "",
      status: "completed",
      conclusion: "failure"
    )
  )
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    githubRepository: "kingkyylian/flowline",
    githubRunID: runID
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("GitHub Actions run did not succeed: completed failure"))
}

@Test func publishPreflightAcceptsCIManifestWhenWorkflowRunMatchesHead() throws {
  let runID = "1234567890"
  let fixture = try releasePreflightFixture(
    githubRun: .init(
      id: runID,
      head: "",
      status: "completed",
      conclusion: "success"
    )
  )
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    githubRepository: "kingkyylian/flowline",
    githubRunID: runID
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 0)
  #expect(result.output.contains("Publish preflight passed for kingkyylian/flowline"))
}

@Test func publishPreflightRejectsCIManifestWhenArtifactIsRequiredButMissing() throws {
  let runID = "1234567890"
  let fixture = try releasePreflightFixture(
    githubRun: .init(
      id: runID,
      head: "",
      status: "completed",
      conclusion: "success"
    )
  )
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    githubRepository: "kingkyylian/flowline",
    githubRunID: runID
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci", "--require-artifact"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release manifest does not identify a GitHub Actions artifact"))
}

@Test func publishPreflightRejectsCIManifestWhenDownloadedArtifactIsMissingArchive() throws {
  let runID = "1234567890"
  let artifactName = "flowline-release-1.2.3"
  let fixture = try releasePreflightFixture(
    githubRun: .init(
      id: runID,
      head: "",
      status: "completed",
      conclusion: "success"
    ),
    githubArtifact: .init(
      name: artifactName,
      archiveName: "Flowline-1.2.3.zip",
      contents: nil
    )
  )
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    githubRepository: "kingkyylian/flowline",
    githubRunID: runID,
    githubArtifactName: artifactName
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci", "--require-artifact"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("downloaded GitHub Actions artifact does not contain release archive"))
}

@Test func publishPreflightRejectsCIManifestWhenDownloadedArtifactHashDoesNotMatch() throws {
  let runID = "1234567890"
  let artifactName = "flowline-release-1.2.3"
  let fixture = try releasePreflightFixture(
    githubRun: .init(
      id: runID,
      head: "",
      status: "completed",
      conclusion: "success"
    ),
    githubArtifact: .init(
      name: artifactName,
      archiveName: "Flowline-1.2.3.zip",
      contents: "different archive\n"
    )
  )
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    githubRepository: "kingkyylian/flowline",
    githubRunID: runID,
    githubArtifactName: artifactName
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci", "--require-artifact"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("downloaded GitHub Actions artifact sha256 does not match archive"))
}

@Test func publishPreflightAcceptsCIManifestWhenDownloadedArtifactMatchesArchive() throws {
  let runID = "1234567890"
  let artifactName = "flowline-release-1.2.3"
  let fixture = try releasePreflightFixture(
    githubRun: .init(
      id: runID,
      head: "",
      status: "completed",
      conclusion: "success"
    ),
    githubArtifact: .init(
      name: artifactName,
      archiveName: "Flowline-1.2.3.zip",
      contents: "archive\n"
    )
  )
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    githubRepository: "kingkyylian/flowline",
    githubRunID: runID,
    githubArtifactName: artifactName
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path, "--require-ci", "--require-artifact"],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 0)
  #expect(result.output.contains("Publish preflight passed for kingkyylian/flowline"))
}

@Test func publishPreflightRequiresReleaseManifestForReleaseArchive() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release manifest does not exist"))
}

@Test func publishPreflightRejectsReleaseManifestVersionMismatch() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(for: archive, version: "1.2.4", gitCommit: fixture.head)

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release manifest version does not match tag: expected 1.2.3, found 1.2.4"))
}

@Test func publishPreflightRejectsReleaseManifestGitCommitMismatch() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(for: archive, version: "1.2.3", gitCommit: String(repeating: "0", count: 40))

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release manifest git commit does not match HEAD"))
  #expect(result.output.contains(fixture.head))
}

@Test func publishPreflightRejectsReleaseManifestChecksumMismatch() throws {
  let fixture = try releasePreflightFixture()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)
  try writeReleaseManifest(
    for: archive,
    version: "1.2.3",
    gitCommit: fixture.head,
    sha256: String(repeating: "0", count: 64)
  )

  let result = try runPublishPreflight(
    in: fixture.repository,
    arguments: ["--tag", fixture.tag, "--archive", archive.path],
    pathPrefix: fixture.fakeBin.path
  )

  #expect(result.status == 2)
  #expect(result.output.contains("release manifest sha256 does not match archive"))
}

@Test func publishPreflightRejectsReleaseArchiveWithoutReleaseTag() throws {
  let repository = try temporaryGitRepository()
  let archive = try temporaryDirectory().appendingPathComponent("Flowline-1.2.3.zip")
  try "archive\n".write(to: archive, atomically: true, encoding: .utf8)

  let result = try runPublishPreflight(
    in: repository,
    arguments: ["--archive", archive.path]
  )

  #expect(result.status == 2)
  #expect(result.output.contains("--archive requires --tag"))
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

  func manifestPath(version: String) -> URL {
    project.appendingPathComponent("dist/release/Flowline-\(version).manifest")
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

private struct ReleasePreflightFixture {
  let repository: URL
  let tag: String
  let head: String
  let fakeBin: URL
}

private struct FakeGitHubRun {
  let id: String
  let head: String
  let status: String
  let conclusion: String
}

private struct FakeGitHubArtifact {
  let name: String
  let archiveName: String
  let contents: String?
}

private func releasePreflightFixture(
  tag: String = "v1.2.3",
  githubRun: FakeGitHubRun? = nil,
  githubArtifact: FakeGitHubArtifact? = nil
) throws -> ReleasePreflightFixture {
  let repository = try temporaryGitRepository()
  let source = repository.appendingPathComponent("Probe.swift")
  try "let released = true\n".write(to: source, atomically: true, encoding: .utf8)
  try runProcess("/usr/bin/git", ["add", "Probe.swift"], in: repository)
  try runProcess(
    "/usr/bin/git",
    ["-c", "user.name=Flowline Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "Release commit"],
    in: repository
  )
  let head = try runProcess("/usr/bin/git", ["rev-parse", "HEAD"], in: repository)
    .output
    .trimmingCharacters(in: .whitespacesAndNewlines)
  try runProcess("/usr/bin/git", ["remote", "add", "origin", "https://github.com/kingkyylian/flowline.git"], in: repository)

  let fakeBin = try temporaryDirectory()
  let fakeRTK = fakeBin.appendingPathComponent("rtk")
  let fakeGitHubRunBlock: String
  if let githubRun {
    let runHead = githubRun.head.isEmpty ? head : githubRun.head
    let fakeGitHubArtifactBlock: String
    if let githubArtifact {
      let writeArtifactBlock: String
      if let contents = githubArtifact.contents {
        writeArtifactBlock = """
        printf '%s' "\(contents)" > "$download_dir/\(githubArtifact.archiveName)"
        """
      } else {
        writeArtifactBlock = ""
      }
      fakeGitHubArtifactBlock = """

      if [[ "$1" == "gh" && "$2" == "run" && "$3" == "download" && "$4" == "\(githubRun.id)" ]]; then
        download_name=""
        download_dir=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --name)
              shift
              download_name="$1"
              ;;
            --dir)
              shift
              download_dir="$1"
              ;;
          esac
          shift
        done
        test "$download_name" = "\(githubArtifact.name)"
        test -n "$download_dir"
        mkdir -p "$download_dir"
        \(writeArtifactBlock)
        exit 0
      fi
      """
    } else {
      fakeGitHubArtifactBlock = ""
    }
    fakeGitHubRunBlock = """

    if [[ "$1" == "gh" && "$2" == "run" && "$3" == "view" && "$4" == "\(githubRun.id)" ]]; then
      printf '%s\\t%s\\t%s\\n' "\(runHead)" "\(githubRun.status)" "\(githubRun.conclusion)"
      exit 0
    fi
    \(fakeGitHubArtifactBlock)
    """
  } else {
    fakeGitHubRunBlock = ""
  }
  try """
  #!/usr/bin/env bash
  if [[ "$1" == "git" && "$2" == "ls-remote" && "$3" == "--exit-code" && "$4" == "origin" && "$5" == "HEAD" ]]; then
    printf '%s\\tHEAD\\n' "\(head)"
    exit 0
  fi

  if [[ "$1" == "git" && "$2" == "ls-remote" && "$3" == "--exit-code" && "$4" == "--tags" && "$5" == "origin" && "$6" == "refs/tags/\(tag)" ]]; then
    exit 2
  fi
  \(fakeGitHubRunBlock)

  exit 99
  """.write(to: fakeRTK, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeRTK.path)

  return ReleasePreflightFixture(repository: repository, tag: tag, head: head, fakeBin: fakeBin)
}

private func writeReleaseManifest(
  for archive: URL,
  version: String,
  gitCommit: String,
  archiveName: String? = nil,
  sha256: String? = nil,
  sizeBytes: Int? = nil,
  githubRepository: String? = nil,
  githubRunID: String? = nil,
  githubArtifactName: String? = nil
) throws {
  let manifest = archive.deletingPathExtension().appendingPathExtension("manifest")
  let resolvedArchiveName = archiveName ?? archive.lastPathComponent
  let resolvedSHA256: String
  if let sha256 {
    resolvedSHA256 = sha256
  } else {
    resolvedSHA256 = try releaseArchiveSHA256(archive)
  }
  let resolvedSizeBytes: Int
  if let sizeBytes {
    resolvedSizeBytes = sizeBytes
  } else {
    resolvedSizeBytes = try releaseArchiveSizeBytes(archive)
  }
  let githubFields: String
  if let githubRepository, let githubRunID {
    let artifactFields = githubArtifactName.map { "github_artifact_name=\($0)\n" } ?? ""
    githubFields = """
    github_repository=\(githubRepository)
    github_run_id=\(githubRunID)
    github_run_attempt=1
    github_workflow=CI
    github_server_url=https://github.com
    \(artifactFields)
    """
  } else {
    githubFields = ""
  }

  try """
  flowline_release_manifest=1
  archive_name=\(resolvedArchiveName)
  version=\(version)
  build=1
  bundle_id=dev.kyylian.flowline.tests
  git_commit=\(gitCommit)
  sha256=\(resolvedSHA256)
  size_bytes=\(resolvedSizeBytes)
  notarized=false
  \(githubFields)
  """.write(to: manifest, atomically: true, encoding: .utf8)
}

private func releaseArchiveSHA256(_ archive: URL) throws -> String {
  let result = try runProcess(
    "/usr/bin/shasum",
    ["-a", "256", archive.path],
    in: archive.deletingLastPathComponent()
  )
  return result
  .output
  .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
  .first
  .map(String.init) ?? ""
}

private func releaseArchiveSizeBytes(_ archive: URL) throws -> Int {
  let attributes = try FileManager.default.attributesOfItem(atPath: archive.path)
  return (attributes[.size] as? NSNumber)?.intValue ?? 0
}

private func runPublishPreflight(
  in directory: URL,
  arguments: [String] = [],
  pathPrefix: String? = nil
) throws -> ProcessResult {
  let script = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("script/publish_preflight.sh")
  return try runProcess(
    "/usr/bin/env",
    ["bash", script.path] + arguments,
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
