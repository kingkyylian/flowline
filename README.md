# Flowline

[![CI](https://github.com/kingkyylian/flowline/actions/workflows/ci.yml/badge.svg)](https://github.com/kingkyylian/flowline/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/swift-6.0-orange.svg)
![macOS](https://img.shields.io/badge/macos-14%2B-black.svg)
![Status](https://img.shields.io/badge/status-early%20preview-6b7280.svg)

Flowline is a local-first macOS context layer for developer workflows. It sits at the top edge of the screen and changes with the active app, current developer context, next calendar event, music state, and temporary shelf items.

Flowline is an early preview. The MVP is usable from source, but there is no public binary release, Homebrew cask, or stable plugin API yet.

## Why This Exists

Developer work already has context: the app in focus, the branch you are on, the next meeting, the music you paused, and the temporary links or files you need for the next task. Flowline keeps that context local and visible without sending it to a cloud dashboard.

## MVP

- Native SwiftUI/AppKit macOS app.
- Floating top-edge overlay with collapsed and expanded states.
- Active app context with optional Accessibility-powered window titles.
- Developer context for known coding apps and local git status.
- Music controls with Spotify/Apple Music now-playing metadata when available.
- Optional Calendar Next with local EventKit access and meeting URL detection.
- Session-only Shelf for copied text, links, and dropped files.
- Settings for privacy permissions, overlay modules, launch behavior, and fullscreen behavior.

## Quick Start

Build and launch the local debug app:

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```

Run the Swift package tests:

```bash
swift test
```

## Privacy

Flowline is local-first:

- No server.
- No AI calls.
- No telemetry.
- Clipboard items are session-only.
- Calendar access is optional and only used when the Calendar module is enabled.
- Accessibility access is optional and only used for active window context.
- Music metadata uses local Apple Events for Spotify/Music; macOS may ask for Automation permission the first time it reads now-playing details.

## Architecture Notes

- `FlowlineCore` owns deterministic models, parsers, URL detection, git status parsing, shelf state, and display geometry.
- `FlowlineApp` owns the SwiftUI/AppKit overlay, permission surfaces, local macOS integrations, settings, and module presentation.
- Tests cover the core parsers, presentation helpers, permission surfaces, shelf behavior, layout calculations, and local service boundaries.

For stable macOS Accessibility permissions during local development, sign with a stable code-signing identity:

```bash
FLOWLINE_CODESIGN_IDENTITY="Developer ID Application: Your Name" ./script/build_and_run.sh
```

If no identity is available, the script falls back to ad-hoc signing and macOS may require Accessibility to be re-granted after rebuilds.

Run tests:

```bash
swift test
```

Scan the current tree, ignored files, and reachable git history for high-risk
secrets such as OAuth client values, AI API keys, GitHub tokens, Slack tokens,
AWS access keys, and long sensitive assignments:

```bash
script/secret_scan.sh
```

Check publish readiness before pushing:

```bash
script/publish_preflight.sh
```

Before creating a release tag, include the intended version tag:

```bash
script/publish_preflight.sh --tag v0.1.0 --archive dist/release/Flowline-0.1.0.zip
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

- First signed preview release with CI-backed build/test evidence.
- Capsule-style static modules for Codex, Claude, GitHub, Linear, and design workflows.
- Plugin SDK after the native MVP is stable.
- GitHub release and Homebrew cask distribution.
- Optional Pro features after the open-core foundation is useful on its own.
