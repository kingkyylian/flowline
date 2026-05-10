# Flowline

Flowline is a local-first macOS context layer for developer workflows. It sits at the top edge of the screen and changes with the active app, current developer context, next calendar event, and temporary shelf items.

## MVP

- Native SwiftUI/AppKit macOS app.
- Floating top-edge overlay with collapsed and expanded states.
- Active app context with optional Accessibility-powered window titles.
- Developer context for known coding apps and local git status.
- Music controls with Spotify/Apple Music now-playing metadata when available.
- Optional Calendar Next with local EventKit access and meeting URL detection.
- Session-only Shelf for copied text, links, and dropped files.
- Settings for privacy permissions, overlay modules, launch behavior, and fullscreen behavior.

## Privacy

Flowline is local-first:

- No server.
- No AI calls.
- No telemetry.
- Clipboard items are session-only.
- Calendar access is optional and only used when the Calendar module is enabled.
- Accessibility access is optional and only used for active window context.
- Music metadata uses local Apple Events for Spotify/Music; macOS may ask for Automation permission the first time it reads now-playing details.

## Build

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```

For stable macOS Accessibility permissions during local development, sign with a stable code-signing identity:

```bash
FLOWLINE_CODESIGN_IDENTITY="Developer ID Application: Your Name" ./script/build_and_run.sh
```

If no identity is available, the script falls back to ad-hoc signing and macOS may require Accessibility to be re-granted after rebuilds.

Run tests:

```bash
swift test
```

## Release

Local debug bundles are built with `script/build_and_run.sh`. Distributable
archives must use the release packaging script, a Developer ID Application
certificate, hardened runtime, and notarization:

```bash
FLOWLINE_DEVELOPER_ID_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  script/package_release.sh --archive
```

See `docs/RELEASE.md` for notarization and manual QA checks.

## Roadmap

- Capsule-style static modules for Codex, Claude, GitHub, Linear, and design workflows.
- Plugin SDK after the native MVP is stable.
- GitHub release and Homebrew cask distribution.
- Optional Pro features after the open-core foundation is useful on its own.
