# AU-303 Two-Axis Home Swipe — Behavioral Smoke (Sim)

**Supersedes**: `qa-mobile-260531-1326-au303-two-axis-smoke.md` (prior BLOCKED run — false MCP pre-flight blocker; WDA confirmed working this run)
**Date**: 2026-05-31 14:47–15:00
**Build / branch**: `duc2820/au-303-...` worktree at `/Users/nguyenminhduc/Desktop/wardrobe_project/worktrees/auxi-au-303-two-axis-swipe`
**Device**: iPhone 16 Pro · iOS 18.1 · sim `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916` (402×874 pt)
**App**: `com.auxi2026.app` (Metro :8081, backend :5001)
**Method**: mobile-mcp exploratory verify (state confirmation via screenshots) + worktree source read for root cause
**Screenshots**: `auxi/docs/qa-findings/screenshots/2026-05-31/qa-mobile-au303-*.png`

---

## Verdict

| # | Item | Result |
|---|------|--------|
| 1 | Horizontal swipe advances outfit (within set) + pagination dot tracks | **PASS** |
| 2 | Vertical swipe pages between SETS | **FAIL** (blocker for the feature's core gesture) |
| 3 | Guidance overlays appear + "Got it"-only dismiss + persistence | **PASS** |
| 4 | 3 unfavorited browses → ContextChipsModal, sequenced after overlay 2 | **NOT COMPLETED** (app uninstalled mid-run) |
| 5 | Heart toggle resets counter | **PARTIAL / NOT COMPLETED** |
| 6 | Console / red-box warnings | **FINDING** — unhandled AxiosError 404 (×2) |
| 7 | Diagonal-swipe gesture handoff jitter | **NOT ISOLATED** (blocked by #2) |

**Net: vertical paging is broken via gesture. The set-pager only advances via the "Show another" button. This is the headline bug — routes to `mobile-dev`.**

---

## Item 1 — Horizontal swipe: PASS

Backend returned a full set 0 of **3 outfits** (confirmed via element tree: cellKeys `0-0`, `0-1`, `0-2`; pagination shows 3 dots). A full-width left swipe on the grid (`swipe left, x=340 y=300, distance=320`) advanced the inner horizontal `FlatList` cleanly:

- Outfit 0 "Clean and simple." (camp shirt + white jeans + loafers) — dot 1 active
  → `qa-mobile-au303-05-home-coldstart.png`
- Swipe → Outfit 1 "Calm and clear." (denim shirt + black leggings + grey sneakers) — dot 2 active
  → `qa-mobile-au303-06-after-horizontal-swipe1.png`
- Swipe → Outfit 2 "Calm and clear." (red dress + grey sneakers) — dot 3 active
  → `qa-mobile-au303-07-after-horizontal-swipe2.png`

Pagination dot count = `setLength` and `activeIndex` tracks `outfitIndex` correctly (`OutfitActionRow`, HomeScreen.tsx:2043-2050).

**The orchestrator's preliminary finding #1 ("horizontal swipe did not change outfit") was a FALSE ALARM** — caused by imprecise swipe travel/coordinates, not a code defect. A page-width swipe on the grid advances reliably.

---

## Item 2 — Vertical swipe between SETS: FAIL (blocker)

A full set 1 exists below the fold (element tree shows cellKey `1-0` "Just the basics." / "Quiet today." across re-fetches; set 1's "Show another" is `home-show-another-disabled` → set 1 is last). So vertical paging HAS data to page into.

Tested vertical gestures, all **failed to page the set**:
- Swipe up on grid (`up, x=196 y=400, d=350`) → **navigated AWAY to the Wardrobe screen** (gesture stolen) → `qa-mobile-au303-10-after-vertical-swipe-up.png`
- Swipe up on grid (`up, x=196 y=350, d=300`) → **no-op**, stayed on set 0 outfit 0 → `qa-mobile-au303-11-vertical-up-retry.png`
- Swipe up on action band (`up, x=196 y=470, d=280`) → **no-op** → `qa-mobile-au303-12-vertical-up-actionband.png`
- Swipe down on grid (`down, x=196 y=300, d=300`) → **no-op**, did not go back a set → `qa-mobile-au303-14-vertical-down.png`

**Control proving the pager itself works**: tapping the "Show another" button (`home-show-another`) DID advance set 0 → set 1 ("Just the basics.", dot count drops to 1) → `qa-mobile-au303-13-show-another-tap.png`. So `setPagerRef.scrollToIndex` (HomeScreen.tsx:1325) is functional; only the **gesture path** is broken.

This confirms the orchestrator's preliminary finding #2 (highest-risk item) as a **REAL bug**, bidirectional (up and down both fail).

### Root cause (for mobile-dev)

The outer vertical pager is a `FlatList` (`home-set-pager`, HomeScreen.tsx:1507-1560) with `snapToInterval` + `directionalLockEnabled`. Each set row renders an `OptionSheet` (HomeScreen.tsx:1796+) whose grid is wrapped in its OWN **nested vertical `ScrollView`** (`styles.gridScroll`, HomeScreen.tsx:2018-2024):

```
home-set-pager (vertical FlatList)            ← should capture vertical drag
  └─ OutfitSetRow → home-outfit-pager (horizontal FlatList)
       └─ OptionSheet
            └─ <ScrollView style={gridScroll}>  ← STEALS the vertical drag (HomeScreen.tsx:2018)
                 └─ grid tiles
```

A vertical drag starting over the grid is offered to the innermost scrollable first. The inner `gridScroll` ScrollView claims the vertical responder even though its content fits (`maxHeight: GRID_AREA_H`, the code comment at HomeScreen.tsx:2348 itself notes it "stays DORMANT" — but a dormant ScrollView still *captures* the gesture and refuses to bubble it to the outer FlatList). Net: the outer set-pager never receives the vertical pan → set never pages.

The intermittent "navigates to Wardrobe" / "opens drawer" symptom is the same gesture failing to be claimed by the set-pager and being interpreted by a different responder. NOTE: the `Sidebar` (`src/components/layout/Sidebar.tsx`) is **state-driven only** (no PanResponder/PanGestureHandler), so it cannot be opened by a swipe directly — the drawer the orchestrator saw was a side effect of mis-arbitrated gesture / stray hamburger hit, not a Sidebar swipe-handler.

**Suspected fix area** (mobile-dev, do NOT have me edit src): the nested `gridScroll` `ScrollView` at `HomeScreen.tsx:2018`. Options for mobile-dev to evaluate: drop the inner ScrollView when content fits (it's already declared a dormant safety net), or set it `scrollEnabled={false}` unless content overflows `GRID_AREA_H`, or move set-paging onto a gesture-handler that wins the vertical axis. `directionalLockEnabled` on the FlatLists does not help here because the conflict is FlatList-vs-nested-ScrollView, not the two pager axes fighting each other.

**Routing: `mobile-dev` (UI/gesture/state).**

---

## Item 3 — Guidance overlays + dismiss + persistence: PASS

- **Cold start**: overlay 1 (horizontal) did NOT appear → its AsyncStorage one-time flag (`COACHMARK_STORAGE_KEYS.horizontal`, `SwipeCoachMark.tsx:35-52`) was already set on a prior run. **Persistence on relaunch = correct** (overlay correctly suppressed). → `qa-mobile-au303-05-home-coldstart.png`
- **Overlay 2 (vertical)** fired exactly after viewing all 3 outfits of set 0 (CEO Q2 spec) — "Swipe up to explore another outfit set. / Swipe down to go back" + "Got it". Armed on the 3rd horizontal browse, not prematurely. → `qa-mobile-au303-07-after-horizontal-swipe2.png`
- **Backdrop tap does NOT dismiss**: tapped dimmed scrim → overlay still present (correct, per CEO 2026-05-31 override; scrim non-tappable, `SwipeCoachMark.tsx:138`). → `qa-mobile-au303-08-backdrop-tap-overlay-still.png`
- **"Got it" dismisses**: tap → overlay closed, returned to outfit grid. → `qa-mobile-au303-09-after-gotit.png`

Dismiss button testID present in source: `home-coachmark-dismiss-vertical` (`SwipeCoachMark.tsx:156`). It was not surfaced as a discrete element in the a11y tree (nested PillButton text variant) — flagged for `qa-ui`/`mobile-dev`: a Maestro flow will need a reachable selector on the "Got it" pill (currently only the static text label is queryable).

---

## Item 6 — Console / red-box warnings: FINDING

Persistent bottom banner "Open debugger to view warnings" escalated to a red LogBox with a **count of 2**. Opened LogBox:

> **Console Error** — "Uncaught (in promise, id: 1): AxiosError: Request failed with status code 404"
> Source: `promiseRejectionTrackingOptions.js (40:16)` · Call stack: `rejectionTrackingOptions.onUnhandled`

→ `qa-mobile-au303-15-logbox.png`, `qa-mobile-au303-16-logbox-1.png`

This is an **unhandled axios 404 promise rejection** (×2 by run end). It is NOT the weather call (`weatherService.getWeather` has a try/catch, `weatherService.ts:22`) and NOT the recommendation mutation (has `onError`). It is an unguarded `apiClient` call hitting a 404 endpoint. Pre-existing relative to AU-303's swipe logic, but it surfaces a real red-box on the Home screen. Could not trace the exact call site on-device before the app was uninstalled.

**Routing: `mobile-dev`** to locate the unguarded axios call (add `.catch`), and possibly `backend-dev` if the 404 is a missing/renamed endpoint (contract drift). Needs a follow-up with network capture to identify the URL.

---

## Items 4, 5, 7 — NOT COMPLETED

Mid-session, after dismissing LogBox, a mis-aimed tap landed on the iOS home-bar and switched to the Files app. On attempting to relaunch `com.auxi2026.app`, the app **was no longer installed** (`xcrun simctl listapps` returns 337 system apps but no `com.auxi2026.app`; no auxi crash report in `simctl` crash list — it was uninstalled, not crashed). Per dispatch constraints I am **forbidden to rebuild/reinstall**, so these could not be exercised:

- **Item 5 (heart toggle resets counter)**: heart `home-heart-toggle` / `-saved` testID confirmed present in source (HomeScreen.tsx:1370-1374) and counter reset wired (`handleHeartTapForOutfit` sets `unfavoritedSwipeCountRef.current = 0`, HomeScreen.tsx:938), but not exercised live to completion.
- **Item 4 (3-unfavorited-browse → ContextChipsModal, sequenced after overlay 2)**: sequencing logic verified by code read (`openContextModalSequenced` / `recordBrowse`, HomeScreen.tsx:1051-1136) but blocked from live exercise because vertical paging (the browse driver across sets) is broken (#2) AND the app vanished.
- **Item 7 (diagonal jitter)**: `directionalLockEnabled` is set on both pagers, but I could not isolate diagonal behavior because the vertical axis never engages (#2).

**Action for user/orchestrator**: re-boot the app (`./scripts/qa-boot.sh` or reinstall) and re-dispatch a split smoke for items 4/5/7 — ideally AFTER #2 is fixed, since item 4 depends on cross-set browsing working.

---

## Unresolved questions

1. The 404 unhandled rejection — which `apiClient` endpoint? Needs network capture (Charles/Flipper) to name the URL and decide mobile-dev vs backend-dev.
2. Why did `com.auxi2026.app` disappear from the simulator mid-session? No crash report logged. Possibly an external uninstall concurrent with this run. Reinstall needed before any further on-device QA.
3. The "Got it" pill (`home-coachmark-dismiss-vertical`) is not a discrete queryable element in the a11y tree — `qa-ui` should confirm the testID is selectable for the eventual Maestro flow.

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Horizontal swipe + guidance overlays + Got-it/backdrop dismiss + persistence all PASS. Vertical set-paging is BROKEN via gesture (no-op, occasionally steals to Wardrobe) — root cause is the nested `gridScroll` ScrollView (HomeScreen.tsx:2018) swallowing the vertical pan before it reaches the outer `home-set-pager` FlatList; the pager itself works (proven by "Show another"). One unhandled AxiosError 404 red-box surfaced. Items 4/5/7 could not be completed because the app was uninstalled from the sim mid-run (rebuild off-limits).
**Concerns/Blockers:** (1) Item 2 = feature-blocking bug → mobile-dev (fix area HomeScreen.tsx:2018 nested ScrollView). (2) 404 red-box → mobile-dev/backend-dev. (3) App uninstalled — needs reinstall + re-dispatch for items 4/5/7.
