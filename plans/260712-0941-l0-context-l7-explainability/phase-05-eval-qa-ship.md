---
phase: 5
title: Eval, QA & Cross-Repo Ship
status: planned
priority: P1
repos: [wardrobe-backend, auxi]
dependencies: [2, 3, 4]
---

# Phase 5: Eval, QA & Cross-Repo Ship

## Overview

Prove the two wedges work end-to-end and lock them with regression coverage before ship.
Verifies the cross-repo contract (P1), that comfort does not starve the pool (P2), that
explanations are honest/deterministic/ToV-safe (P3), and the mobile surface (P4). Uses the
`v05-eval` skill for scenario coverage — its rubric today only checks "severe cold, no outer",
so add hot/humid/rain/mobility context cases + explanation-quality assertions.

## Requirements

- **Backend gates:** `pytest` (comfort + explain suites) + `python test_server.py` green;
  `API_DOCUMENTATION.md` diff includes context fields + `explanation`; tech-lead sign-off on the
  public `/api/v05` contract change.
- **Eval scenarios** (extend `wardrobe-backend/evals/v05-outfits-eval.py` + `.claude/skills/v05-eval/references/rubric.md`):
  - hot+humid → outfit trends breathable, `heavy_layering` down-weighted, factor cites weather.
  - heavy rain (`rain_prob≥0.6`) → no non-waterproof footwear when metadata present; explanation cites it.
  - motorbike → loose/flowing down-weighted; no starvation.
  - `pool_insufficient` rate across the scenario set ≤ pre-change baseline (hard gate — P2 starvation risk).
  - explanation determinism (same seed+ctx twice → identical) + ToV lint + PII-absence across the set.
- **Mobile gates:** `tsc --noEmit` + `yarn lint` clean; `auxi-lint-tokens.sh` clean; qa-mobile smoke on sim (context chips → rebuild → why-panel renders); designer design-review PASS.
- **Smoke (real HTTP, not mocks):** backend on :5001, mobile against it — set context, confirm the returned `explanation` reflects the sent context (umbrella verification gate).

## Related Code Files

- Modify: `wardrobe-backend/evals/v05-outfits-eval.py` — context + explanation cases.
- Modify: `.claude/skills/v05-eval/references/rubric.md` — hot/rain/mobility + explanation rules.
- Read: all P1–P4 outputs.
- Create: `plans/260712-0941-l0-context-l7-explainability/reports/` — eval + QA reports.

## Implementation Steps

1. **Eval extend.** Add the scenario rows + rubric rules; run `v05-eval`; record `pool_insufficient` vs baseline.
2. **Backend verify.** Full `pytest` + `test_server.py`; contract diff; tech-lead sign-off.
3. **Mobile verify.** `tsc`/`lint`/token-lint; qa-mobile sim smoke; designer gate.
4. **Cross-repo smoke.** Live backend + mobile; assert context→explanation coherence end-to-end.
5. **Ship.** Backend PR then mobile PR (contract-first order); PR template checklist green; link eval + design-review artifacts. (PR only on explicit go — do not open unprompted.)

## Success Criteria

- [ ] All P1–P4 success criteria pass.
- [ ] `pool_insufficient` ≤ baseline on the eval set (starvation gate).
- [ ] Explanation determinism + ToV + PII-absence hold across the full scenario set.
- [ ] Cross-repo smoke: sent context is reflected in the outfit's top explanation factor (real HTTP).
- [ ] Both repos' lints/tests green; designer PASS + tech-lead contract sign-off recorded.

## Risk Assessment

- **Baseline drift** (comfort quietly shrinks the pool). Mitigation: explicit `pool_insufficient` compare gate; block ship if it regresses.
- **Contract order** (mobile ships before backend). Mitigation: backend PR + deploy first; `explanation`/context additive so old clients tolerate; tech-lead sequences per two-repo contract.
- **Prod-DB-in-local-.env trap** (see AU-318 journal). Mitigation: do NOT run migrations against local `.env` without devops confirming a dev DB — this phase adds no migration, but the eval must not write prod.

## Unresolved Questions

- Does `models/wardrobe.py` actually carry `breathability` / `waterproof` / `material`? Gates how many P2 comfort rules are live vs dormant (audit in P2 Step 1).
- Is there an existing occasion/`intent.activity` field to reuse, or is activity net-new? (DRY check in P1 Step 1.)
- Pairing factor ("most-worn-with") — is co-wear derivable from `v05_outcome_events` without a new hot-path query? If not, ship P3 without the pairing kind (defer).
- Weather provider: does the current mobile `weatherService` API return humidity/UV/wind, or is a provider/plan change needed?
- ToV banned-word list — is there a single shared constant to reuse, or is it enforced only in code review today?
