# AU-359 — Edge artifact on outfit hold/swipe

**Agent:** mobile-dev
**Date:** 2026-06-17
**Ticket:** [AU-359](https://linear.app/duncan-1/issue/AU-359) — "[bug] when swipe left/right an outfit"
**Scope:** auxi/ only · pure visual fix · outfit swipe deck

## Reporter (CEO/designer Viet)

> When I hold and swipe the screen looks like this. It has something in the edge of the photo.

Two screenshots showed a visual artifact at the EDGE of the outfit photo during a hold/swipe.

## Component map

- Home swipe is a Tinder-style single-card deck (not a FlatList pager / not
  reanimated-carousel).
- `auxi/src/components/features/OutfitSwipeDeck.tsx` — PanResponder + `Animated`
  deck. Renders a `peek` card behind an `active` card.
- The active card carries a live `translateX` (finger follow) **plus a `rotate`**
  up to ±6° (`rotationForDx`, `SWIPE_ROTATION_CAP_DEG`).
- `auxi/src/screens/HomeScreen.tsx` `OptionSheet` is the card body
  (`renderCard`): a white `optionSheet` containing photo tiles. Each photo tile
  (`styles.card`, HomeScreen.tsx:2989) is `borderRadius: 12` + `overflow: 'hidden'`
  + `backgroundColor: figmaCardSurface` (cream `#f2efec`). Photo `Image` uses
  `resizeMode="contain"` (HomeScreen.tsx:2700).

## Root cause

The moving active card (`Animated.View` with `styles.cardBase`,
OutfitSwipeDeck.tsx:206-212) had **no `overflow: 'hidden'` and no
`backgroundColor`**. During a hold/swipe it rotates up to ±6°. Two edge
artifacts result, both visible exactly during the gesture (which matches
"when I hold and swipe"):

1. **Peek-card bleed.** As the active card rotates, its corners pull away from
   the screen edge. With no opaque background and no self-clip, the `peek` card
   behind it (its cream `figmaCardSurface` tiles) shows through as a thin band /
   sliver at the photo edge.
2. **Corner seam.** The child photo tiles are rounded (`borderRadius: 12` +
   `overflow: 'hidden'`). iOS cannot cleanly anti-alias a child's corner mask
   while the parent is mid-transform, so a ragged hairline appears at the tile
   corners during the rotate.

Net: "something in the edge of the photo" while dragging.

## Fix

`auxi/src/components/features/OutfitSwipeDeck.tsx`

- Import the theme (`import { theme } from '../../theme/theme';`) — line 21.
- Add `styles.activeCard` (lines 233-236):
  ```ts
  activeCard: {
    overflow: 'hidden',
    backgroundColor: theme.colors.figmaSurface,
  },
  ```
- Apply it to the **active** card style array only (line 208), alongside
  `styles.cardBase` + `cardStyle` + the transform.

### Why this is the right fix

- `overflow: 'hidden'` clips the moving card to its own rect, so the peek card
  beneath can no longer leak at the rotated edge (artifact #1 gone).
- `backgroundColor: figmaSurface` (`#FFFFFF`, the app/screen surface, same as
  `HomeScreen` container + the inner `optionSheet`) means the card's rotated
  corner gaps read white-on-white against the screen — no visible band
  (reinforces #1, and removes the dark/cream seam from #2 at the card edge).
- Clipping at the card-shell level stabilises what the GPU has to composite
  during the transform, removing the corner hairline.
- **Active card only.** The `peek` card is intentionally left unclipped and
  un-backed: its `scale 0.98→1` affordance must still read behind the active
  card. Clipping the peek would defeat the Tinder depth cue.

### No behavior / swipe change

- Pan/commit/cancel logic untouched. Rotation, like/skip cues, a11y actions
  unchanged.
- Like/skip cue badges (`renderCue`, positioned `top:16`, `right/left:24`,
  24px inside the card) stay within the clip rect — not clipped, shadow intact.
- Token-only: `figmaSurface` from `theme.ts`. No hex literal added.

## Verification

Node 20 (`nvm use 20` — required; default Node 16 breaks yarn).

- `npx tsc --noEmit` → **exit 0**, clean.
- `yarn lint` → 4 errors + 7 warnings, **all pre-existing and in other files**
  (`HomeScreen` exhaustive-deps, `WardrobeScreen` unused vars, `usePinReducer` /
  `DatabaseScreen` / `OutfitCanvasScreen` / `SignInScreen` warnings).
  `OutfitSwipeDeck.tsx` contributes **0** problems. (CLAUDE.md documents the
  baseline as 4 err + 3 warn; the extra 4 warnings are pre-existing drift in
  untouched files, not introduced here.)
- `../scripts/auxi-lint-tokens.sh` → `OutfitSwipeDeck.tsx` is **CLEAN** (0
  violations). The 34 repo-wide violations are all in untouched files.

### Simulator verification — NOT run this session

`mobile-dev` has no mobile-mcp grant and I did not boot the sim in this
session. **Code complete, visual verification pending.** Recommend qa-ui
Compare mode (Pass 2/3) to confirm the photo edge is clean during a live
hold/swipe against Viet's screenshots, then qa-mobile sim smoke.

## Analytics

**Not required.** This is a pure visual/layout fix. No new `onPress` /
`onChange` / handler / interaction was added — swipe already exists and is
already instrumented elsewhere. Per
`.claude/rules/analytics-tracking-required.md` ("When this doesn't apply:
pure UI / visual changes ... with no new interaction"), no new Mixpanel event
and no tracking-plan doc update are needed.

## Files changed

- `auxi/src/components/features/OutfitSwipeDeck.tsx`
  - line 21: import `theme`
  - line 208: apply `styles.activeCard` to the active card
  - lines 224-236: add `activeCard` style (overflow hidden + figmaSurface bg) + rationale comment

## Open questions

- None blocking. If qa-ui/Viet still sees a sliver, the secondary candidate is
  the per-tile `resizeMode="contain"` letterbox (cream `figmaCardSurface`
  showing inside the rounded tile when the garment photo aspect ≠ tile aspect) —
  that is a static, non-swipe artifact and would be a separate, smaller change
  (e.g. `cover` or a neutral letterbox token). Not changed here since the ticket
  is specifically about the hold/swipe edge.

---

**Status:** DONE
**Summary:** Fixed AU-359 edge artifact by self-clipping the moving active swipe card (`overflow: 'hidden'` + white `figmaSurface` bg) so the rotated card no longer leaks the peek card / a corner seam at the photo edge during hold/swipe. tsc clean, lint + token-lint add zero new problems on the touched file. Sim verification pending (no mobile-mcp in this session).
**Files changed:** auxi/src/components/features/OutfitSwipeDeck.tsx
**Concerns/Blockers:** Visual confirmation not run this session — hand to qa-ui (Compare) + qa-mobile (sim smoke). Analytics not required (pure visual, no new interaction).
