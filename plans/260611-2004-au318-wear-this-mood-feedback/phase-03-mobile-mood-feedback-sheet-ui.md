---
phase: 3
title: Mobile Mood Feedback Sheet UI
status: completed
priority: P2
effort: 1d
dependencies: []
---

# Phase 3: Mobile Mood Feedback Sheet UI

## Overview

New `MoodFeedbackSheet` component — pure UI shell, no save wiring (that's Phase 4). Clones the
existing `ContextChipsModal` pattern (`auxi/src/components/features/ContextChipsModal.tsx:102-145`):
`<Modal transparent>` + `Animated.View` translateY bottom sheet, selectable chips, gated CTA.
**No Figma exists** — build per ticket spec + existing theme tokens; this decision is documented and
PR Figma fields get N/A. Independent of Phases 1–2; can run in parallel.

## Requirements

Functional:
- Bottom sheet with: header **"How did this outfit feel?"**, supporting text **"This helps us understand your style and mood better."**, mood chip grid, primary CTA **"Done"**.
- Multi-select chips; tap again deselects. "Done" disabled until ≥1 chip selected.
- Contextual chip sets — static `occasion → chips` map (work / weekend / social / travel / default), max 8 visible per context, keyed off `outfit_context.occasion`. Soft-negative `not_quite_me` ("Not quite me") present in every set, placed last.
- Chip vocab mirrors server `mood_vocab.py` (Phase 1) — ids identical, display labels via i18n.
- Dismiss via swipe-down gesture AND backdrop tap (both call `onDismiss`).
- `isSubmitting` prop: chips + CTA disabled, CTA shows spinner. `errorMessage` prop: error text slot above CTA.
- Selections reset every time the sheet opens (fresh modal per ticket re-tap scenario).

Non-functional:
- Theme tokens only — inactive `theme.colors.figmaCardTag`, selected `figmaChipBg`; NO hex literals (`./scripts/auxi-lint-tokens.sh` gate).
- testIDs: `mood-feedback-sheet`, `mood-chip-<id>`, `mood-feedback-done`, `mood-feedback-backdrop`. `accessibilityLabel` separate from testID (a11y ≠ automation).
- Animation matches house pattern: translateY slide-up ~300ms open / ~220ms close.
- Component ≤200 lines — chips grid extracted to a small internal component if needed.
- i18n strings in all 3 locales (`en-EN.json`, `vi-VN.json`, `fr-FR.json`, `boilerplate` namespace).

## Architecture

```
MoodFeedbackSheet
  props: { visible, occasion?: string, isSubmitting: boolean,
           errorMessage?: string, onSubmit(moodIds: string[]), onDismiss() }
  state: selectedIds: Set<string>   // reset on `visible` rising edge
  render: Modal > backdrop Pressable + Animated.View
            > header + supporting text
            > chip grid (CONTEXT_CHIP_SETS[occasion] ?? DEFAULT_CHIP_SET)
            > error slot + Done PillButton (disabled: selectedIds.size === 0 || isSubmitting)
```

Shared vocab module `mood-chips.ts`:
```ts
export const MOOD_CHIPS = [{ id: 'feels_like_me', labelKey: 'mood.feelsLikeMe' }, ...] // 16 ids = server vocab
export const CONTEXT_CHIP_SETS: Record<string, string[]> = {
  work:    ['professional','sharp','prepared','polished','confident','comfortable','elevated','not_quite_me'],
  weekend: ['relaxed','easy','comfortable','effortless','feels_like_me','confident','elevated','not_quite_me'],
  social:  ['attractive','elevated','confident','expressive','sharp','feels_like_me','polished','not_quite_me'],
  travel:  ['functional','comfortable','lightweight','relaxed','easy','effortless','feels_like_me','not_quite_me'],
}
export const DEFAULT_CHIP_SET = ['feels_like_me','confident','relaxed','polished','comfortable','sharp','effortless','not_quite_me']
```

## Related Code Files

Create:
- `auxi/src/components/features/MoodFeedbackSheet.tsx` — the sheet component
- `auxi/src/components/features/mood-chips.ts` — `MOOD_CHIPS`, `CONTEXT_CHIP_SETS`, `DEFAULT_CHIP_SET` (mirrors server `mood_vocab.py`)

Modify:
- `auxi/src/translations/en-EN.json` / `vi-VN.json` / `fr-FR.json` — header, supporting text, 16 chip labels, Done, error strings (error strings consumed in Phase 4 but added here)
- `auxi/src/theme/theme.ts` — ONLY if an existing token is missing (prefer reuse; expect zero changes)

Delete: none.

## Implementation Steps

1. **Vocab constants.** Create `mood-chips.ts` per Architecture. Ids MUST match server `MOOD_VOCAB` exactly (Phase 1) — add a comment pointing at `wardrobe-backend/blueprints/mood/mood_vocab.py` as the source of truth. Each set ≤8 entries — add a dev-time assert.
2. **i18n.** Add `boilerplate.mood.*` keys to all 3 locale files: `title` ("How did this outfit feel?"), `subtitle`, `done`, 16 chip labels (soft wording for `not_quite_me` → "Not quite me"), `errorGeneric` ("Unable to save your feedback. Please try again."), `errorTimeout` ("Connection timed out. Please try again."), `savedBanner` ("This look is now saved to your favorites."), `moodUpdatedBanner` ("Mood updated for this saved look.").
3. **Sheet skeleton.** Clone `ContextChipsModal` modal/animation/backdrop scaffolding into `MoodFeedbackSheet.tsx` (Modal + Animated.View, 300ms/220ms). Wire `onDismiss` to backdrop press and swipe-down (same gesture approach ContextChipsModal/ItemDetailBottomSheet uses — copy, don't invent).
4. **Chip grid.** Render chips for `occasion` set; toggle membership in `selectedIds`; selected style = `figmaChipBg` bg, inactive = `figmaCardTag` (copy exact styles from `ContextChipsModal:127-145`). testID `mood-chip-<id>`.
5. **CTA + states.** `PillButton` "Done": disabled when 0 selected or `isSubmitting`; spinner while submitting; `errorMessage` rendered above CTA when present. testID `mood-feedback-done`.
6. **Reset-on-open.** `useEffect` on `visible`: rising edge → `setSelectedIds(new Set())`.
7. **Verify.** `cd auxi && npx tsc --noEmit && yarn lint && cd .. && ./scripts/auxi-lint-tokens.sh` — all clean (lint baseline: 4 pre-existing errors in legacy `_HomeScreen.tsx` only).

## Success Criteria

- [x] Sheet renders header/subtitle/chips/Done per ticket copy, slide-up animation, backdrop + swipe-down dismiss.
- [x] `occasion='work'` shows the work set; unknown/missing occasion shows DEFAULT_CHIP_SET; every set ≤8 chips incl. `not_quite_me` last.
- [x] Multi-select + deselect toggling works; Done disabled at 0 selections; disabled+spinner while `isSubmitting`; error slot shows `errorMessage`.
- [x] All interactive elements have testIDs (`mood-feedback-sheet`, `mood-chip-<id>`, `mood-feedback-done`, `mood-feedback-backdrop`).
- [x] Chip ids == server `MOOD_VOCAB` (manual diff against `mood_vocab.py`).
- [x] Strings present in en/vi/fr; `npx tsc --noEmit`, `yarn lint`, `auxi-lint-tokens.sh` all clean.

## Risk Assessment

- **Mood chips emotionally ambiguous** (ticket High). Mitigation: labels copied verbatim from ticket; soft-negative wording exactly "Not quite me"; i18n review for vi/fr nuance.
- **Too many chips / cognitive load** (ticket High). Mitigation: ≤8 enforced in constants with assert; contextual sets keep relevance.
- **Feels like mood tracking / survey** (ticket emotional-design principles). Mitigation: single lightweight sheet, optional, no free-text (MVP decision in ticket), calm copy.
- **Pattern drift from house modal behavior.** Mitigation: copy ContextChipsModal scaffolding verbatim rather than re-implementing.
