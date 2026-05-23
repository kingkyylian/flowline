# Project Checkpoint - 2026-05-23 17:13 +03

## Project

- Root: `/Users/kyylian/flowline`
- Git: branch `main`, synchronized with `origin/main`
- Baseline commit before this release-blocker checkpoint:
  - `ecffe6d Record live hold QA checkpoint`
- Context: Hold left-only code, live Settings QA, live About link QA, checkpoint update, push, and CI are complete. Release-candidate execution is now narrowed to missing external Apple/GitHub credentials.

## Done This Session

- Committed and pushed the live QA checkpoint:
  - `ecffe6d Record live hold QA checkpoint`
- Watched the new GitHub Actions CI run for `ecffe6d`:
  - Run `26334859976`
  - Workflow `CI`
  - Result `success`
- Recorded and pushed the release-candidate blocker checkpoint:
  - `ccd0b93 Record release candidate blocker checkpoint`
- Watched the GitHub Actions CI run for `ccd0b93`:
  - Run `26334984301`
  - Workflow `CI`
  - Result `success`
- Checked release-candidate prerequisites instead of assuming them:
  - Local Keychain has one codesigning identity: `Apple Development: bwib3927@outlook.com (G953CU4G2L)`.
  - No local `Developer ID Application` identity is installed.
  - GitHub Actions repository secrets query returned no configured secret names.
  - The release-candidate workflow requires Developer ID certificate, keychain password, Developer ID identity, Apple ID, Team ID, and app-specific password secrets.

## Current State

- `main` is pushed and synchronized with `origin/main`.
- Working tree is clean.
- Flowline is still running locally from `dist/Flowline.app`.
- Hold left-only behavior is implemented, tested, CI-green, and live-QA verified.
- About links are live-QA verified.
- Real notarized release-candidate execution is blocked by missing external credentials, not by current source code.

## Important Files / Artifacts

- `docs/checkpoints/2026-05-23-1707.md`: live Settings and About QA checkpoint.
- `docs/checkpoints/LATEST.md`: updated to this checkpoint.
- `.github/workflows/release-candidate.yml`: defines the required release candidate secrets and notarized packaging flow.
- `docs/RELEASE.md`: documents the local and CI notarization requirements.
- `script/package_release.sh`: enforces Developer ID and notary credential preflight checks.

## Verification

- Command: `rtk gh run watch 26334859976 --repo kingkyylian/flowline --exit-status`
  - Result: passed; CI completed successfully in `2m50s`.
- Command: `rtk gh run watch 26334984301 --repo kingkyylian/flowline --exit-status`
  - Result: passed; CI completed successfully in `2m51s`.
- Command: `rtk security find-identity -v -p codesigning`
  - Result: only `Apple Development: bwib3927@outlook.com (G953CU4G2L)` is available; no `Developer ID Application` identity is installed.
- Command: `rtk gh api repos/kingkyylian/flowline/actions/secrets --jq '.secrets[].name'`
  - Result: passed with no output; no repository Actions secrets are currently listed.
- Command: `git status --short --branch`
  - Result before this checkpoint edit: `## main...origin/main`.

## Open Questions / Risks

- Release-candidate workflow cannot produce a notarized candidate until these repository secrets are configured:
  - `FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64`
  - `FLOWLINE_DEVELOPER_ID_CERTIFICATE_PASSWORD`
  - `FLOWLINE_DEVELOPER_ID_IDENTITY`
  - `FLOWLINE_KEYCHAIN_PASSWORD`
  - `APPLE_ID`
  - `APPLE_TEAM_ID`
  - `APPLE_APP_SPECIFIC_PASSWORD`
- Local notarized packaging also requires an installed `Developer ID Application` identity or a CI import path with the certificate secret.
- Historical checkpoint files may still mention older right-slot Hold behavior; treat the latest checkpoint and source/tests as authoritative.

## Next Steps

1. Configure the required GitHub Actions release secrets.
2. Run the `Release Candidate` workflow from `main` with the intended tag, for example `v0.1.0`.
3. Run `Release Candidate Verify` / publish preflight against the uploaded notarized artifact before creating a public release tag.

## Project Rules For Resume

- Use `rtk` for noisy shell commands.
- Keep Turkish communication short and concrete.
- Protect dirty worktree state.
- Prefer TDD for behavior changes.
- Do not claim completion without fresh verification.
- No local `AGENTS.md` file exists in the repo; active instructions come from the conversation and user `.codex` files.

## Resume Prompt

Continue from this checkpoint. First inspect `rtk git status -sb`, `rtk git log --oneline -5`, `docs/checkpoints/LATEST.md`, `.github/workflows/release-candidate.yml`, `docs/RELEASE.md`, and the latest GitHub Actions run for `main`. The Hold left-only fix and live QA are complete and CI-green. The remaining release-candidate blocker is external Apple Developer ID/notary credential configuration.
