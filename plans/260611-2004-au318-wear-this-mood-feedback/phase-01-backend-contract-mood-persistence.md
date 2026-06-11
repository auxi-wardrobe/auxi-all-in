---
phase: 1
title: Backend Contract & Mood Persistence
status: completed
priority: P2
effort: 1d
dependencies: []
---

# Phase 1: Backend Contract & Mood Persistence

## Overview

Extend `POST /api/favorites` so an outfit + its mood tags save atomically. Add upsert-by-`outfit_hash`
so a re-submit on an already-saved outfit updates only the mood linkage (`updated: true`). Persist mood
in a new `OutfitMoodSignal` row via a new `MoodFeedbackService` + repository (service-repo pattern per
`wardrobe-backend/CLAUDE.md`). The favorites router stays thin — one service call, no router rewrite.
API doc update mandatory; tech-lead contract sign-off.

## Requirements

Functional:
- `POST /api/favorites` accepts optional `mood_tags: string[]` (each ∈ bounded vocab). Absent/empty → current behavior (no mood row).
- Upsert: if a favorite with same `(user_id, outfit_hash)` exists → do NOT create a duplicate favorite; update/insert mood linkage; response `{ ..., updated: true }`. New favorite → `{ ..., updated: false }`.
- One `outfit_mood_signals` row per submit, linked to favorite + outfit_hash, carrying mood_tags + a context_snapshot.
- Reject unknown mood tags (400) and `mood_tags` length > 8 (400).

Non-functional:
- ORM only, no raw SQL. `Depends(get_current_user)`. Rate limit consistent with other writes (~20/min).
- Errors `{"error","request_id"}`, no stack traces, tokens never logged.
- `decay_at` = created_at + 30 days (matches `v05_user_style_signals`), to support Phase 2 recency/decay.
- API_DOCUMENTATION.md updated; tech-lead signs off on contract change.

## Architecture

Data flow:
```
client POST /api/favorites { ..., mood_tags? }
  → routers/favorites.py (auth, rate-limit, validate mood_tags via shared vocab)
      → existing favorite upsert (find-or-create by user_id+outfit_hash)
      → if mood_tags: MoodFeedbackService.record_mood(user, favorite, outfit_hash, mood_tags, context)
          → MoodFeedbackRepository.upsert_signal(...)  # OutfitMoodSignal row
  ← { id, outfit_hash, created_at, updated: bool }
```
Bounded vocab lives in one module (`blueprints/.../mood_vocab.py` or `models/mood_vocab.py`) — single
source of truth, also referenced by Phase 2 affinity map and documented in API doc for the client. DRY.

`OutfitMoodSignal` (table `outfit_mood_signals`):
- `id` UUID PK
- `user_id` FK(users) — indexed
- `favorite_id` FK(favorites)
- `outfit_hash` str — indexed
- `mood_tags` JSON (list[str], bounded vocab)
- `context_snapshot` JSON (occasion/weather/source copied from favorite.outfit_context)
- `created_at` datetime — indexed
- `decay_at` datetime (created_at + 30d)

## Related Code Files

Create:
- `wardrobe-backend/models/outfit_mood_signal.py` — `OutfitMoodSignal` model
- `wardrobe-backend/blueprints/mood/mood_feedback_service.py` — `MoodFeedbackService`
- `wardrobe-backend/blueprints/mood/mood_feedback_repository.py` — `MoodFeedbackRepository`
- `wardrobe-backend/blueprints/mood/mood_vocab.py` — `MOOD_VOCAB` set + `is_valid_mood()` (shared w/ Phase 2)
- `wardrobe-backend/migrations/versions/<rev>_add_outfit_mood_signals.py` — Alembic migration
- `wardrobe-backend/tests/test_mood_feedback_service.py` — service/repo unit + upsert tests

Modify:
- `wardrobe-backend/routers/favorites.py` (`POST` handler, ref `routers/favorites.py:61-146`) — add `mood_tags` to `AddFavoriteRequest`, upsert-by-hash, service call, `updated` in response
- `wardrobe-backend/models/favorite.py` — confirm `outfit_context.outfit_hash` present for upsert key (no schema change expected; verify)
- `wardrobe-backend/API_DOCUMENTATION.md` (favorites section ~1113-1225) — document `mood_tags`, upsert semantics, `updated`, bounded vocab list

Delete: none.

## Implementation Steps

1. **Vocab module.** Create `mood_vocab.py`:
   ```python
   MOOD_VOCAB = {
       "feels_like_me","confident","relaxed","polished","comfortable","sharp",
       "effortless","elevated","professional","prepared","easy","attractive",
       "expressive","functional","lightweight","not_quite_me",  # soft-negative
   }
   def is_valid_mood(tag: str) -> bool: return tag in MOOD_VOCAB
   ```
2. **Model.** Create `OutfitMoodSignal` per Architecture. Mirror style of `models/v05_user_style_signal.py` (UUID PK, JSON cols, `decay_at`). Add indexes on `user_id`, `outfit_hash`, `created_at`.
3. **Migration.** New Alembic rev (copy structure from `migrations/versions/b7e3f4a8c9d2_add_v05_outcome_events.py`). `create_table('outfit_mood_signals', ...)` + the three indexes. `downgrade()` drops table + indexes.
4. **Repository.** `MoodFeedbackRepository`:
   - `upsert_signal(user_id, favorite_id, outfit_hash, mood_tags, context_snapshot)` — find latest active row by `(user_id, outfit_hash)`; if exists update `mood_tags`, `context_snapshot`, refresh `created_at`/`decay_at`; else insert. Return row.
   - `count_active_signals(user_id)` + `latest_signal_at(user_id)` — used by Phase 2 (add now, thin).
5. **Service.** `MoodFeedbackService.record_mood(user, favorite, outfit_hash, mood_tags, context)`:
   - Validate every tag via `is_valid_mood` → else `ValueError` → router returns 400.
   - Enforce `len(mood_tags) <= 8`.
   - Build `context_snapshot` from `favorite.outfit_context` (occasion, weather, source).
   - Call repo `upsert_signal`. (Phase 2 adds the `V05UserStyleSignal` derivation call here.)
6. **Router upsert.** In `POST /api/favorites` handler:
   - Add `mood_tags: list[str] | None = None` to `AddFavoriteRequest`.
   - Before insert, look up existing favorite by `(current_user.id, outfit_context.outfit_hash)`. If found → reuse it, set `updated=True`; else create as today, `updated=False`.
   - If `mood_tags`: call `MoodFeedbackService.record_mood(...)`. Wrap mood write so a mood failure does NOT silently drop the favorite — but per ticket error handling the client retries the whole call (upsert makes it idempotent), so a 5xx here is acceptable.
   - Return existing response shape + `"updated": updated`.
7. **API doc.** Document new optional field, the full bounded vocab list, max 8, upsert/`updated` semantics, the two response copy implications (client maps `updated` true→"Mood updated for this saved look.", false→"This look is now saved to your favorites.").
8. **Tech-lead sign-off.** Per umbrella CLAUDE.md two-repo contract: tech-lead reviews the `routers/favorites.py` + API_DOCUMENTATION.md diff before merge.

## Success Criteria

- [x] `POST /api/favorites` with `mood_tags:["confident"]` on a new outfit → 200, favorite created, one `outfit_mood_signals` row, `updated:false`.
- [x] Same call again (same `outfit_hash`) → 200, NO second favorite, mood row updated in place, `updated:true`. — 201 on create per tech-lead ratification
- [x] `mood_tags:["bogus"]` → 400 `{"error","request_id"}`; `mood_tags` of length 9 → 400.
- [x] Omitting `mood_tags` → unchanged legacy behavior, no mood row.
- [ ] `cd wardrobe-backend && alembic upgrade head` then `alembic downgrade -1` both clean. — blocked: local .env targets shared prod DB (followup-02); deploy-time step
- [x] `cd wardrobe-backend && pytest tests/test_mood_feedback_service.py` green. — pre-existing app.py port-5001 hardcode (baseline)
- [x] API_DOCUMENTATION.md updated; tech-lead approval recorded on PR.

## Risk Assessment

- **Duplicate saves from retries** (ticket High). Mitigation: upsert-by-`outfit_hash` makes the whole POST idempotent — client can retry safely.
- **Favorites router violates service-repo today (direct DB).** Mitigation (KISS/YAGNI): do NOT refactor the router; add mood via a service call only. Keep blast radius to the new files + one handler.
- **Vocab drift between client and server.** Mitigation: single `mood_vocab.py` is the server source of truth and the API doc is the contract; client mirrors it (Phase 3) — whoever edits one files the follow-up.
- **Atomicity** (outfit + mood "saved together"). Mitigation: same request/transaction scope; if mood write raises, return error so client shows retry rather than a half-save illusion.
