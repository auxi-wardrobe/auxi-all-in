# AU-361 — Item-Ready Snackbar (in-screen rewrite) — Verify

**Date**: 2026-06-18 11:21–11:49
**Device**: iOS Simulator iPhone 16 Pro (iOS 18.1) · UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`
**App**: `com.auxi2026.app` (Metro dev build)
**Backend**: au-346 worktree on :5001 (`/Users/nguyenminhduc/dev/wardrobe_project/worktrees/wb-au346`), DB `switchback.proxy.rlwy.net:17805/railway`
**Seed item**: `e2879f93-eb14-43e7-9940-238e70f723b3` — "Leather Trousers · Black", owned by `qa-test@auxi.app` (`b32cb743-…`)
**Lane**: mobile-mcp exploratory verify (no Maestro flow for this transition yet)

## Result: PASS — snackbar renders

The AU-361 in-screen `ItemReadySnackbar` mounts and renders this time. It appears at the
bottom of WardrobeScreen on a preparing→ready transition, fires exactly once, and
auto-dismisses. No crash. Home hamburger menu is tappable. The earlier failure mode
(react-native-toast-message custom-config path never mounting) is resolved by the
self-controlled in-screen overlay.

## Deliverable answers

- **Did the snackbar render this time?** YES. Captured live via screen recording.
  - Canonical frame: `plans/reports/screenshots-260618-au361-inscreen/qa-mobile-au361-snackbar-visible.png`
  - Zoom (snackbar band beneath the dev banner): `…/snackbar-zoom.png`
  - Appear→dismiss sequence: `…/snackbar-sequence.png`
  - Raw recording: `…/au361-capture.mov`
- **Was `wardrobe-item-ready-snackbar` in the element tree?** Not surfaced by
  `mobile_list_elements_on_screen` — but that tree is sparse on WardrobeScreen
  (it never surfaces grid tiles, the RN dev banner, or nested overlays; only the
  header button + "Wardrobe" title appear). testID absence here is a known a11y-tree
  limitation, NOT evidence of non-render. Render is proven by the recording frames.
- **Fired once?** YES. The teal band appears (frames ~32–35 of the 2 fps extract,
  ≈11:46:04–08) then disappears by frame 36 — single fire, auto-dismiss, no loop on
  subsequent polls. Within a single mounted session the dedup ref
  (`readyToastedIdsRef`) suppresses repeat fires for the same item id (confirmed:
  re-flipping the same item in the same session correctly did NOT re-toast).
- **Menu tappable?** YES. `home-menu-button` is in the a11y tree and opens the drawer;
  navigated Home → drawer → Wardrobe normally on every relaunch.
- **Any crash?** NO. `mobile_list_crashes` shows only stale, unrelated entries
  (Xcode extension 2024, Cursor helper 2025); no `auxi` crash.

## Visual note

The Metro dev build's "Open debugger to view warnings." banner sits on top of the
snackbar and obscures its check icon + "Your item is ready" text. The teal M3 snackbar
surface itself is clearly visible directly below the dev banner (see `snackbar-zoom.png`).
This dev banner is not present in release builds, so the obstruction is a dev-build
artifact only. If a fully unobstructed shot of the icon + label text is required, re-run
on a release build or dismiss the dev banner first.

## Mechanism confirmed end-to-end

Trigger lives in `auxi/src/screens/WardrobeScreen.tsx`:
- `reconcileReadyItems` (≈L159) compares each poll's preparing set against the prior
  via `preparingIdsRef`; on `prevPreparing.has(id) && !readyToastedIdsRef.has(id)` it
  calls `showReadySnackbar(...)` (L135) → `setReadySnackbarVisible(true)` with a
  `READY_SNACKBAR_MS` auto-hide.
- Rendered as an absolute overlay at L640 (`wardrobe-item-ready-snackbar-overlay`
  wrapping `<ItemReadySnackbar testID="wardrobe-item-ready-snackbar" …/>`).
- Background poll cadence observed ≈4s (`GET /api/wardrobe/items` in au346-backend.log).
- Analytics: fires `item_ready_toast_shown` (with `item_category` when present) — wired.

Timing proof (final run): flipped ready 11:46:01; poll at 11:46:01.96 still saw
preparing=true (held baseline); next poll ~11:46:06 saw preparing=false → snackbar
rendered in the recording at frames 32–35, gone by 36.

## Process notes / gotchas for next time

1. **Stuck confound item**: a second item `ecf33819` ("New Item") was genuinely
   `is_preparing=true` since 02:21 today and, being the newest, occupied the top-left
   grid tile — it masked the seed's state during early runs. Parked it to `false` to
   isolate the seed. It remains `false` (left clean).
2. **Seed tile is off-screen**: the seed (created 2026-05-27) sorts far down the grid
   (`ORDER BY created_at DESC`), so its tile-level "Preparing" overlay was never on
   screen. The snackbar is a screen-level overlay so this didn't matter for the toast,
   but it's why tile-state couldn't be used as the visual cue.
3. **Session dedup**: `readyToastedIdsRef` persists for the mounted screen's lifetime.
   After the first transition toasts in a session, re-flipping the SAME item is
   permanently suppressed. To re-capture you must remount — a full app relaunch resets
   it deterministically (drawer-based remount was flaky to drive via mobile-mcp).
4. **Capture timing**: snackbar window (~4s) vs poll cadence (~4s) vs mobile-mcp
   screenshot round-trip (2–4s) makes a single still unreliable. `xcrun simctl io
   recordVideo` over the flip + 2 poll cycles, then ffmpeg frame extraction, is the
   reliable capture method and is what produced the evidence here.

## State left clean
- Seed `e2879f93` reset to `is_preparing = false`.
- Stuck item `ecf33819` left at `is_preparing = false`.

## Unresolved questions
- Promote this to a Maestro flow? It needs a backend state flip mid-flow + visual-only
  assertion (teal overlay), which isn't selector-deterministic — likely stays as
  mobile-mcp exploratory unless `qa-ui` adds a testID-based `assertVisible` on
  `wardrobe-item-ready-snackbar` that Maestro CAN see (mobile-mcp's sparse tree can't,
  but Maestro's hierarchy dump may differ — worth a one-off check by qa-ui).
- Confirm `item_ready_toast_shown` actually lands in Mixpanel (not verified here; only
  confirmed the `track()` call site exists).

---

**Status:** DONE
**Summary:** AU-361 in-screen snackbar rendered? **Y** · in element tree? **N** (sparse a11y tree on WardrobeScreen — render proven via screen recording instead) · menu tappable? **Y**
**Concerns/Blockers:** None blocking. The RN dev "Open debugger" banner overlaps and hides the snackbar's icon + text in this Metro build (teal surface still clearly visible below it) — for a fully clean icon/label shot, re-run on a release build. testID didn't appear in mobile-mcp's element tree, but that tree is sparse on this screen (no grid tiles/overlays surface); recording frames are the authoritative render evidence.
