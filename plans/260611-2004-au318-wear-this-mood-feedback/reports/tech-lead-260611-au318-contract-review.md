# Tech-Lead Contract Review — AU-318 Phase 1 (Mood Feedback on POST /api/favorites)

Reviewer: tech-lead · 2026-06-11 · branch `feat/au318-mood-feedback` (uncommitted working tree)
Scope: `routers/favorites.py`, `API_DOCUMENTATION.md` §Favorites, `models/outfit_mood_signal.py`,
`migrations/versions/au318a1b2c3d_add_outfit_mood_signals.py`, `blueprints/mood/*`,
`tests/test_mood_feedback_service.py`. Pre-existing dirty files (engine_v05*, app.py, admin) excluded.

## Verification run

- `python3 -m pytest tests/test_mood_feedback_service.py -q` → **19 passed** (covers 201/200 split,
  400 unknown-tag / >8 tags / mood-without-hash, legacy no-mood path, 401, 429, upsert-no-dup,
  decay re-insert, dedupe, context snapshot).
- Full `python test_server.py` NOT run here — working tree carries unrelated in-flight work; remains
  backend-dev's pre-merge gate.

## Per-item verdicts

### 1. `routers/favorites.py` — APPROVE (with M1 below)
- Upsert-by-`(user_id, outfit_hash)` via `Favorite.outfit_context['outfit_hash'].as_string()`
  (`routers/favorites.py:166-174`) — correct, scoped by user_id first; unindexed JSON path is fine at
  per-user favorite counts (minor, note only).
- Atomicity correct: new favorite `db.flush()` → mood row on same session → single `db.commit()`
  (`routers/favorites.py:186-207`). `ValueError` → `db.rollback()` → 400; favorite is NOT half-saved.
  Matches the doc's atomicity claim. Verified by `test_post_favorites_unknown_mood_tag_400_no_half_save`.
- `response_model=Dict[str, Any]` (`routers/favorites.py:70-71`) — `updated` field survives
  serialization. Alias route `/api/favourites` (current mobile client's path) gets identical behavior.
- Error shape: dict `detail` is flattened by `app.py:135-165` to top-level `{error, message, request_id}` —
  matches documented `{"error","request_id"}` contract.
- **M1 (major)**: `get_rate_limiter(20)` at `routers/favorites.py:95` is the GLOBAL singleton
  (`utils/rate_limiter.py:254-269` — "only used on first call"). The documented 20/min is not actually
  enforced: real rate = whatever endpoint initialized the singleton first, and the bucket is SHARED
  across every endpoint using `get_rate_limiter` (keyed by user id only) — unrelated reads can 429 the
  core "Wear This" save. The repo already has the correct pattern: dedicated module-level limiter,
  `routers/v05_outcome.py:41`. **Exact change**: module-level `_favorites_limiter = SimpleRateLimiter(20)`
  and use it in the handler (~3 lines). Required before merge (mechanical; no re-review needed).

### 2. `API_DOCUMENTATION.md` §Favorites — APPROVE
Accurate and complete for Phase 4 mobile consumption: optional `mood_tags` (max 8), full 16-tag vocab
incl. `not_quite_me` soft-negative (matches `blueprints/mood/mood_vocab.py` exactly), upsert semantics,
`updated` true/false with client copy mapping, 201/200 split, all four 400 causes, 429, atomicity note,
30-day decay. Vocab source-of-truth pointer + mirror obligation documented. No drift found.

### 3. Model + migration — APPROVE
- `models/outfit_mood_signal.py` mirrors `au318a1b2c3d` faithfully (String(36) UUID PK, JSON/JSONB
  cols, tz-aware datetimes, 3 indexes: user_id, outfit_hash, created_at).
- Migration up/down symmetric; JSONB server_default `'[]'::jsonb`; FK `favorite_id ... ondelete='SET NULL'`
  consistent in both files.
- Minor (m1): `users.id` FK has no ondelete — account-deletion path must clean `outfit_mood_signals`
  (sibling `v05_user_style_signals` has no FK at all, so this is stricter, not worse). File a follow-up;
  not blocking.

### 4. `blueprints/mood/*` — APPROVE
- Vocab: frozenset, 16 tags, `MAX_MOOD_TAGS = 8`, matches doc verbatim.
- Service: validates vocab + cap, order-preserving dedupe, server-side context_snapshot limited to
  `occasion/weather/source` (never trusts client), no commit (caller owns txn). Clean service-repo split.
- Repository: caller-session discipline, decay refresh on upsert, `count_active_signals` /
  `latest_signal_at` thin Phase-2 hooks. No raw SQL.

## Decisions

**(a) 201 create (`updated:false`) / 200 update (`updated:true`) — RATIFIED.**
Deviation from phase file's blanket-200 is an improvement: preserves legacy 201-create for the existing
client (`auxi/src/services/favouriteService.ts:20` ignores status code, reads body — no break), and is
the RESTfully correct split. Mobile branches on `updated`, treats any 2xx as success — compatible.
API doc documents both. Phase file should not be retro-edited; this note is the documented decision.

**(b) 400 when `mood_tags` without `outfit_hash` — RATIFIED.**
Mood keys off the stable hash; silently dropping mood would be a worse contract. Documented. Phase 4
constraint: mobile must always send `outfit_hash` when the mood sheet is open (it has it from v05 build).

**(c) `favorite_id` ON DELETE SET NULL — RATIFIED.**
Learning signal outlives favorite deletion; row stays attributable via `user_id` + `outfit_hash`; signal
self-expires in ≤30d via decay. Consistent in model + migration. (See m1 re user FK cleanup follow-up.)

**(d) Migration chains off UNTRACKED `appfb1a2b3c4d` — CHANGES REQUIRED (sequencing, not code).**
Chain: `au318a1b2c3d → appfb1a2b3c4d → b3c4d5e6f7a8 → au242a1b2c3d (tracked baseline)`. BOTH parents are
untracked working-tree files belonging to the feedback-system effort. If AU-318 merges without them,
`alembic upgrade head` fails: "Can't locate revision 'appfb1a2b3c4d'". Working tree is currently
single-head (good). Prescription:
1. **Preferred**: feedback-system migrations (`b3c4d5e6f7a8` + `appfb1a2b3c4d`) commit/merge FIRST
   (both are complete and idempotent-guarded); AU-318 lands as-is. OR include both migrations + their
   models in the AU-318 PR if feedback ships in the same train.
2. If AU-318 must ship first: re-parent `au318a1b2c3d` to `down_revision = 'au242a1b2c3d'`; whoever
   lands the feedback migrations later re-parents `b3c4d5e6f7a8` onto `au318a1b2c3d`.
Rule: whoever merges second owns the re-parent; devops runs prod `alembic upgrade head` only after the
chain is verified single-head (`alembic heads` = 1). Tech-lead owns this sequencing call at release time.

**(e) Phase 2 planned contract — PRE-APPROVED with two mandatory flags (no second round trip needed).**
- `GET /api/v05/mood-feedback/policy` → `{should_prompt: bool, tier: every_save|frequent|occasional|contextual}`:
  shape APPROVED. Use a DEDICATED read limiter (~60/min) per `v05_outcome.py:41` pattern — do not use
  the `get_rate_limiter` singleton (see M1).
- Zero-engine-change claim CONFIRMED: `active_signals_for_user` filters only `decay_at`, source-agnostic;
  `build_signal_vector` (engine_v05_layers.py:828-866) aggregates source-agnostic. Mood rows ride L4 as-is.
- **FLAG 1 (critical for Phase 2)**: `V05UserStyleSignal.VALID_SOURCES` (models/v05_user_style_signal.py:62)
  = `{feedback_prompt, voluntary}` and `V05StyleSignalRepository.upsert` (v05_style_signal_repository.py:71-74)
  SILENTLY SKIPS invalid sources. Writing `source='mood_feedback'` today is silently dropped. Phase 2 MUST
  add `SOURCE_MOOD_FEEDBACK = "mood_feedback"` to the model + `VALID_SOURCES` (fits String(20); no migration).
  Add a test asserting the row actually persists.
- **FLAG 2 (major for Phase 2)**: `confidence` is INERT in the engine — `build_signal_vector` applies fixed
  1.3/0.7 multipliers and never reads confidence. "Confidence 0.7" is stored metadata only; mood signals hit
  at FULL strength, identical to explicit feedback. Consequence: a "mild" `not_quite_me` dislike is not
  achievable via confidence. v1 must either write nothing for `not_quite_me` (recommended — affinity map
  already maps it to `[]`) or knowingly accept full 0.7 axis multipliers; document the choice in phase-02.
  Clamp `[0.5,1.5]` remains the real diversity guardrail.

## Findings summary

| ID | Severity | Finding | Action |
|---|---|---|---|
| M1 | major | Global-singleton rate limiter ≠ documented 20/min; cross-endpoint 429 risk on save | Dedicated `SimpleRateLimiter(20)` per `v05_outcome.py:41`; before merge |
| M2 | major | au318 migration parented on untracked migrations | Sequencing per decision (d); before merge/deploy |
| F1 | critical (Phase 2) | `VALID_SOURCES` silently drops `mood_feedback` writes | Phase 2 must extend VALID_SOURCES + persistence test |
| F2 | major (Phase 2) | Engine ignores `confidence`; mood signals full-strength | Phase 2 documents `not_quite_me` decision |
| m1 | minor | users FK no ondelete; account-deletion cleanup follow-up | File follow-up ticket |
| m2 | minor | Unindexed JSON-path upsert lookup | None now; promote `outfit_hash` to column if favorites scale |

## SIGN-OFF: YES — conditional on M1 fixed (or explicitly accepted with rationale) and M2 sequencing followed at merge time. Zero critical findings in Phase 1 code.

**Blocking issues for Phase 4 mobile consumption: NONE.** Contract is consumable as documented.
Phase 4 notes: extend `favouriteService.ts` payload with `mood_tags?: string[]`, response with
`updated: boolean`; accept both 200 and 201 (axios default does); mirror the 16-tag vocab (show ≤8 chips);
read top-level `error` on 400; always include `outfit_hash` when mood sheet is shown.
