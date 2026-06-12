# Phase 02 — Set data model (group of 3)

**Priority:** P0 · **Status:** ☐ · **Agent:** mobile-dev · **No Figma dependency** (can run parallel to phase 01)

## Goal

Reshape the flat outfit buffer into **sets of 3** so navigation has two coordinates: `setIndex` (vertical)
and `outfitIndex ∈ {0,1,2}` (horizontal).

## Current state (verified)

- `HomeScreen.tsx:157` `type OutfitSheet = { items, outfitHash, caption }`
- `listOutfits` is a flat `OutfitSheet[]`; V05 fetch requests `count: 3` per batch (one batch ≈ one set).
- `getSheetIndexFromOffset` (`:235`) maps scroll offset → flat index.
- Prefetch keeps `TARGET_AHEAD=2` outfits buffered (`:155`, `ensureBuffer`).

## Design

1. Introduce a derived grouping (don't duplicate state — derive from `listOutfits`):
   ```ts
   type OutfitSet = { setIndex: number; outfits: OutfitSheetWithGrid[] }; // length 1..3
   const sets = chunk(listOutfits, 3); // memoized
   ```
   Keep `listOutfits` as the single source of truth (append-on-prefetch stays intact); `sets` is a
   `useMemo` view. KISS — no parallel array to keep in sync.
2. Active position becomes `{ setIndex, outfitIndex }`. Derive legacy flat
   `activeIndex = setIndex*3 + outfitIndex` for any code still keyed on it (favorite, caption, hash).
3. A batch from `/build` or `/try_another` (count 3) = one set. Partial last set (<3) is allowed and
   renders fewer horizontal pages (pagination dots reflect actual count).

## Prefetch adjustment

Trigger next-set fetch when the user reaches the **last set** (i.e. `setIndex >= sets.length - 1`) AND has
swiped horizontally to the last outfit, OR pre-warm when entering the last set. Re-express `TARGET_AHEAD`
in set terms: keep ≥1 full set buffered ahead. Append results to `listOutfits` as today (grouping
re-derives automatically).

## Files

- `auxi/src/screens/HomeScreen.tsx` — add `chunk` memo, `{setIndex,outfitIndex}` state, derived flat index.
- Maybe extract a tiny pure helper `groupOutfitsIntoSets.ts` under `src/utils/` if it keeps HomeScreen
  under control (file is already large). Prefer extraction (DRY + testable).

## Todo

- [x] Add `chunk`/grouping memo (or `groupOutfitsIntoSets` util + unit test) — `src/utils/groupOutfitsIntoSets.ts` + 9-case unit test (PASS)
- [x] Replace flat `activeIndex` state with `{setIndex,outfitIndex}` (+ derived flat index getter) — `toFlatIndex`/`fromFlatIndex`
- [x] Re-key prefetch trigger on set position — `ensureBuffer` lookahead = flat(setIndex,outfitIndex); TARGET_AHEAD=3 (one set)
- [x] `npx tsc --noEmit` clean

## Success criteria

- `sets` correctly chunks any N into groups of 3 (incl. trailing partial).
- No double source of truth; prefetch still appends without flicker.
- tsc clean (no new errors outside `_HomeScreen.tsx`).

## Next

Phase 03 consumes `{setIndex,outfitIndex}` to drive the 2D gesture.
