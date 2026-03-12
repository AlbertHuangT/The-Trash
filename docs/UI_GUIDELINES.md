# UI Guidelines

## Summary

Smart Sort uses a shared SwiftUI design system built around `TrashTheme`.

The goal is consistency, maintainability, and predictable visual rhythm across Verify, Arena, Community, Leaderboard, Account, and admin surfaces.

Core rule:

- use theme tokens and shared primitives first
- avoid feature-local visual systems unless the theme layer is extended first

## Design System Rules

### Theme Access

- Views should consume theme through `@Environment(\.trashTheme)`
- Do not instantiate `TrashTheme()` inside feature views
- App composition, previews, and test scaffolding are the only acceptable places to create a fresh theme instance

### Grid And Rhythm

The app uses:

- 8pt primary grid
- 4pt secondary grid for compact internal adjustments only

Preferred layout rhythm:

- `screenInset = 16`
- `sectionSpacing = 24`
- `elementSpacing = 12`
- `rowContentSpacing = 12`
- `sheetActionSpacing = 12`

Use theme tokens instead of raw literals for:

- `padding`
- `spacing`
- `frame(minHeight:)`
- input insets
- card insets

## Typography

Use the shared text role system from `TrashTheme`:

- `display`: countdowns, score moments, win states
- `title`: page/sheet/empty-state primary titles
- `headline`: card titles, dialog titles, quiz prompts
- `subheadline`: compact emphasized supporting text
- `body`: standard explanatory copy
- `caption`: metadata, helper text, pills
- `button`: tappable labels and segmented labels
- `kicker`: uppercase section labels only

Rules:

- avoid direct `.font(.system(...))` in feature views
- avoid re-creating uppercase section labels by hand
- let the shared role determine default line limit and scaling behavior

## Component Metrics

Current baseline metrics:

- minimum hit target: `44`
- icon button: `44`
- segmented control height: `44`
- compact control height: `32`
- pill height: `44`
- button height: `52`
- input height: `52`
- standard row height: `52`
- card padding: `16`
- sheet padding: `24`

Current radius family:

- small: `12`
- medium: `16`
- large: `20`
- pill: `22`

## Information Hierarchy

Every interactive surface should respect an information budget:

- `1` primary information item
- up to `2` secondary information items

Apply this especially to:

- compact cards
- rows
- pills
- leaderboard cells
- event/community summaries

If a surface needs more than that, split the information into:

- a secondary region
- a detail screen
- an expanded sheet

## Shared Primitives

Prefer these before building feature-local controls:

- `TrashButton`
- `TrashPill`
- `TrashIconButton`
- `TrashTextButton`
- `TrashSegmentedControl`
- `TrashCard`
- `TrashForm*`
- `TrashLabel`

If a feature needs a new repeated UI pattern:

- add or extend a shared primitive first
- then compose it inside the feature

## Background, Color, And Surface Rules

- Use `ThemeBackgroundView` / `.trashScreenBackground()` for screen backgrounds
- Use theme semantic colors for status states
- Use theme surface tokens for cards, pills, sheets, and inputs
- Do not introduce ad hoc feature-specific gradients or shadows when a named theme token can express the same role

## Do / Don't

### Do

- use `trashTextRole(...)` for text hierarchy
- use theme spacing/layout/component tokens
- reuse shared controls for repeated patterns
- keep compact surfaces visually quiet and scannable

### Don't

- write feature-local `TrashTheme()` instances
- use raw spacing values when a token exists
- use direct system font declarations in feature views
- overload cards with too many badges, metadata lines, and actions
- rebuild pills/cards/hero surfaces with slightly different spacing and radii in each feature

## Review Checklist

Before shipping a UI change, check:

- Is theme read from environment?
- Are spacing and sizing token-driven?
- Does the surface fit the `1 primary + 2 secondary` rule?
- Is typography using shared roles?
- Could this visual pattern have been built with an existing primitive?

If the answer is no, fix the design-system boundary before merging.
