# Phase 01 — BE Schema + Validation

## Context links

- Spec: [`spec.md`](./spec.md) §6 (Backend contract), §9 (IDOR + source guard risks)
- Reference impl (clone target): `wardrobe-backend/tests/test_v05_try_another_service.py::TestPinnedItem`
- Existing `BuildInput` field: `wardrobe-backend/services/v05_build_service.py` (already has `pinned_item_id`, not wired to schema)
- Engine ownership query: `wardrobe-backend/blueprints/recommendation/engine_v05.py:1045-1051`

## Overview

- **Priority:** P2 (blocks all FE phases)
- **Status:** pending
- **Brief:** Extend `BuildRequest` Pydantic schema with `pinned_item_id`. Add ownership + source validation in `V05BuildService.build_v05_for_user` (HTTP 410 if missing/foreign, HTTP 422 if SYSTEM common-essential). Thread value from request → `BuildInput`. Update `API_DOCUMENTATION.md`.

## Key insights

- `BuildInput` (service-layer DTO) already declares `pinned_item_id` — only schema + thread-through missing. No engine work in this phase.
- Validation MUST live in `V05BuildService`, NOT engine, to keep engine pure (spec §6 explicit).
- `try_another` already has the canonical IDOR + source guards. Clone, don't reinvent.
- HTTP 410 (Gone) maps to FE `PINNED_ITEM_GONE` event; HTTP 422 maps to inline error (FE should never trigger 422 because pin icon is hidden on `source="common_essential"` tiles — phase 05).

## Requirements

**Functional:**
- `POST /api/v05/recommendation/build` accepts `pinned_item_id: Optional[str]` in body.
- Missing wardrobe item OR owned by other user → `HTTP 410 Gone`, detail `"pinned_item_unavailable"`.
- `WardrobeItem.is_common_item == True` → `HTTP 422`, detail `"pinned_item_must_be_user_owned"`.
- Null/absent `pinned_item_id` → no behavior change (backwards compat).
- Auth missing → `HTTP 401` (existing JWT dep behavior).

**Non-functional:**
- One DB roundtrip for validation (single `WardrobeItem` query).
- Validation error responses match existing FastAPI error envelope shape.
- No engine path changes (phase 02 scope).

## Architecture

```
Client
  ↓ POST /build { ..., pinned_item_id }
routers/v05_recommendation/routes.py
  ↓ BuildRequest (schema validated)
V05BuildService.build_v05_for_user(request, user_id, db)
  ↓ NEW: _validate_pinned_item_id(pinned_item_id, user_id, db)
  │       └→ 410 if missing/foreign
  │       └→ 422 if is_common_item
  ↓ BuildInput(..., pinned_item_id=...)
engine_v05.build_outfit(...)   ← unchanged this phase
```

## Related code files

**Modify:**
- `wardrobe-backend/schemas/v05_recommendation.py` (~line 45 — `BuildRequest` class; mirror existing `Optional[str]` field style)
- `wardrobe-backend/services/v05_build_service.py` — add `_validate_pinned_item_id`; thread `request.pinned_item_id` into `BuildInput` construction
- `wardrobe-backend/API_DOCUMENTATION.md` — V05 build section ~line 3600-3650 (per spec §4.2 table)

**Create (tests):**
- `wardrobe-backend/tests/test_v05_build_service.py` — append `TestPinnedItem` class (file exists; add class)
- `wardrobe-backend/tests/test_v05_recommendation_router.py` — append router-level integration tests

**Do not touch this phase:**
- `engine_v05.py`, `engine_v05_layers.py` (phase 02)

## Implementation steps

1. **Schema delta** — add to `schemas/v05_recommendation.py` `BuildRequest`:
   ```python
   pinned_item_id: Optional[str] = Field(
       None,
       description="If set, the generated outfit must include this wardrobe item."
   )
   ```
2. **Validator method** in `V05BuildService`:
   ```python
   def _validate_pinned_item_id(self, pinned_item_id: str, user_id: str, db: Session):
       item = db.query(WardrobeItem).filter(
           WardrobeItem.id == pinned_item_id,
           WardrobeItem.owner_id == user_id,
           WardrobeItem.is_deleted == False,
       ).first()
       if not item:
           raise HTTPException(status_code=410, detail="pinned_item_unavailable")
       if item.is_common_item:
           raise HTTPException(status_code=422, detail="pinned_item_must_be_user_owned")
   ```
3. **Wire into `build_v05_for_user`** — call `_validate_pinned_item_id` if `request.pinned_item_id` is set, BEFORE constructing `BuildInput`. Pass value through.
4. **Add `low_confidence: bool = False`** to `BuildResponse` schema — declared here so phase 02 can populate (avoid touching schema twice).
5. **Tests in `test_v05_build_service.py`**:
   - `test_build_with_pinned_item_returns_outfit_containing_it` (happy path stub — engine returns the pinned id in items)
   - `test_build_with_unavailable_pinned_item_returns_410`
   - `test_build_with_pinned_item_owned_by_other_user_returns_410` (IDOR — seed item under different user_id)
   - `test_build_with_pinned_common_essential_item_returns_422` (seed `is_common_item=True`)
   - Clone fixtures from `test_v05_try_another_service.py::TestPinnedItem`
6. **Router integration test** in `test_v05_recommendation_router.py`:
   - `test_build_pinned_unauthorized_returns_401` (no JWT)
   - `test_build_pinned_happy_path_200` (real HTTP via TestClient)
7. **API_DOCUMENTATION.md** — locate V05 build section. Add request body row `pinned_item_id (string, optional)`; add response field `low_confidence (boolean)`; add error rows for 410 + 422 with detail codes.
8. **Run gate:** `cd wardrobe-backend && pytest tests/test_v05_build_service.py tests/test_v05_recommendation_router.py -v` — all green.

## Todo

- [ ] Add `pinned_item_id` field to `BuildRequest` schema
- [ ] Add `low_confidence` field to `BuildResponse` schema
- [ ] Implement `_validate_pinned_item_id` in `V05BuildService`
- [ ] Thread `pinned_item_id` from request → `BuildInput`
- [ ] Clone `TestPinnedItem` class from `test_v05_try_another_service.py`
- [ ] Add 410 + 422 + IDOR tests in `test_v05_build_service.py`
- [ ] Add router-level 401 + happy-path tests
- [ ] Update `API_DOCUMENTATION.md` V05 build section
- [ ] `pytest` green on touched files

## Success criteria

- `BuildRequest` accepts `pinned_item_id` (verified via OpenAPI schema dump).
- 410 returned for missing, deleted, or foreign-owned items.
- 422 returned for common-essential items.
- Null `pinned_item_id` produces identical response to pre-change (backwards compat).
- All new tests pass; existing `test_v05_build_service.py` suite still green.
- `API_DOCUMENTATION.md` updated.

## Risk assessment

| Risk (from spec §9) | Mitigation in this phase |
|---|---|
| IDOR — user pins foreign item | `_validate_pinned_item_id` owner check |
| User pins SYSTEM common-essential | `is_common_item == False` guard, 422 |
| Backwards compat break for clients not sending `pinned_item_id` | Field is `Optional`, default `None`; no path change when null |
| Schema drift vs `BuildInput` | `BuildInput` already has field; this phase aligns the two |

## Security considerations

- **Auth:** existing JWT dep on `/build` route — no change.
- **IDOR:** owner scope filter in single query. No info leak via timing (single round-trip returns 410 for both missing and foreign — same status, same detail).
- **DoS:** validation is one indexed query; no impact.

## Next steps

- Ships in **PR-BE** with phase 02.
- Phase 02 (engine integration) depends on this schema landing first.
- After PR-BE merges, unblocks PR-FE-core (phases 03-06).
