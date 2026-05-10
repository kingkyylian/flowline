import Testing
@testable import FlowlineCore

@Test func parsesCleanBranchStatus() throws {
  let status = GitStatusParser.parse(
    branchOutput: "main\n",
    porcelainOutput: ""
  )

  #expect(status.branch == "main")
  #expect(status.isDirty == false)
  #expect(status.repositoryName == nil)
}

@Test func parsesDirtyBranchStatus() throws {
  let status = GitStatusParser.parse(
    branchOutput: "feature/context\n",
    porcelainOutput: " M Sources/App.swift\n?? README.md\n"
  )

  #expect(status.branch == "feature/context")
  #expect(status.isDirty == true)
}

@Test func usesDetachedWhenBranchIsEmpty() throws {
  let status = GitStatusParser.parse(
    branchOutput: "\n",
    porcelainOutput: ""
  )

  #expect(status.branch == "detached")
  #expect(status.isDirty == false)
}
