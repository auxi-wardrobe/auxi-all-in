# QA-Mobile — Home collage-play e2e (collage-toggle.yaml)

**Date**: 2026-05-29 14:43
**Branch**: `feat/home-collage-canvas-play` (auxi @ `2c2205b8`)
**Device**: iOS Simulator — iPhone 16 Pro, iOS 18.1 (`9DCBFE8A`)
**App**: `com.auxi2026.app`
**Flow**: `auxi/maestro/flows/home/collage-toggle.yaml`

## 1. Stack boot
- `./scripts/qa-boot.sh` → **exit 0**.
- Backend `:5001` → **UP** (`/health` 200; recommendation served, grid populated, no 5xx).
- iOS sim → **BOOTED** (iPhone 16 Pro).
- App → **installed + launched** (existing build re-used; native build inside qa-boot succeeded, no Xcode/SDK BLOCKER).
- WebDriverAgent → **FAILED to start** → mobile-mcp unavailable this session (doctor exit 2). Worked around with `simctl io screenshot` + Maestro's own failure capture for evidence.

## 2. Maestro result — **FAIL**

```
✓ Run ../_shared/ensure-home.yaml (launch + login skipped, already authed)
✓ assertVisible home-outfit-sheet-0
✓ assertVisible home-tile-0-0
✓ assertVisible home-footer-tab-grid-active
✓ tapOn home-footer-tab-collage        (element found @ bounds [209,767][275,815], COMPLETED)
✓ waitForAnimationToEnd
✗ assertVisible home-collage-0          ← FAILED (retried ~6s, never appeared)
  … remaining steps not reached
```

Failing step: `assertVisible: id=home-collage-0` (line ~52 of the flow).
Log: `logs/maestro/collage-toggle-debug/.maestro/tests/2026-05-29_144221/maestro.log`
Failure screenshot: same dir `screenshot-❌-1780040595149-(collage-toggle.yaml).png`

### Maestro log excerpt
```
14:42:56.914  Tap on id: home-footer-tab-collage COMPLETED
              (element: accessibilityText=Collage view, resource-id=home-footer-tab-collage,
               bounds=[209,767][275,815], enabled=true)
14:43:09–15   Assert that id: home-collage-0 is visible  (polled, never matched)
14:43:15.028  CommandFailed: Assertion is false: id: home-collage-0 is visible
```

## 3. What actually happened (root finding)
The collage toggle button **exists, is enabled, and is tapped successfully**, but the
tap is a **no-op**: the view does NOT switch. Post-tap the UI is still the grid:

- `home-tile-0-0` still present, grid layout unchanged.
- `home-collage-0` (collage surface container) never mounts.
- Footer left grid icon still in the active/highlighted state; right collage icon inactive.
- Confirmed by both Maestro's failure capture (14:43) and a live `simctl` screenshot (14:47) — identical grid state.

This is a **real client-side regression**, not a flaky selector. The flow,
selectors, and login path are all correct.

## 4. Collage surface rendering with real item images?
**Cannot confirm — surface never rendered.** The collage view did not mount, so
there was nothing to assess for overlapping real item images.

Side note (positive): the **grid** view renders the outfit's **real item images**
(white shirt, pink pleated skirt, tan loafers, each labelled "common") — NOT mock
jeans. So the recommendation/image pipeline is healthy; the defect is isolated to
the grid→collage view toggle.

## 5. Crash?
**None.** No `auxi` reports in `~/Library/Logs/DiagnosticReports/`. The toggle
fails silently (no render, no crash, no backend call).

## 6. Screenshots
- After-toggle (still grid — the bug): `auxi/docs/qa-findings/screenshots/2026-05-29/qa-mobile-collage-after-toggle-tap.png`  → copy at `plans/reports/collage-view-sim.png`
- Grid view reference (live simctl): `auxi/docs/qa-findings/screenshots/2026-05-29/qa-mobile-collage-grid-view.png` → copy at `plans/reports/collage-grid-sim.png`

## 7. Routing
→ **mobile-dev** (UI/state). The `home-footer-tab-collage` press handler does not
toggle the sheet's middle region to the collage surface. Suspected area:
HomeScreen footer view-toggle state + conditional render of `home-collage-0`
(`auxi/src/screens/HomeScreen.tsx` and the footer toggle component). Backend is
not implicated.

Bug finding filed: `auxi/docs/qa-findings/2026-05-29-home-collage-toggle-noop.md`

## Unresolved questions
- WDA startup failure blocks mobile-mcp for the session — separate infra issue
  (Xcode signing/runtime per `logs/wda.log`); flagged to whoever owns sim infra,
  did not block this verification.
