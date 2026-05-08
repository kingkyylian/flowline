import Foundation

public enum GitStatusParser {
  public static func parse(branchOutput: String, porcelainOutput: String) -> GitStatus {
    let branch = branchOutput
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return GitStatus(
      branch: branch.isEmpty ? "detached" : branch,
      isDirty: !porcelainOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    )
  }
}
