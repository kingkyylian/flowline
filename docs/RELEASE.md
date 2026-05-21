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
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID)" \
  script/package_release.sh --preflight
```

Build a signed release archive:

```bash
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID)" \
  script/package_release.sh --archive
```

Build, submit to Apple notarization, staple, and re-archive:

```bash
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID)" \
FLOWLINE_NOTARY_PROFILE="flowline-notary" \
  script/package_release.sh --notarize
```

`--notarize` validates both the Developer ID identity and notary credentials
before starting the release build.

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
Actions run succeeded for the same `HEAD`.

When the release archive was produced and uploaded by GitHub Actions, set
`GITHUB_ARTIFACT_NAME` before packaging so the release manifest records the
artifact name, then use the stricter artifact gate:

```bash
GITHUB_ARTIFACT_NAME=flowline-release-v0.1.0 script/package_release.sh --notarize
script/publish_preflight.sh --tag v0.1.0 --archive dist/release/Flowline-0.1.0.zip --require-ci --require-artifact
```

`--require-artifact` downloads that artifact from the manifest's workflow run
and verifies the downloaded `Flowline-X.Y.Z.zip` hash matches the archive being
tagged.
