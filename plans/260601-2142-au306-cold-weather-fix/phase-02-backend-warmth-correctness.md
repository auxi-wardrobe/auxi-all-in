---
phase: 2
title: Backend Warmth Correctness
status: completed
priority: P2
effort: 1d
dependencies: []
---

# Phase 2: Backend Warmth Correctness (wardrobe-backend)

## Overview
Within-spec bug-fixes so that **when a correct cold temp reaches the engine**, the COOL path actually produces warm-enough outfits. Does NOT change the `<15C` threshold (deferred to Viet). Repo: `wardrobe-backend/` only (`backend-dev`) + **`tech-lead` sign-off** (warmth-behavior change overlaps in-flight dress-exclusion work).

## Context
- Research: `plans/reports/research-260601-2135-au306-cold-weather-rootcause.md` (causes #3, #4, #5).
- `WARM_OUTER_THRESHOLD = 3` already exists in `engine_v05_constants.py` per **Viet's locked decision (2026-05-13 Q1: OUTER>=3, FULL_BODY substitute>=4)** — #3 is enforcing that, not changing spec.
- The same files are touched by the dress-exclusion fix — coordinate via tech-lead before merging.

## Requirements
- Functional: COOL (<15C) outfits include an OUTER whose `warmth_level >= 3` (or a FULL_BODY warmth>=4 substitute); untagged/missing-warmth items do NOT pass the cold filter as if mid-weight; `try_another` never silently assumes WARM (20C).
- Non-functional: no spurious increase in `pool_insufficient`/starvation (verify in Phase 3); consistent missing-warmth policy across engine paths.

## Related Code Files
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py` (`_warmth` ~:99-100; `_has_cool_weather_layer` ~:125-131; import `WARM_OUTER_THRESHOLD`)
- Read/reconcile: `wardrobe-backend/blueprints/recommendation/engine_v05.py` (missing-warmth default `0` at ~:225, :434, :1121)
- Modify: `wardrobe-backend/services/v05_try_another_service.py` (~:457 temp_c default)
- Read: `wardrobe-backend/blueprints/recommendation/engine_v05_constants.py` (`WARM_OUTER_THRESHOLD`, `warmth_constraint`)
- Reference (where session ctx is written): `wardrobe-backend/services/v05_build_service.py`, `repositories/v05_event_repository.py`

## Implementation Steps
0. **Pre-req — data hygiene measurement (run first).** Against prod-mirror PG `:5433`, measure BOTH corpus-wide and per-family (the leak is per-slot, not per-corpus). Corpus: `SELECT count(*) FILTER (WHERE styling_metadata->>'warmth_level' IS NULL) AS untagged, count(*) AS total FROM wardrobe_items;` Per-family (OUTER is the critical slot for #3+#4): `SELECT category_family, count(*) FILTER (WHERE styling_metadata->>'warmth_level' IS NULL) AS untagged, count(*) AS total FROM wardrobe_items GROUP BY category_family;` (adjust the family column to the actual schema). Record both; they inform the **mandatory backfill** in Step 2.
1. **#3 — F6 honors OUTER>=3.** In `_has_cool_weather_layer`, change the OUTER branch from `if fam == "OUTER": return True` to `if fam == "OUTER" and _warmth(it) >= WARM_OUTER_THRESHOLD: return True`. Add the import. Now a warmth-1 light blazer no longer satisfies the sub-15C cold gate. (FULL_BODY>=`WARM_FULL_BODY_THRESHOLD` branch unchanged.)
2. **#4 — fail-closed missing-warmth default (backfill FIRST, then flip).** Order matters because #3 (Step 1) and #4 subtract from the SAME eligible OUTER set — do not flip on untagged data.
   - **2a. Mandatory backfill before the flip:** if Step 0 shows ANY untagged items (especially OUTER family), backfill `styling_metadata.warmth_level` via the category→warmth map in `utils/item_derivations.py` (cross-check `commonItems/fix_metadata.py` — note its `HOD` vs canonical `HDD` hoodie-code bug and `DRS=1` dress mislabel from the research; fix those if used). Backfilling is strictly safer than flipping the default on nulls — so do it unconditionally when nulls exist rather than gating on a fuzzy corpus %.
   - **2b. Flip the default:** change `_warmth()` default from `3` to `0` so any still-untagged item is excluded from the cold (`[3,4,5]`) filter, matching the `0` default already used at `engine_v05.py:225/434/1121`. Introduce a single shared constant/accessor (e.g. `MISSING_WARMTH_DEFAULT = 0`) so filter + starvation detector agree; genuine starvation then triggers the existing common-item injection.
3. **#5 — try_another temp persistence.** Two concrete sub-steps (the premise is that ctx lacks `temp_c`, so "reuse session temp" is circular — make the write explicit):
   - **3a. Persist at build:** locate where the build writes session/recompose context (`v05_build_service.py` → session/Redis via `repositories/v05_event_repository.py`) and ensure `temp_c` (and `is_rainy`) are written there. If the write is missing, ADD it — this is the real fix; the default only existed because the value wasn't persisted.
   - **3b. Fail-closed for legacy sessions:** at `v05_try_another_service.py:457`, remove the `20.0` default. If `temp_c` is present in ctx, use it. If genuinely absent (legacy/expired session created before 3a), do NOT assume WARM — log an error and return an explicit "session stale, rebuild required" signal to the client so it re-issues a `build` (with fresh weather), rather than recomposing at a guessed temperature.
4. Update `wardrobe-backend/API_DOCUMENTATION.md` only if request/response shape changes (it should not — behavior-only). Note behavior change for tech-lead.
5. `python test_server.py` (or targeted pytest) green.

## Success Criteria
- [ ] At `temp_c=5.0`, an outfit whose only outer is warmth-1 is REJECTED by F6; a warmth-3 outer passes (unit test).
- [ ] An untagged (no `warmth_level`) light item is NOT selected in a COOL outfit (excluded by the fail-closed default); starvation/common-injection backfills if the slot is starved.
- [ ] `try_another` on a cold session never recomposes as WARM when temp_c is missing — it logs + uses the cold temp.
- [ ] Filter and starvation-detector use the SAME missing-warmth default.
- [ ] No new `pool_insufficient` regressions in Phase 3 eval vs baseline.
- [ ] Backend tests green; tech-lead signed off.

## Risk Assessment
- **#4 default flip → starvation risk** if many prod items are untagged. **Mitigation:** Step 0 null-rate gate + optional warmth backfill before flipping; verify pool_insufficient in Phase 3.
- **#3 tightening → fewer eligible cold outfits** in sparse-outerwear wardrobes. **Mitigation:** relies on common-item injection (COOL fallback spec) to add a warm outer; verify.
- **Compounding starvation (#3 + #4 together):** both fixes shrink the SAME eligible OUTER set simultaneously. **Mitigation:** Step 0 measures per-family untagged OUTER; Step 2a backfills before any flip; Phase 3's `pool_insufficient` baseline must be measured with **#3 + #4 combined**, not #4 alone.
- **Overlap with dress-exclusion work** (same files, FULL_BODY warmth). The literal collision point is the F6 FULL_BODY branch (`_has_cool_weather_layer:130`, also `WARM_FULL_BODY_THRESHOLD` at L1 `:442/:550`) — exactly what dress-exclusion edits. **Mitigation:** tech-lead reviews THAT line specifically (not just "the files"); rebase on the latest engine_v05 changes before merge.
