# V05 "No Outfits" — HOT/warmth-0 Categorical Exclusion (duc2820)

**Date:** 2026-06-02 13:53 · **User:** duc2820@gmail.com (user_id=61c9fa0a-07bf-4777-9339-62c43a35371e, role=admin, gender=EMPTY)
**Verdict:** CONFIRMED (high confidence) · **Method:** deployed-code reasoning (`/tmp` dumps + `git show origin/main`) + read-only prod SQL + recorded prod failure events. Live HTTP blocked by SECRET_KEY mismatch.
**Scope:** findings only — no code or DB modified.
**User request (verbatim):** "login tài khoản duc2820@gmail.com rồi eval cho tôi, wheather thì tự call api, tôi thấy hiện tại chả ra đc bộ đồ nào đó, tôi thấy đang có rất nhiều vấn đề về v05 recommend system".

---

## 1. TL;DR

duc2820 has a healthy **54-item wardrobe** yet gets **"no outfits"** because the V05 **L1 warmth filter categorically excludes every `warmth_level=0` item at every temperature**, and the **HOT bucket admits only `warmth==1`**. At Saigon's live climate today (32°C, feels 39°C, Rain → bucket **HOT**), his 16 tops collapse to **1** survivor and his 12 bottoms to **1** — a 54-item wardrobe reduced to a 1-top/1-bottom pool. The chain has **no rescue path** for the user's own warmth-0 items (the only fallback injects SYSTEM common items, which are themselves warmth-filtered). **Live-recorded proof:** on 2026-06-02 `v05_pool_insufficient_events` logged **17 failures, all duc2820, all `climate_bucket=HOT`** — `hot_weather_no_lightwear` (WardrobeGapError) ×11–13, `no_valid_outfits_after_L2` (PoolInsufficientError) ×3, `no_outfits_after_force_axis_or_exclude_filter` ×3. This is the **live everyday condition** for Saigon users, not an edge case.

**Refinement vs original hypothesis:** the claim "TOP truly reaches 0" is **wrong at the current wardrobe state** — live SQL shows TOP=1, BOTTOM=1 survive L1 at 32°C. The recorded failures are a **two-stage collapse**: (1) warmth gating shrinks the HOT pool to ~1 anchor/slot, then (2) `try_another`'s rolling `exclude_ids` + `exclude_hashes` (which, unlike `force_axis`, have **no graceful-degrade**) deplete even that single survivor → WardrobeGapError / PoolInsufficientError. Both recorded `failure_reason`s are explained and traced to exact lines.

---

## 2. Root cause

### The exclusion chain (deployed code)

| Step | Location (deployed) | Behavior |
|---|---|---|
| Warmth buckets | `engine_v05_constants.py:266-267` (`warmth_constraint`) | `temp_c > 28` → `([1], False)` (**HOT**); `>=20` → `[1,2]` (WARM); `>=15` → `[2,3]` (MILD); else `[3,4,5]` (COOL). **No bucket contains `0`.** |
| Item warmth read | `engine_layers_deployed.py:100-107` (`_warmth`) | `styling_metadata.get('warmth_level', 0)` — **missing → 0 (AU-306 fail-closed)** |
| L1 gate | `engine_layers_deployed.py:214-219` | `if _warmth(it) not in allowed_warmth: skip` for **TOP/BOTTOM/OUTER/FULL_BODY**; FOOTWEAR gated only when `temp < 22` (`FOOTWEAR_WARMTH_GATE_TEMP=22`) |

**Consequence:** `warmth_level=0` (and any untagged item, defaulted to 0) is **in NO bucket → categorically excluded as a TOP/BOTTOM/OUTER/FULL_BODY anchor at ALL temperatures**. At HOT, only `warmth==1` survives. `warmth_level=0` is by definition the *lightest* tier — excluding it from hot weather is backwards.

duc2820 distribution (verified against DB):
- TOP `{0:3, 1:1, 2:5, 3:1, 4:1, 5:3, 6:2}` → only **1/16** survives HOT
- BOTTOM `{0:5, 1:1, 2:2, 3:2, 4:1, 5:1}` → only **1/12** survives HOT

### No rescue path
The **only** fallback is climate-starved common-injection (`engine_main_deployed.py:424-535`), which injects **SYSTEM items only** (`owner_id='SYSTEM'`) and **re-applies the same warmth filter** (`if warmth not in allowed_warmth: continue`). The L1 retry (`engine_main_deployed.py:521-528`) re-runs with the **same `temp_c`** and the **same `exclude_ids`**. There is **no widen/relax/drop-warmth escape hatch** anywhere in the build pipeline for the user's own warmth-0 items (exhaustive search for relaxation/retry logic found none).

### Reconciling the two failure_reasons
Both are real and have **distinct triggers**:

- **`hot_weather_no_lightwear` (WardrobeGapError @ L1, ×13)** — fires on a **deep `try_another`**: rolling `exclude_ids` (`v05_try_another_service.py:442-478`) removes the single surviving warmth-1 **BOTTOM** at L1 → `pool[BOTTOM]=0` → `starved |= {BOTTOM, FULL_BODY}` (`engine_main_deployed.py:436-437`) → common-injection runs but **cannot restore BOTTOM** (same temp gate + same exclude_ids) → defense-in-depth `not pool[BOTTOM] and not pool[FULL_BODY]` (`:557`) → `_emit_and_raise(_gap_reason_for({BOTTOM,FULL_BODY}, l3_required=False))` → generic-fallback branch (`:1292`, not l3_required) returns **`hot_weather_no_lightwear`**. Note: the WardrobeGap actually fires on **BOTTOM** starvation, not TOP.
- **`no_valid_outfits_after_L2` (PoolInsufficientError @ L2, ×7) / `no_outfits_after_force_axis_or_exclude_filter` (@ L5, ×3)** — pool **TOP:1 BOTTOM:1 survives, nothing starved, no injection** → L2 composes ≤1 candidate pair → `force_axis` filter *may* relax (`axis_relaxed`, `engine_main_deployed.py:855-887`) but the **`exclude_hashes` filter has NO graceful degrade** (`:888-901`) → removes the already-seen outfit → `candidates=[]` → 422/empty.

All failing events carry `occasion='safe'` (→ not in `OCCASION_FORMALITY` → `unknown` (3,6) ±2 → window `[1,8]`) and `force_axis` present with `exclude_hashes_count` up to 7 → these are **`try_another` recompose calls, not fresh builds**.

---

## 3. Blast radius (hard prod numbers)

| Metric | Value |
|---|---|
| Total active non-common items (prod-wide) | **356** |
| Items `warmth_level=0` or unset | **96** (82 explicit `'0'` + 14 truly unset) |
| % of TOP/BOTTOM/OUTER anchors permanently excluded at ALL temps | **25.9%** (56/216) |
| % of those anchors that survive HOT (`warmth==1`) | **8.3%** (18/216) |
| Active users with items | **7** |
| Users with ZERO surviving tops at HOT (own wardrobe) | **4 of 7 (57%)** |
| Users with ZERO surviving bottoms at HOT | **1 of 6** |
| Users blocked on ≥1 anchor family at HOT | **5 of 7** |
| `weather_suitability` NULL | **100% (356/356)** |
| `season` NULL | **100% (356/356)** |

**Events (last 30d):** 124 events across **9 distinct users** — `hot_weather_no_lightwear` 52, `no_valid_outfits_after_L2` 46, `no_outfits_after_force_axis_or_exclude_filter` 15, `cold_weather_no_outerwear` 9. **Today 2026-06-02:** 17-event spike, **all HOT, all duc2820**.

**SYSTEM catalog CANNOT rescue HOT.** At HOT only **TOP 4/49**, **BOTTOM 5/42**, **OUTER 0/21** SYSTEM commons carry `warmth==1`. Injection adds at most ~4 tops + ~5 bottoms system-wide, **shared across all users** → thin, homogeneous, near-identical fallback for everyone. HOT failure is **structural**; injection is not a viable mitigation as-is.

**Systematic, not random:** all 7 users share an identical drawer shape (exactly 16 tops + 12 bottoms each) — a shared seeded/demo wardrobe through one extraction pipeline. The warmth-tagging gap is a **systematic extraction defect**, not per-user noise. The bug is dominated by **explicit `'0'` tags** (real mislabeling), not just missing data — so a backfill must **re-derive** correct warmth, not merely fill nulls.

---

## 4. Secondary issues (ranked)

| # | Severity | Issue | Evidence (deployed) | Impact |
|---|---|---|---|---|
| V05-1 | **critical** | HOT bucket admits only `warmth==1`; tropical wardrobes collapse to 1-top/1-bottom with no safety net | `engine_v05_constants.py:266-267`; `_warmth` default 0 (`engine_layers:107`) | Primary cause — covered in §2 |
| V05-2 | **critical** | Common-injection re-suggests `exclude_ids` items, so `try_another` starves forever (`injected=5` but `pool_after_inject=0`) | duc2820 event 2026-06-02 03:47:31: `items_injected=5`, `pool_after_inject.BOTTOM=0`, `excluded_by_id=5`; `engine_main:486-529` re-runs L1 which drops injected commons via exclude filter (`engine_layers:186-188`) | Once a user excludes/sees a few outfits, "try another" can never recover this session |
| V05-3 | **high** | Mobile sends RecommendationMode (`safe`/`power`/`creative`) as `occasion`; backend maps every value to `unknown` (3,6) — occasion is dead end-to-end | `auxi HomeScreen.tsx:610,629`; `occasion='safe'` on 75/124 events; misses `OCCASION_FORMALITY` (`engine_v05_constants.py:272-289`) | Users can never get work/formal outfits from Home; formality permanently mid-casual |
| V05-4 | **high** | `weather_suitability` + `season` NULL on 100% of items and **never read** by V05; `warmth_level` is the sole weather signal | SQL 356/356 NULL; grep of `blueprints/recommendation/` for these fields = ZERO refs | Entire weather decision rides on one derived int; two LLM-populated fields are dead weight; one bad default collapses the pool |
| V05-5 | **high** | Rain footwear gate unsatisfiable: 100% of user AND SYSTEM footwear `is_water_resistant=false` → any `is_rainy=true` drops ALL footwear, no catalog rescue | `engine_layers:221`; SQL 48/48 user + 22/22 SYSTEM = false; injected commons hit same gate. **Latent for duc2820** (mobile sends `is_rainy=false` despite Saigon rain) but bricks recs for any client sending `is_rainy=true` | One weather-string flip → guaranteed "no outfits" for whole user base |
| V05-6 | medium | Gender decoupled from DB: mobile derives from local AsyncStorage `wardrobe_direction` (null→U), never reads User object; same user oscillates M/U across sessions | `auxi wardrobeDirection.ts:52-64,113`; duc2820 events flip U→M; under M the strict gate drops W-only items; `UserDTO.gender` validator rejects `''` (422) so local null→U fallback is load-bearing | Reinstall/clear-storage silently switches eligibility; DB gender (empty) never consulted |
| V05-7 | medium | MILD gates footwear to `[2,3]` (drops warmth-1 sandals); COOL requires OUTER≥3 / FULL_BODY≥4 that tropical wardrobes lack | `engine_v05_constants.py` MILD `[2,3]`, COOL `[3,4,5]` l3_required; `FOOTWEAR_WARMTH_GATE_TEMP=22`; cold hard-fail `engine_main:584-601` | "No outfits" / lost open footwear on cool/mild travel days |
| V05-8 | medium | L2 compose failure on a non-starved thin pool returns hard 422 instead of graceful 200 `wardrobe_gap` | `engine_main:710-740` — WardrobeGap(200) branch only fires if `starved` non-empty; else PoolInsufficient→422 | Blunt error instead of actionable "add lighter pieces" message |

**Note on the `W` event rows:** these are the separate **womenswear dress-exclusion bias** issue (already fixed/deployed 2026-05-31), distinct from this warmth-gate starvation.

---

## 5. Recommended fixes (ordered by impact / effort)

### PRIMARY (immediate unblock) — widen HOT/WARM buckets to include `warmth_level=0`

The two mirrored copies of the warmth-constraint function **must change together** (their docstrings cite each other as mirror source of truth).

**File 1 — `blueprints/recommendation/engine_v05_constants.py`, `warmth_constraint(temp_c)`, origin/main L234-241:**
```python
# BEFORE
    if temp_c > TEMP_HOT_THRESHOLD:
        return ([1], False)
    if temp_c >= TEMP_COOL_THRESHOLD:
        return ([1, 2], False)
    if temp_c >= TEMP_COLD_THRESHOLD:
        return ([2, 3], False)
    return ([3, 4, 5], True)
# AFTER
    if temp_c > TEMP_HOT_THRESHOLD:
        return ([0, 1], False)
    if temp_c >= TEMP_COOL_THRESHOLD:
        return ([0, 1, 2], False)
    if temp_c >= TEMP_COLD_THRESHOLD:
        return ([2, 3], False)
    return ([3, 4, 5], True)
```
(Also update the HOT/WARM docstring lines 225-226 to `[0,1]` / `[0,1,2]`.)

**File 2 (MANDATORY sync) — `utils/item_derivations.py`, `get_warmth_constraint(...)`, origin/main L162-176:**
```python
# BEFORE: > hot_threshold → ([1], False);  >= cool_threshold → ([1, 2], False)
# AFTER:  > hot_threshold → ([0, 1], False); >= cool_threshold → ([0, 1, 2], False)
```
(Update its "Temperature Ranges" docstring block, L157-158.)

**Cold safety preserved:** MILD stays `[2,3]`, COOL stays `[3,4,5]` — `warmth=0` never becomes cold-eligible (the exact property AU-306 protects). Over-warmth at 32°C is a far milder failure than NO outfit; HOT/WARM are the warm end where over-warmth carries no hypothermia risk.

**No other code change needed for the sync point:** `_load_common_safety_items` (`engine_v05.py origin/main ~L1170: if warmth not in allowed_warmth: continue`) **reuses** the same `allowed_warmth` array computed from `warmth_constraint(inp.temp_c)` at `:431/:489` → injection path widens **for free**. `_warmth()`'s missing→0 default stays unchanged (now hot-eligible, the desired behavior for untagged items). The L1 gate logic (`engine_layers:217`) is unchanged — the set it checks now includes 0.

**Risk:** `warmth=0` is overloaded (means both "lightest" AND "untagged/default"). A genuinely heavy but mis-tagged-0 item could now leak into HOT/WARM. Low blast radius, correct tradeoff; the durable fix is the data backfill below.

### SECONDARY (durable) — data backfill

1. **`warmth_level`:** re-derive for ~96 warmth-0/unset items (82 explicit `'0'` + 14 unset). Source of truth = the Gemini vision-extraction prompt that writes `styling_metadata.warmth_level` (no standalone derivation helper exists in `utils/item_derivations.py`). Fix at source: audit/strengthen the extraction prompt, then run a **one-off targeted backfill management command** (not hand-edited rows). The SYSTEM catalog itself needs this (biggest HOT buckets are `warmth=0`: TOP 12, BOTTOM 18, FOOTWEAR 7).
2. **`weather_suitability` + `season`:** NULL on 100% prod-wide — same fix-at-source path (extraction prompt must populate these JSON fields), then backfill.

### Tests to update (will fail on the bucket change — intentional)
- `tests/test_engine_v05_unit.py:198-199` → `warmth_constraint(30) == ([0,1], False)`, `warmth_constraint(22) == ([0,1,2], False)`. L200-201 (MILD/COOL) stay green.
- `tests/test_recommendation_v2.py:26,34` → `get_warmth_constraint(30) == ([0,1], False)`, `(22) == ([0,1,2], False)`. L30/38 unaffected.
- `tests/test_v05_logging_service.py:35` → if its WARM scenario logs `allowed_warmth`, update `[1,2]` → `[0,1,2]` (verify the temp it uses first).
- `tests/test_v05_engine_common_safety_items.py:190-200` → still passes as written (caller passes `[1]` literal), but encodes a stale assumption; add a case asserting warmth-0 IS included when `allowed_warmth=[0,1]`.

### Sync / contract note
`warmth_constraint` return values are **internal engine logic**, not part of the public `/api` contract or `API_DOCUMENTATION.md` → **no auxi mobile-client sync required**. Change is backend-only and behavior-additive (more outfits surface; none disappear). The V05-2 (injection-vs-exclude_ids loop), V05-3 (occasion conflation), and V05-5 (rain footwear) fixes are separate follow-ups requiring mobile + tech-lead coordination.

### Post-deploy verification
Re-run the v05-eval harness / `SELECT` on `v05_pool_insufficient_events` — `hot_weather_no_lightwear` for HOT sessions should stop recording for duc2820.

---

## 6. Repro / verification method

- **Deterministic source of truth:** deployed engine analyzed via `/tmp/engine_main_deployed.py` + `/tmp/engine_layers_deployed.py` and `git show origin/main:<path>`. The working tree is on `feat/backfill-cutout-rembg`, which differs from `origin/main` by **118 lines** in `engine_v05.py` (removes thin/COOL-enrichment) — all conclusions reasoned from **deployed** code, not the on-disk branch. Confirmed `engine_v05_constants.py` differs from origin/main only by AU-308 COLOR_FAMILY/CLASSIC_PAIRS (`warmth_constraint` untouched → deployed == on-disk); `engine_v05_layers.py` is **identical** to origin/main and to the `/tmp` dump.
- **Read-only prod SQL** (SELECT only): warmth distributions, survivor counts at 32°C, anchor-exclusion %, SYSTEM catalog warmth dist, `weather_suitability`/`season` NULL rates, gender_tags.
- **Recorded prod events:** `v05_pool_insufficient_events` filtered to duc2820 and to last-30d, by `failure_reason` × `climate_bucket` × `gender`.
- **Live HTTP eval blocked** by SECRET_KEY mismatch (qa-test/duc2820 401 on Railway-backed :5001) — substituted with deployed-code + DB + recorded-events triangulation.

### Counter-hypotheses tested & refuted
- "TOP reaches 0 at HOT" — **REFUTED** by live SQL (TOP=1) and prod events (TOP:1 no-inject, TOP:4 post-inject). The L1 WardrobeGap fires on **BOTTOM**, not TOP.
- Gender-drop as root cause — **REFUTED**: all duc2820 items carry `'U'` in gender_tags, gender field empty → user_gender `'U'` → allow {M,W,U}, no gender drop.
- Formality window dropping survivors — **REFUTED**: occasion `safe`→unknown→`[1,8]`; survivors have formality 2, well inside.
- On-disk branch misleading analysis — **controlled** by reasoning exclusively from deployed dumps + `git show origin/main`.
- Two failure_reasons share a trigger — **REFUTED**: distinct (WardrobeGap@L1 on empty family post-injection; PoolInsufficient@L2/L5 on 1×1 pool that can't compose / exclude_hashes empties candidates).

---

## 7. Open questions

1. **Backfill correctness:** do we trust a re-run of the current extraction prompt to fix the 82 explicit-`'0'` mislabels, or does the prompt's `warmth_level` rubric itself need redesign first? (The systematic skew toward 0 suggests the prompt, not transient errors.)
2. **V05-2 injection loop:** widening buckets unblocks the *fresh* build, but the `try_another` `exclude_ids`/`exclude_hashes` depletion (no graceful-degrade) still strands deep retry sessions. Should `exclude_hashes` get an `axis_relaxed`-style escape hatch (re-show oldest-seen outfit rather than 422)?
3. **V05-3 occasion conflation:** is the fix to stop sending mode-as-occasion from mobile, or to add `safe/power/creative` to `OCCASION_FORMALITY`? Needs tech-lead + mobile-dev contract decision.
4. **V05-5 rain gate:** ship water-resistant SYSTEM footwear, or relax the rain gate to a soft penalty? Currently latent (mobile not sending `is_rainy`) but a one-flag time bomb.
5. **SYSTEM catalog seeding:** even after the bucket fix, should we seed dedicated `warmth==1` SYSTEM lightwear so injection is a real HOT safety net rather than a ~9-garment shared pool?
6. **Live HTTP eval:** resolve the SECRET_KEY mismatch to enable end-to-end on-device verification (currently triangulated only).
