# Security Policy

Flowline is a local-first macOS app. It reads local developer context, optional
window titles, optional calendar metadata, optional music metadata, and
session-only shelf items. It should not send this data to a server.

## Reporting a Vulnerability

Please do not open public issues for security reports.

Use GitHub's private vulnerability reporting flow if it is available for this
repository. If it is not available, contact the maintainer privately through the
GitHub profile.

Include:

- affected Flowline version or commit
- macOS version
- enabled modules and permissions
- reproduction steps
- expected and observed behavior
- screenshots or logs with private data removed

## Scope

Security-sensitive areas include:

- Accessibility, Calendar, Automation, and clipboard permission handling
- session-only shelf storage and cleanup
- local git and active app context collection
- release signing, hardened runtime, notarization, and artifact verification
- accidental telemetry, network calls, or persistence of private context

Reports showing unexpected network access, private context leakage, unsafe file
handling, or release integrity failures are in scope.

## Supported Versions

Flowline is currently an early preview. Security fixes target the current
`main` branch until public binary releases begin.
