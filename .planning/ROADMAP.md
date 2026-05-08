# Roadmap: Wardrobe v0.5 Remix Launch

## Overview

Seven-day sprint (2026-05-08 to 2026-05-15) to ship the V05 recommendation engine and Remix UX to existing users. The backend `/next` endpoint lands first (Phase 1), foundational gates and design assets close in parallel (Phase 2), then the mobile UI and telemetry wire up against the live backend (Phase 3). V05 onboarding is best-effort and does not block the flag flip (Phase 4). Launch verification is the final gate (Phase 5).

## Phases

**Phase Numbering:**
- Integer phases (1-5): Planned milestone work for v0.5
- Decimal phases: Urgent insertions only, not planned at start

- [ ] **Phase 1: Remix Backend** - `/next` endpoint, Redis session, 4-axis cycle, invariants, unit tests — must merge by 2026-05-10
- [ ] **Phase 2: Foundational Gates + Design Sign-Off** - Env config, telemetry wiring, security defaults, API doc consolidation, weather fallback, design assets from Viet — parallel to Phase 1, must close before Phase 3 ships
- [ ] **Phase 3: Remix Mobile + Telemetry** - Wire V05 start/next on HomeScreen, RemixButton, AxisChip, daily reset, edge cases, animations, Mixpanel events, Jest tests — blocked by Phase 1 and Phase 2 (design assets)
- [ ] **Phase 4: V05 Onboarding Rollout** - Onboarding generate endpoint, mobile entry-point routing, Phase 0 inventory audit — parallel-eligible, acceptable to slip; does not block flag flip
- [ ] **Phase 5: Launch Verification** - Maestro E2E, internal smoke, feature flag flip, TypeScript/lint gate, API doc update

## Phase Details

### Phase 1: Remix Backend
**Goal**: The `/next` endpoint is live, tested, and mergeable — the mobile team can start wiring against a real API
**Depends on**: Nothing (Phase 0 inventory PR #41 must be merged first as a precondition — not a GSD phase, already in-review)
**Requirements**: REMIX-BE-01, REMIX-BE-02, REMIX-BE-03, REMIX-BE-04, REMIX-BE-05, REMIX-BE-06, REMIX-BE-07, REMIX-BE-08
**Success Criteria** (what must be TRUE):
  1. `POST /api/v05/recommendation/next` returns a valid outfit plus `trace.variation_axis` when called with a valid `session_id` and `current_outfit_hash`
  2. Redis session `v05_recsess:{uuid}` advances through all 4 stages (SILHOUETTE → LAYERING → COLOR → NEW_ANCHOR → SILHOUETTE) across sequential `/next` calls without repeating seen items
  3. Anchor-pin invariant: BT item is unchanged across stages 1-3; any violation causes a hard-fail response (not a silent wrong outfit)
  4. Single-layer-swap invariant: exactly 1 layer differs vs `current_outfit` at stages 1-3; hard-fail on violation
  5. Unit test suite green (`pytest -m unit`) covering state transitions, anchor enforcement, single-layer check, no-repeat on `seen_item_ids`; p95 latency < 250ms under 1-user load assertion passes
**Plans**: TBD

**Timeline risk**: AU-251 must merge by 2026-05-10 (Cycle 10 close) to unblock mobile. If state machine complexity exceeds 2 days of work, descope path is: drop NEW_ANCHOR axis, ship 3-axis cycle, file AU-251b for NEW_ANCHOR in Cycle 11 post-launch.

### Phase 2: Foundational Gates + Design Sign-Off
**Goal**: Production-readiness blockers are closed and Viet's design assets are in hand before mobile wiring begins
**Depends on**: Nothing (parallel to Phase 1; must complete before Phase 3 ships)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, DESIGN-01, DESIGN-02
**Success Criteria** (what must be TRUE):
  1. Mobile app builds with no hardcoded `localhost:5001` — all three files use environment variable injection (`react-native-config` on mobile, Vite env on admin); simulator connects to staging URL without code change
  2. `console.info` analytics stubs in `HomeScreen.tsx` are replaced with a real Mixpanel service; staging Mixpanel receives events when triggered in simulator
  3. `wardrobe-backend/API_DOCUMENTATION.md` is the single source of truth; `auxi/docs_agent/API_DOCUMENTATION.md` is removed or clearly marked as generated copy
  4. Production config: `CORS_ORIGINS` is not `["*"]`; `SECRET_KEY` is not the default value; both are validated at startup (raise on bad values)
  5. RemixButton, AxisChip, and tooltip copy assets received from Viet and incorporated — OR a product decision is recorded to ship placeholder copy and polish post-launch
**Plans**: TBD

**Timeline risk**: FOUND-05 (Location/Weather) has an explicit fallback — if AU-72 is not ready, the app defaults to a standard temperature. This is acceptable for launch and should not delay Phase 3. DESIGN-02 (Viet's assets) was due 2026-05-09; if late, ship with placeholder copy per the risk register decision and unblock mobile.

### Phase 3: Remix Mobile + Telemetry
**Goal**: The user can tap Remix on HomeScreen and receive a fresh same-vibe outfit with an axis hint — the full Remix UX is wired, animated, and instrumented
**Depends on**: Phase 1 (backend `/next` endpoint live), Phase 2 (design assets in hand, env config set)
**Requirements**: REMIX-ME-01, REMIX-ME-02, REMIX-ME-03, REMIX-ME-04, REMIX-ME-05, REMIX-ME-06, REMIX-ME-07, REMIX-ME-08, REMIX-ME-09, REMIX-TEL-01, REMIX-TEL-02, REMIX-TEL-03
**Success Criteria** (what must be TRUE):
  1. HomeScreen mount calls V05 `/start` (not the legacy `valenGetRecommendation`); `session_id` persists in `recommendationMemory.ts` and survives app backgrounding within the same calendar day
  2. Tapping RemixButton fires `/next`, the outfit cross-fades in 250ms, and an AxisChip ("New top" / "New layer" / "New color" / "Full remix") appears and auto-fades after 3 seconds
  3. Long-pressing RemixButton opens the forced-axis sheet; selecting an axis sends `force_variation_axis` to `/next` and produces the correct swap
  4. Pull-to-refresh on HomeScreen triggers a Remix cycle (not a full `/start` reset); foregrounding after midnight discards session and shows "Today's outfit" header
  5. Mixpanel events `remix_tapped`, `remix_completed`, `v05_recommendation_shown`, and `daily_reset_triggered` fire with correct properties (session_id, outfit_hash, variation_axis, latency_ms); Jest tests verify event emission
**Plans**: TBD

**Timeline risk**: 8pt scope across 2026-05-11 to 2026-05-14. If Phase 1 slips past 5/11, descope path is: wire `/start` + `/next` auto-cycle first (ship RemixButton without forced-axis sheet), defer long-press picker (REMIX-ME-04) and first-time tooltip (REMIX-ME-08) to a post-launch patch. Core critical path is REMIX-ME-01, REMIX-ME-02, REMIX-ME-06, REMIX-TEL-02.

### Phase 4: V05 Onboarding Rollout
**Goal**: New users can be routed through the V05 onboarding flow backed by a live generate endpoint — best-effort for launch, acceptable to slip to v0.6
**Depends on**: Phase 1 (V05 engine live); Phase 3 not required (parallel-eligible after Phase 1)
**Requirements**: ONBD-01, ONBD-02, ONBD-03
**Success Criteria** (what must be TRUE):
  1. `POST /api/v05/onboarding/generate` returns 30-60 cloned items deterministically for a valid onboarding input payload
  2. Mobile entry point routes new users to V05 onboarding (FitPreference → OutfitApproval → OnboardingConfirmation) when the V05 feature flag is on; legacy flow is gated behind flag
  3. Phase 0 inventory in DB: 166/166 SYSTEM items have `style_tags`, `gender_tags`, `fit_category` populated; audit script reports ≥ 90% pass rate
**Plans**: TBD

**Timeline risk**: LOW launch impact — V05 flag for launch targets existing users only. AU-245 onboarding can slip to Cycle 11 without blocking the 2026-05-15 flag flip. If ONBD-03 (inventory audit) is the only blocker, confirm PR #41 merged and run the audit script without a new phase.

### Phase 5: Launch Verification
**Goal**: The full V05 + Remix stack is verified end-to-end, the codebase is clean, and the feature flag is flipped for production users
**Depends on**: Phase 3 (all Remix mobile work merged), Phase 2 (foundational gates closed); Phase 4 can be in-progress
**Requirements**: LAUNCH-01, LAUNCH-02, LAUNCH-03, LAUNCH-04, LAUNCH-05
**Success Criteria** (what must be TRUE):
  1. Maestro E2E flow completes: 4 sequential Remix taps produce 4 distinct outfits each showing the correct axis chip; no single-layer-swap violations appear in backend logs
  2. Internal smoke test: 2 testers each complete 10+ Remixes on production without crashes, confusion, or silent session failures
  3. V05 feature flag is flipped on production for existing users; `v05_recommendation_shown` event is visible in Mixpanel staging dashboard within 5 minutes of flag flip
  4. `python test_server.py` exits green; `npx tsc --noEmit && yarn lint` in `auxi/` exits with 0 errors (warnings acceptable per existing baseline)
  5. `wardrobe-backend/API_DOCUMENTATION.md` documents both `/api/v05/recommendation/next` and `/api/v05/onboarding/generate` (or ONBD-01 deferred decision is recorded)
**Plans**: TBD

**Timeline risk**: This phase executes 2026-05-14 to 2026-05-15. Any slip in Phase 3 beyond 5/13 compresses QA to 1 day. If that happens: proceed with Maestro for core Remix path only (LAUNCH-01 scoped to auto-cycle, not forced-axis), defer Edit Context and tooltip scenarios to post-launch regression.

## Progress

**Execution Order:** 1 → 2 (parallel) → 3 → 4 (parallel-eligible) → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Remix Backend | 0/TBD | Not started | - |
| 2. Foundational Gates + Design Sign-Off | 0/TBD | Not started | - |
| 3. Remix Mobile + Telemetry | 0/TBD | Not started | - |
| 4. V05 Onboarding Rollout | 0/TBD | Not started | - |
| 5. Launch Verification | 0/TBD | Not started | - |
