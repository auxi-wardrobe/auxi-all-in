# Codebase Concerns

**Analysis Date:** 2026-05-08

## Submodule & API Contract Drift

**Umbrella-level submodule pinning vs HEAD divergence:**
- Files: `.gitmodules`, umbrella commit history
- Issue: Submodule commits tracked in umbrella may drift from active development branches in `auxi/` and `wardrobe-backend/` submodules. Recent commits show frequent re-bumps (5 times in last 10 commits), indicating manual pin management without automated sync.
- Risk: Silent feature gaps if mobile/backend work ahead without umbrella pointer update. No CI gate enforces API contract sync during submodule updates.
- Fix approach: Implement CI job that on each umbrella commit: (1) validates API_DOCUMENTATION.md exists in backend submodule, (2) runs API endpoint scan against `wardrobe-backend/routers/`, (3) cross-checks live endpoints vs documented in `API_DOCUMENTATION.md`.

**API documentation drift between repos:**
- Files: `wardrobe-backend/API_DOCUMENTATION.md` vs `auxi/docs_agent/API_DOCUMENTATION.md`
- Issue: Files diverge (confirmed: +79 lines in `docs_agent` version with "Outfit Suggestions / POST /api/suggest" endpoint not in main documentation). No documented sync process. Rule says "ALWAYS update API_DOCUMENTATION.md when modifying routes.py" but doesn't cover which copy or when to sync replica.
- Impact: Mobile developers reading stale docs, implementing against non-existent endpoints, or missing new contract.
- Fix approach: Establish single source of truth (backend repo owns docs), generate mobile docs copy from CI on tag/release. Add pre-commit hook in backend to validate all routers have documentation entries.

**No shared SDK or codegen:**
- Impact: Manual axios client updates in `auxi/src/services/*.ts` required for each backend route change. Existing drift already observed in recommendation endpoint patterns between V2 and V05 sessions.
- Documented in CLAUDE.md as acceptable MVP, but becomes tech debt at scale. Consider OpenAPI/Swagger integration to auto-generate TypeScript clients.

---

## Mobile App Lint & Type Errors

**Legacy `_HomeScreen.tsx` blocking clean build:**
- Files: `auxi/src/screens/_HomeScreen.tsx`
- Errors: 4 ESLint errors (unused imports `useMemo`, `Outfit`; unused vars `buildGridOutfitSheet`, `requestedNextFromHashesRef`)
- Known Status: Documented as "pending deletion" once dual-home migration verified in production. Lint errors explicitly accepted in current baseline (4 errors, 3 warnings).
- Risk: File gets copied or referenced accidentally; errors propagate. No test prevents re-importing from legacy file.
- Fix approach: Add ESLint rule to forbid imports from `_HomeScreen.tsx` explicitly. Move legacy file to `archived/` or suffix with `.archived` to prevent accidental imports. Set deletion deadline (post-V05 launch).

**Inline style warnings in DatabaseScreen:**
- Files: `auxi/src/screens/DatabaseScreen.tsx` (lines 125, 164)
- Issue: 2 ESLint warnings for inline styles. Low severity but indicator of style system usage gaps.
- Fix: Extract to `src/theme/theme.ts` or component stylesheet.

**TypeScript void vs undefined mismatch:**
- Files: `auxi/src/translations/index.ts` (line 18)
- Issue: i18n index expects `undefined` but sees `void` from translator function. May indicate missing return statement or callback signature drift.
- Fix: Add explicit return type and validate i18n integration tests.

---

## Analytics & Telemetry Gaps

**Console.info stubs in HomeScreen:**
- Files: `auxi/src/screens/HomeScreen.tsx` (lines 437, 475, 479, 495, 506, 531 and more)
- Issue: 7+ event points logged via `console.info` with `TODO(analytics): replace console.info with the real telemetry hook` comments. Events: home.swipe.favorite, home.pin.set, home.pin.clear, home.mode.change. No Mixpanel/real telemetry wired.
- Impact: V05 launch (5/15/2026) requires Mixpanel event "v05_recommendation_shown" firing. Current implementation will not track user behavior on Remix feature.
- Fix approach: Implement telemetry service (`src/services/telemetryService.ts`) wrapping Mixpanel, replace all `console.info` calls, add Jest tests for event emission. Include in AU-250 mobile acceptance criteria.

---

## Hardcoded Configuration

**Localhost API URLs embedded in source:**
- Files:
  - `auxi/src/services/apiClient.ts` (line 8): `ROOT_URL = 'http://localhost:5001'`
  - `auxi/src/services/auth.ts` (line 15): `const BASE_URL = 'http://localhost:5001/api'`
  - `wardrobe-backend/wardrobe-admin/src/services/api.ts` (line 4): fallback to `'http://localhost:5001'`
  - Backend also hardcoded in multiple test files and tools
- Documented TODOs: `apiClient.ts` and `auth.ts` both marked `// TODO: Externalize config` in CLAUDE.md
- Impact: Blocking multi-environment deployment (dev/staging/prod). Mobile simulator can't connect to staging API without code change. No `.env` / `react-native-config` yet.
- Risk: Dev accidentally ships with localhost pointing to production.
- Fix approach: Implement environment config layer via `react-native-config` (or direct .env for web). Add build-time substitution for staging/prod URLs. Include in AU-245 onboarding API phase or earlier if blocking tests.

---

## Security Concerns

**CORS set to wildcard `["*"]`:**
- Files: `wardrobe-backend/settings.py` (line 76), `app.py` (lines 71-80)
- Config: `CORS_ORIGINS: List[str] = ["*"]` default
- Risk: Any website can make authenticated requests on behalf of wardrobe users. Low risk for MVP (local-first) but critical for production mobile/web clients.
- Mitigation present: Environment variable `CORS_ORIGINS` can be overridden. Needs production `.env` configuration.
- Fix approach: Set secure defaults in production config (specific origin list for mobile app + admin domain). Add CI validation that `CORS_ORIGINS` is NOT `["*"]` in prod environment.

**Default JWT secret key in production:**
- Files: `wardrobe-backend/settings.py` (line 21)
- Issue: `SECRET_KEY: str = "dev-secret-key-change-in-production"` — default is non-empty but clearly insecure. ProductionSettings doesn't override (inherits base).
- Risk: All JWTs signed with same key across deployments; if code leaks, tokens forged.
- Fix: Add validation in `get_settings()` to raise error if `ENV=production` and `SECRET_KEY` hasn't been changed from default.

**Ephemeral file cleanup relies on context manager discipline:**
- Files: `wardrobe-backend/utils/file_utils.py`, used in services/
- Pattern: EphemeralFileManager documented as "preferred: context manager" but manual cleanup option exists. If developer forgets context manager in large multipart uploads, temp files leak.
- Risk: Disk exhaustion on production if error path doesn't cleanup.
- Fix approach: Add finalizer to EphemeralFileManager to ensure cleanup even without context manager. Add monitoring alert for `/tmp/wardrobe_temp` directory size.

**No input validation on user upload filenames:**
- Files: `wardrobe-backend/utils/validation.py`, file handling rules
- Rules present but check if consistently applied. Search shows `secure_filename()` documented but need to verify all upload handlers use it.
- Fix: Add linter rule or pre-request middleware to validate all file uploads pass through `validate_image_upload()`.

---

## Testing Gaps

**Skipped tests blocking confidence:**
- Files:
  - `wardrobe-backend/tests/test_segmentation.py` (lines 71, 344): `@pytest.mark.skipif(True, reason="Requires rembg installation")` — 2 tests skipped by design (heavy dependencies)
  - `wardrobe-backend/tests/test_tryon.py` (lines 103, 403): 2 tests skipped (mediapipe, OpenCV, rembg)
  - `wardrobe-backend/tests/test_engine_v05_repetition.py` (lines 42, 91): 2 tests with conditional skips on pool size / outfits returned
- Status: Documented as intentional (comment: "skipped by default") for slow/dependency-heavy tests. Acceptable for MVP but risk is regression in image processing paths.
- Test coverage: Backend requires 80% minimum, 95%+ for auth/payment/data-access paths. Image processing not in "critical" tier.
- Fix approach: Move heavy tests to separate `slow` pytest marker, run them nightly in CI, but don't block PRs. Add coverage threshold check to enforce 80% on core paths.

**Mobile E2E tests in Maestro but limited coverage:**
- Files: `auxi/maestro/flows/` (see `maestro/README.md`)
- Status: V05 onboarding flow recently added (commit 76fa269), but Maestro flows are QA-authored YAML. No unit test coverage of recommendation logic in mobile.
- Risk: Logic bugs in `auxi/src/services/recommendationService.ts` (session caching, variation tracking) untested until QA runs manual Maestro.
- Fix: Add Jest unit tests for `recommendationService.ts`, validate session_id persistence, variation axis cycling, daily reset logic. Include in AU-250 acceptance criteria.

**No integration test for V05 session lifecycle:**
- Files: `wardrobe-backend/tests/test_v05_onboarding_integration.py` exists but marked as `integration` (can be skipped via `pytest -m "not integration"`). V05 session Redis state machine not covered in automated tests.
- Impact: AU-251 (Remix `/next` endpoint) ships without automated proof that session state cycling works across 4 axes, doesn't repeat items, and respects anchor pins.
- Fix: Create `test_v05_recommendation_session.py` with unit tests for `engine_v05_variation.py` and `recommendation_session_v05.py`, mock Redis, validate state transitions. Add to `pytest -m unit` suite (not slow, not integration).

---

## Migration & Schema Debt

**Many migrations present, potential for stale applied state:**
- Files: `wardrobe-backend/migrations/versions/` (10+ migration files)
- Status: Alembic configured. Last notable migration: `3523fb8b123c_add_decision_sessions_and_decisions_.py` (decision engine). No migration blocking known.
- Risk: If SQLite development DB gets corrupted or migrations applied out of order, hard to debug. No migration validation in test suite.
- Fix: Add CI test that runs fresh migrations on test database in CI, validates schema matches models. Use Alembic `--autogenerate` for drift detection.

**Dual onboarding flow (legacy + V05) both active:**
- Files: Entry point still routes to legacy `GenderPreference → StylePreference` flow
- Issue: `auxi/CLAUDE.md` states "Product decision pending: swap the flow, run both, or delete the legacy two screens."
- Status: V05 screens exist (FitPreference, OutfitApproval, OnboardingConfirmation) but not wired into entry point. Legacy screens unreplaced.
- Risk: Confusion on which flow is canonical. If V05 shipped but legacy still reachable, A/B test unclear.
- Fix: Make product decision explicit in ticket (AU-244 or AU-245). If V05 ships with V05 flag, add feature flag to route to new flow, log user path, prepare deprecation of legacy screens. Remove legacy screens in next major version.

---

## Performance & Scalability

**Redis session TTL set to 1800s (30 min) for Remix:**
- Files: `wardrobe-backend/routers/recommendation/routes.py` (if implemented)
- Spec: `redis_ttl = 1800s` for `v05_recsess:{uuid}` sessions
- Risk: User opens app, gets outfit (session created), leaves app for 31+ minutes, reopens, session gone. Remake call to `/start`, lose Remix progress.
- Spec says "Session expires (Redis 30min) → Silent re-`/start`, continue from outfit shown" — acceptable by design but may confuse users if Remix button state resets unexpectedly.
- Fix: Document in release notes. Add client-side monitoring (log re-start due to session expiry). Monitor Redis memory usage with many concurrent sessions.

**V05 recommendation engine scaling:**
- Files: `wardrobe-backend/services/recommendation_service.py`, V05 engine logic
- Current: Pre-filters pool by climate + gender + formality (±3) + weight (±2) + color-temp. Multi-layer invariants checked in handlers.
- Risk: If user wardrobe grows large (1000+ items), pre-filtering and invariant checks may slow down. No pagination or limit documented.
- Fix: Add query limit + batch processing if pool > threshold. Benchmark with 500+ item wardrobe in test.

**Gemini API timeout 60s default:**
- Files: `wardrobe-backend/settings.py` (line 62): `GEMINI_TIMEOUT_SECONDS: int = 60`
- Risk: Try-on high-res generation (10–20s) + network latency can hit timeout under load. No retry logic documented.
- Fix: Add exponential backoff retry for Gemini service, reduce timeout to 45s, monitor p99 latency.

---

## Code Quality & Maintainability

**Recommendation engines V2 + V05 coexist:**
- Files: `wardrobe-backend/services/recommendation_service.py` (V2), `services/engine_v05.py` (V05)
- Status: V05 being rolled out gradually via feature flag. Both engines maintained in parallel.
- Risk: Bug fixes or improvements to one don't propagate to the other. V2 eventually deprecated but unclear when.
- Fix: Document V2 deprecation timeline (e.g., remove 3 months post-V05 launch). Add clear "DO NOT USE" warning on V2 code if frozen.

**Multiple test runners (pytest, test_server.py, test_chat_flow.py, test_agent.py, test_garment_extraction.py):**
- Files: `wardrobe-backend/test_*.py` (5 standalone scripts)
- Issue: Non-standard. `test_server.py` is the "pre-commit" check documented in CLAUDE.md, but others are independent ad-hoc tests.
- Risk: Developers may skip pre-commit if they only ran their feature test. No CI gate enforces full suite.
- Fix: Consolidate into single pytest entry point with markers. Keep `test_server.py` as convenience wrapper for e2e smoke, but base all tests on pytest.

**Backend service-repository pattern inconsistently applied:**
- Files: `wardrobe-backend/routers/`, `services/`, `repositories/`
- Documentation shows pattern clearly, but if new routes added without following pattern, hard to enforce.
- Fix: Add linter rule to detect Router directly importing models (should go through service). Pre-commit check in CI.

---

## Known Unfinished Work (Scheduled)

**AU-251 (BE) — V05 Remix `/next` endpoint:**
- Status: 🚧 In Progress (started 5/8, target 5/10 cycle 10 closure, 5pt)
- Blocker: Tech-lead review of session contract design (Redis schema, 4-axis state machine)
- Risk: If complex, may slip 1-2 days. Descope plan: drop NEW_ANCHOR axis, ship 3-axis cycle first.
- Dependencies: PR #41 (AU-244 Phase 0 inventory import) must merge to seed SYSTEM items in DB.

**AU-250 (ME) — V05 Remix UI wiring:**
- Status: ⏳ Blocked by AU-251 (started 5/11, target 5/15, 8pt)
- Scope: Replace `valenGetRecommendation` → V05 `/start|next`, add RemixButton + AxisChip, wire daily reset + Edit Context, Maestro E2E.
- Risk: Large scope (8pt). If AU-251 slip, mobile descope decision: ship lắc lại + V05 wire first, defer daily reset + Edit Context Phase 5.
- Hard dependency: Design assets from Viet (button, axis hints, copy) due 5/9.

**AU-245 (BE) — V05 Phase 1 Onboarding API:**
- Status: 🔄 In Progress
- Impact on launch: LOW — only blocks NEW users. Existing users can test V05 anyway. Acceptable to slip to Cycle 11.

**AU-72 (ME) — Location/Weather integration:**
- Status: 🔄 In Progress (small task)
- Impact on launch: LOW — fallback to default temperature if not ready.

**Dual HomeScreen migration:**
- Status: Legacy `_HomeScreen.tsx` (941 LOC) coexists with `HomeScreen.tsx`. Post-V05 launch, determine: delete legacy, keep as variant, or document as archived.
- Dependencies: V05 verified in production (5/15+), user feedback on stability.

---

## Technical Debt Summary

| Area | Severity | Impact | Effort to Fix |
|---|---|---|---|
| Hardcoded localhost URLs | HIGH | Blocks staging/prod deployment | Medium (1-2 days) |
| API docs drift (2 copies) | MEDIUM | Developer confusion, contract misses | Low (establish source-of-truth process) |
| CORS wildcard in prod config | HIGH | Security risk | Low (override in .env) |
| Analytics stubs (7+ console.info) | MEDIUM | V05 launch untracked | Medium (1 day telemetry service) |
| Dual-home + legacy HomeScreen | MEDIUM | Code maintenance burden | Low (cleanup post-launch) |
| Submodule bump management (manual, frequent) | MEDIUM | Drift risk between repos | Medium (CI validation gate) |
| Skipped integration tests | LOW | Regression risk (acceptable for MVP) | Low (nightly CI run) |
| Multiple test runners | LOW | Developer confusion | Low (consolidate to pytest) |
| V2 + V05 engine coexistence | LOW | Maintenance burden | Medium (deprecation + timeline) |
| Redis session TTL (30min) | LOW | UX gap if session expires | Low (document + monitor) |

---

*Concerns audit: 2026-05-08*
