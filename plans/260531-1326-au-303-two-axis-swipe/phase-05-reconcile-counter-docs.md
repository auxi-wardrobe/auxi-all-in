# Phase 05 — Reconcile 3-swipe counter + update docs

**Priority:** P1 · **Status:** ☐ · **Agent:** mobile-dev · **Depends on:** phase 02, 03

## Goal

The existing unfavorited-swipe counter (hits 3 → opens `ContextChipsModal`) was built on a flat vertical
index. Re-anchor it to the two-axis model WITHOUT losing the "after 3 unfavorited browses → ask for
context" behavior, and rewrite the stale source-of-truth doc.

## Counter reconciliation

- Current: increments on each vertical `onMomentumScrollEnd` landing on a new index where prior sheet
  wasn't favorited; resets on heart-tap; opens modal at `UNFAVORITED_SWIPE_THRESHOLD = 3`.
- New: an "outfit browse" = landing on a new `(setIndex, outfitIndex)`. Increment on either axis move to a
  not-yet-seen outfit where the previous active outfit wasn't favorited. Threshold stays 3.
- **Watch overlap with guidance overlay 2** (also keyed on "3 outfits"). These are two different "3"s:
  - guidance overlay 2 = first-time education, fires once ever (AsyncStorage).
  - context modal = recurring per-session nudge.
  Make sure they don't both pop simultaneously on the 3rd browse — sequence them (guidance first if
  unseen, suppress context modal that one time), or gate context modal to fire only after guidance
  dismissed. Decide + document.

## Docs (mandatory — prevents regression)

1. Rewrite `auxi/docs/HOME_SWIPE_PLAN.md` §1 "swipe model": the vertical-only model is **superseded by
   AU-303**. Document the two-axis model (L/R = outfit in set, U/D = set) as the new source of truth and
   reference AU-303 + Figma node `3140-8191`. Leave a dated note explaining the change so future agents
   don't revert.
2. Note in the doc that the old "Tinder-style horizontal NOT used" line is removed/inverted.

## Todo

- [x] Move counter increment to `(setIndex, outfitIndex)` browse events — `recordBrowse` fires on both axes via handleOutfitChange/handleSetChange
- [x] Define "seen outfit" set to avoid double-count on back-swipe — `seenOutfitKeysRef` (flat-index Set); only not-yet-seen forward browses count
- [x] Sequence guidance-overlay-2 vs context-modal on the 3rd browse — `openContextModalSequenced` defers context modal when vertical overlay armed; flush on overlay dismiss OR on resolve(false)
- [x] Rewrite HOME_SWIPE_PLAN.md §1 + dated supersede note — two-axis model now source of truth; old "Tinder NOT used" line inverted; AU-303 + node 3140-8191 referenced
- [x] tsc + lint clean (no new errors over baseline)

> Threshold stays `UNFAVORITED_SWIPE_THRESHOLD = 3`. Heart-tap still resets the
> counter. Sequencing guarantees the vertical guidance overlay and the context
> modal never display simultaneously.

## Success criteria

- 3 unfavorited browses still open `ContextChipsModal` (per session).
- Heart-tap still resets the counter.
- Guidance overlay 2 and context modal never collide.
- `HOME_SWIPE_PLAN.md` reflects two-axis model.

## Next

Phase 06 verification.
