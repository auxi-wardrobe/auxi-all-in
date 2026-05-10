# Requirements: Wardrobe v0.5 Remix Launch

**Defined:** 2026-05-08
**Core Value:** Personalized + vibe-coherent outfit recommendations from user's actual wardrobe; Remix shifts one dimension at a time, never random.
**Launch target:** 2026-05-15

## v1 Requirements (v0.5 milestone)

### Remix Feature (Backend)

- [ ] **REMIX-BE-01**: `POST /api/v05/recommendation/next` endpoint accepts `{session_id, current_outfit_hash, rejected_items?, preferred_colors?, style_feedback?, force_variation_axis?}` and returns same shape as `/build` plus `trace.variation_axis`
- [ ] **REMIX-BE-02**: Redis session `v05_recsess:{uuid}` (TTL 1800s) tracks `current_outfit`, `variation_stage` (1-4), `seen_item_ids`, `anchor_id` (BT), `style_signals`
- [ ] **REMIX-BE-03**: 4-axis cycle handlers implemented — SILHOUETTE (swap L2), LAYERING (swap L3 cold or SH warm), COLOR (swap L2 different color), NEW_ANCHOR (full regen)
- [ ] **REMIX-BE-04**: Anchor pin invariant — BT (bottom) frozen across stages 1-3; hard-fail if violated
- [ ] **REMIX-BE-05**: Single-layer-swap invariant — exactly 1 layer changed vs `current_outfit` at stages 1-3; hard-fail if violated
- [ ] **REMIX-BE-06**: Pre-filtered candidate pool — formality±3, weight±2, color-temp match, fit-contrast respected
- [ ] **REMIX-BE-07**: Unit tests cover state transitions across 4 axes, anchor pin enforcement, single-layer invariant, no-repeat across `seen_item_ids`
- [ ] **REMIX-BE-08**: p95 latency for `/next` < 250ms under 1-user load

### Remix Feature (Mobile)

- [ ] **REMIX-ME-01**: HomeScreen mount calls V05 `/start` (replaces `valenGetRecommendation` legacy call); session_id persisted via `recommendationMemory.ts`
- [ ] **REMIX-ME-02**: RemixButton component with default/loading/cooldown/disabled states; tap fires `/next` with `session_id` + `current_outfit_hash`
- [ ] **REMIX-ME-03**: AxisChip component renders `trace.variation_axis` ("New top" / "New layer" / "New color" / "Full remix"); auto-fades after 3s
- [ ] **REMIX-ME-04**: Long-press RemixButton opens forced-axis sheet (Top / Layer / Color / Full remix); sends `force_variation_axis` to `/next`
- [ ] **REMIX-ME-05**: Pull-to-refresh on HomeScreen triggers Remix tap (auto-cycle, not full reset)
- [ ] **REMIX-ME-06**: Daily reset — `AppState` listener detects foreground after midnight; discards session_id, calls `/start` fresh; header reads "Today's outfit"
- [ ] **REMIX-ME-07**: Edge cases handled — network fail (toast, keep current outfit), wardrobe < 5 items per layer (disable button), session expired (silent re-`/start`)
- [ ] **REMIX-ME-08**: First-time tooltip shown once per user — "Tap Remix to swap part of your outfit. Long-press to choose what to change."
- [ ] **REMIX-ME-09**: Outfit swap animation — 250ms cross-fade (no slide); chip enter slide-up + fade (200ms); button press 100ms scale-down haptic

### Remix Telemetry

- [ ] **REMIX-TEL-01**: Mixpanel events fired — `remix_button_shown`, `remix_tapped`, `remix_completed`, `remix_failed`, `remix_axis_picker_opened`, `remix_axis_picker_selected`, `daily_reset_triggered`, `pull_to_refresh_remix`
- [ ] **REMIX-TEL-02**: `v05_recommendation_shown` event fires on every successful `/start` and `/next` response (launch criteria)
- [ ] **REMIX-TEL-03**: Jest tests verify event emission with correct properties (session_id, outfit_hash, variation_axis, latency_ms)

### V05 Onboarding Rollout

- [ ] **ONBD-01**: `POST /api/v05/onboarding/generate` endpoint live — accepts onboarding input, returns 30-60 user-cloned items per valid input, deterministic
- [ ] **ONBD-02**: Mobile entry point routes new users to V05 onboarding screens (FitPreference, OutfitApproval, OnboardingConfirmation); legacy GenderPreference/StylePreference flow gated behind feature flag
- [ ] **ONBD-03**: Phase 0 inventory imported — 166/166 SYSTEM items in DB with `style_tags` (5-vocab) + `gender_tags` + `fit_category` populated, ≥90% audit pass

### Foundational Gates (Must Close Before Flag Flip)

- [ ] **FOUND-01**: All hardcoded `localhost:5001` URLs externalized — `auxi/src/services/apiClient.ts`, `auxi/src/services/auth.ts`, `wardrobe-backend/wardrobe-admin/src/services/api.ts`; uses `react-native-config` (mobile) and Vite env (admin)
- [ ] **FOUND-02**: Real Mixpanel telemetry service replaces 7+ `console.info` analytics stubs in `auxi/src/screens/HomeScreen.tsx` (lines 437, 475, 479, 495, 506, 531+); events fire to staging Mixpanel project
- [ ] **FOUND-03**: API_DOCUMENTATION.md drift resolved — `wardrobe-backend/API_DOCUMENTATION.md` is single source of truth; `auxi/docs_agent/API_DOCUMENTATION.md` removed or generated from backend on tag/release
- [ ] **FOUND-04**: Production CORS allowlist configured (NOT `["*"]`); production JWT `SECRET_KEY` validated as non-default in `get_settings()`
- [ ] **FOUND-05**: Location/Weather integration — outfit climate input pulled from device location with fallback to default temp if permission denied or service down (AU-72)

### Design Sign-Off

- [ ] **DESIGN-01**: 2 borderline copy items reviewed and approved by Viet (WAR-AU243-005, ~30min)
- [ ] **DESIGN-02**: RemixButton + AxisChip + tooltip copy assets received from Viet and matched in implementation

### Launch Verification

- [ ] **LAUNCH-01**: Maestro E2E green — Remix tap × 4 produces 4 distinct outfits with correct axis chips, no single-layer-swap violations
- [ ] **LAUNCH-02**: Internal smoke test — 2 testers complete 10+ Remixes each without confusion; no crashes
- [ ] **LAUNCH-03**: V05 feature flag flipped on production for existing users; AU-245 onboarding flag stays off until Phase 1 lands
- [ ] **LAUNCH-04**: `python test_server.py` green; `npx tsc --noEmit && yarn lint` green in `auxi/`
- [ ] **LAUNCH-05**: API_DOCUMENTATION.md updated for `/api/v05/recommendation/next` and `/api/v05/onboarding/generate`

## v2 Requirements (deferred to v0.6+)

### Affinity & Feedback (WAR-AU243-004)

- **AFFIN-01**: `user_style_affinity` table populated from onboarding signal
- **AFFIN-02**: EMA-updated affinity from feedback signals (likes, saves, rejects)
- **AFFIN-03**: Recommendation engine consumes affinity scores to bias selection

### Vocabulary Expansion

- **VOCAB-01**: Sporty/athleisure vocabulary added to 5-vocab tagger (WAR-AU243-006); requires user-feedback corpus first

### LLM & ML

- **LLM-01**: LLM narration side-endpoint generates outfit captions (Phase 2 stretch only)
- **ML-01**: ML-based outfit ranking replaces rules-based scoring (after V05 has feedback corpus)

### Color System

- **COLOR-01**: Color-pair learning system (V05 spec §15.7) — moves color rules from frozen whitelist to learned pairs

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile try-on with V05 outfits | Try-on is V2-engine-bound; requires V05 cutover first |
| Multi-day calendar planning | Out of scope for vibe-coherence MVP; not core value |
| Random reroll Remix | Explicit anti-feature — brand promise is "same vibe, fresh take" |
| Real-time chat / video posts / OAuth | Not part of wardrobe product surface |
| Cross-platform Android polish | iOS-first for v0.5; Android best-effort |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REMIX-BE-01 | Phase 1 | Pending |
| REMIX-BE-02 | Phase 1 | Pending |
| REMIX-BE-03 | Phase 1 | Pending |
| REMIX-BE-04 | Phase 1 | Pending |
| REMIX-BE-05 | Phase 1 | Pending |
| REMIX-BE-06 | Phase 1 | Pending |
| REMIX-BE-07 | Phase 1 | Pending |
| REMIX-BE-08 | Phase 1 | Pending |
| REMIX-ME-01 | Phase 3 | Pending |
| REMIX-ME-02 | Phase 3 | Pending |
| REMIX-ME-03 | Phase 3 | Pending |
| REMIX-ME-04 | Phase 3 | Pending |
| REMIX-ME-05 | Phase 3 | Pending |
| REMIX-ME-06 | Phase 3 | Pending |
| REMIX-ME-07 | Phase 3 | Pending |
| REMIX-ME-08 | Phase 3 | Pending |
| REMIX-ME-09 | Phase 3 | Pending |
| REMIX-TEL-01 | Phase 3 | Pending |
| REMIX-TEL-02 | Phase 3 | Pending |
| REMIX-TEL-03 | Phase 3 | Pending |
| ONBD-01 | Phase 4 | Pending |
| ONBD-02 | Phase 4 | Pending |
| ONBD-03 | Phase 4 | Pending |
| FOUND-01 | Phase 2 | Pending |
| FOUND-02 | Phase 2 | Pending |
| FOUND-03 | Phase 2 | Pending |
| FOUND-04 | Phase 2 | Pending |
| FOUND-05 | Phase 2 | Pending |
| DESIGN-01 | Phase 2 | Pending |
| DESIGN-02 | Phase 2 | Pending |
| LAUNCH-01 | Phase 5 | Pending |
| LAUNCH-02 | Phase 5 | Pending |
| LAUNCH-03 | Phase 5 | Pending |
| LAUNCH-04 | Phase 5 | Pending |
| LAUNCH-05 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35/35
- Unmapped: 0

---
*Requirements defined: 2026-05-08*
*Last updated: 2026-05-08 — traceability filled after roadmap creation*
