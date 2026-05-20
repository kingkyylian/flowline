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
