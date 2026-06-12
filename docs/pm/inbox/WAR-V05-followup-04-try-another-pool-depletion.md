---
id: WAR-V05-FU-04
parent: V05-LLM-pivot
type: bug
title: "[V05] Try Another pool depletion in long sessions caps axis success at 75% full-session"
state: Superseded
priority: P2
labels: [type:bug, area:backend, role:backend-dev, v05, try-another, source:llm3-eval]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 0.5-1d
linear_sync_status: pending
created: 2026-05-25
---

> **SUPERSEDED (2026-06-11):** addressed by the diversity pivot —
> `plans/260611-2012-v05-diversity-try-another/` (branch
> `feature/v05-diversity-try-another`). Pool reseed (top-K strict-floor
> survivors on widened recompose, `V05_POOL_RESEED_COUNT=3`) + graduated
> exhaustion ladder (strict floor → 0.5× relaxed w/ `relaxed_distance` flag →
> cycle → terminal) shipped there. Live eval full 10-call session: 93.3%
> incl-terminal / 96.6% excl (old: 75%/94%), p95 2.40s. Terminal-UX product
> decision: graceful flagged serves, terminal message unchanged.
> Close in Linear as superseded.

## Context

After the LLM-3 picker (Phase 02/03) and the accessory-axis fix (FU-03),
the try_another live eval shows:

- **Fresh pool / first cycle: 80%** axis success (meets the bar).
- **Full 10-call session: 75%** — the gap is entirely **2nd-cycle pool
  depletion**: once the build-seeded pool is consumed, recompose can't
  produce enough distinct candidates → `recompose_pool_insufficient`
  (and one `axis_unsatisfied`). Layering dropped to 1/4 from the same
  starvation.

This is NOT the picker (verified healthy, 0 init/timeout errors) and NOT
the accessory fix (accessory is now 3/3 on reachable calls). It is the
candidate-supply running dry deep in a session.

If terminal "no more variations" fallbacks are excluded, overall is
15/16 = 94%.

## Acceptance criteria

- [ ] Decide + implement how to sustain candidate supply across a long
      try_another session. Options (pick per investigation):
      - Raise `V05_BUILD_ALTERNATES` / `V05_MAX_POOL` (seed a deeper pool).
      - Deepen the recompose widening (more anchors/variants on the
        force_axis recompose path).
      - Pool reseed when the cached pool falls below a threshold.
- [ ] Define the product behavior for genuine exhaustion (when the
      wardrobe truly can't produce another on-axis variation) — terminal
      "no more variations" UX vs counting against the metric.
- [ ] Re-run the try_another eval; target **full-session axis success
      ≥80%** without regressing latency (p95 ≤ 2.5s) or primary quality.

## Out of scope

- LLM-3 picker logic (verified healthy).
- Accessory axis (fixed in FU-03).
- Tier-pretag promotion (FU-01).
- Gender-balanced eval user (eval data limitation — the prod-mirror user
  is W-skewed; M try_another path remains unvalidated, note for re-eval).

## Refs

- Eval reports: `wardrobe-backend/plans/reports/v05-eval-260525-1620-llm3-try-another.md`,
  `wardrobe-backend/plans/reports/v05-eval-260525-1652-llm3-accessory-fix-confirm.md`
- LLM-3 branch: `feat/v05-llm3-try-another-picker`
- Files: `wardrobe-backend/services/v05_try_another_service.py`,
  `wardrobe-backend/utils/v05_session_cache.py`,
  `wardrobe-backend/blueprints/recommendation/engine_v05.py` (recompose widening),
  config (`V05_BUILD_ALTERNATES`, `V05_MAX_POOL`)
