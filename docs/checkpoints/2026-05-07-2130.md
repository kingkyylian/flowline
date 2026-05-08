# Project Checkpoint - 2026-05-07 21:30

## Project

- Root: `/Users/kyylian/flowline`
- Git: `main`, no commits yet; project files are currently untracked.
- Context: Flowline is a SwiftPM macOS notch overlay app. Current priority is making the collapsed notch visually disappear into the physical MacBook notch, while hover reveals useful AI limit percentages.

## Done This Session

- Reworked notch positioning and sizing around the real macOS camera housing geometry.
- Measured current built-in display notch from `NSScreen`:
  - frame: `(0, 0, 1470, 956)`
  - auxiliary top left: `(0, 924, 646, 32)`
  - auxiliary top right: `(825, 924, 645, 32)`
  - physical notch gap: `x=646...825`, `width=179`, `height=32`, center `735.5`
- Added `DisplayNotchGeometry.housingFrame(...)` and tests.
- Changed collapsed notch width from fixed `214` to measured physical notch width.
- Kept hover wing independent from physical notch size:
  - current hover width: `235`
  - current hover percent offsets: `±100`
  - percent font: `8`
  - percent metric frame: `36`
- Added real AI usage model and parsers:
  - Codex from `chatgpt.com/backend-api/wham/usage`
  - Claude from `api.anthropic.com/api/oauth/usage`
  - Gemini from `cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`
- Replaced old Codex-only usage service with `AIUsageService`.
- Small collapsed notch now reads real Codex session/weekly values from `AIUsageSnapshot`.
- Added color rules for collapsed percentages:
  - `%100`: green
  - `%11...%99`: white
  - `%10 and below`: red
- Made expanded panel more functional:
  - middle column changed from confusing `AGENT` wording to `LIMITS`
  - provider rows show compact quota chips
  - added `Copy context`
  - added `Refresh limits`
- Added `ContextSummaryBuilder` for copy-context output and a focused test.

## Current State

- App builds and runs.
- Latest app bundle has been rebuilt and relaunched successfully.
- Collapsed state should now sit exactly over the real physical notch on this MacBook.
- Hover opens a narrow `235px` wing area and shows real Codex percentages at `±100`.
- All repository files are still uncommitted/untracked because there is no initial commit.

## Important Files / Artifacts

- `Sources/FlowlineCore/Models/DisplayNotchGeometry.swift`: notch center and measured housing frame logic.
- `Tests/FlowlineCoreTests/DisplayNotchGeometryTests.swift`: center/housing frame tests, including current `179x32` physical notch case.
- `Sources/FlowlineApp/Models/NotchMetrics.swift`: current notch constants; `hoverWidth = 235`.
- `Sources/FlowlineApp/App/OverlayController.swift`: reads `NSScreen` auxiliary top areas and updates physical notch size in state.
- `Sources/FlowlineApp/App/OverlayHostingView.swift`: collapsed hit-test now uses physical notch size or hover width.
- `Sources/FlowlineApp/Stores/AppState.swift`: owns physical notch dimensions, AI usage snapshot, refresh/copy actions.
- `Sources/FlowlineApp/Views/Overlay/OverlayRootView.swift`: collapsed visual surface uses physical notch dimensions.
- `Sources/FlowlineApp/Views/Overlay/CollapsedPillView.swift`: percent offsets, font, colors, real Codex values.
- `Sources/FlowlineApp/Views/Overlay/ExpandedBarView.swift`: expanded `LIMITS` panel, chips, copy/refresh buttons.
- `Sources/FlowlineApp/Services/AIUsageService.swift`: reads CodexBar CFURLCache SQLite data for Codex/Claude/Gemini.
- `Sources/FlowlineCore/Models/CodexUsageSnapshot.swift`: AI usage provider/window models and parsers.
- `Sources/FlowlineCore/Support/ContextSummaryBuilder.swift`: copy-context summary generation.

## Verification

- Command: `rtk swift test`
- Result: passed, 21 tests, after physical notch geometry/state changes.

- Command: `rtk swift build`
- Result: passed after latest collapsed percentage color/offset/font work.

- Command: `rtk ./script/build_and_run.sh --verify`
- Result: passed after latest changes, `Flowline is running`.

## Open Questions / Risks

- Latest full `swift test` was before the last tiny percent color/offset-only UI tweaks; latest `swift build` and app verify passed after them.
- User should visually inspect the current `235 / ±100 / font 8` hover state; the next likely changes are small visual calibration only.
- `AIUsageService` depends on CodexBar cache files being present at `~/Library/Caches/com.steipete.codexbar/Cache.db`; without cache, usage rows are absent.
- Repo has no initial commit; future sessions must preserve all untracked files and avoid destructive git operations.
- There is no `AGENTS.md` file in the repo root, but the user provided AGENTS-style instructions in conversation. Key rules: Turkish, short, use `rtk`, verify before done, do not revert unrelated changes.

## Next Steps

1. Ask user to confirm current visual notch alignment after the latest relaunch.
2. If hover still feels off, only tune `NotchMetrics.hoverWidth` and the two hover offsets in `CollapsedPillView`.
3. If expanded panel still feels busy, reduce `CONTEXT`/`SHELF` prominence or hide them behind icons.
4. Consider adding a settings/debug line showing measured physical notch width/height only in development builds.
5. Once the UI stabilizes, create the first git commit so the all-untracked baseline is no longer fragile.

## Resume Prompt

Continue from this checkpoint. First read this file and the project instructions supplied by the user, then inspect `NotchMetrics.swift`, `CollapsedPillView.swift`, `OverlayRootView.swift`, `OverlayHostingView.swift`, and `OverlayController.swift` before changing notch behavior. Preserve the current physical notch model: collapsed width comes from measured housing frame, hover width is a separate visual wing.
