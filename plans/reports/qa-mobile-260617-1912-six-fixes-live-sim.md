# QA-Mobile — Six Fixes Live Verification (iOS Sim)

**Date**: 2026-06-17 19:12–19:33
**Device**: iPhone 16 Pro · iOS 18.1 · UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916` (booted)
**App**: com.auxi2026.app (installed + launched)
**Backend**: http://localhost:5001 (UP, /docs 200) · Metro :8081 (UP)
**QA account**: qa-test@auxi.app
**Tooling**: Maestro 2.5.1 (JAVA_HOME = openjdk@homebrew) + mobile-mcp full tier
**Screenshots**: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260617-1912/`

App crashes during the whole session: **0** (`com.auxi2026.app` never crashed). The
only entries in `mobile_list_crashes` are simulator-system daemons
(`AccessibilityControlsExtension`, `trustd`, `searchd`) triggered by mobile-mcp's
accessibility queries — not the app under test.

---

## 1. AU-356 — register routing → PasswordCreation · **PASS**

Deterministic Maestro flow `auth/au356-signup-reaches-password.yaml`, run with a
fresh timestamped email (`qa-au356-<ts>@example.com`).

All 11 steps **COMPLETED**, including:
- `assertVisible: id=password-input-field` (reached PasswordCreation)
- `assertVisible: id=password-email-value` + `assertVisible: text=<fresh email>` (email carried through read-only)
- `assertVisible: id=password-submit-button` (account can be created)
- `assertNotVisible: id=signin-password-input` (NEGATIVE GUARD — no bounce to SignIn)

Live re-walk via mobile-mcp reproduced the password step: read-only email +
"create a password" field + criteria checklist (8 chars / lowercase / number) +
Create-password submit button.

**Bonus confirmation of the AU-356 server-side path**: while manually logging in
the existing `qa-test@auxi.app`, EmailInput (signup mode) advanced to
PasswordCreation, and on submit the server's 409 EMAIL_ALREADY_EXISTS correctly
re-routed to the **SignIn** screen (`signin-submit`, email pre-filled). Both the
fresh-email and already-registered branches behave per spec.

Evidence:
- `au356-password-step-live-PASS.png` (canonical — live password step with fresh email)
- `au356-password-step-PASS.png`

---

## 2. AU-360 — canvas layer reorder · **PASS** (visibly verified)

Opened the Outfit Canvas (Remix editor) from Home with a seeded outfit
(white shirt + tan loafers). Initial stack: **loafers ON TOP of shirt**.

- Tapping an item **enables** the layer toolbar (bring-forward / send-backward
  icons darken); tapping empty canvas **disables** them (selection mechanism works).
- Selected the loafers → tapped **send-backward** → the loafers moved **BEHIND the
  shirt**: the shirt now fully covers them, only the loafer toes peek out at the
  bottom-right. The **redo arrow** activated (an undoable canvas mutation recorded).

This is exactly the fix: z-index SWAP with the adjacent neighbour produces a
distinct, visible re-stack (the pre-fix ±1 nudge was a no-op tie). Verified
visually via screenshot before/after.

Note on the Maestro flow `home/au360-canvas-layer-reorder.yaml`: it could not run
to completion because `_shared/ensure-home.yaml` asserts `home-screen-root` while a
first-launch swipe **coachmark overlay** (`home-coachmark-dismiss-horizontal`) dims
it. `home-screen-root` IS present in the captured hierarchy — the coachmark just
obscures it. This is a **flow-authoring gap** (ensure-home doesn't dismiss the
coachmark before asserting), routed to **qa-ui** — NOT an AU-360 regression.

Evidence (before/after):
- `au360-loafers-sel2.png` (BEFORE — loafers on top, selected, toolbar enabled)
- `au360-after-send-back.png` (AFTER — loafers behind shirt, redo active)
- `au360-canvas-state.png`, `au360-before-reorder.png`

---

## 3. AU-359 — swipe edge artifact · **PASS**

Logged in, Home recommendations loaded from backend. Performed 3 swipes
(left ×2, right ×1) across single-item and 2×2-grid outfit cards.

On every transition the active card and item tiles render with **clean rounded
corners — no edge artifact, no bleed, no smear** at photo edges. The
bottom **peek card retains its scale affordance** on each card. Mode pill,
"common" badges, and pin affordances all render correctly.

Evidence:
- `au359-home-resting.png`, `au359-during-left-swipe.png`,
  `au359-swipe-edge-check.png`, `au359-right-swipe-edge.png`

---

## 4. AU-361 — item-ready snackbar · **PARTIAL** (code wired, runtime trigger blocked)

Reached the Wardrobe grid (4-col, category filters All/Top/Bottoms/One-Piece/
Shoes/Acc., ~15 items). The `+` add button launches the **native iOS image
picker / camera**, which can't be driven on the simulator (no camera) and isn't
queryable by mobile-mcp, so the upload could not be completed.

Even with an upload, the teal M3 "Your item is ready" snackbar fires only on the
backend **`is_preparing → ready`** transition — needs a completed background
processing job on a fresh photo, not forceable in a sim smoke.

Code IS wired (read-only verify): `testID="wardrobe-item-ready-snackbar"` at
`src/components/feedback/toastConfig.tsx:26`; the `is_preparing`/ready logic lives
in `WardrobeScreen.tsx` + `ItemDetailScreen.tsx`.

**Flag**: ready-snackbar needs a completed background job (+ camera/photo) to observe live.

Evidence: `au361-wardrobe-grid.png`, `au361-add-flow*.png`

---

## 5. AU-358 — self-viz quit + notify · **PARTIAL** (code wired, live generating blocked)

Entered the Self Visualization (STOM) flow from a favourite's "Self visualization"
button (`favourite-self-visualization-<id>`). Landed on **StepSelfie 1/3** —
"Start with a selfie photo · Your photos are always kept private".

The selfie/full-body capture CTA (`stom-take-photo`) opens the **native camera /
photo-library picker** — not exercisable on the sim (no camera, picker not
mobile-mcp-drivable). Without real selfie + body photos I can't advance through
steps 1/3 → 3/3 to reach the AI generating screen where `stom-quit-generating`
renders. Live AI generation also needs the backend render to actually run.

Code IS wired (read-only verify):
- `GeneratingView.tsx:48` renders `stom-quit-generating` (PillButton, quit hint +
  a11y label) in the non-errored generating state; omitted in the errored state.
- `SeeThisOnMeScreen.tsx`: `handleQuitGeneration` (onQuit, line 461) backgrounds the
  render, fires `body_shape_generation_backgrounded`; header back during generation =
  quit-to-background, **not cancel** (line 446). A background-safe generation store
  (`try-on-generation-store.ts`) runs the high-res render outside React so it
  continues after unmount.
- `try-on-completion-notice.ts`: `showTryOnCompletionNotice` fires an in-app tappable
  Toast ("Your look is ready · View") via react-native-toast-message when a
  backgrounded render finishes (in-app notify, push deliberately out of scope — YAGNI).

**Flag**: quit control + backgrounding + completion-notify cannot be observed live
without a full photo capture + a running AI render (both blocked on sim).

Evidence: `au358-stom-step1-selfie.png` (STOM step 1/3 reached)

---

## 6. AU-354 — reuse body-photo · **PARTIAL** (code wired, needs pre-existing profile)

The reuse-confirm screen activates only when a **persisted body profile with a
usable photo** exists. The QA account has **no saved profile** — STOM opened to a
**fresh capture (step 1/3)**, so the reuse path correctly did not appear.

Setting up a profile first requires the same native selfie/body capture that's
blocked on the sim, so the reuse-confirm screen was not reachable in this smoke.

Code IS wired (read-only verify): `SeeThisOnMeScreen.tsx:490` renders
`StepReuseConfirm` with the persisted `photoUri` + `onConfirm`/`onRetake` ("Use
this photo" / "Retake photos") under the gate
`reuseMode && !reuseConfirmed && !rehydratedRef.current && reusePhotoUri &&
step === 'selfie'` — replacing silent auto-regeneration. `BodyShapeCarousel.tsx`
exposes `stom-shape-retake` / `stom-generate` / `stom-optin`.

**Flag**: reuse-confirm needs a pre-existing saved body profile (not creatable in a
sim smoke without camera).

Evidence: same STOM entry as AU-358 — fresh capture (no reuse) confirms the gate.

---

## Summary table

| # | Ticket | Area | Verdict | Evidence (canonical) |
|---|--------|------|---------|----------------------|
| 1 | AU-356 | register → PasswordCreation | **PASS** | au356-password-step-live-PASS.png |
| 2 | AU-360 | canvas layer reorder | **PASS** | au360-loafers-sel2 → au360-after-send-back.png |
| 3 | AU-359 | swipe edge artifact | **PASS** | au359-right-swipe-edge.png |
| 4 | AU-361 | item-ready snackbar | **PARTIAL** (code wired; needs background job + camera) | au361-wardrobe-grid.png |
| 5 | AU-358 | self-viz quit + notify | **PARTIAL** (code wired; needs photo capture + live render) | au358-stom-step1-selfie.png |
| 6 | AU-354 | reuse body-photo | **PARTIAL** (code wired; needs saved profile) | au358-stom-step1-selfie.png |

**Counts**: PASS 3 · PARTIAL 3 · FAIL 0 · App crashes 0

All 3 PARTIALs share one root cause: the **native camera / photo-library picker is
not exercisable on the iOS simulator** (no camera, picker not mobile-mcp-drivable),
which gates item upload (AU-361) and STOM photo capture (AU-358, AU-354). In every
case the fix code is present and correctly wired; only the live runtime trigger is
unobservable in a sim smoke. None are regressions.

## Routing / follow-ups

- **qa-ui**: `_shared/ensure-home.yaml` should dismiss the
  `home-coachmark-dismiss-horizontal` first-launch coachmark before asserting
  `home-screen-root`, else any flow chaining through it (incl.
  `home/au360-canvas-layer-reorder.yaml`) fails at the gate on a fresh launch.
- **qa-ui**: `_shared/login.yaml` assumes `auth-email-input` is visible immediately
  after launch, but the app now boots into the **Welcome** screen — the flow is
  missing the `welcome-cta-email` tap (and the post-fix SignIn detour for existing
  accounts). `auth/login.yaml` currently fails on this.
- **mobile-dev** (non-blocking): WardrobeScreen exposes almost no queryable
  testIDs/a11y to mobile-mcp (hamburger, `+`, grid tiles) — coordinate taps are the
  only option there, which slows exploratory verify. Consider testIDs on the header
  buttons + grid tiles.
- To fully observe AU-361 / AU-358 / AU-354 live, either (a) seed a wardrobe item in
  `is_preparing` state + a body profile with a photo via the backend before the
  smoke, or (b) promote these to Maestro flows with mocked capture/render once stable
  testIDs land.
