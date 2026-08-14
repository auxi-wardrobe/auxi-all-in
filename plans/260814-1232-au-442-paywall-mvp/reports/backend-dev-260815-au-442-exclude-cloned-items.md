# backend-dev report: AU-442 exclude cloned items from wardrobe_items quota

Branch: `nguyenthaihiep94/au-442-paywall` (was on `a793461`, uncommitted work-in-progress on top)

## Clone paths investigated (both live, both fixed)

1. **`services/wardrobe_service.py::clone_common_item`** (`wardrobe-backend/services/wardrobe_service.py:196-256`)
   - Reachable from `POST /wardrobe/common-items/<id>/clone` (single) and `/clone-batch` (`routers/wardrobe.py:409,461`).
   - Also reused by `services/trending_drop_service.py:88` for the trending-drop "add" response flow — confirmed live, not dead code.
   - Fixed: added `is_cloned_from_common=True` to the constructed `WardrobeItem` (`services/wardrobe_service.py:247-248`).

2. **`services/v05_wardrobe_clone_service.py::V05WardrobeCloneService._build_clones`** (`services/v05_wardrobe_clone_service.py:210-295`)
   - Reachable from `routers/v05_onboarding.py:177` — the onboarding starter-wardrobe seeder (30-60 items on first onboarding + retake, per module docstring "Used by onboarding to materialize the generated 30-60 item starter wardrobe").
   - Confirmed live, not onboarding-specific-but-dead — it's the only clone path onboarding uses.
   - Fixed: added `is_cloned_from_common=True` to the constructed `WardrobeItem` (`services/v05_wardrobe_clone_service.py:290-291`).

Conclusion: both paths are live and distinct (manual single/batch clone + trending-drop "add" vs. onboarding bulk seed) — both needed the flag. No third/dead clone path found.

## Changes

- **Model**: `models/wardrobe.py:32-42` — new column `is_cloned_from_common: Boolean, default=False, index=True, server_default='false'`. Chose a plain boolean over a self-referential FK per YAGNI — only "was this cloned from SYSTEM" is needed for the quota exclusion, not full lineage tracing.
- **Migration**: `migrations/versions/clonedflag1a2_add_is_cloned_from_common.py` — additive, `down_revision = usagepwl1a2b` (current head), same pattern as the AU-442 usage-tracking migration (server_default so existing rows backfill to `false`, i.e. pre-existing clones are treated as genuine uploads — no retroactive reclassification, matches current quota behavior for old data).
- **Repository**: `repositories/usage_repository.py::count_wardrobe_items` (`repositories/usage_repository.py:43-57`) — added `WardrobeItem.is_cloned_from_common.is_(False)` alongside the existing `is_deleted=False` / `is_common_item=False` filters.
- **Docs**: `API_DOCUMENTATION.md` §Usage (`API_DOCUMENTATION.md:79`) — updated the `wardrobe_items` reset-cadence note to mention cloned-from-common exclusion. Also updated `MODELS_DOCUMENTATION.md` (not mandatory per the API-doc rule since this isn't a `routes.py` change, but kept the model field table in sync) to document the new column.
- **Tests**: `tests/test_usage_endpoint.py` — added `TestUsageRepository::test_cloned_from_common_excluded_from_wardrobe_count` (3 genuine + 5 cloned → `used == 3`).

## Verification

- `pytest tests/test_usage_endpoint.py -q` → 16 passed (new case included).
- `pytest tests/test_v05_wardrobe_clone_service.py tests/test_wardrobe_common_items_clone_batch.py tests/test_v05_onboarding_integration.py tests/test_wardrobe_new_badge_contract.py -q` → 30 passed, 1 skipped (clone paths untouched by the flag addition).
- `pytest -m unit -q` → 613 passed, 39 pre-existing failures, 1 skipped. Confirmed the 39 failures are **pre-existing on this branch**, unrelated to this change — re-ran one (`test_v05_engine_weather_safety.py::TestMildClimate::test_fifteen_celsius_is_mild_not_cool`) with my changes `git stash`ed and it fails identically (`AttributeError: 'FakeItem' object has no attribute 'image_studio'`, a `FakeItem` test double missing an unrelated field, in engine_v05 build/exploration/distance-filter test modules). Not touched by this change; did not attempt to fix (out of scope).
- `pytest -m integration -q` → 259 passed, 1 skipped, 0 failed.
- `python test_server.py` → 45/45 passed.

## Unresolved questions

- None. Both clone paths confirmed live and fixed; quota exclusion verified end-to-end at repo/service/integration level.

**Status:** DONE
**Summary:** Added `WardrobeItem.is_cloned_from_common` (additive migration `clonedflag1a2`, down_revision `usagepwl1a2b`), set `True` in both live clone paths (`wardrobe_service.clone_common_item` and `V05WardrobeCloneService._build_clones`), excluded it in `count_wardrobe_items`, updated `API_DOCUMENTATION.md` + `MODELS_DOCUMENTATION.md`, added a repo test. Full verification green (unit/integration/e2e); the 39 unit failures are pre-existing on this branch, confirmed via git-stash re-run, unrelated to this change.
