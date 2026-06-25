# AU-361 — Custom successSnackbar at TOP (topOffset 120) — Decisive Probe

**Date:** 2026-06-18 11:06 · **Device:** iOS Simulator iPhone 16 Pro (iOS 18.1, UDID 9DCBFE8A…F3916)
**App:** com.auxi2026.app · **Backend:** au-346 :5001 · **Lane:** mobile-mcp exploratory verify
**Seed item:** `e2879f93-eb14-43e7-9940-238e70f723b3`

## Verdict

The custom `successSnackbar` does **NOT render** when fired at `position:'top'` (topOffset 120),
even though it is fully un-occluded by the bottom RN LogBox. The ready-branch *logic* fires
(debug banner `hits` incremented 0→1 on the first transition) but **no teal M3 snackbar ever
appeared** at the top, and the `wardrobe-item-ready-snackbar` testID was **absent from the element
tree on all three transitions**.

## Evidence — 3 preparing→ready transitions, all on the Wardrobe screen

| Transition | Banner at fire tick | Snackbar visible (top)? | testID in tree? | hits |
|---|---|---|---|---|
| T1 (flip 11:03:46) | `prev=2 next=2 seedP=false` post | No | No | 0 → **1** |
| T2 (flip 11:04:?) | `prev=2 next=1 seedInPrev=true` (caught pre-fire) | No | No | stayed **1** |
| T3 (flip 11:05:50) | `prev=2 next=1 seedInPrev=true` (caught pre-fire, t3-s1) | No | No | stayed **1** |

- T2/T3 captured the exact pre-fire tick (`seedInPrev=true`, `next=1`) then post-fire
  (`seedInPrev=false`) — the snackbar render window was inside the sampled frames and is **empty
  at top**. M3 snackbars persist ~3-4s; 1.2s-cadence sampling would have caught it.
- The only toast on screen is the dark RN **LogBox** "Open debugger to view warnings" at the
  BOTTOM — not the custom teal snackbar, not at top.

## Debug banner — final reading
`rc=44 prev=1 next=1 hits=1 seedP=false seedInPrev=false`
**hits=1** (incremented only on the very first transition; did not re-increment on T2/T3).

## Snackbar at top?  **NO**
## `wardrobe-item-ready-snackbar` in element list?  **NO** (all 3 transitions)
## hits=  **1**

## Crashes
None for com.auxi2026.app (`mobile_get_crash` lists only stale 2024/2025 unrelated entries).
The non-render is silent — the ready-branch executes without throwing.

## Screenshots → `plans/reports/screenshots-260618-au361-top/`
- `t3-s1.png` — **canonical**: green debug banner `seedInPrev=true` (pre-fire tick), clean filter
  row where the top snackbar would sit, bottom LogBox. No teal snackbar.
- `t3-s2.png`, `t3-s3.png` — post-fire (`seedInPrev=false`), still no snackbar.
- `wardrobe-post-flip-no-snackbar.png` — quiescent post-T2 state.

## Interpretation (for routing, not a fix)
Moving the toast to `position:'top'` ruled OUT "occluded by LogBox" as the cause — the top area is
clearly visible and the snackbar still does not paint. The ready-branch reaches its trigger (hits
0→1) but the custom `successSnackbar` component never mounts/renders. This points at the snackbar
component/host itself (not the bottom occlusion). Two secondary observations worth flagging to the
flow/component owner:
1. `hits` increments only once per app session (0→1), then stays 1 across subsequent
   preparing→ready transitions — the fire path may be guarded/one-shot, OR prev-baseline isn't
   resetting per transition.
2. No testID in the tree at any point → the component subtree is not rendering at all (vs rendering
   off-screen).

Route to: **mobile-dev** (custom successSnackbar component not rendering / not mounting on the
ready-branch) — this is a UI/state render bug, not a selector/flow-author issue.

---
**Status:** DONE
**Summary:** custom successSnackbar rendered at top? **N** · in element tree? **N** (`wardrobe-item-ready-snackbar` absent on all 3 transitions) · hits=**1** (ready-branch fired once, snackbar never painted)
**Concerns/Blockers:** `hits` only increments on the first transition then stays at 1 — fire path may be one-shot/guarded, worth mobile-dev confirming. No crash logged; non-render is silent.
