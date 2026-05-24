# Flowline Release Checklist

## Blockers

- Package with `script/package_release.sh`, not `script/build_and_run.sh`.
- Sign release builds with `Developer ID Application` identity.
- Keep hardened runtime enabled through `codesign --options runtime`.
- Notarize the release archive and staple the ticket before distribution.
- Verify Gatekeeper on a clean machine or a fresh macOS user account.

## Commands

Check local release prerequisites before building:

```bash
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID1234)" \
  script/package_release.sh --preflight
```

Build a signed release archive:

```bash
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID1234)" \
  script/package_release.sh --archive
```

Build, submit to Apple notarization, staple, and re-archive:

```bash
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID1234)" \
FLOWLINE_NOTARY_PROFILE="flowline-notary" \
  script/package_release.sh --notarize
```

`--notarize` validates both the Developer ID identity and notary credentials
before starting the release build.

## GitHub Release Candidate

For a CI-built notarized candidate, configure these repository secrets:

- `FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64`
- `FLOWLINE_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `FLOWLINE_DEVELOPER_ID_IDENTITY`
- `FLOWLINE_KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Use the helper to validate and configure them without printing secret values:

```bash
FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH="/path/to/DeveloperIDApplication.p12" \
FLOWLINE_DEVELOPER_ID_CERTIFICATE_PASSWORD="p12-password" \
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID1234)" \
FLOWLINE_KEYCHAIN_PASSWORD="ci-keychain-pw" \
APPLE_ID="apple-id@example.com" \
APPLE_TEAM_ID="TEAMID1234" \
APPLE_APP_SPECIFIC_PASSWORD="app-specific-password" \
  script/configure_release_secrets.sh --repo kingkyylian/flowline
```

Before writing anything, validate local inputs with:

```bash
script/configure_release_secrets.sh --repo kingkyylian/flowline --dry-run
```

After setup, verify only the secret names with:

```bash
script/configure_release_secrets.sh --repo kingkyylian/flowline --check
```

Then dispatch the `Release Candidate` workflow from `main` with the intended
tag, for example `v0.1.0`:

```bash
script/run_release_candidate.sh --repo kingkyylian/flowline --tag v0.1.0
```

This helper refuses to dispatch until publish preflight passes, the tag is still
unused, and `script/configure_release_secrets.sh --check` confirms every
required secret name exists. The workflow also runs the same helper in
`--dry-run` mode before importing the certificate, so CI validates the
Developer ID certificate base64, signing identity prefix, and Apple Team ID
format before touching the signing keychain. It also requires the signing
identity to include the same Team ID used for notarization. The workflow imports
the Developer ID certificate, stores a temporary notary profile, runs
`script/package_release.sh --notarize`, and uploads the zip plus manifest as
`flowline-release-vX.Y.Z`.

After that workflow completes, `Release Candidate Verify` checks out the exact
candidate commit, downloads the uploaded artifact, and runs:

```bash
script/publish_preflight.sh --tag v0.1.0 --archive dist/release/Flowline-0.1.0.zip --require-ci --require-artifact
```

Create or push the release tag only after the verify workflow succeeds.

Validate the shipped app:

```bash
codesign --verify --deep --strict --verbose=2 dist/release/Flowline.app
spctl -a -vv dist/release/Flowline.app
xcrun stapler validate dist/release/Flowline.app
```

## Manual QA

- Accessibility permission prompt and granted-state refresh.
- Calendar disabled: no calendar prompt and no event display.
- Shelf disabled: no clipboard polling and no retained shelf items.
- Spotify and Apple Music automation permission prompts.
- Safari audio keeps playing when Flowline music controls are used.
- Notch mode on a notched display and companion mode on a non-notched display.
- Fullscreen behavior with `Show over fullscreen` off and on.
- Launch at login from an installed `/Applications/Flowline.app` bundle.

## Pre-Tag Checks

```bash
swift test
swift build -c release
git diff --check
script/publish_preflight.sh --tag v0.1.0 --archive dist/release/Flowline-0.1.0.zip --require-ci
```

Use the release version for the tag value. The tag preflight rejects invalid
release tag names, tags that already exist locally or on `origin`, and missing,
mismatched, or empty release archives. It also requires the manifest generated
next to the archive, for example `dist/release/Flowline-0.1.0.manifest`, and
verifies the manifest version, archive name, checksum, size, and git commit.
For public releases, keep `--require-ci`; it verifies the manifest's GitHub
Actions run attempt succeeded for the same `HEAD`.

When the release archive was produced and uploaded by GitHub Actions, set
`FLOWLINE_GITHUB_ARTIFACT_NAME` before packaging so the release manifest records
the artifact name, then use the stricter artifact gate:

```bash
FLOWLINE_GITHUB_ARTIFACT_NAME=flowline-release-v0.1.0 script/package_release.sh --notarize
script/publish_preflight.sh --tag v0.1.0 --archive dist/release/Flowline-0.1.0.zip --require-ci --require-artifact
```

`--require-artifact` downloads that artifact from the manifest's workflow run
and requires both the manifest and GitHub run metadata to come from the
`Release Candidate` workflow with an artifact name matching
`flowline-release-vX.Y.Z`, and requires the manifest to be marked
`notarized=true` before verifying the downloaded `Flowline-X.Y.Z.zip` hash and
`Flowline-X.Y.Z.manifest` content match the files being tagged.
