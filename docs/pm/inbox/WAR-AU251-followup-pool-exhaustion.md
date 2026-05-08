# AU-251 follow-up: PoolExhaustedError on happy-path Remix /next

**Surfaced by:** Wave 4 / Task 4.3 integration tests
**Status:** 3 happy-path tests xfailed in `tests/test_v05_recommendation_next.py`
**Branch first observed:** `feat/au-251-remix-next`

## Symptom
POST `/api/v05/recommendation/next` (no force_axis or `force_variation_axis="COLOR"`)
returns 422 with detail `"No more options to vary along axis 'unknown'..."` even when
the seeded wardrobe has multiple valid candidates per axis (3 L2 items in 3 distinct
colors, plus L1/L3/SHOES variants).

## Diagnosis so far
- The 422 is `PoolExhaustedError` bubbling from one of the axis swap handlers
  in `blueprints/recommendation/engine_v05_variation.py`.
- Root cause unconfirmed. Two candidates per the prior debug agent:
  1. `_pre_filter_for_anchor_v05` over-filters the pool before the swap handler runs.
  2. Session init populates `seen_item_ids` with the entire initial outfit, so
     every alternative is excluded by `excluded_ids = seen | rejected` on the very
     first /next call.
- The "axis 'unknown'" string is a separate (smaller) bug: `PoolExhaustedError`
  has no `.axis` attribute, so the router falls back to "unknown".

## Wave 5 work
1. Fix `PoolExhaustedError` to carry `axis` (constructor arg).
2. Reproduce the over-filter / seen-id-poisoning issue with the integration test.
3. Patch the engine.
4. Remove `@pytest.mark.xfail(strict=True)` from the 3 tests — they should go green.

## Refs
- AU-251 (parent ticket)
- Test file: `wardrobe-backend/tests/test_v05_recommendation_next.py`
- Engine: `wardrobe-backend/blueprints/recommendation/engine_v05_variation.py`
- Router: `wardrobe-backend/routers/v05_recommendation.py:307fd93`

## Resolution

**Resolved by Wave 5 (2026-05-08).**

### Which hypothesis was correct

**Hypothesis 1 (pre-filter over-filters) was partially correct**, but the full story involves three bugs:

1. **warmth_level misread** (`_pre_filter_for_anchor_v05` in `engine_v05_layers.py`):
   The climate warmth gate read `warmth_level` exclusively from `styling_metadata`, but the
   test fixture stores it in `physical_attributes`. The result: all L2 items got the default
   sentinel value of 3, which is outside the MILD allowed set [1, 2], so the entire L2 pool
   was silently rejected. Fix: read from `physical_attributes` first, fall back to
   `styling_metadata`.

2. **Slot reconstruction added spurious L3 slot** (`silhouette_swap`, `color_swap`,
   `_try_swap_layer` in `engine_v05_variation.py`):
   Once warmth was fixed, the handlers raised `SingleLayerSwapViolation` (500) instead.
   Handlers always emitted all 4 slots (BT, L2, L3, SH) using `current_map.get("L3", "")`
   even when the 3-item test outfit had no L3. The invariant check saw `None → ""` on the
   L3 slot and counted 2 changed slots instead of 1. Fix: omit optional slots (L3) from
   the new outfit when absent from the current outfit.

3. **ItemDTO missing layer_code** (`schemas/v05_recommendation_next.py`,
   `services/recommendation_service.py`):
   The test's two-call cycle test computed `outfit_hash_1` from the first /next response,
   but `ItemDTO` had no `layer_code` field. `_stable_outfit_hash()` silently used `""` for
   all layer codes, producing a hash that differed from what the server stored, causing the
   second call to fail with 422 OutfitDrift. Fix: add `layer_code` to `ItemDTO` and forward
   it from the outfit entry in `_build_item_dto`.

### Commit hashes

- `8102f49` — Bug A: `PoolExhaustedError` carries `axis` name
- `fdc589b` — Bug B: three-part engine fix (warmth dual-read, slot reconstruction, ItemDTO layer_code)
- `c113353` — test: remove `xfail` from 3 happy-path tests

### Test result

All 5 integration tests in `tests/test_v05_recommendation_next.py` now green.
`xfail` markers removed from `test_next_force_color_axis_changes_l2`,
`test_next_cycles_through_axes`, and `test_next_anchor_unchanged_across_cycle`.
