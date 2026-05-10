# Flowline Release Checklist

## Blockers

- Package with `script/package_release.sh`, not `script/build_and_run.sh`.
- Sign release builds with `Developer ID Application` identity.
- Keep hardened runtime enabled through `codesign --options runtime`.
- Notarize the release archive and staple the ticket before distribution.
- Verify Gatekeeper on a clean machine or a fresh macOS user account.

## Commands

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
```
