# Contributing

Flowline is an early preview macOS app. Contributions should keep the app
local-first, privacy-preserving, and native to macOS.

## Before Opening a PR

- Open or link an issue for non-trivial changes.
- Keep changes focused on one behavior or workflow.
- Avoid adding network services, telemetry, or cloud dependencies.
- Preserve optional permission boundaries for Accessibility, Calendar, and
  Automation access.
- Include the closest useful verification command in the PR description.

## Local Development

Build and launch the debug app:

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```

Run tests:

```bash
swift test
```

Run publish preflight before release-oriented changes:

```bash
script/publish_preflight.sh
```

## Quality Bar

Changes that affect the overlay, permission surfaces, shelf behavior, or release
packaging should include tests or a clear manual verification note. UI changes
should be checked on desktop-scale and compact widths where practical.

## Release Changes

Release packaging, signing, notarization, and GitHub artifact verification are
high-risk areas. Keep those changes small, include command output in the PR, and
do not bypass preflight checks.
