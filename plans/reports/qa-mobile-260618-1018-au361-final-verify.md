# AU-361 Snackbar — Final Verify After Clean Metro Bundle (--reset-cache)

**Date:** 2026-06-18 10:25
**Device:** iOS Simulator iPhone 16 Pro (iOS 18.1, UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`)
**App:** `com.auxi2026.app`
**Backend:** au-346 on :5001
**Seed item:** `e2879f93-eb14-43e7-9940-238e70f723b3`
**Hypothesis under test:** stale Metro bundle meant the App.tsx `<Toast config={toastConfig}/>` change hadn't taken effect; a fresh `--reset-cache` bundle should fix it.

## Result — FAIL (hypothesis NOT confirmed)

The clean bundle did **not** fix the snackbar. The preparing→ready transition was
correctly **detected** by the polling layer (`hits=1`), but the teal
`wardrobe-item-ready-snackbar` **never rendered** and **never appeared in the
accessibility hierarchy** across ~9 poll cycles (rc 11 → 20) over the full ~20s
watch window. The fresh bundle did load (no red box, confirmed below) — so the
"stale bundle" explanation is ruled out. The defect is in the snackbar render
path itself, not in Metro caching.

## Did the snackbar render this time?

**NO.** Not visually, not in the element hierarchy.

- Screenshot at end state: `plans/reports/screenshots-260618-au361-final/03-wardrobe-after-flip-hits1-no-snackbar.png`
- The only bottom toast on screen throughout was the dark RN dev system toast
  "Open debugger to view warnings." — that is NOT the AU-361 snackbar.

## hits= value

`hits=1` — the poll detected exactly one preparing→ready transition for the seed
item and held steady at 1 thereafter. Detection logic works; render does not.

Full debug banner progression:
- Armed (preparing=true): `rc=3 prev=2 next=2 hits=0 seedP=true:boolean seedInPrev=true`
- Immediately after flip to ready: `rc=11 prev=1 next=1 hits=1 seedP=false:boolean seedInPrev=false`
- Stable through watch: `rc=14 … hits=1`, `rc=17 … hits=1`, `rc=20 … hits=1`

## Was `wardrobe-item-ready-snackbar` in the element list?

**NO.** Polled `mobile_list_elements_on_screen` immediately after the flip and at
rc=11, 14, 17, 20. The selector `wardrobe-item-ready-snackbar` was absent every
time. The hierarchy only ever contained the debug banner StaticText, the
"Wardrobe" title, and the status-bar clock.

## Verification chain (evidence)

1. **Fresh bundle confirmed loaded** — relaunched app after `--reset-cache`;
   Home rendered cleanly in ~25s, no red error box.
   `screenshots-260618-au361-final/01-home-fresh-bundle.png`
2. **Seed armed** — `UPDATE … is_preparing = true` → DB returns `t`. Wardrobe
   grid showed "Preparing this item" overlay on the seed tile; banner
   `seedP=true:boolean seedInPrev=true hits=0`.
   `screenshots-260618-au361-final/02-wardrobe-preparing-armed.png`
3. **Waited ~6s on Wardrobe, then flipped to ready** — `UPDATE … is_preparing = false`
   at 10:25:23 → DB returns `f`.
4. **Detection fired but no render** — banner flipped to `hits=1` within one poll;
   no snackbar in hierarchy or on screen across ~20s / 9 poll cycles.
   `screenshots-260618-au361-final/03-wardrobe-after-flip-hits1-no-snackbar.png`
5. **Seed reset** to `false` (clean). **No crashes** — `mobile_list_crashes`
   returned only stale unrelated 2024/2025 system reports, none for auxi.

## Side observation (not the primary finding)

The seed grid tile still showed the "Preparing this item" overlay after the flip
to ready (`seedP=false`), suggesting the per-item grid UI also didn't reflect the
ready state during the window. The polling layer clearly saw the transition
(`hits=1`), so the gap is on the consumption/render side, not detection.

## Routing

This is NOT a Metro/cache issue — fresh bundle reproduces it. The detection hook
fires (`hits=1`) but the Toast does not mount. Route to **mobile-dev**: the
`hits` increment is not driving a visible `Toast.show` / the `toastConfig` entry
for `wardrobe-item-ready-snackbar` is not producing a mounted node. Suspected
area: the snackbar trigger that consumes the `hits` signal on WardrobeScreen and
the `toastConfig` wiring in `App.tsx`. qa-mobile cannot localize file:line
without reading src (out of scope for this run); hand the `hits=1`-fires-but-no-render
repro to mobile-dev.

## Unresolved questions

- Does `Toast.show()` actually get called when `hits` increments, or does the
  increment update state without invoking the toast API? (mobile-dev to confirm.)
- Is the `wardrobe-item-ready-snackbar` testID defined on the custom toast
  component in `toastConfig`, or only intended on a different element? (If the
  testID lives on a node that never mounts, the selector absence is expected.)

---

**Status:** DONE
**Summary:** AU-361 snackbar **FAIL after clean bundle** — snackbar rendered? **N**, hits=**1**. Fresh `--reset-cache` bundle loaded fine (no red box, no crash), the preparing→ready transition was detected (`hits=1`), but `wardrobe-item-ready-snackbar` never mounted (absent from hierarchy across rc 11→20) and was never visible. Stale-bundle hypothesis ruled out — defect is in the snackbar render path. Route to mobile-dev.
**Concerns/Blockers:** None blocking. Detection works but render doesn't; this is a code defect for mobile-dev, not a QA/env issue. Seed reset to false and verified clean.
