# Flowline Design System

Flowline is a local-first macOS context layer for developer workflows. The UI should feel native, quiet, compact, and utility-grade: visible when needed, out of the way when not needed.

## Product Pattern

- Product type: macOS productivity utility, developer workflow overlay.
- Primary surface: top-edge floating overlay with collapsed and expanded states.
- Secondary surface: native macOS Settings window.
- Audience: developers working across terminal, editor, calendar, browser, and local files.

## Visual Direction

- Use restrained system materials, semantic colors, and SF Symbols.
- Keep the overlay compact, but preserve clear hit targets for icon actions.
- Avoid decorative gradients, neon color, heavy shadows, emoji icons, and oversized cards.
- In notch mode, black can remain the anchor surface; content must keep high contrast.
- In companion mode, prefer system-adaptive foregrounds over fixed black/white.

## Layout Rules

- Collapsed state should communicate status, current context, and expand affordance in one scan.
- Expanded state should use three clear modules: Now, Agent, Shelf.
- Modules should have consistent internal spacing, header treatment, and action placement.
- Text should wrap or truncate predictably; no dynamic text should resize the overlay.
- Icon-only actions need a visible hover/press region and an accessibility label.

## Typography

- Use SF system fonts.
- Keep monospaced text for developer/status metadata only.
- Use semibold for primary context, medium for labels, regular for secondary detail.
- Use tabular digits for numeric settings and counters.

## Interaction

- Hover feedback should be subtle but visible within 100ms.
- Destructive actions, such as removing shelf items, must be visually distinguishable and have a label/help string.
- Permission rows must show state with text plus symbol, not color alone.
- Settings should remain native: grouped Form, segmented picker, toggles, sliders.

## Accessibility

- Keep contrast readable in both notch and companion modes.
- Do not rely on color alone for warnings, permissions, or status.
- Preserve keyboard and VoiceOver labels for all icon-only actions.
- Avoid tiny unlabelled controls inside the overlay.
