---
id: WAR-V05-FU-01
parent: V05-LLM-pivot
type: bug
title: "[V05] Tier-pretag elevated/exploratory promotion too tight — caps LLM-1 firing at 25%"
state: Backlog
priority: P0
labels: [type:bug, area:backend, role:backend-dev, v05, llm1, source:ticket-b-eval]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 1-2d
linear_sync_status: pending
created: 2026-05-25
---

## Context

Ticket B (PR #63) widened the V05 build candidate set so `all_composed`
went from 1–3 → 8–12 and LLM-1 firing from 0/16 → **4/16**. But the
≥50% acceptance bar is still NOT met (lands at 25%).

Live eval on a prod-mirror local DB proved the remaining gate is NOT
pool size — it's the `engine_v05_tier_pretag` **promotion criteria**.
Evidence: scenario `W/30/casual` has `all_composed=8` (rich pool) yet
tier pretag still classifies it `{safe:1, elevated:0, exploratory:0}`.
With `non_empty < 2` the tier diversifier short-circuits to fallback and
LLM-1 never fires — even though candidates exist.

So the original Ticket B plan's assumption ("pretag thresholds already
correct, out of scope") is disproven. The elevated/exploratory bands are
under-filled because promotion is too strict, not because there are too
few candidates.

## Acceptance criteria

- [ ] Audit `blueprints/recommendation/engine_v05_tier_pretag.py` promotion
      logic — identify why `all_composed≥8` rich pools still yield
      `elevated:0 / exploratory:0`.
- [ ] Loosen / re-tune the elevated/exploratory promotion criteria so
      that rich pools (≥8 composed, multi-formality) reliably fill
      `non_empty ≥ 2` without degrading outfit quality.
- [ ] Re-run the v05-eval 16-cell matrix (use `v05-eval` skill on a
      prod-mirror local DB). Target: **AC #4 ≥50%** scenarios with
      `elevated≥1 OR exploratory≥1` AND **AC #5 LLM-1 fires ≥50%**.
- [ ] Re-run on a gender-balanced eval user (the Ticket-B eval user was
      skewed 49 W / 30 M → all 4 passes were W cells, 0 M). Confirm the
      ≥50% holds across both genders, not just W.
- [ ] No regression to primary-outfit quality (deterministic top-scored
      pick unchanged).

## Out of scope

- Compose-pool widening (shipped in Ticket B / PR #63).
- LLM-1 prompt changes.
- try_another path.

## Refs

- Eval report: `wardrobe-backend/plans/reports/v05-eval-260525-1526-ticket-b-compose-diversity.md`
- Ticket B PR: auxi-wardrobe/auxi-backend#63
- Files: `wardrobe-backend/blueprints/recommendation/engine_v05_tier_pretag.py`
- Spec: `wardrobe-backend/docs/v05-llm-pivot-design-spec.md`
