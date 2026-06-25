# QA-Mobile Re-verify — AU-361 / AU-354 / AU-358 quit (LIVE sim)

**Date:** 2026-06-18 00:02 (run started 2026-06-17 23:50)
**Device:** iOS Simulator iPhone 16 Pro, iOS 18.1, UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`
**App:** `com.auxi2026.app` (relaunched at start to pick up menu a11y hot-reload)
**Backend:** http://localhost:5001 (au-346 build) — `GET /api/body/active` → 200 confirmed at start
**Account:** qa-test@auxi.app (session persisted; already logged in on relaunch)
**Menu reachable?** YES — `home-menu-button` now in a11y tree (`Button`, label "Open menu"); tap opens nav drawer (Wardrobe, My Favourite, etc.). Prior BLOCKED state is resolved.

---

## 1) AU-361 — item-ready snackbar — **FAIL**

Seeded item `e2879f93-eb14-43e7-9940-238e70f723b3` ("Leather Trousers · Black", bottoms).

**Observation:**
- Preparing state renders correctly. After arming `is_preparing=true` and entering Wardrobe fresh, the seeded tile shows a "Preparing this item" overlay (screenshot 01). Confirmed via API: `is_preparing: true`.
- Flipping `is_preparing=false` → the client polls and the preparing overlay **clears** every time (tile re-renders to a normal item). So the poll + tile-state update path works.
- BUT the teal "Your item is ready" snackbar (`wardrobe-item-ready-snackbar`) **never appeared** — not in any screenshot and not in the a11y element tree.

**Repro rate:** 3/3 clean repros failed to show the snackbar. Final repro monitored a full 20s on Wardrobe (2+ poll cycles) after the flip, screenshotting at t+6s / t+13s / t+20s — overlay cleared by t+6s, no snackbar at any point.

**Per spec:** "FAIL if no snackbar after 2 poll cycles" → condition met. **FAIL.**

**Screenshots:**
- Preparing state: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260617-2009/01-au361-preparing-state.png`
- (ready/post-flip frames showed cleared overlay, no snackbar — not saved individually)

**Suspected area / routing:** mobile-dev. The tile-level preparing→ready transition works, but the snackbar dispatch on that transition does not fire. Likely the snackbar trigger (compare prev-poll preparing vs current-poll ready) isn't wired to the same query update that re-renders the tile, OR the dedup/visibility gate suppresses it. Selector `wardrobe-item-ready-snackbar` is absent from the rendered tree. Needs mobile-dev to confirm the snackbar effect actually runs on the poll diff.

---

## 2) AU-354 — reuse body-photo confirm screen — **PASS**

**Path:** drawer → My Favourite → a favourite's "Self visualization" (testID `favourite-self-visualization-<id>`) → reuse-confirm.

**Observation:** Instead of auto-generating, the app shows a reuse-confirm screen:
- Header "Self visualization" (`stom-back` back button present)
- Banner: "Here's the body photo you saved. Use it again, or retake your photos."
- Saved body photo thumbnail (testID `stom-reuse-confirm-thumb`) — renders the user's saved body photo (olive trousers + tank)
- Two buttons visible: **"Use this photo"** (dark primary) and **"Retake photos"**

Tapping "Use this photo" advanced to the generating screen (see AU-358 below). **PASS** — reuse-confirm shows the saved photo + both buttons.

**Screenshots:**
- Favourites list: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260617-2009/03-favourites-list.png`
- Reuse-confirm: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260617-2009/04-au354-reuse-confirm.png`

---

## 3) AU-358 quit (quick) — **PASS**

**Observation:** "Use this photo" → generating screen renders: `macgie-loader` (Image, value "busy"), "Creating your look…", helper text "This can take a moment. You can leave — we'll let you know the second it's ready.", and a **"Leave — notify me when ready"** quit button at the bottom.
- The quit affordance is present (visible button). Note: it did not surface in the a11y tree under the exact testID `stom-quit-generating` — the named elements returned were `stom-back` + `macgie-loader` + the helper text. The Leave button is visually present and functional.
- Tapping "Leave — notify me when ready" **returned toward Home** (landed on Home: hamburger menu, weather, outfit grid, "Wear this" CTA). Quit works.

Completion-notify not tested (render 500s known-separate; never reached a completed render).

**Screenshots:**
- Generating + quit: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260617-2009/05-au358-generating-quit.png`
- Returned to Home: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260617-2009/06-au358-returned-home.png`

**Minor note for mobile-dev (not a blocker):** the quit button on the generating screen did not expose the `stom-quit-generating` testID in the accessibility tree (only `stom-back` did). If automated Maestro coverage is planned for the quit path, the Leave button needs an accessible testID. Confirm whether this is the intended id or a missing wiring.

---

## Crashes
`mobile_list_crashes` checked after each flow — **no `com.auxi2026.app` crashes**. Only unrelated system process entries (AccessibilityControlsExtension, searchd, trustd, IDE/Cursor helpers).

## Cleanup
Seeded item `e2879f93-...` reset to `is_preparing=false` (ready) at end of run.

---

## Other a11y note (observational, not in scope)
The nav drawer items (Wardrobe, My Favourite, Setting, etc.) are **not exposed in the accessibility tree** — only the pushed Home/Wardrobe content shows when the drawer is open. Navigation worked via screenshot-coordinate taps. This blocks selector-based Maestro coverage of drawer navigation. Flag to qa-ui / mobile-dev if drawer flows are to be automated.

---

**Status:** DONE_WITH_CONCERNS
**Summary:** AU-361 FAIL (preparing→ready transition works, tile overlay clears, but `wardrobe-item-ready-snackbar` never fires — 3/3 repros, 2+ poll cycles) · AU-354 PASS (reuse-confirm shows saved photo + "Use this photo"/"Retake photos") · AU-358 quit PASS (Leave button present, returns toward Home) · menu reachable? YES
**Concerns/Blockers:** AU-361 snackbar regression → route to mobile-dev. Drawer nav items + generating-screen quit button lack accessibility testIDs (`stom-quit-generating` not in tree) — blocks Maestro automation of those paths; flag to mobile-dev/qa-ui.
