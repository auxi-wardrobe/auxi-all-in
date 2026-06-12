---
id: WAR-V05-FU-03
parent: V05-LLM-pivot
type: bug
title: "[V05] Try Another accessory axis produces 0 distinct outfits even on a fresh pool"
state: Superseded
priority: P1
labels: [type:bug, area:backend, role:backend-dev, v05, try-another, source:llm3-eval]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 0.5-1d
linear_sync_status: pending
created: 2026-05-25
---

> **SUPERSEDED (2026-06-11):** variation axes were removed entirely by the
> diversity pivot — `plans/260611-2012-v05-diversity-try-another/` (branch
> `feature/v05-diversity-try-another`). The accessory axis no longer exists;
> distinctness is now enforced by a composite distance floor vs ALL seen
> outfits. Live eval: fresh 100%, full-session 93.3% (old axis system: 80/75%).
> No further work needed on this ticket — close in Linear as superseded.

## Context

Surfaced by the LLM-3 Phase 04 live eval (PR for LLM-3 try_another picker).
The picker itself is healthy (fires with real candidates, varied reasoning,
p95 ~2.2s), but the **accessory** variation axis returns **0/3 distinct
outfits even on a fresh, un-depleted pool** — while the other 4 axes
(silhouette, color, layering, footwear) are 3/3 on the first cycle.

This single broken axis is the main reason try_another axis success lands
at 67% overall instead of ≥80%. Excluding accessory, the picker is at
20/24 = 83%.

Eval user wardrobe has 8 ACCESSORY items, so it is NOT a wardrobe-emptiness
problem — the engine/axis logic is failing to produce a distinct
accessory-varied outfit. Failures recorded as `recompose_pool_insufficient`
and `recompose_axis_unsatisfied` on the accessory axis.

## Acceptance criteria

- [ ] Reproduce accessory-axis 0-variation on a rich wardrobe (≥6 accessory
      items) on a fresh session.
- [ ] Root-cause: is it the accessory axis-diff in `services/v05_axis_scoring.py`,
      the engine not slotting ACCESSORY into composed candidates, or the
      `force_axis=accessory` compose path? Trace `recompose_axis_unsatisfied`
      vs `recompose_pool_insufficient` on this axis.
- [ ] Fix so the accessory axis yields ≥80% distinct outfits on a rich pool.
- [ ] Re-run the LLM-3 try_another eval; confirm overall axis success ≥80%.

## Out of scope

- LLM-3 picker logic (verified healthy).
- Pool-depletion-on-long-sessions (separate tuning — first cycle 80%,
  second 53%; consider pool reseed / deeper widening).
- Tier-pretag promotion (see WAR-V05-FU-01).

## Refs

- Eval report: `wardrobe-backend/plans/reports/v05-eval-260525-1620-llm3-try-another.md`
- LLM-3 branch: `feat/v05-llm3-try-another-picker`
- Files: `wardrobe-backend/services/v05_axis_scoring.py`,
  `wardrobe-backend/blueprints/recommendation/engine_v05.py` (force_axis compose),
  `wardrobe-backend/services/v05_try_another_service.py`
