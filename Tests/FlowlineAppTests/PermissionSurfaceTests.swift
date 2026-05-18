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
