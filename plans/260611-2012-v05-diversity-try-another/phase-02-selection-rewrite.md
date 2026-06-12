---
phase: 2
title: Selection Rewrite
status: completed
priority: P1
effort: 1d
dependencies:
  - 1
---

# Phase 2: Selection Rewrite

## Overview
Replace axis cycling + axis scoring in `V05TryAnotherService` with the
distance-floor + MMR-style scoring from Phase 1. Add `seen_signatures` to the Redis
session so diversity is measured against ALL served outfits, surviving pool FIFO eviction.

## Requirements
- Functional: cache-hit path serves the candidate maximizing
  `1.0·min_dist_to_seen + 0.3·engine_score + 0.5·style_feedback_fit` among candidates with
  `min_dist_to_seen ≥ V05_MIN_DISTANCE` (env, default 0.35). `req.axis` ignored (warn-log
  once per request). `pinned_item_id` filter unchanged, applied before the floor.
- Non-functional: backward-compatible with existing Redis sessions (missing
  `seen_signatures` → derive from `primary` + `pool` on first access); no change to lock /
  IDOR / StaleHash semantics.

## Architecture
```
state (Redis v05_try_another:{sid}) += "seen_signatures": [
  {"outfit_hash": "ab12…", "item_ids": ["i1","i2"], "silhouette": "BOXY",
   "color_family": "earth", "layer_count": 1}, …
]
```
- `V05SessionCache.create()` seeds signatures for **all** `/build` outfits (the 3-card set
  is all visible to the user), while `seen` hash-list semantics stay unchanged (avoid
  StaleHash behavior change — only `primary` hash stays in `seen` at build).
- `append_seen(sid, hash)` → `append_seen(sid, outfit)` (or new `append_signature`)
  so every serve records both hash and signature. Cap list at `V05_MAX_SEEN_SIGNATURES`
  (default 30) — distance vs a 30-deep window is plenty and bounds the Redis value.

`_select_from_pool` rewrite:
1. drop seen hashes + current (unchanged)
2. pinned filter (unchanged)
3. floor: `min_distance_to_seen(o, seen_signatures) ≥ V05_MIN_DISTANCE`
4. empty → return None (recompose path, Phase 3)
5. else max by `1.0·min_dist + 0.3·score + 0.5·style_feedback_fit`

Delete: `_AXIS_CYCLE`, `_pick_axis`, hard axis filter, `axis_diff` import. Keep
`_collect_anchor_excludes` (F2-tune) — complements diversity on the recompose path.
`variation_axis` in responses → `None` (schema change lands Phase 4; service sets None now
behind the schema's Optional type).

## Related Code Files
- Modify: `wardrobe-backend/services/v05_try_another_service.py` (lines ~105-115 cycle,
  ~186-187 axis pick, ~344-393 `_select_from_pool`)
- Modify: `wardrobe-backend/utils/v05_session_cache.py` (create/append + signature cap)
- Modify: `wardrobe-backend/services/v05_build_service.py` (seed signatures at create)
- Modify: `wardrobe-backend/config.py` (V05_MIN_DISTANCE, V05_MAX_SEEN_SIGNATURES)
- Delete (if dead after refactor): `wardrobe-backend/services/v05_axis_scoring.py` —
  grep consumers first
- Modify: `wardrobe-backend/tests/test_v05_try_another*.py` (axis tests → distance tests)

## Implementation Steps
1. Session cache: add `seen_signatures` (create + append + legacy-derive fallback + cap).
2. Service: delete axis cycle/pick; rewrite `_select_from_pool` per architecture; thread
   `seen_signatures` from state; set `variation_axis=None` in all response constructions.
3. `req.axis` deprecation: if non-null, `logger.info("axis param deprecated, ignored")`.
4. Tests:
   - serves candidate above floor with max composite score
   - candidate identical-but-shoes to ANY seen outfit is never served (floor)
   - legacy session without `seen_signatures` → derives, no 500
   - pinned filter still wins before floor; floor-empty → None (recompose trigger)
   - explicit `req.axis` value changes nothing
5. `pytest -m unit && pytest tests/test_v05_try_another*.py` green.

## Success Criteria
- [ ] No reference to `_AXIS_CYCLE` / `_pick_axis` / `axis_diff` left in services/
- [ ] A→B→A-like oscillation impossible: candidate near-identical to any seen outfit rejected
- [ ] Legacy-session fallback test green (no Redis migration needed)
- [ ] `python test_server.py` e2e green

## Risk Assessment
- Floor empties pool more often than axis filter did → expected; recompose (Phase 3) is the
  designed escape, graduated relaxation guards exhaustion.
- Redis value growth → signature cap 30 ≈ a few KB; TTL 1h unchanged.
