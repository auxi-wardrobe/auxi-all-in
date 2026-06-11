---
name: wardrobe-review-heuristics
description: Recurring review blind spots in wardrobe-backend/auxi that pass CI but break in prod
metadata:
  type: project
---

Recurring review heuristics for this project (found during AU-318 review, 2026-06-11):

- Backend tests run on SQLite; prod is Postgres. SQLite does NOT enforce `String(N)` lengths, so missing length validation on client strings bound for VARCHAR columns is invisible to the whole pytest suite. Always check length guards on new String columns fed by request data.
  **Why:** AU-318 shipped `outfit_hash` → `String(64)` with 52 green tests and a prod-only 500 path.
  **How to apply:** for any new model column + router accepting the value, grep for a length check before approving.
- `utils/rate_limiter.get_rate_limiter(n)` is a global singleton that ignores `n` after first call AND shares one bucket across endpoints. Correct house pattern: module-level `SimpleRateLimiter(n)` (see `routers/v05_outcome.py:41`, now also `routers/favorites.py`). Flag any new `get_rate_limiter` usage.
- All upserts in this codebase are SELECT-then-INSERT with no DB uniqueness backstop (favorites JSON-path lookup, mood signals). Concurrent-request duplicates are a standing risk; check whether the client's retry/timeout behavior (auxi uses 15s axios timeouts) widens the window.
- auxi `HomeScreen` generates client fallback `outfit_hash` values (`outfit-${index}`, session-scoped). Any backend feature that treats `outfit_hash` as identity must consider fallback-hash collisions across sessions.
- Favorites router 500 handler leaks `"details": str(e)` (pre-existing) — any new code path that can raise driver errors there amplifies the leak.
- auxi i18n: keys resolve under `defaultNS='boilerplate'` (JSON root key = namespace), so `t('mood.title')` ↔ `.boilerplate.mood.title`. Verify locale parity with `jq -S '.boilerplate.<ns> | keys'` diff across en-EN/fr-FR/vi-VN.
- Known baselines (2026-06): auxi tsc 19 errors (all `_HomeScreen.tsx`), eslint errors in `HomeScreen.tsx` from commented-out PHASE C mode selector are pre-existing on HEAD — diff against `git show HEAD:<file>` before attributing lint errors to a change.
