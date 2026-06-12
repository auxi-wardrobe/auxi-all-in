---
phase: 3
title: Verification and Eval
status: completed
priority: P2
effort: 0.5d
dependencies:
  - 1
  - 2
---

# Phase 3: Verification and Eval (both repos)

## Overview
Prove the fixes work end-to-end and lock them with regression coverage. Assertions match **scope B** (no threshold change): the bar is "COOL outfits carry a warmth>=3 outer and real cold temp drives the request" — NOT "15-19.9C forces a layer" (that's the deferred #2).

## Context
- Research verification plan: `plans/reports/research-260601-2135-au306-cold-weather-rootcause.md` (§Verification plan).
- Existing eval rubric only hard-rejects "severe exposure <5C, no outer" (presence-of-outer only) — `.claude/skills/v05-eval/references/rubric.md`. `au308-style-rules-eval.py` has zero weather cases.
- Env: local backend `:5001`, prod-mirror PG `:5433`, qa-test account (memory `v05_live_eval_local_db`, `v05_sim_verify_method`).

## Requirements
- End-to-end repro of the cold path with real (simulated cold) location.
- Automated assertions that catch regressions of #1/#3/#4.

## Related Code Files
- Modify: `wardrobe-backend/evals/v05-outfits-eval.py` (add cold-warmth assertions)
- Add tests: `auxi/src/services/__tests__/weatherService.test.ts` (fallback observability, getCurrentLocation called)
- Add tests: backend pytest for `_has_cool_weather_layer` (F6) and `_warmth` default
- Use: `v05-eval` skill cold scenarios; `qa-mobile` (mobile-mcp) sim verify

## Implementation Steps
1. **Live repro (mobile #1).** Run auxi against local backend `:5001`; simulate a cold city (Xcode sim location). Capture the actual `POST /v05/recommendation/build` body — confirm `temp_c` reflects the cold location (not Hanoi) and matches the widget. Confirm the COOL outfit returned includes a warmth>=3 outer.
2. **Engine unit tests (backend #3/#4).** Add pytest: (a) F6 at `temp_c=5.0` rejects warmth-1-outer outfit, accepts warmth-3; (b) untagged item excluded from COOL filter under the new default; (c) `try_another` with missing ctx temp_c does not run WARM.
3. **Eval-harness cold assertions.** First **capture a baseline** `pool_insufficient` run on the current pre-change HEAD with a fixed seeded wardrobe, and save it as an artifact in this plan dir (do NOT rely on the stale `260513` report — different seed/wardrobe). Then extend `evals/v05-outfits-eval.py` cold scenarios to assert: COOL (<15C) outfit has an OUTER with `warmth_level >= 3` (or FULL_BODY>=4 substitute); no untagged/warmth-<3 item fills the outer slot. Run the `v05-eval` skill on the **combined #1+#3+#4** build and confirm pass; compare `pool_insufficient` to the captured baseline (no regression).
4. **Mobile regression tests.** In `weatherService.test.ts`: assert a `/weather` failure logs and returns last-known (not a silent 22C); add a Home test asserting `getCurrentLocation()` is invoked on mount.
5. **Data hygiene confirm.** Re-run the warmth_level null-rate query (Phase 2 Step 0) post-backfill (if backfill was done) to confirm the default-flip is safe.
6. Umbrella verification gates (CLAUDE.md): backend `python test_server.py`; mobile `npx tsc --noEmit && yarn lint`; real-HTTP smoke (not mocks).

## Success Criteria
- [ ] Live: cold-location user receives an outer-bearing, warmth>=3 COOL outfit; request `temp_c` is correct.
- [ ] Backend unit tests (F6 warmth floor, fail-closed default, try_another) pass.
- [ ] Eval cold assertions pass; `pool_insufficient` not regressed vs baseline.
- [ ] Mobile regression tests (fallback observability, geolocation-called) pass.
- [ ] All umbrella gates green; `qa-mobile` sim smoke clean.

## Risk Assessment
- **Eval flakiness / wardrobe variance:** use a fixed seeded wardrobe with known warm + light items for deterministic cold assertions.
- **Sim location not honored:** fall back to temp-editing the coords or directly POSTing `temp_c=5/14/16` to the build endpoint to isolate the engine path.
- **#4 starvation only visible at scale:** compare eval `pool_insufficient` distribution to the **freshly captured** baseline (Step 3), measured with #1+#3+#4 combined — not the stale `260513` report.
