# Follow-up: favorites upsert needs DB uniqueness backstop (TOCTOU)

**Source**: AU-318 code review (B2), plans/260611-2004-au318-wear-this-mood-feedback/reports/code-review-260611-au318.md
**Severity**: Major (race condition, low frequency)

## Problem

`POST /api/favorites` upsert (routers/favorites.py) and the mood-signal upsert
(blueprints/mood/mood_feedback_repository.py) are SELECT-then-INSERT with no DB
uniqueness constraint. Two concurrent requests with the same `(user_id,
outfit_hash)` — realistic trigger: client 15s timeout fires → user retries while
the first request is still being processed server-side — can create duplicate
favorites and inflate mood-signal counts feeding the prompt-frequency policy.

## Proposed fix

- Postgres partial unique expression index on
  `(user_id, (outfit_context ->> 'outfit_hash'))` WHERE outfit_hash IS NOT NULL
  (Alembic migration), catch `IntegrityError` → re-select → return `updated:true`.
- Same treatment for `outfit_mood_signals (user_id, outfit_hash)` latest-active
  semantics, or move to one-row-per-(user,outfit) with updated timestamp.

## Interim mitigations (already shipped in AU-318)

- Client in-flight guard prevents same-session duplicate POSTs.
- Docstring/API doc claim softened to "sequential retries are idempotent".

## Acceptance

- Concurrent duplicate POST test (two threads, same payload) → exactly one
  favorite row, second response `updated: true`.
