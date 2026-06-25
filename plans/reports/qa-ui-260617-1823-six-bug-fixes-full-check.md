# qa-ui — Six Bug-Fix Full Visual + Behavioral QA (260617-1823)

**Agent:** qa-ui · **Mode:** Compare (static) + Maestro authoring
**Scope:** read-only on `auxi/src/**`; authored 2 Maestro flows; updated maestro README
**Tree state:** all six fixes uncommitted in working tree; `npx tsc --noEmit` clean (Node 20); token-lint shows only pre-existing legacy debt (no new drift in any fix file)
**Sim screenshots:** PENDING — no booted simulator, app not built (`mcp-doctor` → "No iPhone simulator booted"; `mobile_list_available_devices` → `[]`). Per the time-box directive, fell back to thorough static review. A full `qa-boot.sh` (boot + cold RN build + Metro) exceeds the box for uncommitted working-tree changes.

---

## AU-361 — item-ready toast → **ESCALATE (functional PASS, design deviation)**

**File:** `WardrobeScreen.tsx`

**What I checked**
- `reconcileReadyItems` (123–159): compares prior vs current `is_preparing` set; toasts only on a true `preparing→ready` transition. Dedup is correct — `readyToastedIdsRef` guarantees one toast per item per session across polls/refocus.
- Lightweight polling (202–214): `setInterval(PREPARING_POLL_MS=4000)` runs only while focused AND something is preparing; `silent` refetch avoids skeleton flash; cleared on unfocus/no-preparing. Sound.
- Toast root: `<Toast />` is mounted once at `App.tsx:83`, so `Toast.show` from the screen renders. Position `bottom` matches the Figma snackbar's bottom anchor (node 3910:22258 @ y=747).
- **testID:** N/A (toast is library-rendered, non-interactive).
- **i18n:** `wardrobe.list.item_ready_title` present + translated in en/fr/vi.
- **analytics:** `item_ready_toast_shown { item_category? }` wired (152); documented in tracking-plan §5 + take-photo funnel §10.

**Defects / why ESCALATE**
1. **Design deviation (the flagged one).** Figma node 2852-18884 specifies a **Material-3 Snackbar** (`3910:22258`): teal `#4cf4d3` (success/200) bg, leading check icon, dark `#1d1f23` text, 4px radius, M3 elevation shadows. The fix uses `react-native-toast-message` `type:'success'` with **no custom `config`** on `<Toast />` — so it renders the library's DEFAULT success toast (white card / green left-border), which materially differs from the designed teal snackbar. Reporter explicitly wanted a snackbar. **Route to mobile-dev:** either supply a custom toast `config` matching the snackbar tokens, or build the snackbar primitive. (Note the Figma snackbar copy is the *"item added… preparing in background"* string; the bug's actual ask is the *ready* notification — copy choice "Your item is ready" is correct, only the visual styling deviates.)
2. **Minor:** `is_preparing` is read off the `[key: string]: unknown` index signature on `WardrobeItem` (not an explicit field). Compiles, but an explicit `is_preparing?: boolean` typed field would be cleaner and self-documenting. Non-blocking.
3. **Nit:** tracking-plan cites `WardrobeScreen.tsx:149`; the `track()` call is at `:152`. Doc line-ref drift.

---

## AU-360 — canvas layer order → **PASS**

**File:** `OutfitCanvasScreen.tsx` (`moveLayer` 411–451)

**What I checked**
- Fix is correct: sorts items ascending by z, finds selected, **swaps z-index with the adjacent neighbour**, no-ops at the front/back edge (and fires NO event there — matches doc). Replaces the broken `±1` nudge that produced z-ties → invisible moves.
- Render honors it: `OutfitCanvasSurface` sorts by `zIndex` (412) and binds `zIndex: item.zIndex` per item (323), so the swap visibly re-stacks.
- **testID:** `canvas-tool-layer-up` / `canvas-tool-layer-down` present + distinct; both carry a11yLabels (`outfitCanvas.a11y_bring_forward` / `a11y_send_backward`).
- **i18n:** both a11y keys present in en/fr/vi.
- **analytics:** `canvas_item_layer_reordered { direction }` wired (448); documented in tracking-plan §5.11 (fires only on an actual move).

**Defects** — none functional. Testability gap only (see Maestro section): canvas items use dynamic `canvas-item-${item.id}` testIDs + surface has no `testID`, so a Maestro flow can't deterministically verify the *visible* swap. Filed to mobile-dev.

**Maestro:** authored `home/au360-canvas-layer-reorder.yaml` (reaches canvas, asserts controls present + tappable; deferred select→reorder→assert-swap block pending indexed item testIDs).

---

## AU-359 — swipe edge artifact → **PASS (sim mid-swipe confirm pending)**

**File:** `OutfitSwipeDeck.tsx`

**What I checked**
- Fix adds `activeCard { overflow:'hidden', backgroundColor: theme.colors.figmaSurface }` (`#FFFFFF`) applied **only** to the active Animated.View (209). The peek card uses only `cardBase + cardStyle + scale` — confirmed **unclipped**, so its `peekScale` (0.98→1) affordance still reads behind. Logic correctly masks the ±6° rotation edge-bleed against the white screen surface.
- **Regression check (overflow:hidden clipping):** verified the drag cues (`deckCue` @ `top:16, right/left:24`) are positioned INSIDE the card bounds (won't be cropped), and neither the swipe-deck cards nor `OptionSheet` cast an OUTWARD drop-shadow that `overflow:hidden` would now clip. No regression risk found.
- **testID / i18n / analytics:** N/A (pure visual style change; `home-swipe-deck` testID already present on the deck root).

**Defects** — none. Only true confirmation is a mid-swipe screenshot (hardest to capture deterministically); logic is sound. Marked sim-pending.

---

## AU-356 — register email validation → **PASS** (strongest fix)

**File:** `EmailInputScreen.tsx`

**What I checked**
- Fix is logically correct and well-reasoned. Signup mode: OAuth → `EmailGoogleNotice`; any other result → `PasswordCreation` (the previously-broken happy path). Signin mode: `none` → Toast + Welcome bounce; otherwise → `SignIn`. Routing branches on **`mode`**, not the enumeration-safe (always-`password` for anonymous callers) provider value.
- **Downstream safety claim verified:** the genuinely-already-registered case is caught server-side at register time — `PasswordCreationScreen.tsx:164-165` handles `409 EMAIL_ALREADY_EXISTS → navigate('SignIn')`. The full loop is coherent; no enumeration leak.
- **testID:** `email-input-field`, `email-submit-button` (a11yLabel `uac.email_input.submit_a11y`), `email-back-button` — Maestro-ready.
- **i18n:** routing copy keys (`uac.email_input.*`) used via `t()`.
- **analytics:** `sign_up_started { method:'email' }` fires at the signup commit (175); pre-existing event.

**Defects** — none.

**Maestro:** authored `auth/au356-signup-reaches-password.yaml` (welcome→signup email→assert `password-input-field` reached; negative guard `assertNotVisible: signin-password-input`). Use a unique per-run email.

---

## AU-358 — self-viz quit-loading + completion notification → **ESCALATE (code PASS, analytics-doc gap + infra gap)**

**Files:** `GeneratingView.tsx`, `try-on-generation-store.ts`, `use-try-on-generation.ts`, `try-on-background-notify.ts`, `try-on-completion-notice.ts`, `SeeThisOnMeScreen.tsx`

**What I checked**
- **Architecture is excellent.** Generation is lifted OUT of the React tree into a module singleton (`tryOnGenerationStore`), subscribed via `useSyncExternalStore`. `runToken` discards stale runs. KISS-compliant (no Redux/Zustand). Quitting flags `backgrounded=true`; the render keeps running; on completion the store invokes `onBackgroundComplete` only when backgrounded.
- **Quit affordance:** `GeneratingView` shows `stom-quit-generating` (testID + a11yLabel + hint) ONLY in the non-errored generating state (correct). The generating-state header back ALSO routes to quit-to-background (`handleQuitGeneration`), not a plain goBack — leaving doesn't cancel.
- **Completion notice:** app-root Toast + `navigationRef` (both work outside React tree), tappable → re-navigates `SeeThisOnMe` with the outfit. Mount lifecycle rehydrates from the store if returning to an in-flight/finished render, `rehydratedRef` blocks double-generation.
- **i18n:** `seeThisOnMe.quit.{hint,cta}` + `seeThisOnMe.notify.{readyTitle,readyBody,failedTitle,failedBody}` all present + translated in en/fr/vi.

**Defects / why ESCALATE**
1. **Analytics-doc gap (rule violation).** Two AU-358 events are wired in code but **NOT documented** in `docs/analytics/mixpanel-tracking-plan.md`: `body_shape_generation_backgrounded` (`SeeThisOnMeScreen.tsx:418`, props `outfit_hash`) and `body_shape_generation_completed_notified` (`try-on-completion-notice.ts:50`, props `result`). The analytics-tracking-required rule states a feature is incomplete if the doc wasn't updated (the doc WAS updated for AU-361/360/354 but missed AU-358). **Route to mobile-dev:** add both to §5 + the try-on funnel §10.
2. **Infra gap (correctly flagged in-code, needs live verification).** Completion is **IN-APP only** — no native push (APNs/expo-notifications not set up). So if the user backgrounds the *app* (not just the screen), they are NOT pulled back on completion. The code honestly documents this (tracking-plan §6.7 ref). **Needs live data** to verify the in-app Toast actually fires on real backend completion (AI generation requires backend on :5001 + a real render round-trip). State wiring verified; live completion path is sim-pending.

---

## AU-354 — reuse body-photo state → **PASS** (analytics-doc clean for this ticket)

**Files:** `StepReuseConfirm.tsx` (new), `SeeThisOnMeScreen.tsx`

**What I checked**
- `StepReuseConfirm` shows the persisted photo (full-body preferred, else selfie) in the transcript style + "Use this photo" / "Retake photos" pills. Gated correctly: `reuseMode && !reuseConfirmed && !rehydratedRef.current && reusePhotoUri && step==='selfie'` — skipped when rehydrating an AU-358 background gen, once confirmed, or when the profile is malformed (falls through to capture).
- **Composes cleanly with AU-358:** `handleReuseRetake` fires `body_photo_retake_selected` BEFORE any render, then `restartCapture()` which calls `tryOnGenerationStore.reset()` — correctly tearing down any background render. Does not regress quit/notification.
- `handleReuseConfirm` guards double-fire (`reuseFiredRef`), runs generation with stored body+shape (no re-capture).
- **testID:** `stom-reuse-confirm`, `stom-reuse-confirm-prompt`, `stom-reuse-confirm-thumb`, `stom-reuse-confirm-use`, `stom-reuse-confirm-retake` — all present.
- **i18n:** `seeThisOnMe.reuseConfirm.{prompt,confirm,retake}` present + translated in en/fr/vi.
- **analytics:** `body_photo_reuse_confirmed` (268) + `body_photo_retake_selected` (309), props `outfit_hash`. Both **documented** in tracking-plan §5 + reuse-on-return funnel §10.

**Defects** — none functional. **Nit:** tracking-plan cites `:267`/`:308`; actual `track()` calls are at `:268`/`:309`. Off-by-one doc line-refs (also affects AU-361 §). Non-blocking.

---

## Overall summary

| Bug | Verdict | testID | i18n (en/fr/vi) | analytics wired | analytics doc | screenshot |
|---|---|---|---|---|---|---|
| AU-361 item-ready toast | **ESCALATE** | N/A (toast) | ✅ | ✅ | ✅ (line-ref nit) | sim pending |
| AU-360 canvas layer order | **PASS** | ✅ | ✅ | ✅ | ✅ | sim pending |
| AU-359 swipe edge artifact | **PASS** | N/A (style) | N/A | N/A | N/A | sim pending (mid-swipe) |
| AU-356 register email | **PASS** | ✅ | ✅ | ✅ | ✅ | flow authored |
| AU-358 quit + notify | **ESCALATE** | ✅ | ✅ | ✅ | ❌ **2 events undocumented** | sim pending (live AI) |
| AU-354 reuse body-photo | **PASS** | ✅ | ✅ | ✅ | ✅ (line-ref nit) | sim pending |

**Counts: PASS 4 · ESCALATE 2 · FAIL 0**

### Routed to mobile-dev
1. **AU-361** — toast vs Figma snackbar visual deviation. Supply a custom `<Toast config>` matching the M3 snackbar tokens (teal `#4cf4d3`/success-200 bg, check icon, 4px radius, M3 elevation) OR build a snackbar primitive. (Optional: explicit `is_preparing?: boolean` on `WardrobeItem`.)
2. **AU-358** — add `body_shape_generation_backgrounded` (`SeeThisOnMeScreen.tsx:418`) + `body_shape_generation_completed_notified` (`try-on-completion-notice.ts:50`) to `mixpanel-tracking-plan.md` §5 + try-on funnel §10.
3. **AU-360 testID backfill** — stable indexed canvas-item testIDs (`canvas-item-0…` + `-selected` suffix) + `canvas-surface-root` so the visible z-swap becomes Maestro-assertable.
4. **Doc nits** — fix off-by-one line refs in tracking-plan: AU-361 `:149`→`:152`; AU-354 `:267`/`:308`→`:268`/`:309`.

### Needs live-data verification (hand to qa-mobile on a booted sim + backend :5001)
- **AU-358** completion path: background a real render, confirm the in-app Toast fires + tap re-navigates. (Native push out of scope — documented gap.)
- **AU-359** mid-swipe screenshot to visually confirm no edge bleed during the ±6° rotation.
- **AU-361** ready transition on a freshly uploaded item (toast appears once, bottom).
- **AU-360 / AU-356** — execute the two authored Maestro flows.

### Artifacts authored (this run)
- `auxi/maestro/flows/auth/au356-signup-reaches-password.yaml`
- `auxi/maestro/flows/home/au360-canvas-layer-reorder.yaml`
- `auxi/maestro/README.md` — inventory rows + AU-360 canvas testID gap added.

### Unresolved questions
- AU-361: does the CEO want the exact Figma snackbar styling, or is the default success toast acceptable? (Drives whether finding #1 is a blocker or accepted deviation.)
- AU-358: is in-app-only notification acceptable for v1, or is native push (APNs) required before close? (Currently documented as deferred.)
