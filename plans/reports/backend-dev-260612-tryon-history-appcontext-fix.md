# Try-On History App-Context Fix (Flask → FastAPI)

**Date:** 2026-06-12
**Worktree:** `/Users/nguyenminhduc/dev/wardrobe-backend-tryon-wt` (branch `feat/tryon-openai-gpt-image-1`)
**Bug:** `POST /api/tryon/highres` returned 500 after a *successful* OpenAI render because the post-generation history save used Flask-SQLAlchemy `TryOnImage.query` / `db.session` under FastAPI (no Flask app context).

## Root cause
`repositories/tryon_repository.py` used Flask-style `Model.query` and the global `db.session` (from `extensions import db`). Under FastAPI these need a Flask app context that doesn't exist, so `.query` raised `Working outside of application context.` The image was already generated + uploaded to R2/S3; only persistence failed, but it bubbled up as a 500 and the user got no preview.

## Fix — Part 1: use the injected Session, not `Model.query`

Refactored to the canonical `BodyRepository` pattern (constructor takes `db: Session`, uses `self.db.query(...)`).

### Files + methods changed

**`repositories/tryon_repository.py`** — rewritten to take `db: Session` in `__init__`; dropped `from extensions import db`.
- `__init__(self, db: Session)` — new; stores `self.db`.
- `create_image(...)` — `db.session.add/commit/rollback` → `self.db.add/commit/refresh/rollback`.
- `get_images_by_user(...)` — `TryOnImage.query.filter_by(...)` → `self.db.query(TryOnImage).filter_by(...)`.
- `get_image_by_job_id(...)` — `TryOnImage.query.filter_by(...)` → `self.db.query(TryOnImage).filter_by(...)`.

**`services/tryon_history_service.py`** — threads `db: Session` per-call; repo is now constructed per-call with the session (removed the cached `self.tryon_repo`).
- `save_tryon_result(self, db, user_id, job_id, image_url, processing_time_ms=None)` — added `db`; builds `TryOnRepository(db)`.
- `get_user_tryon_history(self, db, user_id)` — added `db`; `TryOnRepository(db).get_images_by_user(...)`.
- `get_tryon_result_by_job(self, db, job_id)` — added `db`; `TryOnRepository(db).get_image_by_job_id(...)`.

**`routers/tryon.py`**
- `_format_success_response(result, options, folder, user_id, db: Session)` — added `db` param; passes `db` (and `processing_time_ms`) into `history_service.save_tryon_result(...)`.
- `highres_tryon` (~line 322) — call site now passes `db` (already in scope via `Depends(get_db)`).

### Flask `.query` / `db.session` usages found + fixed in the tryon path
Grepped `routers/`, `services/`, `repositories/` for `.query` / `db.session`. All Flask-style usages were confined to `repositories/tryon_repository.py`:
1. `repositories/tryon_repository.py:25` `db.session.add(image)` → `self.db.add(image)` (`create_image`)
2. `repositories/tryon_repository.py:29` `db.session.rollback()` → `self.db.rollback()` (`create_image`)
3. `repositories/tryon_repository.py:37` `TryOnImage.query.filter_by(user_id=...)` → `self.db.query(TryOnImage).filter_by(...)` (`get_images_by_user`)
4. `repositories/tryon_repository.py:43` `TryOnImage.query.filter_by(job_id=...)` → `self.db.query(TryOnImage).filter_by(...)` (`get_image_by_job_id`)

The two latent siblings (`get_images_by_user`, `get_image_by_job_id`) had the same crash and are fixed even though their endpoints (`GET /tryon/images`, `/tryon/result/<job_id>`) aren't yet wired in the FastAPI router. All other `.query` hits in those dirs already use injected-session repos/routers (e.g. `BodyRepository`, `WardrobeRepository`, admin/auth routers) — no Flask app-context usage anywhere else.

## Fix — Part 2: non-fatal history save (safety net)
In `routers/tryon.py` `_format_success_response`, the `history_service.save_tryon_result(...)` call is wrapped in try/except: on ANY exception, `logger.warning(..., exc_info=True)` and CONTINUE. The endpoint still returns 200 with `composite_url` / `composite_key` / `provider` / `processing_time_ms` / `message`. A successful render can never 500 because persistence hiccupped.

## Constraints honored
- Success response shape unchanged (`composite_url`, `composite_key`, `processing_time_ms`, `provider`, `message`) → **no `API_DOCUMENTATION.md` change needed** (pure internal data-access fix, no route/payload/response change).
- Ownership / consent (`gemini_opt_in`) / rate-limit / temp-file cleanup (`finally`) all untouched.
- SQLAlchemy ORM only; no raw SQL.

## Verification
- `python -c "import routers.tryon, repositories.tryon_repository, services.tryon_history_service"` → `imports OK`.
- `python -m pytest tests/test_openai_tryon_service.py tests/test_tryon.py -q` → **38 passed, 2 skipped** (the 2 skips are pre-existing mediapipe/full-pipeline skips in `test_tryon.py`; not related to this change).

### Tests added (`tests/test_openai_tryon_service.py`)
- `test_success_response_survives_history_save_failure` — mocks `save_tryon_result` to raise `Working outside of application context.`; asserts `_format_success_response` still returns `composite_url`/`composite_key`/`provider`/`processing_time_ms` (no exception). This is the exact regression.
- `test_success_response_threads_db_into_history_save` — asserts the injected session + `user_id` + uploaded `image_url` are threaded into `save_tryon_result`.
- `test_repository_uses_session_not_flask_query` — fakes a `Session`, asserts `TryOnRepository` routes through `session.query(TryOnImage)` (not `TryOnImage.query`).

## Not done / out of scope
- `python test_server.py` (full e2e on :5002) not run here — parent owns the :5001 restart + 4× sim loop. Live HTTP path not exercised in this session.
- Did NOT commit (per instructions).

## Unresolved questions
- `GET /tryon/images` / `GET /tryon/result/<job_id>` are documented in CLAUDE.md but not wired into this FastAPI `routers/tryon.py`. The history-service getters are fixed and ready, but if/when those routes are added they must pass `db` (now required). Flagging for whoever wires them.

**Status:** DONE
**Summary:** Threaded the injected SQLAlchemy `Session` through `TryOnHistoryService` → `TryOnRepository` (replacing all 4 Flask `.query`/`db.session` usages), and made the highres history save non-fatal so a successful render returns 200 even if persistence fails. 38 passed / 2 pre-existing skips; 3 regression tests added.
**Concerns:** None on correctness. Full e2e (`test_server.py`) + sim loop pending on parent.
