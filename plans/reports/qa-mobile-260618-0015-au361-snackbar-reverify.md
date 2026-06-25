# AU-361 Item-Ready Snackbar — Live Re-verify (post isPreparing() coercion fix)

**Date**: 2026-06-18 00:15–00:22
**Device**: iOS Simulator iPhone 16 Pro (iOS 18.1, UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`)
**App**: `com.auxi2026.app` (Metro hot-reload of the `isPreparing()` coercion fix)
**Backend**: feature-complete au-346 on `http://localhost:5001` (Railway DB, seeds applied)
**Seed item**: `e2879f93-eb14-43e7-9940-238e70f723b3` — "Leather Trousers · Black"
**Lane**: mobile-mcp exploratory verify (no Maestro flow for this transition yet)

## Verdict: FAIL

The teal "Your item is ready" snackbar (`wardrobe-item-ready-snackbar`) did **NOT** appear
after a preparing→ready transition observed live on the Wardrobe screen, across 2+ poll cycles
(~14s). The coercion fix DID repair the tile overlay (it now shows + clears correctly), but the
transition snackbar still does not fire.

## What worked (the fix is partially effective)
- Preparing overlay renders on initial fetch: navigated Home → drawer → Wardrobe with the seed
  armed to `is_preparing = true`; the first tile (Leather Trousers · Black) correctly showed the
  "Preparing this item" overlay. Screenshot:
  `auxi/docs/qa-findings/screenshots/2026-06-18/qa-mobile-au361-01-preparing-state.png`
- Preparing→ready tile update works: after flipping `is_preparing = false` in the DB while staying
  on Wardrobe, the silent poll picked up the change and the tile overlay cleared (full image
  rendered). This proves the app **received the ready data on its poll** and re-rendered.

## What failed
- No snackbar at the transition. After the overlay cleared (app saw ready), I captured the screen
  immediately and at t+~6s and t+~14s (2+ poll cycles, `PREPARING_POLL_MS = 4000`). Only the
  persistent Metro "Open debugger to view warnings" banner was present — never the teal M3
  snackbar. `mobile_list_elements_on_screen` showed no `wardrobe-item-ready-snackbar` testID at any
  point. Screenshot:
  `auxi/docs/qa-findings/screenshots/2026-06-18/qa-mobile-au361-02-no-snackbar-after-ready.png`

## Fired once vs repeated
- N/A — it never fired at all. (Could not assess single-vs-repeat because there was no fire to
  observe.)

## Crash
- None. `mobile_list_crashes` shows no `com.auxi2026.app` entries during the window; only unrelated
  system/Cursor/AccessibilityControls processes from 2024–2026-06-17, none coincident with the
  flips. The no-fire is silent, not a crash.

## Secondary observation (re-arm mid-session does not re-show overlay)
- On an interim attempt I flipped `is_preparing` true→false→**true** while staying on Wardrobe; the
  overlay did NOT reappear even after ~15s. The reliable path to a preparing baseline was a fresh
  screen entry (relaunch → navigate to Wardrobe) where the initial fetch reads preparing. The
  successful FAIL repro used that fresh-entry path, so this quirk did not invalidate the test, but
  it is worth a mobile-dev look (poll may not surface false→true edges back into the preparing set).

## Root-cause read (code, read-only — for routing, not a fix)
`auxi/src/screens/WardrobeScreen.tsx`:
- `isPreparing()` coercion fix present and correct — lines 100–109 (string `'true'`, number `1`,
  boolean `true`).
- Transition detector `reconcileReadyItems` — lines 141–180. Logic looks correct in isolation:
  builds `nextPreparing`, fires `Toast.show({ type: 'successSnackbar', ... })` + `track('item_ready_toast_shown')`
  when an item was in `prevPreparing` and is now ready, dedup via `readyToastedIdsRef`.
- Called on BOTH the focus fetch and the silent poll — line 195 (`reconcileReadyItems(data)`).
- Poll lifecycle — lines 226–235: runs only while `hasPreparingItems`, every `PREPARING_POLL_MS` (4s).

Since the tile cleared (so `setItems` ran with ready data on the silent poll) but the toast did not
fire, the failure is between "poll received ready" and "toast shown." Two candidates for mobile-dev:
1. **`preparingIdsRef` not seeded when the toast-firing poll runs.** If the initial focus fetch's
   `isPreparing()` returned `false` for the seed (e.g. the wire value for `is_preparing` differs
   from what the tile overlay path evaluated, or a stale `reconcileReadyItems` closure), the item is
   never added to `preparingIdsRef`, so `prevPreparing.has(item.id)` is false on the ready poll and
   no toast fires — even though the overlay (loose truthy / separate path) still showed/cleared.
   NOTE: I could not confirm the on-the-wire `is_preparing` value/type — the unauthenticated
   `/api/auth/login` probe returned an empty token (login payload shape differs from my probe), so I
   did not capture the serialized form. Worth confirming whether the API serializes the seed's
   `is_preparing` as `true` / `"true"` / `1` and whether the tile-overlay path and the detector path
   evaluate it identically on the SAME fetch.
2. **`successSnackbar` toast type not registered / mis-keyed** in
   `src/components/feedback/toastConfig.tsx`, so `Toast.show({ type: 'successSnackbar' })` is a no-op.
   Quick to rule out by checking the toast config registers `successSnackbar`.

## Routing
- **mobile-dev (UI/state)** — primary. The detector fires `Toast.show` but nothing renders; the tile
  path and the detector path are diverging on the same poll. Verify (a) `preparingIdsRef` is seeded
  on the initial preparing fetch and (b) `successSnackbar` is a registered toast type in
  `toastConfig.tsx`. Suspected: `auxi/src/screens/WardrobeScreen.tsx:141-180` +
  `auxi/src/components/feedback/toastConfig.tsx`.
- **qa-ui (flow author)** — once mobile-dev re-fixes, ask qa-ui to promote this to a Maestro flow
  (`wardrobe/item-ready-snackbar.yaml`) so we stop hand-driving the preparing→ready transition.

## Evidence
- Preparing state: `auxi/docs/qa-findings/screenshots/2026-06-18/qa-mobile-au361-01-preparing-state.png`
- Post-ready, no snackbar: `auxi/docs/qa-findings/screenshots/2026-06-18/qa-mobile-au361-02-no-snackbar-after-ready.png`
- Seed reset to `is_preparing = false` (cleanup) confirmed via psql at end of run.

## Repro steps (deterministic)
1. Arm: `UPDATE wardrobe_items SET is_preparing = true WHERE id = 'e2879f93-...';`
2. Relaunch app → Home → hamburger → Wardrobe. Confirm first tile shows "Preparing this item".
3. Flip: `UPDATE wardrobe_items SET is_preparing = false WHERE id = 'e2879f93-...';`
4. Stay on Wardrobe ~14s. Tile overlay clears (poll works) but NO teal snackbar appears.

## Open questions
- On-the-wire serialized form of `is_preparing` for this seed (true / "true" / 1)? Needed to confirm
  the `preparingIdsRef`-seeding hypothesis. My authenticated API probe failed to obtain a token.
- Does the false→true (re-arm) edge ever re-enter the preparing set mid-session, or only initial mount?
