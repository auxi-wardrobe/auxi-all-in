# V05 Prod Eval — duc2820 "no outfits" FIXED (live prod verification)

**Date:** 2026-06-02 17:03 (+07) · **User:** duc2820@gmail.com (`61c9fa0a-...`) · **Surface:** PROD (`wardrobe-backend-production-c8d9.up.railway.app`)
**Method:** real HTTP calls to prod with a minted read-only token (prod `SECRET_KEY` via Railway CLI) + prod DB forensics + deployed-source analysis. Goal: "call prod, fix until it works, eval on prod."
**Result:** ✅ FIXED — 18/18 prod builds yield outfits across dry+rain × HOT+WARM.

---

## 1. TL;DR
duc2820's "gọi không ra đồ" was **three stacked bugs**, surfacing by weather. All three found, fixed, deployed to prod, and **verified by live HTTP calls**:

| PR | Bug | Trigger | Prod status |
|---|---|---|---|
| #82 | L1: `warmth_level=0` excluded at all temps; HOT bucket `[1]` too narrow | HOT, dry | ✅ deployed — prod 12/12 dry |
| #83 | L2: greedy composer dead-ends on incoherent footwear (no backtracking, no floor) | HOT/WARM, dry | ✅ deployed |
| #84 | Rain: `is_rainy=true` drops ALL footwear (0% tagged water-resistant) | any temp, **raining** | ✅ deployed — prod 6/6 rainy |

## 2. Live prod matrix (post all 3 deploys)
duc2820, gender M, occasion casual, mood calm, seeds 0..5:

| temp | rainy | outfits |
|---|---|---|
| 33°C (HOT) | dry | **6/6** |
| 27°C (WARM) | dry | **6/6** |
| 27°C | **rain** | **3/3** |
| 33°C | **rain** | **3/3** |

Sample outfit: `White T-shirt + Relaxed Trousers + Black rubber slides`. Build `count=3` returns 3 distinct outfits.

## 3. Root causes (deployed-code, file:line)
- **#82** `engine_v05_constants.warmth_constraint` + `item_derivations.get_warmth_constraint`: no bucket contained `0`; `_warmth` defaults missing→0 (AU-306). At HOT only `warmth==1` survived → 16 tops→1, 12 bottoms→1. Fix: HOT `[1]→[0,1]`, WARM `[1,2]→[0,1,2]` (MILD/COOL unchanged → cold-safety preserved).
- **#83** `engine_v05_layers.layer2_compose`: per-slot `rng.randint(0,top_n-1)` picks footwear BEFORE outfit-level `style_jaccard` coherence check, no backtracking → BOLD boots (top score) locked in, whole compose returns None despite coherent shoes lower. Plain build failed 13/500 seeds. Fix: `_pick_coherent_slot` (randomize only among coherent candidates) + `layer2_best_effort_compose` deterministic floor (non-empty pool ⇒ ≥1 outfit; gated `not l3_required` + `not starved`).
- **#84** `engine_v05_layers.layer1_feasibility` rain gate: `is_rainy and not _is_water_resistant → drop`. `is_water_resistant` never populated → 0/8 user + 0/22 SYSTEM footwear → all dropped. App sends `is_rainy=true` when raining (`auxi HomeScreen.tsx:681`). Fix: collect rain-excluded footwear; restore if FOOTWEAR would be empty (prefer waterproof when any exist).

## 4. Verification rigor
- **#83** verified by 500 in-process `build()` runs against duc2820's REAL prod wardrobe (300 plain + 200 force_axis) → 0 failures, before deploy.
- All three confirmed by **live prod HTTP matrix** post-deploy (18/18).
- Each fix: independent test run + diff review; #82 also code-reviewed (APPROVE_WITH_NITS).
- **Lesson logged:** #82 was prematurely called "fixed" on an L1-only proof — corrected by full-pipeline + live-prod verification thereafter.

## 5. Known limitation (not a no-outfit bug)
`try_another` returns the graceful exhausted response (`outfit=None`, schema-modeled) on **silhouette/color/layering** axes for duc2820 — his items lack silhouette/color metadata to vary on. footwear/accessory axes vary fine (2/5). Build always yields outfits; this only limits variation depth. Resolved by the metadata backfill (below).

## 6. Follow-ups (gated — not yet run)
1. **Data backfill** (`scripts/backfill-warmth-weather-season.py`, --dry-run default; from #82 work): re-derive `warmth_level` (~96 items skew 0) + populate `weather_suitability`/`season`. Add `is_water_resistant` (100% unpopulated → rain always relaxes) + `silhouette`/`color` (unblocks try_another axes). Review warmth tiers before `--apply` on prod.
2. **Mobile contract** (needs tech-lead + auxi): surface `exclude_relaxed` / `rain_no_waterproof_relaxed` / try_another-exhausted as user-facing signals ("served a repeat", "no waterproof shoes — bring an umbrella").
3. **V05-3 occasion conflation** (report 260602-1353 §4): mobile sends mode (`safe`/`power`/`creative`) as `occasion` → backend maps all to `unknown` → users can't get work/formal outfits.

## 7. Open questions
1. Backfill `warmth_level`/`is_water_resistant` via heuristic (shipped script) vs re-running Gemini extraction with a strengthened rubric — which is authoritative?
2. Should rain footwear relaxation surface a UI advisory, or stay silent?
3. try_another axis exhaustion — acceptable as-is until metadata backfill, or add a cross-axis fallback so a variation always returns *something* new?
