# Wardrobe — Auxi mobile + recommendation backend

## What This Is

Personal-wardrobe + AI outfit recommender. A two-repo monorepo: **Auxi** (React Native mobile app) lets users photograph and tag their clothes; **wardrobe-backend** (FastAPI + Gemini) generates outfits from the user's actual wardrobe and powers the "Remix" feature — never random rerolls, always same-vibe variations along a single dimension at a time.

## Core Value

Users get outfit suggestions that are **personalized to their actual wardrobe** and **vibe-coherent** — every Remix tap shifts one dimension (top, layer, color, or anchor) while preserving the overall style direction. No jarring random rerolls.

## Requirements

### Validated

<!-- Already shipped and proven valuable in production. -->

- ✓ **AUTH-V**: User can sign up, sign in, persist session (mobile + admin SPA)
- ✓ **WARD-V**: User can add wardrobe items via photo upload (auto background removal + Gemini tagging)
- ✓ **REC-V2**: V2 recommendation engine generates outfits with 4-axis variation (legacy, V05 cutover in progress)
- ✓ **ONBD-V05-MVP**: V05 onboarding screens scaffolded (FitPreference, OutfitApproval, OnboardingConfirmation) — not yet wired to entry point
- ✓ **TAGGER**: 5-style vocabulary (Minimal/Casual/Soft/Bold/Formal) tagger pipeline (PRs #35-#39)
- ✓ **V05-ENGINE-MVP**: V05 outfit generation engine (PR #42 merged 2026-05-08)
- ✓ **WGS-SPEC-LOCKED**: WARDROBE_GENERATION_SPEC + RECOMMEND_V05_SPEC ratified by designer/CEO 2026-05-07

### Active

<!-- v0.5 launch milestone — ship by 2026-05-15. -->

**Remix feature (V0.5 headline)**
- [ ] **REMIX-BE**: `POST /api/v05/recommendation/next` returns same-vibe outfit with single-axis variation (AU-251)
- [ ] **REMIX-SESSION**: Redis session (TTL 1800s) tracks `variation_stage`, `seen_item_ids`, `anchor_id` across taps (AU-251)
- [ ] **REMIX-AXES**: 4-axis cycle SILHOUETTE → LAYERING → COLOR → NEW_ANCHOR with single-layer-swap invariant (AU-251)
- [ ] **REMIX-UI**: Mobile wires V05 `/start` + `/next`, RemixButton + AxisChip, daily-reset, pull-to-refresh (AU-250)
- [ ] **REMIX-PICKER**: Long-press Remix → forced axis sheet (Top/Layer/Color/Full) (AU-250)
- [ ] **REMIX-TELEMETRY**: Mixpanel events `remix_tapped`, `remix_completed`, `daily_reset_triggered`, `v05_recommendation_shown` (AU-250)

**V05 onboarding rollout**
- [ ] **ONBD-API**: `POST /api/v05/onboarding/generate` returns 30-60 user-cloned items per onboarding input (AU-245)
- [ ] **ONBD-WIRE**: Mobile entry point routes to V05 onboarding (resolve dual-flow ambiguity)
- [ ] **INVENTORY-AUDIT**: 166/166 items in DB with style_tags + gender_tags + fit_category, ≥90% audit pass (WAR-AU243-001)

**Foundational gaps (must close before launch)**
- [ ] **ENV-CONFIG**: Externalize hardcoded `localhost:5001` URLs in mobile + admin (`react-native-config` or equivalent)
- [ ] **TELEMETRY-SVC**: Replace 7+ `console.info` analytics stubs in `HomeScreen.tsx` with real Mixpanel hook
- [ ] **CONTRACT-DOC**: Reconcile `wardrobe-backend/API_DOCUMENTATION.md` vs `auxi/docs_agent/API_DOCUMENTATION.md` drift
- [ ] **WEATHER**: Location/Weather integration for outfit climate input (AU-72) — fallback to default if slips

**Design sign-off**
- [ ] **COPY-REVIEW**: 2 borderline copy items reviewed by Viet (WAR-AU243-005, ~30min)

### Out of Scope

<!-- Explicit boundaries with reasoning. -->

- **Mobile try-on with V05 outfits** — try-on is V2-engine-bound; V05 cutover required first
- **ML-based outfit ranking** — defer until V05 has real user feedback; rules-based ranking sufficient for v0.5
- **Multi-day calendar planning** — out of scope for vibe-coherence MVP
- **LLM narration side-endpoint** — Phase 2 stretch only, not committed
- **Color-pair learning system** (V05 spec §15.7) — Phase 3+, requires user feedback corpus first
- **Sporty/athleisure vocabulary v2** — tracked as research (WAR-AU243-006), not committed for v0.5
- **Random reroll Remix** — explicit anti-feature; brand promise is "same vibe, fresh take"
- **Phase 4 affinity persistence + EMA feedback** (WAR-AU243-004) — defer to v0.6
- **Real-time chat / video posts / OAuth** — not part of wardrobe product surface

## Context

**Repo layout**: Umbrella git repo with two submodules (`auxi/` RN 0.83 + `wardrobe-backend/` FastAPI) and one nested SPA (`wardrobe-backend/wardrobe-admin/` React 19 + Vite + AntD). No shared SDK; API contract maintained via `API_DOCUMENTATION.md`.

**Team**: Solo dev (Duc, ducga1998) + designer/CEO (Viet, vietdesign81). Designer's Figma is the source of truth for visual fidelity — non-negotiable on-simulator verification before claiming UI work done.

**Active in-flight tickets** (Linear AU-243 epic):
- AU-251 BE Remix `/next` (5pt, Cycle 10 close 5/10)
- AU-250 ME Remix UI (8pt, Cycle 11, blocked by AU-251)
- AU-245 BE V05 onboarding API (carry-over OK if slips)
- AU-72 ME Location/Weather (small, low launch impact)
- AU-244 V05 Phase 0 inventory PR #41 (in review)

**Tech debt entering this milestone** (from `.planning/codebase/CONCERNS.md`):
- Hardcoded `localhost:5001` in 3+ files (HIGH severity, blocks staging deploy)
- CORS wildcard `["*"]` default + default JWT secret (HIGH security risk if shipped)
- Analytics stubs not wired (MEDIUM — required for launch metrics)
- API docs drift between backend + auxi-side copy (MEDIUM)
- Submodule pin drift (5 re-bumps in last 10 umbrella commits)
- Dual onboarding flow active (legacy + V05 both reachable)
- Legacy `_HomeScreen.tsx` (941 LOC) blocking clean lint baseline

**v0.5 launch criteria** (from `docs/pm/v05-launch-plan-2026-05-08.md`):
PR #42 merged ✓ · AU-251 merged ⏳ · AU-250 merged ⏳ · Maestro E2E green ⏳ · Internal smoke (2 users × 10 Remixes) ⏳ · Feature flag flipped ⏳ · Mixpanel `v05_recommendation_shown` firing ⏳

## Constraints

- **Tech stack**: React Native 0.83 + TS 5.8 + TanStack Query 5 + React Navigation 7 (mobile); Python 3.9+ + FastAPI + SQLAlchemy + Gemini + S3 (backend); React 19 + Vite + TS + AntD (admin SPA). No swaps mid-milestone.
- **Timeline**: Launch target **2026-05-15** (7 days from today). AU-251 must merge by 5/10 to unblock AU-250.
- **Budget**: Solo dev + designer. Each phase scoped to fit cycle (5pt or 8pt max).
- **Compatibility**: V05 ships behind feature flag; V2 path must remain functional through cutover. Existing-users-first rollout.
- **Performance**: p95 `/next` latency < 250ms; Remix cross-fade animation 250ms; pre-filter pool kept under threshold.
- **Security**: Production deploy requires CORS allowlist + non-default JWT secret + S3 ACL audit before flag flip.
- **Designer authority**: Visual changes require Figma reference + on-simulator verification. No screenshot-based eyeballing.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 2026-05-07: V05 vocabulary locked (5 styles / 3 fits / 3 directions / 6 item types) | Single source of truth in WGS §3, ratified by designer | ✓ Good — unblocks tagger + engine work |
| 2026-05-08: Feature codename **Remix** (English-only, no Vietnamese alias) | Brand consistency; user explicitly chose this over "Lắc lại" alias | ✓ Good — locked |
| 2026-05-08: 4-axis cycle SILHOUETTE → LAYERING → COLOR → NEW_ANCHOR | Ports proven V2 pattern, predictable variation | — Pending — validate post-launch |
| 2026-05-08: Anchor pin (BT frozen stages 1-3) | Preserves outfit foundation between Remixes | — Pending |
| 2026-05-08: Single-layer-swap invariant (hard-fail if >1 layer changed at stages 1-3) | Vibe coherence — defining brand promise | — Pending |
| 2026-05-08: Strategy Option B — AU-251 in Cycle 10, AU-250 in Cycle 11, V05 flag stays off until both done | Avoid half-launched state visible to users | — Pending |
| 2026-05-08: Existing users first, new-user V05 onboarding can slip | Decouples AU-245 from launch critical path | — Pending |
| Pre-existing: API contract via `API_DOCUMENTATION.md`, no shared SDK / codegen | Acceptable MVP cost; revisit at scale | ⚠️ Revisit — drift between 2 doc copies already observed |
| Pre-existing: V2 dress regression accepted trade-off until V05 cutover | Avoid double-fix; V05 rewrites cleanly | ✓ Good — documented, not silent |

## Current Milestone: v0.5 Remix Launch

**Goal:** Ship V05 recommendation engine + Remix UX to existing users on 2026-05-15.

**Target features:**
- Remix backend `/next` endpoint with 4-axis cycling (AU-251)
- Remix mobile UI with axis hints, daily reset, pull-to-refresh (AU-250)
- V05 onboarding API for new users (AU-245 — best-effort)
- Production-readiness gates: env config, telemetry wiring, security defaults

---
*Last updated: 2026-05-08 after bootstrapping PROJECT.md from existing artifacts (`/gsd:map-codebase` + `docs/pm/`)*
