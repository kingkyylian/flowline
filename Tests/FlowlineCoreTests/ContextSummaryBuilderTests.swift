import Foundation
import Testing
@testable import FlowlineCore

@Test func buildsContextSummaryWithGitUsageAndShelf() {
  let snapshot = ContextSnapshot(
    activeApp: ActiveAppContext(
      name: "Terminal",
      bundleIdentifier: "com.apple.Terminal",
      windowTitle: "flowline"
    ),
    git: GitStatus(branch: "main", isDirty: true),
    nextEvent: nil,
    shelfItems: [
      ShelfItem(kind: .file, title: "README.md", value: "/tmp/README.md", url: nil)
    ],
    permissions: PermissionState(accessibility: .granted, calendar: .granted)
  )
  let usage = AIUsageSnapshot(
    providers: [
      AIProviderUsage(
        provider: .codex,
        primary: AIUsageWindow(label: "Session", percentLeft: 61),
        secondary: AIUsageWindow(label: "Weekly", percentLeft: 78)
      )
    ],
    updatedAt: Date(timeIntervalSince1970: 0)
  )

  let summary = ContextSummaryBuilder.build(snapshot: snapshot, aiUsage: usage)

  #expect(summary == """
    App: Terminal
    Window: flowline
    Git: main dirty
    Codex: Session 61% left, Weekly 78% left
    Shelf: README.md
    """)
}
