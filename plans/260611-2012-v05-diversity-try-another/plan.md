---
title: V05 Diversity-Driven Try Another (remove variation axes)
description: >-
  Replace the 5-axis variation mechanism with a composite outfit-distance
  metric: each Try Another result must be sufficiently different from ALL
  previously seen outfits while staying style-coherent (rules R1-R11 unchanged).
status: completed
priority: P1
branch: feature/v05-diversity-try-another
tags:
  - v05
  - try-another
  - backend
  - recommendation
blockedBy: []
blocks: []
created: '2026-06-11T13:17:46.225Z'
createdBy: 'ck:plan'
source: skill
---

# V05 Diversity-Driven Try Another (remove variation axes)

## Overview

**Decision (CEO, 2026-06-11):** v05 Try Another no longer varies along a single axis
(silhouette/color/layering/footwear/accessory). Instead the engine picks the next outfit
itself: **maximally different from everything already shown this session, but still valid**.

### Why

- Axis hard-filters starve the pool: FU-03 (accessory axis 0/3 distinct on a fresh pool),
  FU-04 (2nd-cycle `recompose_pool_insufficient` caps full-session success at 75%).
- Axis-diff only compares against the *current* outfit → "A→B→A-like" oscillation is legal today.
- Product no longer wants user/engine-driven axis selection at all.

### Design (locked)

1. **Composite distance** `outfit_distance(a, b) ∈ [0,1]` (new leaf module, reuses
   `engine_v05_axis.py` comparators):
   `0.50·item_jaccard_dist + 0.15·silhouette_diff + 0.15·color_family_diff + 0.10·layer_count_diff + 0.10·footwear_set_diff`
   - "Same fit, different shoes" ≈ 0.30 → below floor → rejected as too similar (kills the
     pattern flagged by the 260513 evals).
2. **Diversity vs ALL seen** — not just current. Session cache gains compact
   `seen_signatures` (hash, item_ids, silhouette, color_family, layer_count) so distance
   survives FIFO pool eviction.
3. **Selection = quality + diversity (MMR-style):** hard floor
   `min_dist_to_seen ≥ V05_MIN_DISTANCE` (default 0.35), then
   `score = 1.0·min_dist + 0.3·engine_score + 0.5·style_feedback_fit`.
4. **Coherence unchanged:** style rules R1–R11, climate buckets, mood filters keep
   guaranteeing "vẫn hợp lý". This plan only changes *which* valid outfit gets served.
5. **Recompose without `force_axis`:** engine post-L5 filter becomes a distance filter
   (`min_distance` + `seen_signatures` on `BuildInput`). Widened recompose **reseeds the
   pool** with surviving high-distance candidates (top-K) → fixes FU-04 depletion.
6. **Graduated exhaustion:** floor → recompose → relaxed floor (0.5×, flag
   `relaxed_distance`) → terminal "No more variations" (`pool_exhausted`).
7. **LLM-3 picker stays**, re-prompted: "most distinct from these seen outfits, most
   coherent" instead of "varies on axis X". Distance floor enforced post-pick.
8. **Contract:** `axis` request field accepted-but-ignored (deprecated);
   `variation_axis` response → `null`; new trace fields `min_distance`, `distance_floor`,
   flag `recompose_distance_unsatisfied` replaces `recompose_axis_unsatisfied`.

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Distance Metric](./phase-01-distance-metric.md) | Completed |
| 2 | [Selection Rewrite](./phase-02-selection-rewrite.md) | Completed |
| 3 | [Engine Recompose](./phase-03-engine-recompose.md) | Completed |
| 4 | [API Contract](./phase-04-api-contract.md) | Completed |
| 5 | [Mobile Sync](./phase-05-mobile-sync.md) | Completed |
| 6 | [Eval & Tuning](./phase-06-eval-tuning.md) | Completed |

Order: 1 → 2 → 3 → 4 → (5 ∥ 6). Phases 1–4 = `backend-dev` in `wardrobe-backend/` on
branch `feature/v05-diversity-try-another`. Phase 5 = `mobile-dev` in `auxi/`.
Phase 4 contract diff needs `tech-lead` sign-off (umbrella rule).

## Dependencies

- **Supersedes** PM inbox tickets `docs/pm/inbox/WAR-V05-followup-03-…` (accessory axis —
  obsolete once axes are gone) and `…-04-…` (pool depletion — reseed lands here). Phase 6
  updates both.
- **Compatible, not blocking:** `plans/260611-1902-v05-tester-simple-mode/` (admin tester
  sends `axis: null`, reads `outfit`/`message` only — keeps working).
  `plans/260531-1326-au-303-two-axis-swipe/` (mobile *gesture* axes, orthogonal to
  backend variation axes).
- **V2 engine untouched** (`utils/recommendation_session.py` axis cycle is V2-only).

## Risk summary

- Distance floor too strict on sparse wardrobes → graduated relaxation (design §6) + Phase 6 tuning.
- Redis session shape change (`seen_signatures`) → old sessions lack the key; code must
  default to deriving from `primary`+`pool` (no 500 on stale session).
- LLM-3 prompt regression → eval gate in Phase 6 before merge.
