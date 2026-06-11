# Code Review — AU-318 Wear-This Mood Feedback (uncommitted, both submodules)

Reviewer: code-reviewer · 2026-06-11 · scope per task list (pre-existing dirty files excluded)
Ratified decisions (201/200 split, FK SET NULL, 400 no-hash, M1 limiter fix, M2 sequencing) not re-litigated.

## Verification run

- Backend: `pytest tests/test_mood_feedback_service.py tests/test_mood_affinity.py tests/test_mood_feedback_policy.py -q` → **52 passed**.
- Mobile: `npx tsc --noEmit` → 19 errors, **all in legacy `_HomeScreen.tsx`** (known baseline; 0 from AU-318 files).
- Mobile: `eslint` on the 7 AU-318 files → 3 errors in `HomeScreen.tsx`, **all pre-existing on HEAD** (commented-out PHASE C mode selector: `RECOMMENDATION_MODE_OPTIONS`, `handleSelectMode`, `onEditContext`). Not AU-318 regressions.
- i18n: `jq` parity check → `boilerplate.mood` has **24/24 identical keys in en-EN, fr-FR, vi-VN**; `t('mood.*')` resolves via `defaultNS='boilerplate'` (verified `src/translations/index.ts:22`, `src/i18n/init.ts:115`).
- Tech-lead M1 (dedicated limiter) verified fixed: `routers/favorites.py` module-level `SimpleRateLimiter(20)`; policy router `SimpleRateLimiter(60)`.
- M2 still live: all 3 feedback-train migrations (incl. `au318a1b2c3d`) remain untracked — sequencing per tech-lead decision (d) applies at merge.

## CRITICAL

None.

## MAJOR

### B1 — Unbounded `outfit_hash` reaches `String(64)` column → 500 + internal error leak (prod only)
`routers/favorites.py` validates mood_tags presence/vocab but never the **length of `outfit_hash`**. The mood path inserts it into `outfit_mood_signals.outfit_hash` (`String(64)`, model + migration). On Postgres, a >64-char client hash raises `DataError` at flush/commit → caught by the generic handler at `routers/favorites.py:220-226`, which returns 500 with `"details": str(e)` — leaking driver/statement internals (the leaky 500 shape is pre-existing, but AU-318 adds the first user-controlled value that can trip it). SQLite doesn't enforce VARCHAR length, so the 52 tests cannot catch this.
**Fix (2 lines):** in the existing `mood_tags`-without-hash guard block, also reject `len(data.outfit_hash) > 64` → 400. Optionally strip `"details"` from the 500 (separate, pre-existing).

### B2 — Upsert TOCTOU: concurrent POSTs with the same `outfit_hash` create duplicate favorites + duplicate active mood rows
Both upserts are SELECT-then-INSERT with no DB uniqueness backstop:
- `routers/favorites.py:171-190` (favorite by JSON-path lookup — no constraint possible without an expression index),
- `blueprints/mood/mood_feedback_repository.py:52-72` (mood row).
Two interleaved transactions both miss on SELECT and both INSERT. The mobile client's `inFlightRef`/`lockRef` guards shrink the window but don't close it — the realistic trigger is the new 15s client timeout: axios gives up while the server is still processing, user retries, two server transactions overlap. Result: user-visible duplicate favorites; inflated `count_active_signals` (skews policy tiers). The docstring/API-doc claim "retries are idempotent" holds sequentially, not concurrently.
**Fix or ticket:** Postgres partial unique expression index on `favorites (user_id, (outfit_context->>'outfit_hash')) WHERE outfit_context->>'outfit_hash' IS NOT NULL` + IntegrityError→re-select, or `pg_advisory_xact_lock(hashtext(user_id || outfit_hash))` around the upsert. Acceptable to ship with a follow-up ticket given low probability — but file it; don't let the "idempotent" doc claim stand unqualified.

### B3 — Client fallback hash is now server-side upsert identity → silent "save" that saves nothing
`HomeScreen.tsx:311` `fallbackHash = \`outfit-${indexOffset + index}\`` is **session-scoped, not content-scoped**. Pre-AU-318 it only keyed local `saveStateByHash`. Now it's sent as the backend upsert key: outfit A saved as `outfit-0` in session 1; a *different* outfit B gets `outfit-0` in session 2 → backend finds the session-1 favorite → **no new favorite created**, returns `updated: true`, banner says "Mood updated for this saved look". Outfit B is silently never saved. Only reachable when V05 omits `outfit_hash` (legacy/malformed shapes), so likelihood is low — but the failure is silent data loss from the user's perspective.
**Fix (cheap):** mark fallback hashes (they're distinguishable: `outfit-` prefix) and omit `outfit_hash` from the save payload / route to `saveDirectly` instead of opening the mood sheet when the hash is a fallback.

## MINOR

1. **Policy limiter keyed by spoofable IP, gating inconsistent** — `mood_feedback_policy.py:37-42` keys on first `X-Forwarded-For` hop (client-spoofable) though the endpoint is authenticated (`user.id` available); also it's unconditional while the favorites limiter is gated on `settings.RATE_LIMIT_ENABLED`. Matches the v05_outcome house pattern, so consistency-accepted; consider user-id keying when that pattern is next touched.
2. **Learning write ordering** — `_learn_style_signals` commits a `V05UserStyleSignal` in its own session *before* the favorites transaction commits (`mood_feedback_service.py:129-143`). If the outer commit then fails, an orphan style signal persists (bounded by 30d decay). Consider moving the learn call post-commit in the router; current never-raise posture otherwise correct.
3. **400 error echoes unbounded user strings** — `Unknown mood tags: [...]` reflects raw client strings of arbitrary length into the error body (JSON-encoded, no injection; vocab tags themselves never echo PII). Truncate each echoed tag to ~64 chars.
4. **`wear_this_clicked` double-fires on rapid taps** — `use-mood-feedback.ts:174-182` tracks before the `lockRef` check, so analytics counts taps the UX correctly no-ops. Move below the lock check if dedup is intended; fine if "raw taps" is the metric.
5. **Post-unmount banner timer escapes cleanup** — a submit resolving after HomeScreen unmounts calls `showMoodBanner`, creating a timeout after the unmount-cleanup effect already ran. Harmless (no-op setState, React 18), noted for completeness.
6. **`context_snapshot` is effectively empty** — mobile never sends `outfit_context` in the save payload, so snapshots are `{occasion: null, weather: null, source: 'home'}` and occasion-contextual chip sets only trigger if `selectedMode` happens to equal `work|weekend|social|travel`. Acknowledged in code comments ("if/when real occasions flow"); informational — contextual learning and `soft_negative_dislikes` are dormant until threaded.
7. **Stale comment** — `mood-chips.ts:8` says labels live at `boilerplate.mood.*`; actual lookup keys are `mood.*` under the `boilerplate` namespace. Works; comment imprecise.
8. **Selected-chip salience** — selected vs idle is bg-only (`rgba(18,18,18,0.75)` → `#5b5550`), both dark with identical white text. `accessibilityState.selected` is set (good); visual differentiation is subtle — qa-ui/design call, not blocking.
9. **Error-shape coverage gap in tests** — integration tests assert FastAPI-nested `detail` (test app lacks the `app.py` flattener); the documented top-level `{error, request_id}` shape isn't exercised here. Already noted as flattener behavior in tech-lead review; fine.

## Conventions — PASS

- Service-repo pattern clean: router → `MoodFeedbackService` → `MoodFeedbackRepository`; no commits below router; no raw SQL; JSON-path query is ORM-parameterized (no injection).
- Auth: both new surfaces behind `Depends(get_current_user)`; 401 covered by tests.
- Theme tokens only in new mobile files (no hex literals); all tokens verified to exist in `theme.ts`.
- testIDs on every interactive element: `mood-feedback-{sheet,backdrop,done,error,banner}`, `mood-chip-<id>`; a11y labels distinct from testIDs; `accessibilityRole="alert"` on banner.
- Vocab mirror: 16/16 ids byte-identical client↔server; dev-time guard enforces ≤8 chips/set + trailing `not_quite_me`.
- API_DOCUMENTATION.md favorites + policy sections match implementation exactly (vocab, tiers, status codes, rate limits).
- New `maestro/flows/home/mood-feedback.yaml` present (untracked) — QA hook exists.

## State machine / edge cases — PASS

- Rapid "Wear this" taps: synchronous `lockRef` → single sheet instance.
- Dismiss-during-submit blocked in 3 layers (hook guard, backdrop `undefined` handler, PanResponder `isSubmittingRef`).
- Unmount-during-submit: no crash, setState no-ops, no unbounded leak.
- Error keeps selections (sheet `visible` never flips; selections reset only on re-open) + Done re-enables; timeout vs generic copy split works (`ECONNABORTED` via new 15s timeout).
- Policy fallback: ANY failure (network/5xx/malformed 2xx body) → prompt-always default, single-flight cached, refetched post-submit. Save path never blocked by policy outage.
- Old-backend tolerance: missing `updated` field degrades to `false` (create copy) — graceful.

## Tests — substantive, not tautological

52/52 pass. Spot-checked: DB row-count assertions (no-dup, atomic no-half-save), 201/200 + `updated` flag, engine parity test imports the real `AXIS_MATCHERS`, real-persistence test re-patches `_open_session` against a file DB (validates the conftest autouse stub doesn't mask the write path), clamp boundary tests for stacked dislikes. The autouse `_isolate_v05_style_signal_persist` fixture is correctly scoped and documented.

## Recommended actions (priority order)

1. B1: add `len(outfit_hash) <= 64` guard → 400 (before merge; 2 lines + 1 test).
2. B3: skip mood-sheet/omit hash for client fallback hashes (before merge; small guard in `handleWearThisForOutfit` or hook).
3. B2: file follow-up ticket for upsert uniqueness backstop (expression index or advisory lock); soften "retries are idempotent" doc wording to "sequential retries".
4. Minors 1-3 as follow-ups at next touch.

## Verdict: APPROVE WITH FIXES

0 critical · 3 major (B1, B3 fix-before-ship — both trivial; B2 fix-or-ticket) · 9 minor. Architecture, contract fidelity, state machine, i18n, conventions, and test quality are all strong. Pre-ratified items untouched and verified implemented as ratified.
