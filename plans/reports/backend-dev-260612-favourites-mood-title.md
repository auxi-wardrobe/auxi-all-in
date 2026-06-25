# Favourites list/detail enrichment — mood_tags + title (AU-318 Love Collection card)

Worktree: `/Users/nguyenminhduc/dev/wardrobe-backend-tryon-wt` (branch `feat/tryon-openai-gpt-image-1`).
Contract change — additive only. Needs tech-lead sign-off.

## Files changed
- `routers/favorites.py` — list + detail handlers batch-fetch mood tags and enrich; added `FavoriteItem` response schema; `FavoriteListResponse.favorites` now typed.
- `models/favorite.py` — `to_dict(mood_tags=None, title=None)` + `_title()` helper.
- `blueprints/mood/mood_feedback_repository.py` — `active_mood_tags_for_hashes()` batch query.
- `blueprints/mood/mood_feedback_service.py` — `mood_tags_for_outfits()` service wrapper.
- `API_DOCUMENTATION.md` — favourites list + detail response examples and field docs.
- `tests/test_mood_feedback_service.py` — 1 repo unit test + 4 integration tests.

## Added response fields (both `GET /api/favorites` list items AND `GET /api/favorites/{id}`)
- `mood_tags: list[str]` — active (non-decayed) mood tag ids saved for the outfit via `OutfitMoodSignal`,
  keyed off `outfit_context.outfit_hash`. Raw stored vocab values, e.g. `["confident","relaxed"]`.
  `[]` when no active signal. Most-recent active row wins per `(user_id, outfit_hash)` (mirrors upsert semantics).
- `title: str | null` — **chosen source: `null` (no first-class source exists)**.
  Investigated thoroughly:
  - `FavoriteContext` schema accepts only `occasion`/`weather`/`styling_note`.
  - Recommendation `OutfitDTO` (`schemas/v05_recommendation.py`) carries only `reasoning_human` (long),
    `reasoning_debug`, `score`, `vibe_signature`, `outfit_hash` — **no outfit-level title/caption/name**.
    (`ItemDTO.name` is per-garment, not the outfit.)
  - The only `title` keys in the codebase are per-item garment titles (`services/wardrobe_service.py`,
    `blueprints/tryon/gemini_service.py`) — not outfit captions.
  Decision: return the stored `outfit_context.title`/`outfit_title` **only if a client supplied one**;
  otherwise `null`. Never synthesized, never duplicates `styling_note`/`reasoning_human`. The mobile card
  omits the title line on `null`. This leaves a forward-compatible hook if the engine later emits an
  outfit caption.

## Batch-query approach (no N+1)
List handler collects `outfit_context.outfit_hash` for the page, calls
`MoodFeedbackService.mood_tags_for_outfits` → `MoodFeedbackRepository.active_mood_tags_for_hashes`,
which runs ONE `SELECT ... WHERE user_id = ? AND outfit_hash IN (...) AND decay_at > now ORDER BY created_at ASC`
and folds into `{outfit_hash: mood_tags}` (ascending order ⇒ newest active row overwrites ⇒ wins).
Detail handler uses the same method with a single-hash list. Service-repository layering preserved
(router → service → repo); SQLAlchemy ORM only.

## Schema
- New `FavoriteItem` Pydantic model documents `mood_tags` + `title` (and existing fields). `extra="allow"`
  for forward-compat. `FavoriteListResponse.favorites: List[FavoriteItem]`.
- UK (`/api/favourites`) and US (`/api/favorites`) aliases unchanged — still both routed for list + detail.
- `POST /api/favorites` response (`Favorite.to_dict()` with defaults) now also carries `mood_tags: []`
  and the derived `title` — additive, no removals/renames.

## API_DOCUMENTATION.md diff summary
- `GET /api/favorites` response example expanded to a full favourite object incl. `mood_tags` + `title: null`;
  added field docs for both (semantics, batching note, null-title rationale).
- `GET /api/favorites/<id>` response example expanded incl. `mood_tags`/`title`; cross-referenced semantics.

## Test results
`python -c "import routers.favorites"` → clean.

Targeted run by module (favourites + mood):
`pytest tests/test_mood_feedback_service.py tests/test_mood_feedback_policy.py tests/test_mood_affinity.py -q`
→ **58 passed** (includes 5 new: 1 repo batch-map unit test, 4 integration tests for list/detail
`mood_tags` populated + empty, `title` null, and `title` surfaced from context when present).

`pytest tests/ -q -k "favorit or favourite or mood"` cannot run whole-suite collection because of a
**pre-existing** collection error in `tests/test_gemini_service.py`
(`ImportError: cannot import name 'GeminiJobManager'`) — that file and `blueprints/tryon/gemini_service.py`
are NOT in my changeset (in-flight try-on refactor on this branch).

With `--ignore=tests/test_gemini_service.py`: 68 passed, 3 failed. The 3 failures are
`tests/test_engine_v05_integration.py::{test_mood_calm_shifts_aesthetic_distribution,
test_mood_low_energy_drops_classic_pairs, test_no_mood_baseline_unchanged}` →
`sqlite3.OperationalError: no such column: wardrobe_items.image_png`. Root cause: the try-on branch added
`WardrobeItem.image_png` (`models/wardrobe.py`, not my file) without a matching test-schema migration; the
V05 engine's `_load_user_pool` selects it. **Pre-existing, unrelated to favourites/mood** — left untouched.

## Status
**Status: DONE_WITH_CONCERNS**
**Summary:** `mood_tags` (batched, no N+1) and `title` (null — no real source; surfaces a client-stored
`outfit_context.title` if present) added to favourites list + detail responses, schema + API doc + 5 tests.
All favourites/mood tests pass.
**Concerns:**
1. `title` is `null` for all engine-sourced outfits today — no outfit caption exists upstream. If the
   product wants a real title, the recommendation engine's `OutfitDTO` must emit one (separate ticket).
2. Pre-existing red on this branch unrelated to my change: `test_gemini_service.py` import error and 3
   `test_engine_v05_integration` failures (`wardrobe_items.image_png` test-schema drift). Flagging for
   whoever owns the try-on branch; did not fix (out of scope).

---

# Follow-up (2026-06-12) — P1: favourites mood enrichment graceful degradation

Worktree: `/Users/nguyenminhduc/dev/wardrobe-backend-tryon-wt` (branch `feat/tryon-openai-gpt-image-1`).

## Bug
`GET /api/favorites` (and detail) returned **500** in environments whose DB
lacks the `outfit_mood_signals` table:
`psycopg2.errors.UndefinedTable: relation "outfit_mood_signals" does not exist`.
The batched/single mood-tag lookup added for the AU-318 enrichment above could
fail and take down the whole favourites response. Optional mood data must never
500 the list.

## Fix — degrade gracefully at the service boundary
Wrapped the lookup in `MoodFeedbackService.mood_tags_for_outfits()` — the
single shared seam called from BOTH `routers/favorites.py::list_favorites`
(batched) and `get_favorite` (single). One try/except covers list + detail
without touching either route or the repository (repo stays pure SQLAlchemy).

On ANY exception it:
- calls `db.rollback()` (best-effort, itself guarded) so the caller's session
  stays usable after Postgres aborts the failed tx,
- logs ONE `logger.warning(..., exc_info=True)` (not silent),
- returns `{}` → routes default each favourite to `mood_tags: []` via the
  existing `mood_by_hash.get(outfit_hash, [])`.

Happy path (table present) unchanged — no behaviour change when the lookup
succeeds. `title` behaviour untouched. Catches broad `Exception` (covers
`SQLAlchemyError` / `UndefinedTable` / transient DB errors) per "must NEVER 500".

## Files + lines changed
- `blueprints/mood/mood_feedback_service.py:147-190` — `mood_tags_for_outfits`
  wraps `self._repo.active_mood_tags_for_hashes(...)` in try/except (rollback +
  single warning + return `{}`). Catches `Exception`.
- `tests/test_mood_feedback_service.py:630-714` — two new integration tests:
  - `test_get_favorites_list_degrades_to_empty_tags_when_mood_lookup_raises` —
    monkeypatches the repo to raise `SQLAlchemyError("relation
    \"outfit_mood_signals\" does not exist")`; asserts 200, `count==2`,
    `mood_tags == []` per favourite, other fields intact.
  - `test_get_favorite_detail_degrades_to_empty_tags_when_mood_lookup_raises` —
    same for the detail path; 200 + `mood_tags == []`.

`routers/favorites.py` NOT modified → no response-shape/contract change → no
`API_DOCUMENTATION.md` update needed.

## Verify
- `python -c "import routers.favorites"` → `IMPORT_OK` (clean).
- `python -m pytest tests/test_mood_feedback_service.py -q` →
  **27 passed, 3 warnings in 4.33s** (25 existing + 2 new). Warnings are
  pre-existing Pydantic V2 deprecations, unrelated.
- Not committed (per instruction).

## Status
**Status:** DONE
**Summary:** Mood enrichment degrades gracefully at the service boundary —
favourites list + detail return 200 with `mood_tags: []` when the
`outfit_mood_signals` lookup fails, with one logged warning; happy path and
`title` unchanged. 27/27 pass.
**Concerns:** None for this fix. (The earlier branch-level red noted above —
`test_gemini_service.py` import + `image_png` schema drift — persists and is
still out of scope.)
