# AU-361 Built-in Toast Probe — qa-mobile

**Date:** 2026-06-18 ~10:28–10:56
**Device:** iOS Simulator iPhone 16 Pro (iOS 18.1, UDID 9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916)
**App:** com.auxi2026.app · Metro --reset-cache · backend au-346 :5001
**Probe code:** `WardrobeScreen.tsx:153-157` fires built-in `Toast.show({type:'success', text1:'AU361 BUILTIN PROBE', position:'bottom'})` on the seed item's preparing→ready transition (custom `successSnackbar` temporarily disabled).
**Screenshots:** `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260618-builtin-probe/`

## Headline

**Built-in toasts DO render in the running app.** The AU-361 built-in `success` probe toast (green success card) appeared at `position:'bottom'` after the seed flip, and `hits` incremented 0→1 confirming the `Toast.show` call fired. The `<Toast config={toastConfig}/>` root mount at `App.tsx:84` is working.

The toast is visually OCCLUDED by React Native's dev LogBox banner ("Open debugger to view warnings") which lives in the same bottom zone and renders on top — but the toast's white rounded card + green success accent are clearly visible peeking above it.

---

## Part A — built-in `info` "coming soon" toast (Wardrobe → + → Import from web)

**Result: INCONCLUSIVE (could not reliably deliver the tap).**

- Reached Wardrobe and opened the add sheet (`wardrobe-add-btn`). All three options render: "Search the database", "Take a photo", **"Import from web — Paste a product link to save an item"** (`testID="wardrobe-add-import"`, `onPress=handleImportFromWeb`, fires built-in `type:'info'` "Coming soon" toast — `WardrobeScreen.tsx:265-273`).
- The add sheet is a `Modal`-based bottom sheet whose option rows collapse into a single flattened accessibility container — neither mobile-mcp nor WDA could address the rows by `testID` (`wardrobe-add-import` → "no such element").
- Coordinate taps (mobile-mcp click + WDA `wda/tap`) on the row repeatedly failed to fire the `onPress`: a positive-control tap on "Search the database" (which navigates to the Database screen) also did NOT navigate, and a mobile-mcp click landed on the dismiss-scrim instead. So I cannot assert the info toast did or didn't render — I never confirmed the row's handler ran.
- Across ~6 tap attempts and dozens of burst frames, no info toast was observed, but with no confirmation the tap fired this is **not** evidence of non-rendering.
- Screenshot: `canonical-partA-add-sheet-import-visible.png` (all 3 options visible after LogBox dismiss).

**Part A built-in info toast shown?** Inconclusive (tap not deliverable on the flattened modal sheet). Superseded by Part B, which is a stronger, tap-free built-in-toast test.

---

## Part B — AU361 built-in `success` probe toast (DB seed flip)

**Result: PASS — built-in success toast rendered. `hits=1`.**

Procedure (run cleanly after app relaunch to reset the `readyToastedIdsRef` one-shot dedup):
1. On Wardrobe, fresh: banner `rc=1 prev=0 next=1 hits=0 seedP=false`.
2. Armed seed `is_preparing=true`; after ~9s (poll = `PREPARING_POLL_MS` 4000ms) banner showed `rc=6 prev=2 next=2 hits=0 seedP=true:boolean seedInPrev=true` — screen observed the preparing state.
3. Flipped `is_preparing=false`; ~4s later the transition-detecting poll fired the probe.
4. Banner after flip: **`rc=16 prev=1 next=1 hits=1 seedP=false:boolean seedInPrev=false`** — `hits` 0→1, the `Toast.show` provably executed.
5. Dense burst caught the toast slide-in/settle window: a **white rounded toast card with a green success accent bar** rendered at the bottom.

Evidence screenshots:
- `canonical-partB-toast-green-card-zoom.png` — zoomed strip: white toast card top edge + bright green success accent clearly above the dark LogBox banner. **This is the rendered built-in success toast.**
- `canonical-partB-toast-rendered-occluded.png` (= `partB3-28.png`) — full frame: green toast card behind the "Open debugger to view warnings" LogBox banner.
- `partB3-25.png` / `partB3-26.png` — toast mid-slide-in with green accent emerging.

**Part B "AU361 BUILTIN PROBE" shown?** YES — green success toast card rendered at position:bottom. **hits=1.** (Exact "AU361 BUILTIN PROBE" text body sits behind the RN dev LogBox banner, which auto-reappears on every grid-refetch render warning and occupies the same bottom slot.)

---

## Implications for the AU-361 custom-toast defect

- The `<Toast>` mount is fine and built-in types render (success card + green accent confirmed). So the custom `successSnackbar` failing to render is **NOT** a broken mount — it points to a custom-config application issue (the `successSnackbar` entry in `src/components/feedback/toastConfig.tsx` not being picked up / mis-keyed / rendering empty), not the library wiring.
- Secondary finding worth flagging to mobile-dev: built-in `position:'bottom'` toasts on Wardrobe are visually buried under the RN dev LogBox warning banner in this dev build. In release (no LogBox) this won't occur, but during QA it makes bottom toasts hard to see. The grid refetch is also logging a warning that keeps re-summoning LogBox.

## Notes / unresolved
- Add-sheet option rows have `testID`s in code (`wardrobe-add-import`) but are not addressable via WDA/mobile-mcp because the `Modal` bottom sheet flattens them into one a11y node — Part A could not be driven deterministically. If Part A must be settled, ask `qa-ui` whether the sheet rows can expose individual accessibility nodes, or trigger `handleImportFromWeb` via a Maestro flow that taps by visible text inside the modal.
- The probe toast is one-shot per item id per session (`readyToastedIdsRef`), so re-arming without an app relaunch will NOT re-fire — relaunch to reset between runs.
- No crashes during the probe (`mobile_list_crashes` shows only unrelated 2024/2025 entries).
- Seed `e2879f93-eb14-43e7-9940-238e70f723b3` left at `is_preparing=false` (verified).

**Status:** DONE
**Summary:** Part A built-in info toast — INCONCLUSIVE (add-sheet rows not tappable via synthetic input; flattened modal a11y). Part B "AU361 BUILTIN PROBE" — YES, built-in success toast rendered (green card visible, occluded by RN LogBox); hits=1. Built-in toast mount is healthy → AU-361 custom defect is a toastConfig application issue, not a broken `<Toast>` mount.
**Concerns/Blockers:** (1) Modal bottom-sheet option rows aren't addressable by testID via WDA/mobile-mcp — blocks deterministic Part A; route to qa-ui for a text-based Maestro tap or a11y-node fix. (2) RN dev LogBox occludes bottom toasts in this dev build — cosmetic to QA only, but flag to mobile-dev (grid refetch logs a warning that keeps re-summoning LogBox).
