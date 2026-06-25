# Code Review — auxi-mobile PR #118

**PR:** [#118 Design-system pass + motion + home/pin fixes](https://github.com/auxi-wardrobe/auxi-mobile/pull/118)
**Branch:** `claude/quirky-wozniak-t17mfh` → `main` · +549 / −177 · 47 files
**Reviewed:** 2026-06-23 · confidence ≥80 reported

## Verdict
No Critical bugs. Logic changes sound; all referenced color tokens exist, all 4 Poppins
weights bundled, prop scopes valid. Main gaps are **process/compliance** (AI disclosure
dismissibility, missing analytics tracking + tracking-plan update, no tests for new logic)
plus minor cleanups. ~90% of the diff is mechanical token swaps (radius→16px, fonts→Poppins,
opacity→0.5, raw zIndex→tokens) — low risk, verified by spot-check.

## Critical
None.

## Important

### 1. AI disclosure became dismissible + lost-for-session (compliance/product call)
`HomeScreen/index.tsx` — the "AI-generated — may be inaccurate" disclosure moved from an
always-visible inline row to a dismissible black `InfoSnackbar` gated on `!aiNoticeDismissed`.
Once the user taps close, it never returns for the session. AI-output transparency is an App
Store / project compliance concern (see `appstore-readiness-pr100`). A permanently-dismissible
disclosure may weaken that. **Not a code bug — needs a CEO/PM/compliance decision** on whether
the recommendation-surface AI label must stay persistent. (conf 80)

### 2. New interactions ship no analytics + tracking-plan doc not updated (rule violation)
`.claude/rules/analytics-tracking-required.md` requires a Mixpanel event on every new
interaction handler + a `mixpanel-tracking-plan.md` update. Missing:
- `FavouriteOutfitCard` tile → `navigation.navigate('ItemDetail')` (new `onItemPress`) — no `track()`.
- AI snackbar dismiss (`setAiNoticeDismissed`) and "seen them all" dismiss (`setCycledHintDismissed`) — no `track()`.
- PR touches **no** tracking-plan doc (verified against file list).
Either wire events or log §6 gaps + update the doc. (conf 90)

### 3. No tests for new logic
PR adds **zero** test files. New untested logic:
- `outfit-normalize.ts` `buildGridOutfitSheetWithPin` — new category-dedup branch (pure fn, trivially testable, no `outfit-normalize.test.ts` exists).
- `HomeScreen/index.tsx` `pinnedItem` resolve-from-wardrobe fallback.
- `BackgroundScaleContext` ref-counting (push/pop balance, reduce-motion).
At minimum add a unit test for the pure dedup branch. (conf 85)

## Advisory / Low

### 4. Orphaned dead style `aiDisclosureRow`
`HomeScreen/styles.ts:59` defines `aiDisclosureRow` but it has **no consumer** anywhere in
the HomeScreen dir after the inline disclosure was removed — and this PR even edited its
`paddingHorizontal`. Delete it. (conf 95, verified)

### 5. Stale comment in theme.ts
`theme.ts` — `fontFamily: 'Poppins-Regular', // Use system font for now`. Comment now
contradicts the value. Drop/replace it. (conf 95)

### 6. Pin dedup strips ALL same-category items, not one
`outfit-normalize.ts` — `outfit.items.filter(... !== pinnedCategory)` removes every
same-category item; the comment says "drops the backend's same-category item" (singular).
Benign for the typical one-per-category outfit, but over-strips layered/multi-accessory
outfits before the `.slice(0,3)`. (conf 85, low impact)

### 7. InfoSnackbar close-button a11y label hardcoded English
`InfoSnackbar.tsx` — `accessibilityLabel="Close"` is a literal; app ships vi-VN/fr-FR/en-EN.
The action label is localized but the close affordance isn't. (conf 90, low impact)

### 8. BackgroundScale can stick scaled-down if Reduce Motion toggled mid-sheet
`BackgroundScaleContext.tsx` — `pushSheet` animates only when `!reduced`; `popSheet` restores
only when `!reduced`. Enabling Reduce Motion while a sheet is open leaves the driver at 1
(page stuck at scale 0.96 / −8px). Very rare; guard `popSheet` to restore regardless, or
snap the driver on `reduced` change. (conf 70, edge case)

### 9. `pinnedItem` category default `'Top'`
`HomeScreen/index.tsx` — mapping a wardrobe item with no category to `'Top'` then drives the
dedup (#6) to strip the outfit's real Top. Edge case for uncategorized items. (conf 70)

## Notes
- CI `archive` check fails in ~3s = macOS-runner provisioning (infra), not compilation —
  consistent with PR body. Not a code blocker.
- Good practices observed: `useAiReport` extraction (DRY), ref-counted sheet scaling honoring
  reduce-motion, `disabled={!onItemPress}` defensive guard on the favourite tile, mailto carries
  no PII, snackbar has `accessibilityRole="alert"`.

## Unresolved questions
- Is the recommendation-surface AI disclosure legally required to be persistent? (gates #1)
- Should favourite-tile→ItemDetail nav be a tracked funnel step? (gates #2)
