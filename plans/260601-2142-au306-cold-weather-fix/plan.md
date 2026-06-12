---
title: AU-306 Cold-Weather Outfit Fix
description: >-
  Fix cold-weather outfits feeling too light: wire real device weather (dominant
  cause) + within-spec backend warmth bug-fixes. <15C threshold change deferred
  to CEO.
status: completed
priority: P1
branch: main
tags:
  - AU-306
  - v05
  - weather
  - recommendation
  - cross-repo
blockedBy: []
blocks: []
created: '2026-06-01T14:47:04.234Z'
createdBy: 'ck:plan'
source: skill
---

# AU-306 Cold-Weather Outfit Fix

## Overview

Cold-weather outfits feel too light (CEO-filed, [AU-306](https://linear.app/duncan-1/issue/AU-306)). Root-cause research (`plans/reports/research-260601-2135-au306-cold-weather-rootcause.md`) found a **stacked failure: warm-biased INPUT meets a permissive cold THRESHOLD**. The prior commit (`d76d98b2`, the current auxi HEAD) only fixed a 22C placeholder race — the real causes remain.

**Scope (B): mobile dominant fix + within-spec backend warmth bug-fixes. The CEO-locked `<15C` threshold (#2) is NOT changed — deferred to Viet (see Follow-ups).**

Causes fixed here: **#1** hardcoded Hanoi coords / unused geolocation (dominant), **#6** silent 22C fallback, **#3** F6 accepts any outer (violates locked OUTER>=3), **#4** missing-warmth defaults to 3 (light items leak into cold), **#5** try_another defaults temp_c=20C.

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Mobile Weather Input](./phase-01-mobile-weather-input.md) (auxi) | Completed |
| 2 | [Backend Warmth Correctness](./phase-02-backend-warmth-correctness.md) (wardrobe-backend) | Completed |
| 3 | [Verification and Eval](./phase-03-verification-and-eval.md) (both) | Completed |

Phases 1 and 2 are **independent (different repos)** → parallelizable. Phase 3 depends on both.

## Agent routing

- Phase 1 → `mobile-dev` (auxi only), sim verify via `qa-mobile`.
- Phase 2 → `backend-dev` (wardrobe-backend only) **+ `tech-lead` sign-off** — #4 changes warmth behavior and interacts with in-flight dress-exclusion + starvation logic.
- Phase 3 → `qa-mobile` (sim smoke), `backend-dev`/`tester` (pytest), `v05-eval` skill (cold scenarios).

## Dependencies

- **Cross-plan (coordinate, not blocking):** V05 dress-exclusion fix (`auxi-backend#74` merged+deployed; `auxi-mobile#52` open) edits the SAME files `engine_v05_layers.py` / `engine_v05.py` (FULL_BODY warmth path, starvation). #4's default-warmth flip must be reconciled with it via tech-lead. See memory `v05_dress_exclusion_bias`.
- **Env:** local backend `:5001`; prod-mirror PG `:5433` (memory `v05_live_eval_local_db`); qa-test account.

## Out of scope / Follow-ups (file separately)

1. **#2 `<15C` threshold (CEO call)** — DEFERRED. File a Linear comment on AU-306 asking Viet: (a) does "cold" mean 15-19.9C borderline or sub-15C? (b) should 15-18C force a light outer / add a COLD `<8-10C` tier? Include a repro screenshot request.
2. **COOL warmth ceiling = 5** bars heavy coats (warmth 6-7) — bundle with #2 (warmth-scale question for Viet).
3. **#7** `style_refinement`/mood/novelty warmth-blindness (low) — separate ticket.
4. **#8 / deploy check** — ask `devops` which commit is live on Railway (manual `railway up`) to rule out the `bc51084` widened-COOL branch.
5. **Footwear `temperature_range` enum** (HOT/MILD/COOL/COLD) is tagged+stored but never read by the cold filter — enhancement ticket.
6. **`is_rainy` hardcoded `false`** (`HomeScreen:582`) — confirmed contract drift; enables engine `rain_no_waterproof` path. Done in Phase 1 only if the diff stays small (optional Step 5); otherwise file here.
7. **V2 `/start2` `temp_c` unvalidated** (`routers/recommendation.py:92-96`) — °F-as-°C risk; add `ge=-50, le=60` bound. Low priority (Home uses V05 build, not `/start2`); confirm no auxi caller before closing.
