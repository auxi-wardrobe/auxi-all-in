# Phase 03 — Two-axis gesture rework

**Priority:** P0 (core) · **Status:** ☐ · **Agent:** mobile-dev · **Depends on:** phase 02

## Goal

Replace vertical-only `ScrollView` snap with a **2D pager**:
- **Vertical** axis pages between SETS (`setIndex`).
- **Horizontal** axis pages between the 3 outfits inside the active set (`outfitIndex`).

## Approach (decide, default = nested paged FlatList — no new dep)

**Option A (preferred):** vertical `FlatList` (pagingEnabled, snap per set) where each row renders a
horizontal `FlatList` (pagingEnabled, 3 outfits). Each outfit cell = existing `OptionSheet` grid shell.
Pros: no new dependency, RN-native paging. Cons: nested horizontal-in-vertical gesture handoff needs care
(`directionalLockEnabled`, `nestedScrollEnabled`).

**Option B (fallback):** `react-native-pager-view` for vertical + inner pager horizontal. Cleaner gesture
arbitration but adds a dependency + native rebuild. Only if A shows gesture conflicts on device.

> Verify the dep choice on the sim before committing. If adding a dep, native rebuild required (see memory
> on stale binary vs branch deps).

## Wiring

1. Outer vertical pager: `onMomentumScrollEnd` → new `setIndex`; reset `outfitIndex = 0` on set change
   (per ticket: a fresh set starts at its first outfit). Drives set-exploration guidance trigger.
2. Inner horizontal pager: `onMomentumScrollEnd` → new `outfitIndex`; drives the `• • •` pagination dots
   and the unfavorited-swipe counter (phase 05).
3. `directionalLockEnabled` so a diagonal drag commits to one axis only — prevents fighting between the
   two pagers (matches "intentional, controlled" design intent in the ticket).
4. Keep `collageDragActive` disable hook (current `scrollEnabled={!collageDragActive}`) on BOTH pagers.

## Pagination dots

Render `• • •` row (active dot filled) bound to `outfitIndex` of the active set, positioned between
"Remix" and "Show another" per Figma frame 2. Dot count = active set length (1..3).

## testIDs (Maestro — mandatory)

- `home-set-pager` (vertical), `home-outfit-pager-<setIndex>` (horizontal)
- `home-pagination-dot-<i>` with active suffix `home-pagination-dot-<i>-active`
- keep existing sheet/grid testIDs intact

## Files

- `auxi/src/screens/HomeScreen.tsx` (main rework)
- `auxi/src/components/features/OptionSheet*` (no structural change — it becomes the horizontal cell)

## Todo

- [x] Spike Option A on sim; confirm gesture handoff clean; else Option B — chose Option A (nested paged FlatList, NO new dep); sim handoff verification handed to qa-mobile/qa-ui
- [x] Vertical set pager + reset outfitIndex on set change — `home-set-pager`, snapToInterval (not pagingEnabled), `handleSetChange` resets outfitIndex=0
- [x] Horizontal outfit pager (3 cells) reusing OptionSheet — `OutfitSetRow` → `home-outfit-pager-<setIndex>`, pagingEnabled, OptionSheet cell
- [x] Pagination dots bound to outfitIndex — OutfitActionRow `activeIndex={outfitIndexInSet}` `dotCount={setLength}`, tokens #5b5550/#c6bcb1
- [x] All new testIDs present — set-pager, outfit-pager, pagination-dot-<i>(-active)
- [x] `npx tsc --noEmit` + `yarn lint` (no new errors over baseline)

> Decision: **Option A (nested paged FlatList)** — no new dependency, no native
> rebuild. `directionalLockEnabled` on both axes; `scrollEnabled={!collageDragActive}`
> on both. On-device gesture-handoff confirmation is the qa-mobile/qa-ui pass (sim
> not run by mobile-dev).

## Success criteria (sim walk)

- Swipe L/R cycles the 3 outfits of the current set; dots track.
- Swipe up → next set (3 new outfits), starts at outfit 0; swipe down → previous set.
- No diagonal-drag jitter; collage drag still disables paging.

## Next

Phase 04 layers the first-time guidance overlays on top of this.
