# backend-dev report — AU-442 Phase 01: GET /api/me/usage

**Plan:** `plans/260814-1232-au-442-paywall-mvp/phase-01-backend-usage-endpoint.md`
**Scope:** `wardrobe-backend/` only. Public API contract change — **requires tech-lead sign-off**.

## What was built

New read-only endpoint `GET /api/me/usage` (see-on-me / wardrobe-items / enhance-photo usage
snapshot for the mobile soft-paywall sheet). Not a real IAP feature — no purchase flow, no
server-side enforcement, no 429 on limit.

### New files
- `wardrobe-backend/routers/usage.py` — `GET /api/me/usage`, `Depends(get_current_user)`, 60/min read-tier rate limit
- `wardrobe-backend/services/usage_service.py` — `limit_reached = used >= limit`; premium/kill-switch bypass (used stays honest)
- `wardrobe-backend/repositories/usage_repository.py` — 3 aggregate COUNT queries (SQLAlchemy ORM only)
- `wardrobe-backend/schemas/usage.py` — Pydantic response model
- `wardrobe-backend/models/beautify_attempt_event.py` — new model, `beautify_attempt_events` table
- `wardrobe-backend/migrations/versions/usagepwl1a2b_add_usage_tracking.py` — head is now `usagepwl1a2b` (was `trendingdrop1a2b`)
- `wardrobe-backend/tests/test_usage_endpoint.py` — 14 tests (repo/service/integration/migration)

### Modified files
- `wardrobe-backend/settings.py` — `PAYWALL_MVP_ENABLED`, `FREE_LIMIT_SEE_ON_ME` (2), `FREE_LIMIT_WARDROBE_ITEMS` (51), `FREE_LIMIT_ENHANCE_PHOTO` (31)
- `wardrobe-backend/app.py`, `wardrobe-backend/routers/__init__.py` — router registration
- `wardrobe-backend/models/tryon.py` — added `cache_hit` column (bool, default false)
- `wardrobe-backend/repositories/tryon_repository.py`, `services/tryon_history_service.py`, `services/tryon_render_service.py` — threaded `cache_hit` (True at the cache-hit re-serve call site, False at the fresh-render call site)
- `wardrobe-backend/services/beautify_service.py` — inserts one `BeautifyAttemptEvent` row in the same transaction/commit as the existing `beautify_attempts += 1` (line ~105); the existing per-item regen cap logic is untouched
- `wardrobe-backend/migrations/env.py` — registered new model import
- `wardrobe-backend/API_DOCUMENTATION.md` — new `## Usage (Paywall MVP — AU-442)` section (request/response/errors/rate-limit/reset-cadence/env-config), inserted after the existing "AI Usage Limits & Error Contracts" section
- `wardrobe-backend/tests/test_tryon_render_service.py` — updated one pre-existing assertion to match the new `cache_hit=True` kwarg on the cache-hit path (this is the exact call the plan asked to change; the test just needed to catch up)

## Key implementation notes

- `limit_reached = used >= limit` uniformly, limits are see_on_me=2, wardrobe_items=51, enhance_photo=31 — matches the plan's confirmed "trigger-at" semantics exactly.
- Reset cadence: see_on_me/enhance_photo filter `created_at >= month_start` (UTC, computed once per request as `datetime(now.year, now.month, 1, tzinfo=utc)`); wardrobe_items has no date filter (lifetime).
- `count_enhance_photo` never joins `wardrobe_items` — a soft-deleted item's past beautify attempts still count (per test matrix).
- Premium (`User.is_premium`) and `PAYWALL_MVP_ENABLED=false` both force `limit_reached=False` without touching `used`.
- Migration is additive-only: `tryon_images.cache_hit` (nullable=False, server_default `'false'` — existing rows backfill to false, matching "all pre-cache-hit-tracking renders were fresh"), new `beautify_attempt_events` table (FK CASCADE on user_id/item_id, indexed on both).

## Discovered (out of scope, flagged not fixed)

Writing the migration round-trip test surfaced a **pre-existing bug** unrelated to this
change: `migrations/versions/f9c1a2b3d4e5_scope_user_hrid_uniqueness.py` uses
`sqlite_where="..."` as a raw string on `op.create_index(...)`, which is incompatible with the
installed SQLAlchemy on SQLite (`AttributeError: 'str' object has no attribute
'_compiler_dispatch'`). It has evidently only ever run against Postgres (prod) — no test in this
repo replays the full alembic chain on SQLite. I did **not** touch it (unrelated revision, no
mandate to fix, risk of touching a merged historical migration without review). I scoped my own
migration round-trip test around it (`alembic stamp` onto a hand-built pre-migration schema
instead of replaying full history from base) rather than working around it in the shared file.
Worth a follow-up ticket if anyone wants SQLite-runnable full-chain migrations (e.g. local
onboarding, CI schema-drift checks).

## Test results

- `pytest -m unit` (repo): 611 passed / 39 failed / 1 skipped. **The 39 failures are pre-existing**
  — same V05 recommendation-engine test files fail identically on a clean stash of my changes
  (verified via `git stash` A/B: baseline showed 47 failed with a different flaky subset, same
  files). None touch usage/tryon/beautify code paths.
- `pytest -m integration`: 259 passed / 1 skipped / 0 failed.
- `pytest tests/test_usage_endpoint.py`: 14/14 passed (repo boundary/filter cases, service
  boundary/premium/kill-switch cases, integration 401+happy-path, migration round-trip).
- `pytest tests/test_tryon_render_service.py tests/test_beautify_service.py`: 32/32 passed
  (confirms the `cache_hit` threading and the `BeautifyAttemptEvent` insert don't regress
  existing render/beautify behavior).
- `python test_server.py`: **45/45 passed** (full e2e on :5002, includes trending-drop suite as a
  regression signal for router registration ordering).

All verification commands were actually run in this session (not claimed without running).

## Unresolved questions

None for this phase. Cross-repo: phase-03 (mobile trigger wiring) is unblocked — mobile-dev
should sync `auxi/src/services/*.ts` against the new `API_DOCUMENTATION.md` §Usage entry once
tech-lead signs off on the contract.
