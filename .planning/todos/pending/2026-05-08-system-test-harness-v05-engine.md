---
created: 2026-05-08T18:45:00+07:00
title: Add system-test harness for V05 recommendation engine
area: testing
files:
  - wardrobe-backend/tests/test_v05_recommendation_next.py
  - wardrobe-backend/tests/test_engine_v05_variation_invariants.py
  - wardrobe-backend/tests/test_engine_v05_variation_cycle.py
  - wardrobe-backend/blueprints/recommendation/engine_v05_variation.py
  - wardrobe-backend/utils/recommendation_session_v05.py
---

## Problem

Phase 1 Wave 5 surfaced **three latent bugs** in the V05 Remix engine that escaped both unit
tests and the initial integration test pass:

1. `_pre_filter_for_anchor_v05` read `warmth_level` only from `styling_metadata`; real items
   store it in `physical_attributes`. Defaulted to sentinel 3 → killed all MILD-climate L2
   candidates silently.
2. Swap handlers emitted phantom `{"id":""}` L3 slots for 3-item outfits → tripped
   `SingleLayerSwapViolation` on slot-count diff.
3. `ItemDTO` lacked `layer_code` → client-computed outfit hashes diverged from server-stored
   hashes → spurious 422 drift on every second `/next` call.

All three were only caught when the `/next` integration test (Task 4.3) ran end-to-end. Unit
tests passed throughout. The integration test suite is small (5 cases) and the bugs
specifically required: a real wardrobe seed with `physical_attributes.warmth_level` populated,
a 3-item outfit (no L3), and two sequential `/next` calls.

We need a **system-test harness** — a layer above unit/integration tests that exercises
realistic multi-cycle scenarios, varied wardrobe seeds, and contract invariants over many
calls. Not e2e (Maestro covers that). Closer to property-based testing or scenario fuzzing.

## Solution

TBD — candidate approaches to evaluate when this gets picked up:

- **Scenario harness**: parametrize `(climate, gender, wardrobe-shape, force-axis sequence)`
  and run 4-axis cycles end-to-end, asserting invariants on every step.
- **Property-based tests**: hypothesis-style generators for wardrobes + sessions; assert
  anchor pin + single-layer-swap hold for any valid input.
- **Contract tests**: pin the request/response shape between mobile + backend so
  `ItemDTO`-style schema drift is caught at PR time, not at runtime.
- **Production replay harness**: capture real `/start`+`/next` payloads from staging,
  replay against PR builds, compare outfit deltas (regression detection).

## Open questions

- Should this run in CI on every PR, or as a nightly scenario job?
- Where does it live — `wardrobe-backend/tests/system/` or a new `wardrobe-backend/tests/scenarios/` dir?
- Does it require seeding more SYSTEM items into the test DB to exercise enough variety?

## Refs

- Wave 5 commits: `8102f49`, `fdc589b`, `c113353` on `feat/au-251-remix-next`
- Wave 5 followup note: `docs/pm/inbox/WAR-AU251-followup-pool-exhaustion.md`
- Phase 1 plan: `.planning/phases/01-remix-backend/01-01-PLAN.md`
