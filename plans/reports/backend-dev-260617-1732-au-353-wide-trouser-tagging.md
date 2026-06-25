# AU-353 — [bug] Wide trouser tagged REGULAR instead of OVERSIZE

**Agent:** backend-dev · **Date:** 2026-06-17 · **Scope:** wardrobe-backend/ only

## Reporter (Viet / CEO)
> When I add a wide or a baggy jeans, our auto tagging system tags them as REGULAR FIT. It should be OVERSIZE FIT.

## Root cause
The user-facing auto-tagging pipeline runs through `AIService` (OpenAI gpt-4o vision):

`routers/wardrobe.py:390` → `AIService.create_and_enhance_item` → `enhance_item_with_ai` → `generate_ai_metadata` → prompt from `AIService._build_prompt()` (`services/ai_service.py`).

The prompt declared the fit field as a bare enum with **no definitions and no examples**:

```
"fit_code": "<SLM|REG|OVS|TLR...>"
```

With zero semantics for what each code means, gpt-4o defaulted wide/baggy bottoms to `REG` (the "neutral" middle value). The model was never told that baggy/wide/loose/relaxed cuts map to `OVS`. Note the sibling **admin/common-items** batch tagger (`commonItems/gemini_tagger.py:160`) already had the inline definition `# ... OVS=oversized/boxy`, but that guidance never existed on the per-user upload path in `ai_service.py`. So the bug was specific to the user auto-tagging path.

The downstream enum/mapping was fine — `OVS` exists and is reachable (`_generate_human_readable_id` reads `fit_code`, default `REG` at `services/ai_service.py:219`). The classification *input* (the prompt) was the only defect. No enum value was missing.

## Fix
File: `services/ai_service.py`, method `_build_prompt()`.

1. Tightened the JSON-schema fit line from `"<SLM|REG|OVS|TLR...>"` to the closed set `"<SLM|REG|OVS|TLR>"` (removes the `...` that invited drift).
2. Added an explicit **Fit code** definitions block before the `Rules:` line, mirroring the proven `gemini_tagger.py` wording and adding hard guidance for the reported case:
   - `SLM = slim / fitted / skinny`
   - `REG = regular / standard straight cut`
   - `OVS = oversized / baggy / wide / loose / relaxed` — and: *"Wide-leg, baggy, loose, relaxed, slouchy, balloon, or boyfriend bottoms (jeans/trousers) are ALWAYS OVS, never REG."*
   - `TLR = tailored / structured`
   - Closing nudge: *"When the garment reads as wide or baggy, prefer OVS over REG."*

Change is minimal, aligned with the existing prompt style and the existing common-items tagger vocabulary. No new enum, no mapping/post-processing change.

## Files changed (path:line)
- `services/ai_service.py:70` — fit_code enum tightened (`...` removed).
- `services/ai_service.py:82` (now `:82–90`) — new Fit code definitions + baggy/wide→OVS rule inserted before `Rules:`.
- `tests/test_ai_service_fit_prompt.py` — NEW. 5 unit tests asserting the prompt carries the OVS definition, the "ALWAYS OVS, never REG" rule, the "prefer OVS over REG" nudge, the valid 4-code enum, and all four definitions. Regression guard for AU-353.

## Tests
```
python -m pytest tests/test_ai_service_fit_prompt.py -v
5 passed in 0.85s
```
All 5 new unit tests pass. `python -c ast.parse` compile-check clean. Adjacent unit suite (`test_admin_metadata_normalization.py`) still green.

A live semantic test (feed a real baggy-jeans image, assert `fit_code == OVS`) requires the OpenAI API and is non-deterministic — out of scope for unit testing. The prompt-content tests are the practical regression guard; behavioural validation is best done by Viet re-uploading the original wide jeans against a deployed build.

## API_DOCUMENTATION.md
**No update needed.** This is a pure LLM-prompt/classification-logic change. No route, request, or response shape changed in `routers/**`. The `fit_code` field and its enum were already documented; the closed-set values (`SLM|REG|OVS|TLR`) are unchanged. Confirmed no `routers/` files touched.

## Concerns (NOT my changes — pre-existing junk-drawer state)
The working tree of this submodule was already dirty (~130 modified files) on branch `feature/au318-mood-feedback`, per the known stale-checkout warning in project memory. `services/ai_service.py` itself carried **pre-existing uncommitted edits I did not make**:
- `enhance_item_with_ai` was changed from `ThreadPoolExecutor` to `asyncio.gather(...)` **without `await`** and unpacks the coroutine/gather object as a tuple (`metadata, image_png = results`). This looks like a latent runtime bug, but it is NOT mine and is outside AU-353 scope — flagging only.
- `_update_item_with_metadata` had its `if metadata:` null-guards removed (also pre-existing).

My AU-353 change is cleanly isolated to the two prompt hunks. If this file is committed, the pre-existing async edits should be reviewed/reverted separately — do not let them ride on the AU-353 fix.

---
**Status:** DONE
**Summary:** Fixed AU-353 by adding explicit fit-code definitions to the user auto-tagging prompt in `services/ai_service.py::_build_prompt()` — baggy/wide/loose/relaxed bottoms now map to OVS instead of defaulting to REG. Added 5 regression unit tests (all pass). No API contract change, so no API_DOCUMENTATION.md update.
**Files changed:** `services/ai_service.py` (prompt), `tests/test_ai_service_fit_prompt.py` (new tests).
**Concerns/Blockers:** Submodule working tree is the known stale junk-drawer checkout (~130 dirty files); `services/ai_service.py` carried pre-existing non-AU-353 async edits (`asyncio.gather` without `await`) that I did not touch and that look buggy — must be reviewed/reverted separately, not committed as part of this fix.
