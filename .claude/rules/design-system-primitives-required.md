# Design System Primitives — Required For Product Screens

> **Rule (CEO directive 2026-06-24):** Standard UI on product screens MUST use the `M*` primitive library at `auxi/src/components/design-system/lib/`. No new bespoke buttons/inputs/switches/dialogs/sheets/rows/chips when an `M*` exists. One import → render.

## Why
Product screens were built ad-hoc (≈214 raw Pressable, 27 raw TextInput, 18 PillButton, 6 modal styles → inconsistent "loạn"). The `M*` lib (GH-364) is the single source for crafted, animated, on-system, a11y-correct components.

## The rule
- For: button, icon button, text input, switch, checkbox, radio, dialog, bottom sheet, action sheet, list/settings row, chip, badge, tag, status, segmented, tabs, divider, avatar → import the matching `M*` from `src/components/design-system/lib` and render it.
- Do NOT hand-roll these with raw `TouchableOpacity`/`Pressable`/`TextInput`/`Switch`/`Modal` when an `M*` exists.
- Raw RN primitives allowed ONLY when no `M*` fits — justify it in the PR/handoff.
- Pass `testID` + `accessibilityLabel` to the `M*` (they accept pass-through).
- Feature-specific composites (OutfitCard, SkeletonTile, mood grids) MAY stay bespoke — they are not generic primitives.

## When this applies
Any new/edited UI on `auxi/src/screens/**` and `auxi/src/components/{features,layout}/**`.

## When it does NOT apply (yet)
- The `M*` lib itself (`auxi/src/components/design-system/**`).
- Auth/UAC dark screens until DS dark roles land (Phase 1 of the migration plan).
- Pure logic / service / data changes.

## Enforcement
- Lint: `auxi/scripts/auxi-lint-ds-primitives.sh` — **warn-mode now** (Phase 0); flips to **error** at Phase 4 (PR gate).
- The `mobile-dev` agent carries this as a mandatory section.

## Related
- Lib + barrel: `auxi/src/components/design-system/lib/index.ts`
- Migration plan: `plans/260624-1110-GH-364-ds-primitive-migration/plan.md`
- Token unification (theme.ts → m-tokens, app-wide) is staged in that plan (Phase 1).
