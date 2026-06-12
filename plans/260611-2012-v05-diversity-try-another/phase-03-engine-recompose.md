---
phase: 3
title: Engine Recompose
status: completed
priority: P1
effort: 1-1.5d
dependencies:
  - 2
---

# Phase 3: Engine Recompose

## Overview
Remove `force_axis` from the engine recompose path; replace the post-L5 hard axis filter
with a distance filter vs `seen_signatures`. Reseed the session pool from the widened
candidate set (FU-04 fix). Re-prompt the LLM-3 picker for distinctness instead of
on-axis variation. Graduated exhaustion behavior.

## Requirements
- Functional:
  - `BuildInput`: drop `force_axis` + `current_signature` + `current_items`; add
    `min_distance: Optional[float]` and `seen_signatures: List[dict]`. Validation updated.
  - Engine post-L5: when `min_distance` set, drop candidates with
    `min_distance_to_seen(c, seen_signatures) < min_distance` (replaces force_axis filter,
    `exclude_hashes` unchanged). Axis-specific oversample hacks (layering flip, accessory
    append, F1 axis oversample) → replaced by one diversity oversample on the
    try_another path (`widen_candidates` semantics preserved).
  - Pool reseed: widened recompose returns surviving candidates; service appends top-K
    (`V05_POOL_RESEED_COUNT`, default 3) above-floor candidates to the pool (not `seen` —
    only served outfits enter seen).
  - Graduated exhaustion in service: floor-empty pool → recompose(min_distance=floor) →
    on PoolInsufficient retry once with `min_distance=0.5·floor` + flag `relaxed_distance`
    → still nothing → terminal fallback (`pool_exhausted`, message "No more variations…").
  - LLM-3 prompt: input = candidate list + compact seen-outfit summaries; instruction =
    "pick the candidate most distinct from the seen outfits that is still coherent;
    explain in one sentence for the user". Defensive post-pick check: picked candidate
    must satisfy the (possibly relaxed) floor, else flag `recompose_distance_unsatisfied`
    and fall back to rule-based max-distance pick.
- Non-functional: recompose latency budget unchanged (`RECOMPOSE_TIMEOUT_SECONDS` 8s,
  p95 ≤ 2.5s target at eval); single engine call per recompose preserved.

## Architecture
```
service._recompose
  └─ BuildInput(exclude_ids=anchors+ctx, exclude_hashes=seen,
                min_distance=floor_or_relaxed, seen_signatures=state.seen_signatures,
                widen_candidates=llm3_enabled, count=1)
       └─ engine: L1..L5 → distance filter (replaces force_axis filter) → L6
            └─ BuildOutput.outfits[0] (+ .candidates when widened)
  ├─ llm3 pick (if enabled) over candidates, distance-aware prompt
  ├─ append served outfit → pool + seen + seen_signatures
  └─ reseed: top-K remaining above-floor candidates → pool
```

## Related Code Files
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05.py`
  (~L106-160 BuildInput fields/validation; ~L567-660 oversample/stratify branches;
  ~L800-830 post-L5 force_axis filter → distance filter)
- Modify: `wardrobe-backend/services/v05_try_another_service.py`
  (`_build_recompose_input` ~L395-485, `_recompose`, exhaustion ladder, reseed)
- Modify: LLM-3 picker prompt + parsing (locate via `llm3` grep — picker service/prompt
  module on `feat/v05-llm3-try-another-picker` lineage)
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05_axis.py` — `axis_diff`
  now dead → delete (helpers live on in/are imported by `engine_v05_distance.py`)
- Modify: `wardrobe-backend/config.py` (V05_POOL_RESEED_COUNT)
- Tests: `tests/test_v05_engine*.py`, `tests/test_v05_try_another*.py`

## Implementation Steps
1. BuildInput field swap + validation + trace fields (`min_distance`,
   `seen_signatures_count` in build trace ~L306).
2. Engine: distance filter post-L5; collapse axis-specific oversample branches into one
   widened/diversity oversample; keep stratify semantics for widen path.
3. Service: `_build_recompose_input` new fields; exhaustion ladder (floor → relaxed →
   terminal); reseed top-K; flags `relaxed_distance`, `recompose_distance_unsatisfied`.
4. LLM-3: prompt rewrite + seen summaries; post-pick floor check; keep llm3_call trace shape.
5. Update/replace axis-based engine tests with distance-filter tests:
   - recompose result respects floor vs all seen_signatures
   - relaxed retry fires only after strict PoolInsufficient, flag present
   - reseed appends ≤K, all above floor, none already in seen
   - LLM-3 disabled path = rule-based max-distance pick
6. `pytest && python test_server.py` green.

## Success Criteria
- [ ] `grep -rn "force_axis" wardrobe-backend/` → no hits outside docs/changelog
- [ ] Full-session simulation (10 try_another, rich wardrobe fixture): 0
      `recompose_pool_insufficient` before call 8; reseed observed in pool sizes
- [ ] p95 recompose latency within existing budget on local bench

## Risk Assessment
- Removing axis oversample hacks may shrink candidate richness for specific slots →
  the widened diversity oversample must keep ~10-20 candidates; verify via trace
  `pool_sizes_after_L1` in tests.
- LLM-3 picks low-distance candidates → defensive floor check forces rule-based fallback,
  flagged for eval visibility.
