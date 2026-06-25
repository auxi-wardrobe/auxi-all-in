# Body-Photo Person Guard — Try-On Upload

**Date:** 2026-06-12
**Branch/worktree:** `feat/tryon-openai-gpt-image-1` @ `/Users/nguyenminhduc/dev/wardrobe-backend-tryon-wt`
**Status:** DONE

## Problem
`POST /api/body` (multipart) accepted any image — screenshots, objects, empty
rooms — as the try-on "body" photo. The image model (`gpt-image-1`) then
rendered garbage instead of erroring. Added a fast vision guard that rejects
confidently-non-person photos BEFORE S3 upload + DB write, with a
machine-readable error.

## Files changed
- **NEW** `blueprints/tryon/body_photo_validator.py` — `validate_person_photo(image: PIL.Image | bytes | path) -> dict`.
- `routers/body.py` — wired guard into multipart path (after `validate_image_file`, before `body_service.add_body_image`).
- `settings.py` — added `BODY_PHOTO_PERSON_CHECK` (bool, default `True`) + `BODY_PHOTO_CHECK_MODEL` (str, default `"gpt-4o-mini"`).
- `config.py` — same two settings for the legacy Flask-style config.
- `.env.example` — documented both env vars.
- `API_DOCUMENTATION.md` — `POST /api/body`: new 422 response, error_kind values, fail-open note, config vars.
- **NEW** `tests/test_body_photo_validator.py` — 11 tests (unit + route), OpenAI mocked.

## 422 contract implemented
On a confident-negative vision result the multipart route raises HTTP 422 with:
```json
{
  "detail": {
    "error_kind": "no_person",
    "message": "We couldn't find a clear photo of a person. Please upload a photo of yourself for the try-on.",
    "request_id": "<id>"
  }
}
```
- `error_kind` ∈ `{no_person, screenshot_or_graphic, multiple_people, too_small_or_occluded}` (mapped from the vision `issue` field; defaults to `no_person`).
- `message` is the user-facing string; `request_id` echoed from `request.state`.
- Rejected image is **not** stored (guard runs before the S3/DB service call).

## Model + fail-open behavior
- Model: `gpt-4o-mini` via `client.chat.completions.create(...)`, temperature 0.0, base64 JPEG data URL (reuses `flatten_transparent_image`, mirrors `AIService._prepare_image`). Timeout reuses `OPENAI_IMAGE_TIMEOUT_SECONDS`.
- Vision prompt asks for STRICT JSON: `{"is_person", "full_or_upper_body_visible", "issue"}`. Valid = `is_person == true AND issue == "none"`.
- **Fail-open** on ANY of: vision API error/timeout, missing `OPENAI_API_KEY`, unparseable JSON, image-decode failure, or `BODY_PHOTO_PERSON_CHECK=false` → returns `is_valid=True` (logs a warning). A transient AI outage never blocks a legit upload.
- One extra vision call on the happy path only; no other slowdown.

## Scope notes
- Guard applied to the **multipart** path only (the STOM try-on flow). The
  `application/json` `image_url` path is intentionally left as-is (would need a
  remote fetch round-trip); documented as unguarded in API_DOCUMENTATION.md.
- Service-repository pattern preserved: HTTP envelope + 422 raised in the
  router; the reusable validation logic lives in the validator module. The
  body service / repository were untouched.

## Verification
- `python -c "import routers.body, blueprints.tryon.body_photo_validator"` → OK (also settings, config).
- `python -m pytest tests/test_body_photo_validator.py tests/test_body_api_fastapi.py -q` → **11 passed**.
- Regression check: `tests/test_openai_tryon_service.py tests/test_tryon.py` → **35 passed, 2 skipped**.
- Did NOT commit (per task).

## Docs diff
`API_DOCUMENTATION.md` §`POST /api/body`: added the 422 example, `error_kind`
enum, fail-open paragraph, and `BODY_PHOTO_PERSON_CHECK` / `BODY_PHOTO_CHECK_MODEL`
config block.

## Concerns / unresolved
- One pre-existing deprecation warning: `status.HTTP_422_UNPROCESSABLE_ENTITY`
  is being renamed to `..._CONTENT` in newer Starlette. Kept the old constant
  to match the rest of the codebase's `status.HTTP_*` usage; both exist on the
  pinned version. Cosmetic only — flag for a future codebase-wide sweep.
- Worktree had ~10 unrelated pre-existing modified files (mood, favorites,
  tryon.py, requirements.txt) NOT touched by this task. Did not stage/commit anything.

**Summary:** Added a fail-open OpenAI-vision person guard to the multipart
`POST /api/body` upload that returns 422 `{error_kind, message, request_id}`
for non-person photos before storage; 11 new tests pass, no regressions.
