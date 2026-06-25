# AU-361 Debug Banner — Instrumentation Capture (260618)

**Type:** Data capture (transcribe on-screen debug banner across a preparing→ready flip). No verdict, no code changes.
**Device:** iOS Simulator iPhone 16 Pro · iOS 18.1 · UDID 9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916
**App:** com.auxi2026.app · Backend au-346 :5001 · Metro :8081
**Seed item:** `e2879f93-eb14-43e7-9940-238e70f723b3`
**Banner testID:** `au361-debug-banner` (green-on-black, top of WardrobeScreen)

## Transcribed banner text (verbatim)

| # | When (post-flip) | Banner text | screenshot |
|---|---|---|---|
| 1 | BEFORE flip (preparing armed) | `rc=3 prev=2 next=2 hits=0 seedP=true:boolean seedInPrev=true` | `01-before-flip-preparing.png` |
| 2 | ~11s after flip | `rc=24 prev=1 next=1 hits=1 seedP=false:boolean seedInPrev=false` | `02-after-flip-t5.png` |
| 3 | ~28s after flip | `rc=28 prev=1 next=1 hits=1 seedP=false:boolean seedInPrev=false` | `03-after-flip-t10.png` |
| 4 | ~44s after flip (final) | `rc=32 prev=1 next=1 hits=1 seedP=false:boolean seedInPrev=false` | `04-after-flip-t15.png` |

Flip executed at 10:13:44 (`UPDATE wardrobe_items SET is_preparing=false`).

## Field-by-field deltas (the data you asked about)

- **`hits`**: incremented **0 → 1** at the first post-flip capture and held at `1` through all subsequent cycles. Did NOT climb past 1.
- **`seedP`**: flipped **`true` → `false`**; type stayed **`boolean`** both sides (i.e. `seedP=true:boolean` → `seedP=false:boolean`). It is a real JS boolean, not a string/number.
- **`seedInPrev`**: flipped **`true` → `false`**.
- **`prev` / `next`**: went `2`/`2` → `1`/`1` at the flip and stayed there.
- **`rc`** (render count): `3` → `24` → `28` → `32` — climbing steadily from poll-driven re-renders, ~4 per ~15s window (consistent with a 4s poll).

## Snackbar

Teal "Your item is ready" snackbar: **NOT observed** in any of the 3 post-flip captures (~11s, ~28s, ~44s). Only the benign React-Native "Open debugger to view warnings." toast was present at the bottom in every frame.
Caveat: first post-flip screenshot landed ~11s after the flip; a snackbar that fired in the first few seconds and auto-dismissed (typical 3–4s) would not be in any capture. Cannot positively confirm it never fired — only that it was absent at every sampled moment.

## Side observation (state, not verdict)

The runtime state flipped to ready (`seedP=false`, `hits=1`) but the **first wardrobe tile's "Preparing this item" overlay did NOT clear** in any post-flip frame (visible through the final ~44s capture). The banner's runtime state and the tile UI are out of sync in this run — flagged for whoever owns AU-361, since that's the kind of thing the banner exists to expose.

## Navigation note (tooling)

mobile-mcp/WDA could **not** tap the drawer menu item `sidebar-menu-wardrobe` to reach Wardrobe — the RootDrawer is a `base`-tier back layer and the pushed `content` layer (native-driver `translateX`) keeps catching all hit-tests (8 coordinate taps across the full row failed; the right-strip `drawer-close-catcher` tapped fine, confirming the hit-test desync). Resolved by driving the nav with a throwaway Maestro harness (`home-menu-button` → `sidebar-menu-wardrobe`, the same nav prelude already in `maestro/flows/_shared/open-first-wardrobe-item.yaml`), which taps by view-hierarchy testID. Harness was run from `/tmp` and deleted; no `maestro/flows/**` authored. If drawer-reachable screens need recurring mobile-mcp verifies, ask qa-ui to keep a Maestro nav prelude — coordinate taps won't reach the back-layer menu.

## Artifacts

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-debug/01-before-flip-preparing.png`
- `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-debug/02-after-flip-t5.png`
- `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-debug/03-after-flip-t10.png`
- `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-debug/04-after-flip-t15.png`
- Banner crops (2x, legible): `banner-im-01.png` … `banner-im-04.png` in the same dir.

Seed reset to `is_preparing=false` after run. No app crash (`mobile_list_crashes` shows only stale 2024/2025 unrelated entries).
