---
phase: 1
title: Distance Metric
status: completed
priority: P1
effort: 0.5d
dependencies: []
---

# Phase 1: Distance Metric

## Overview
New pure leaf module `outfit_distance` + `min_distance_to_seen` — the composite
similarity metric that replaces per-axis `axis_diff`. No behavior change yet
(nothing calls it until Phase 2).

## Requirements
- Functional: `outfit_distance(a, b) -> float` in [0,1]; symmetric; 0.0 for identical
  item sets; works on the cached outfit dict shape AND on the compact signature shape
  (`{outfit_hash, item_ids, silhouette, color_family, layer_count}`).
- Non-functional: pure dicts, no engine/services imports (same leaf constraint as
  `engine_v05_axis.py`); O(len(seen)) per candidate, negligible vs LLM latency.

## Architecture
```
outfit_distance(a, b) =
    0.50 * (1 - jaccard(item_ids(a), item_ids(b)))
  + 0.15 * (silhouette(a) != silhouette(b))
  + 0.15 * (color_family(a) != color_family(b))
  + 0.10 * (layer_count(a) != layer_count(b))
  + 0.10 * (footwear_ids(a) != footwear_ids(b))

min_distance_to_seen(candidate, seen_signatures) = min(outfit_distance(candidate, s) for s in seen) or 1.0 when seen empty
to_signature(outfit_dict) -> compact signature dict (for Redis seen_signatures)
```
Weights as module constants overridable by env (`V05_DIST_W_JACCARD`, … — read once at
import like other v05 config). Comparators (`_silhouette`, `_color_family`,
`_layer_count`, `_ids_by_family`) extracted/shared from
`blueprints/recommendation/engine_v05_axis.py` — do NOT duplicate them.

## Related Code Files
- Create: `wardrobe-backend/blueprints/recommendation/engine_v05_distance.py`
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05_axis.py` (export helpers
  for reuse; keep `axis_diff` intact until Phase 3 removes its callers)
- Create: `wardrobe-backend/tests/test_v05_distance_unit.py`

## Implementation Steps
1. Branch: `cd wardrobe-backend && git checkout -b feature/v05-diversity-try-another`.
2. Implement `engine_v05_distance.py` with `outfit_distance`, `min_distance_to_seen`,
   `to_signature`, env-overridable weights, defensive handling of missing
   `vibe_signature`/empty items (treat missing field as "differs" only when the other
   side has a value; identical-empty → 0 contribution).
3. Accept both shapes: full outfit dict (`items: [{id, category_family}]`) and compact
   signature (`item_ids: [str]`) — normalize internally.
4. Unit tests (`pytest -m unit`):
   - identical outfit → 0.0; fully disjoint → 1.0
   - shoes-only swap on a 4-item outfit → ≈0.30 (< 0.35 floor)
   - top swap with silhouette+color shift → ≥0.5
   - signature-shape vs dict-shape give equal results
   - empty seen list → min_distance 1.0

## Success Criteria
- [ ] `pytest tests/test_v05_distance_unit.py` green
- [ ] No imports from `services/` or engine internals (leaf check)
- [ ] Weight/floor sanity table in module docstring matches plan.md design §1

## Risk Assessment
- Weight choices wrong → all tunable via env, recalibrated in Phase 6 eval; floor chosen
  so the known-bad "same outfit + different shoes" pattern lands below it by design.
