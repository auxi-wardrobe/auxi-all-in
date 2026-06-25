# Phase 02 — BE Engine Integration + Fallback

## Context links

- Spec: [`spec.md`](./spec.md) §4.2 (touched files), §6 (engine integration + fallback)
- Engine entry: `wardrobe-backend/blueprints/recommendation/engine_v05.py:1045` (`_load_user_pool`)
- L1/L2 ranking layers: `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py`
- Existing `pinned_item_id` field consumer in `try_another` path — reference for L1/L2 patterns

## Overview

- **Priority:** P2 (blocks FE generation flow)
- **Status:** pending
- **Brief:** Wire `BuildInput.pinned_item_id` into engine pipeline. L1 filters candidate pool to outfits containing pinned id; L2 ranking enforces presence. Implement fallback: if filtered pool < 3 candidates → relax axis/distance floor, retry, set `low_confidence=True` in response.

## Key insights

- `BuildInput` already declares the field — pipeline just ignores it. Threading work is mechanical.
- L1 is the dominant cost — filtering after candidate gather avoids re-querying DB.
- "Relax" means dropping axis-distance floor (not lowering quality bar across the board). Single retry, no recursion.
- L2 assertion is a defense-in-depth log; if L1 did its job, L2 always sees pinned id present.
- Engine stays pure — no DB lookups, no HTTP error raising. Validation (phase 01) caught bad ids upstream.

## Requirements

**Functional:**
- When `pinned_item_id` set, top-1 outfit MUST contain it.
- When post-filter pool ≥ 3 candidates → normal ranking, `low_confidence=False`.
- When post-filter pool < 3 candidates → relax axis floor, retry candidate gather, `low_confidence=True`.
- When even after relax there's no candidate containing pinned id → engine emits single-outfit best-effort containing pinned + remix slots, `low_confidence=True`.
- Response items unique (no duplicate slots).

**Non-functional:**
- Single relax retry (no unbounded loop).
- Threshold `3` exposed as module constant (tunable per spec §13 open item).
- No DB queries from engine layers (validation upstream).
- p95 latency delta ≤ 100ms vs non-pinned build.

## Architecture

```
V05BuildService.build_v05_for_user
  ↓ BuildInput(..., pinned_item_id="abc123")
engine_v05.build_outfit(input)
  ↓ _load_user_pool(user_id)              [unchanged]
  ↓ candidates = layers.L1_gather(...)
  ↓ if pinned_item_id:
  │     filtered = [c for c in candidates if pinned_item_id in c.item_ids]
  │     if len(filtered) < LOW_POOL_THRESHOLD:
  │         candidates = L1_gather(..., relaxed=True)
  │         filtered = [c for c in candidates if pinned_item_id in c.item_ids]
  │         low_confidence = True
  │     candidates = filtered or [best_effort_outfit(pinned_item_id)]
  ↓ top = layers.L2_rank(candidates)
  ↓ assert pinned_item_id in top.item_ids   [warn-log only, no raise]
  ↓ return BuildOutput(outfit=top, low_confidence=low_confidence)
```

## Related code files

**Modify:**
- `wardrobe-backend/blueprints/recommendation/engine_v05.py` — `build_outfit` path; consume `BuildInput.pinned_item_id`; apply filter + fallback; emit `low_confidence` in output.
- `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py` — L1 `gather` accepts `relaxed: bool = False` to drop axis floor; L2 ranking adds presence assertion (warn log).
- `wardrobe-backend/services/v05_build_service.py` — map engine output `low_confidence` → `BuildResponse.low_confidence`.

**Modify (tests):**
- `wardrobe-backend/tests/test_v05_build_service.py::TestPinnedItem` — add:
  - `test_build_with_pinned_item_low_pool_sets_low_confidence`
  - `test_build_pinned_no_duplicate_items`
  - `test_build_pinned_item_in_top_outfit`

**Do not touch:**
- `schemas/v05_recommendation.py` — `low_confidence` already added in phase 01.

## Implementation steps

1. **Constant** in `engine_v05_layers.py`:
   ```python
   LOW_POOL_THRESHOLD = 3  # spec §13: tune with real wardrobe data
   ```
2. **L1 relax param** — extend gather signature with `relaxed: bool = False`. When True, drop axis-distance floor (use min `0.0` instead of configured min).
3. **build_outfit pipeline** — in `engine_v05.py:build_outfit`:
   - After existing candidate gather, check `input.pinned_item_id`.
   - If set: filter candidates by `pinned_item_id in candidate.item_ids`.
   - If `len(filtered) < LOW_POOL_THRESHOLD`: re-gather with `relaxed=True`, re-filter, set local `low_confidence=True`.
   - If still empty: synthesize single best-effort outfit (pinned item + nearest neighbors from full pool), `low_confidence=True`.
   - Pass filtered candidates to L2.
4. **L2 assertion** — in `engine_v05_layers.py` ranking layer, after top selection:
   ```python
   if pinned_item_id and pinned_item_id not in top.item_ids:
       logger.warning("pinned_item_id missing from top outfit", extra={"pinned_item_id": pinned_item_id, "user_id": user_id})
       # do not raise — engine pure; FE check is belt-and-suspenders
   ```
5. **Output threading** — `BuildOutput` (service-layer DTO) carries `low_confidence`; `V05BuildService` maps to `BuildResponse.low_confidence`.
6. **Tests** — append to `TestPinnedItem`:
   - **Happy path** — seed wardrobe with 10+ items, pin one, assert response outfit contains pinned id, `low_confidence=False`.
   - **Low pool** — seed wardrobe with only 2 compatible items, pin one, assert response 200 + `low_confidence=True` + outfit contains pinned id.
   - **No duplicates** — assert `len(set(outfit.item_ids)) == len(outfit.item_ids)`.
   - **L2 enforcement** — directly invoke ranking, assert assertion fires (capture log via `caplog`).
7. **Run gate:** `cd wardrobe-backend && pytest tests/test_v05_build_service.py tests/test_v05_recommendation_router.py -v` — all green; `python test_server.py` e2e green.

## Todo

- [ ] Add `LOW_POOL_THRESHOLD` constant in `engine_v05_layers.py`
- [ ] Extend L1 gather with `relaxed` param (drop axis floor)
- [ ] Wire `pinned_item_id` filter + fallback in `engine_v05.build_outfit`
- [ ] Synthesize best-effort outfit when post-relax pool empty
- [ ] Add L2 presence warn-log assertion
- [ ] Thread `low_confidence` through `BuildOutput` → `BuildResponse`
- [ ] Add `test_build_with_pinned_item_low_pool_sets_low_confidence`
- [ ] Add `test_build_pinned_no_duplicate_items`
- [ ] Add `test_build_pinned_item_in_top_outfit`
- [ ] `pytest` + `python test_server.py` green

## Success criteria

- Top-1 outfit deterministically contains `pinned_item_id` when set.
- `low_confidence=True` when post-filter pool < 3.
- No duplicate item ids in response outfit.
- Existing non-pinned `/build` requests unaffected (regression test passes).
- p95 latency delta ≤ 100ms (measured locally via `test_server.py` instrumentation).

## Risk assessment

| Risk (from spec §9) | Mitigation |
|---|---|
| Pinned item accidentally replaced during ranking | L1 filter + L2 warn-log assertion |
| Loading infinite — engine recursion in fallback | Single relax retry, no recursion |
| Backend duplicate items in response | `test_build_pinned_no_duplicate_items` regression gate |
| Grid position shifts | Engine preserves `slotIndex` of pinned item in output (existing contract — verify in test) |
| Low pool threshold wrong for real data | Constant exposed; spec §13 flags as tunable post-MVP |

## Security considerations

- No new DB queries from engine layer (validation in phase 01).
- No PII in warn log — only `pinned_item_id` (already in request).
- No auth surface change.

## Next steps

- Ships in **PR-BE** with phase 01.
- Branch: `duc2820/au-307-be-pin-build`.
- Merging PR-BE unblocks PR-FE-core (phases 03-06).
- Open item (spec §13): tune `LOW_POOL_THRESHOLD` after observing real wardrobe data distribution.
