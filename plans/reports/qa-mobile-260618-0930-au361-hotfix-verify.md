# AU-361 "item ready" snackbar — hotfix live verification

**Verdict: FAIL** (confirmed across 3 independent dispatches)
**Date:** 2026-06-18 ~09:30–10:27
**Build:** `auxi` branch `fix/au361-toast-config-wiring` (debug build, Metro :8081, `__DEV__=true` → backend `http://localhost:5001`)
**Device:** iOS Simulator iPhone 16 Pro (iOS 18.1, UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`), app `com.auxi2026.app`
**Backend:** au-346 on :5001, seeds applied (login `/api/login`, items `/api/wardrobe/items` — both verified live)

## Result summary

| Check | Result |
|---|---|
| Full reload, no red error box | PASS (clean launch to Home, session persisted; also clean on `--reset-cache` bundle) |
| Preparing overlay renders | PASS (grid shows "Preparing this item" for genuinely-preparing items) |
| Teal "Your item is ready" snackbar fires on preparing→ready | **FAIL — never appeared** |
| Fired exactly once | N/A (toast rendered zero times; transition logic DID fire once — banner `hits=0→1`) |
| Preparing overlay cleared (no white-screen) | No white-screen / no crash; seed tile off-screen, but banner runs saw first-tile overlay NOT clear despite ready state (UI-vs-state desync) |
| App crash | None (`mobile_get_crash` clean — only unrelated 2024/2025 system entries) |

## Screenshots
- Failure (no snackbar after a confirmed ready transition, bottom region cleared):
  `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-hotfix/au361-no-snackbar-after-ready-transition.png`
- Earlier stuck-preparing state:
  `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-hotfix/wardrobe-stuck-preparing-no-snackbar.png`
- Debug-banner run (separate dispatch):
  `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-debug/` (`01-before-flip-preparing.png` … `04-after-flip-t15.png` + `banner-im-01..04.png`)
- Clean-bundle run (separate dispatch):
  `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-au361-final/` (`01-home-fresh-bundle.png`, `02-wardrobe-preparing-armed.png`, `03-wardrobe-after-flip-hits1-no-snackbar.png`)

## What was run
Ran the preparing→ready transition **4 times** in this dispatch, including **2 fully fresh app sessions** (terminate+launch → empty `preparingIdsRef`/`readyToastedIdsRef`), with the bottom dev-warnings bar dismissed on the final runs so it could not occlude a `position: 'bottom'` toast. In every run: seed armed `is_preparing=true`, app polled and recorded it as preparing, seed flipped to `false`, waited ≥3 poll cycles. The `wardrobe-item-ready-snackbar` element never appeared in any `list_elements_on_screen` call and never rendered in any screenshot. Two follow-up dispatches (runtime banner; clean Metro bundle) confirmed the finding — see below.

## Key correction to the original test assumption
The persistent "Preparing this item" overlay on the **top-left** grid tile is a DIFFERENT item — **"New Item" (`ecf33819-878a-419e-b300-44fefa9454b7`)**, genuinely `is_preparing=true` in the backend. The seed item **"Leather Trousers · Black"** sits at **list position 25** (off-screen, below the fold). The app's data layer is correct — it faithfully renders whichever items the API reports as preparing. The grid/poll/data path is healthy; only the toast surfacing is broken.

## The hotfix IS present and correct (registration restored)
Verified on the checked-out branch:
- `auxi/src/components/feedback/toastConfig.tsx:30` — `SuccessSnackbar` renders `testID="wardrobe-item-ready-snackbar"` + check icon + `text1` label.
- `auxi/src/components/feedback/toastConfig.tsx:50` — `successSnackbar: props => <SuccessSnackbar {...props} />` registered.
- `auxi/App.tsx:84` — `<Toast config={toastConfig} />` wired.
- `auxi/src/translations/en-EN.json:239` — `item_ready_title` = "Your item is ready" present.

Registration was the original AU-361 root cause and it is now fixed. But registration is **necessary, not sufficient** — the toast still does not surface on a live transition.

## ROOT CAUSE ISOLATED — transition fires, toast no-ops (debug-banner run)
A separate instrumented dispatch injected a runtime banner into `reconcileReadyItems` and read it before/after the flip:

| When | Banner |
|---|---|
| before flip (preparing) | `rc=3 prev=2 next=2 hits=0 seedP=true:boolean seedInPrev=true` |
| after flip (settled) | `rc=32 prev=1 next=1 hits=1 seedP=false:boolean seedInPrev=false` |

- **`hits` 0 → 1, held at 1** — the `Toast.show({ type: 'successSnackbar' })` branch (`WardrobeScreen.tsx:146`) WAS reached, exactly once. Dedup correct (never climbed past 1).
- **`seedP=false:boolean`** — `is_preparing` is a real JS boolean (not `"false"` string); `isPreparing()` check sound.
- **`seedInPrev` true → false** — prior-fetch preparing set contained the seed, so the `prevPreparing.has(item.id)` guard passed.

Conclusion: transition detection, field mapping, dedup, and the show-call all execute correctly. **The toast does not render when `Toast.show` is invoked with the custom `successSnackbar` type.** Root cause is the toast render/mount seam — registration *source* is correct, so suspect a runtime mismatch (a second/shadowed config-less `<Toast>` swallowing the custom type, the configured `<Toast>` not mounting at the root above overlays, or `position:'bottom'` clipping/occlusion).

## STALE-BUNDLE HYPOTHESIS RULED OUT — clean Metro bundle run
Final dispatch reloaded with a clean Metro bundle (`--reset-cache`) to eliminate any cached-transform explanation. Result:
- Fresh bundle confirmed loading — Home rendered, no red error box, no crash.
- Seed armed → banner `seedP=true:boolean seedInPrev=true hits=0`; Wardrobe tile showed "Preparing this item".
- Flipped to ready at 10:25:23 → detection fired: banner flipped to **`hits=1`** within one poll and held steady through rc 11 → 14 → 17 → 20 (~20s / ~9 poll cycles).
- **Snackbar never rendered** — `wardrobe-item-ready-snackbar` absent from every `list_elements_on_screen`; no teal toast on screen (only the dark RN dev "Open debugger" system toast).

This disproves the Metro-caching theory. The `hits=1` detection works on a guaranteed-fresh bundle; the Toast node still does not mount. **Three independent dispatches now agree: this is a render-path code defect, not env/cache/QA.**

Visibility-window caveat (now closed): one earlier run's first post-flip capture landed ~11s out, leaving a sub-10s window unsampled. My 4 runs plus the clean-bundle run sampled tighter (element queries within the toast window across ~20s / 9 poll cycles) and never observed the node — the toast effectively does not surface.

Side observation (separate from the toast bug): in both banner runs, runtime state went ready (`seedP=false`, `hits=1`) but the first grid tile's "Preparing this item" overlay never cleared through the final capture — a UI-vs-state desync worth the AU-361 owner's attention.

## Routing
**mobile-dev (UI/state)** — AU-361 toast does not surface even though `Toast.show` is provably invoked (banner `hits=0→1`, reproduced on a clean bundle). Registration source is correct, so the bug is at the toast render/mount seam, NOT transition detection or Metro caching. Reproduce on sim: arm an owned item `is_preparing=true`, open Wardrobe (let poll record it), flip to `false`, observe `hits` increment but no toast node. Suspected files (re-prioritized after the banner + clean-bundle runs):
- `auxi/App.tsx:84` (`<Toast config={toastConfig} />`) — **primary**: confirm this is the only `<Toast>` mounted, carries the config, and renders at the root above the navigator/overlays. A second config-less `<Toast>` elsewhere would swallow the custom `successSnackbar` type.
- `auxi/src/components/feedback/toastConfig.tsx:27-50` — confirm `successSnackbar` renders when `Toast.show({type:'successSnackbar'})` is called directly (isolate from the wardrobe path); check `position:'bottom'` isn't clipped/occluded.
- `auxi/src/screens/WardrobeScreen.tsx:146-150` — confirmed REACHED (banner `hits=1`); call site to keep in the repro, not the fault.
- Secondary (separate desync): first-tile "Preparing" overlay not clearing after ready — `WardrobeScreen.tsx` preparing-overlay render path (`:390`, `:573-587`).

## Notes / unresolved
- Could not positively screenshot the seed's OWN overlay clearing — seed is at grid position 25 (off-screen) and the test is bottom-toast-centric. No white-screen or crash in any session — the dispatch's white-screen regression did NOT recur.
- Seed reset to `is_preparing=false` (ready) at teardown of every run — confirmed via psql.
- "New Item" (`ecf33819-...`) remains `is_preparing=true` in the backend (pre-existing, not touched).
- The `home-menu-button` / sidebar items (`sidebar-menu-wardrobe`) / Wardrobe filter pills are NOT tappable/exposed via mobile-mcp's accessibility tree (TopIconButton + native-driver push-drawer hit-test desync); had to drive by coordinate, and a follow-up dispatch needed a throwaway Maestro nav prelude to reach Wardrobe. **Ask qa-ui** for a Maestro nav prelude covering drawer-reachable screens so repeat AU-361 verifies are deterministic.
