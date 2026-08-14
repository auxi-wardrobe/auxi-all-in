# Phase 01 — Backend usage endpoint (`GET /api/me/usage`)

**Owner:** backend-dev · **Sign-off:** tech-lead (public API contract change)
**Priority:** P1 (blocks phase 03) · **Status:** pending · **Effort:** 3h
**Scope:** `wardrobe-backend/` only.

## Context links

- Umbrella contract rule: `CLAUDE.md` → "Two-Repo Contract"
- Backend conventions: `wardrobe-backend/CLAUDE.md` (service→repository pattern, API doc mandatory)
- Consumer: [phase-03](./phase-03-trigger-wiring-and-analytics.md)

## Key insights (verified 2026-08-14; reset/cache-hit decisions locked same day; reset cadence
corrected monthly→daily same day, user-confirmed against Figma sheet copy)

### Counter source of truth — per feature (post-clarification)

| Feature | Reset | Durable source | Verified at |
|---|---|---|---|
| **See on Me** | daily | `COUNT(tryon_images WHERE user_id=? AND cache_hit=false AND created_at >= day_start)` | `models/tryon.py:6-14` |
| **Wardrobe items** | never (lifetime) | `COUNT(wardrobe_items WHERE owner_id=? AND is_deleted=false AND is_common_item=false)` | `models/wardrobe.py:21,32,33` |
| **Enhance photo** | daily | `COUNT(beautify_attempt_events WHERE user_id=? AND created_at >= day_start)` — **new table** | see below |

Traces:
- try-on rows are written by `TryOnHistoryService.save_tryon_result`
  (`services/tryon_history_service.py:19` → `repositories/tryon_repository.py:21` `create_image`),
  called from `services/tryon_render_service.py:214` (fresh render) **and** `:133` (cache-hit
  re-serve) — same call, no distinguishing flag today. **CEO decision: cache-hit re-serves must NOT
  count.** → add `tryon_images.cache_hit` (boolean, default `false`, migration), pass
  `cache_hit=True` from the `:133` call site and `cache_hit=False` from `:214`. The usage query
  filters `cache_hit=false`. (Existing history/gallery reads of `tryon_images`, if any, are
  unaffected — additive column.)
- `beautify_attempts` (`models/wardrobe.py:46`, incremented `services/beautify_service.py:105`) is a
  **lifetime running integer counter with no per-attempt timestamp** — confirmed by grep, no
  beautify job/history table exists (`services/beautify_service.py` writes only this column). It
  cannot answer "attempts today". **New table required**: `beautify_attempt_events(id, user_id,
  item_id, created_at)`, one row inserted alongside the existing `beautify_attempts += 1` at
  `beautify_service.py:105` (same transaction). The existing per-item regen cap of 5
  (`routers/wardrobe.py:798`, `BEAUTIFY_MAX_REGENERATIONS`) keeps reading `beautify_attempts` as-is —
  unrelated, unaffected. The new table is purely additive and only feeds the daily usage count.

### What is NOT reusable

- `deps/ai_usage.py:20` `enforce_ai_daily_limit` / `utils/rate_limiter.py:253`
  `check_ai_daily_limit` — Redis `INCR` on `ai:daily:{user_id}:{YYYYMMDD}` with a 2-day TTL
  (`utils/rate_limiter.py:271-276`), config `settings.py:52-56`. **Ephemeral, fail-open, and
  shared across all AI endpoints.** Even though it happens to share the daily granularity now,
  it cannot express a durable, per-feature "2 See-on-me per day" free-tier quota (no historical
  correctness, no premium bypass, no per-feature limits). Do not extend it.
- The mobile `aiLimitStore` (`auxi/src/services/aiLimitStore.ts`) is in-memory-per-session — same
  reason, not reusable.

### What the client already has

`GET /api/wardrobe/items` returns `count` (`routers/wardrobe.py:103` route, `:355` field) — so
wardrobe count *is* client-derivable. See-on-me count and enhance count are **not** exposed by any
endpoint (`routers/tryon.py` has only `/highres`, `/result/{job_id}`, feedback). Deriving enhance
count client-side by summing `beautify_attempts` over the item list would silently undercount
(soft-deleted items are excluded from the list). → server-side is the only correct option.

### Rejected alternatives

| Option | Why rejected |
|---|---|
| Client-side AsyncStorage counters | Resets on reinstall, not cross-device, can't be corrected; the whole point of the ticket is trustworthy demand data |
| 3 separate endpoints | 3× round trips, 3× docs, no single place for the premium bypass |
| Reuse `ai:daily:*` Redis counter | Ephemeral TTL, fail-open, no premium bypass, no per-feature limits — not a durable quota source even though granularity now matches |

## Requirements

**Functional**
1. `GET /api/me/usage` — auth required, read-only, returns used/limit/limit_reached per feature.
2. Limits come from env config, not code constants, so the CEO can retune the experiment without
   an app release.
3. Premium users (`models/user.py:62` `is_premium` property, backed by `:44-50`) always get
   `limit_reached: false`.

**Non-functional**
4. Three indexed aggregate queries, no N+1 — target < 50 ms.
5. Read-only: MUST NOT mutate anything, MUST NOT 429, MUST NOT block any flow.
6. Rate limit: read tier (60/min) per `wardrobe-backend/.claude/rules/security.md`.

## Architecture

```
GET /api/me/usage   (routers/usage.py, new — auth.py is already large; keep files <200 LOC)
   → services/usage_service.py   compute + compare against settings
        → repositories/usage_repository.py   3 aggregate queries
             tryon_images.COUNT · wardrobe_items.COUNT · wardrobe_items.SUM(beautify_attempts)
```

**Response shape** (single object, feature-keyed — one comparison rule for the client):

```json
{
  "is_premium": false,
  "features": {
    "see_on_me":      { "used": 2,  "limit": 2,  "limit_reached": true  },
    "wardrobe_items": { "used": 12, "limit": 51, "limit_reached": false },
    "enhance_photo":  { "used": 31, "limit": 31, "limit_reached": true  }
  }
}
```

**Comparison rule: `limit_reached = used >= limit`, uniformly.** The ticket mixes operators
("2 times" vs "more than 50" vs "more than 30"), so `limit` is expressed as the *trigger-at* value:
`see_on_me=2`, `wardrobe_items=51`, `enhance_photo=31`. One operator, no per-feature branching.
**Confirmed by user 2026-08-14.**

**Reset: `see_on_me` and `enhance_photo` are scoped to the current calendar day (UTC);
`wardrobe_items` is lifetime, never reset.** Corrected 2026-08-14 (was monthly; the Figma sheet copy
— "today's limit" / "come back tomorrow when your free tries refresh" — is daily framing). `day_start`
= `datetime(now.year, now.month, now.day, tzinfo=utc)`, computed once per request, no stored "period"
row — purely a query filter against `created_at`, so there is nothing to reset/cron.

**Config** (`settings.py`, alongside `AI_DAILY_LIMIT_*` at `:52-56`):

```
FREE_LIMIT_SEE_ON_ME: int = 2
FREE_LIMIT_WARDROBE_ITEMS: int = 51
FREE_LIMIT_ENHANCE_PHOTO: int = 31
PAYWALL_MVP_ENABLED: bool = True     # kill-switch; false → all limit_reached false
```

## Related code files

**Create**
- `wardrobe-backend/routers/usage.py`
- `wardrobe-backend/services/usage_service.py`
- `wardrobe-backend/repositories/usage_repository.py`
- `wardrobe-backend/models/beautify_attempt_event.py` — new table (`id`, `user_id` FK indexed,
  `item_id` FK, `created_at`)
- `wardrobe-backend/migrations/versions/<rev>_add_usage_tracking.py` — adds `tryon_images.cache_hit`
  (bool, default `false`, server_default `'false'`) + creates `beautify_attempt_events`
- `wardrobe-backend/tests/test_usage_endpoint.py`

**Modify**
- `wardrobe-backend/settings.py` — 4 config keys
- `wardrobe-backend/app.py` — `include_router(usage.router)` (follow existing include pattern)
- `wardrobe-backend/models/tryon.py` — add `cache_hit` column
- `wardrobe-backend/services/tryon_render_service.py:133,214` — pass `cache_hit=True`/`False` into
  `save_tryon_result`
- `wardrobe-backend/services/tryon_history_service.py:19` — accept + forward `cache_hit`
- `wardrobe-backend/repositories/tryon_repository.py:21` — persist `cache_hit` on `create_image`
- `wardrobe-backend/services/beautify_service.py:105` — insert one `beautify_attempt_events` row in
  the same transaction as the existing `beautify_attempts += 1`
- `wardrobe-backend/API_DOCUMENTATION.md` — new §Usage section (MANDATORY per repo rule)

**Read for context**
- `wardrobe-backend/deps/ai_usage.py` (dependency style), `routers/auth.py:382` (`/me` precedent),
  `repositories/tryon_repository.py`, `models/wardrobe.py`

## Implementation steps

1. Migration: add `tryon_images.cache_hit` (bool, default false) + create `beautify_attempt_events`
   table (id, user_id FK indexed, item_id FK, created_at indexed). Run it.
2. `models/tryon.py` — add `cache_hit` column. `models/beautify_attempt_event.py` — new model.
3. `tryon_render_service.py` — pass `cache_hit=True` at the `:133` cache-hit call, `cache_hit=False`
   at the `:214` fresh-render call, threading the param through `tryon_history_service.py:19` →
   `tryon_repository.py:21`.
4. `beautify_service.py:105` — in the same transaction as `beautify_attempts += 1`, insert one
   `BeautifyAttemptEvent(user_id=item.owner_id, item_id=item.id)` row.
5. Add the 4 settings keys with defaults + docstring noting they are experiment knobs.
6. `usage_repository.py`: three functions.
   - `count_see_on_me(user_id, day_start)` → `count(tryon_images) WHERE user_id=? AND
     cache_hit=false AND created_at >= day_start`
   - `count_wardrobe_items(user_id)` → `count(wardrobe_items) WHERE owner_id=? AND is_deleted=false
     AND is_common_item=false` (lifetime, no date filter)
   - `count_enhance_photo(user_id, day_start)` → `count(beautify_attempt_events) WHERE user_id=?
     AND created_at >= day_start`
7. `usage_service.py`: compute `day_start` once (UTC, start of current calendar day); assemble the
   dict; short-circuit `limit_reached=False` when `user.is_premium` or `not PAYWALL_MVP_ENABLED`.
   Keep the feature-key strings in ONE constant tuple shared with the response model.
8. `routers/usage.py`: `@router.get("/me/usage")`, `Depends(get_current_user)`, read-tier rate limit,
   Pydantic response model.
9. Register in `app.py`.
10. Tests (below).
11. Update `API_DOCUMENTATION.md` with request/response/errors/rate-limit + the reset-cadence note
    per `wardrobe-backend/.claude/rules/api-documentation.md`.
12. `python test_server.py` green.

## Test matrix

| Level | Case | Expect |
|---|---|---|
| unit (repo) | user with 0 try-ons / 0 items / 0 enhances | all `used: 0` |
| unit (repo) | try-on row with `cache_hit=true` today | NOT counted in see_on_me |
| unit (repo) | try-on row with `cache_hit=false` from yesterday | NOT counted (outside current day) |
| unit (repo) | try-on row with `cache_hit=false` earlier today | STILL counted (within current day) |
| unit (repo) | soft-deleted item, still has `beautify_attempt_events` rows | counted in enhance (events table doesn't care about item soft-delete), NOT in wardrobe count |
| unit (repo) | common item (`is_common_item=true`) in user's list | NOT counted in wardrobe count |
| unit (repo) | wardrobe item created yesterday, still present | STILL counted (lifetime, no date filter) |
| unit (service) | `used == limit` | `limit_reached: true` (boundary — the whole feature) |
| unit (service) | `used == limit - 1` | `limit_reached: false` |
| unit (service) | premium user over every limit | all `limit_reached: false` |
| unit (service) | `PAYWALL_MVP_ENABLED=false` | all `limit_reached: false`, `used` still real |
| integration | no auth token | 401 |
| integration | happy path | 200, exact shape above |
| migration | upgrade then downgrade (alembic) round-trips cleanly | no data loss on existing `tryon_images` rows |

## Todo

- [ ] migration: `tryon_images.cache_hit` + `beautify_attempt_events` table
- [ ] thread `cache_hit` through render_service → history_service → repository
- [ ] insert `beautify_attempt_events` row alongside `beautify_attempts += 1`
- [ ] settings keys
- [ ] usage_repository (day-scoped see_on_me/enhance, lifetime wardrobe_items)
- [ ] usage_service (+ premium/kill-switch short-circuit)
- [ ] routers/usage.py + app.py registration
- [ ] tests per matrix
- [ ] API_DOCUMENTATION.md §Usage (incl. reset cadence)
- [ ] `python test_server.py` green
- [ ] tech-lead contract sign-off

## Success criteria

- `curl -H "Authorization: Bearer …" :5001/api/me/usage` returns the documented shape.
- Boundary tests pass at `used == limit` for all three features.
- `API_DOCUMENTATION.md` diff reviewed and signed off by tech-lead.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| New `beautify_attempt_events` table grows unbounded (one row per enhance attempt, forever) | L×L | tiny row (3 FKs + timestamp), indexed on `(user_id, created_at)`; acceptable for MVP, revisit if it ever needs pruning |
| Migration touches a hot path (`beautify_service.py:105`, `tryon_render_service.py:133/214`) | M×M | additive-only changes (new column default false, new insert in same transaction); no behavior change to existing responses; covered by existing beautify/tryon test suites + new tests above |
| Endpoint failure blocks a user flow | L×H | client treats any error/timeout as "not limited" — fail-open, specified in phase-03 |
| Contract drift with mobile | M×M | tech-lead gate + API doc in the same PR |

## Security

- `Depends(get_current_user)` — a user can only read their own counts; no `user_id` path/query param.
- No PII in the response (counts only).
- Read-tier rate limit; no writes → no CSRF/abuse surface.

## Backwards compatibility / migration

Purely additive: new route, no schema migration, no change to existing responses. Old app builds are
unaffected. No data backfill needed — counters are computed from rows that already exist, so every
existing user has a correct historical count on day one.

## Next steps

Unblocks phase 03. Notify mobile-dev + tech-lead when the API doc entry lands.

## Unresolved questions

None — operator semantics, cache-hit counting, and reset cadence (corrected monthly→daily) were
confirmed by the user 2026-08-14 (see top of file). Remaining open item is cross-repo, not backend:
whether `NotifyMe` is a full screen or a sheet state (phase 02, depends on the Figma frame).
