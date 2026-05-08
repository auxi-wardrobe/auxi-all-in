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
