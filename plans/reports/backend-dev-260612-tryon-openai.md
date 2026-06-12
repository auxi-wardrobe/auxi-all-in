# Try-On: OpenAI gpt-image-1 primary + Gemini fallback

Worktree: `/Users/nguyenminhduc/dev/wardrobe-backend-tryon-wt` (branch `feat/tryon-openai-gpt-image-1`). Not committed.

## Files

Created:
- `blueprints/tryon/openai_service.py` — `OpenAITryOnService`, drop-in for `GeminiTryOnService`.
- `tests/test_openai_tryon_service.py` — 9 tests (service unit + router fallback), all mocked.

Modified:
- `routers/tryon.py` — `_execute_highres_service` now does provider selection + fallback; added `_run_provider`; `provider` field added to success response.
- `settings.py` / `config.py` — `TRYON_IMAGE_PROVIDER`, `OPENAI_IMAGE_MODEL`, `OPENAI_IMAGE_TIMEOUT_SECONDS`.
- `.env.example` — new OpenAI vars with comments.
- `requirements.txt` — `openai>=1.40`.
- `API_DOCUMENTATION.md` — try-on section: provider selection, env vars, `provider` response field.

## OpenAI call signature used

```python
client = OpenAI(api_key=settings.OPENAI_API_KEY, timeout=settings.OPENAI_IMAGE_TIMEOUT_SECONDS)
result = client.images.edit(
    model=settings.OPENAI_IMAGE_MODEL,   # "gpt-image-1"
    image=[(filename, BytesIO_png, "image/png"), ...],  # body first, then garments
    prompt=<built prompt>,
    size="1024x1536",
    n=1,
)
b64 = result.data[0].b64_json
```

Images normalized via `flatten_transparent_image` (reused) → PNG bytes → `(filename, BytesIO, mime)` tuples so the SDK can infer mime per file.

### SDK caveat
- Installed SDK is `openai==2.7.1` (well above `>=1.40`). Verified by introspection: `images.edit` accepts a **Sequence** of file-likes for `image` (multi-image edit), `size` literal includes `'1024x1536'`, and params `quality`/`background`/`input_fidelity`/`response_format` exist. For gpt-image-1, `b64_json` is returned by default (no `response_format` needed).
- context7/docs-seeker had no OpenAI entry; confirmed the contract directly against the installed SDK type hints instead.

## Config defaults
`TRYON_IMAGE_PROVIDER=openai`, `OPENAI_IMAGE_MODEL=gpt-image-1`, `OPENAI_IMAGE_TIMEOUT_SECONDS=120`.

## Fallback behavior
Router reads `TRYON_IMAGE_PROVIDER`. If `openai`: call OpenAI; on raise OR `success=False`, log a warning and fall back to Gemini. `provider` ("openai"|"gemini") added to both the result dict and the formatted success response. Ownership/consent/rate-limit/cleanup logic unchanged. `gemini_opt_in` field name kept for mobile compat.

## Tests
```
tests/test_openai_tryon_service.py ......... 9 passed
```
Covers: success parses `b64_json`→`composite_png`; exception→`success=False`; empty response→`success=False`; missing key→`success=False`; prompt includes `body_shape`; singleton; router uses openai on success; router falls back to gemini on `success=False`; router falls back when openai raises.

Broader `-k "tryon or try_on"` run: **35 passed, 2 skipped** after excluding 2 PRE-EXISTING baseline failures (NOT caused by my changes, verified by stashing my edits):
- `tests/test_gemini_service.py` — collection ImportError: imports `GeminiJobManager`, which does not exist in current `gemini_service.py`.
- `tests/test_multi_garment_logic.py::test_generate_tryon_sync_multi` — patches `gemini_service.current_app`, but that module imports `current_app` lazily inside a function (no module attr).

`python test_server.py` NOT run: it boots a live server on :5002 and hits real endpoints (needs DB + live provider keys for the try-on path). Out of scope for a keyless session.

## Unresolved
- The pre-existing `test_gemini_service.py` / `test_multi_garment_logic.py` failures predate this work — flag to tech-lead/PM; not fixed here (out of scope, untouched files).
