# V05 Womenswear FULL_BODY (One-Piece) Bias — Structural Exposure Simulation

**Date:** 2026-05-31
**Author:** backend-dev
**Type:** Measurement harness — findings only (NO engine code modified)
**Script:** `wardrobe-backend/scripts/eval_v05_fullbody_exposure.py`
**Branch:** `feat/backfill-cutout-rembg`
**Run:** `.venv/bin/python scripts/eval_v05_fullbody_exposure.py` (deterministic, seeded, no DB/network)

---

## TL;DR verdict

**YES — the structural dress bias manifests, and it is materially LARGER than the
code review's "≈2× lift" hypothesis.** In a 50/50 BALANCED womenswear wardrobe the
engine produces **100% one-piece (dress) outfits** for `gender="W"` (vs a 50% fair
baseline). The hypothesized 2× lift is the *floor*, observed only when separates
heavily outnumber dresses (DRESS-LIGHT). The mechanism is **winner-take-all**, not
proportional: the `W_FB_BIAS=2.0` weight combined with the top-N anchor cutoff in
`select_anchors` makes TOP anchors **unreachable** whenever dresses ≥ the cutoff size.

The `gender="M"` hard gate is clean (0% dresses everywhere). The cold-weather torso
cap holds (max 2 torso pieces, never 3). The novelty layer **cannot** throttle
consecutive dresses (P(dress|dress) ≈ base rate; 8-long all-dress runs are routine).

---

## Method & faithfulness

The harness imports the REAL engine layer functions and drives them directly,
replicating the BUILD orchestration loop (`engine_v05.py:564-668`, `force_axis=None`
branch):

```
layer1_feasibility(items, temp_c, user_gender, occasion)
  -> select_anchors(pool, user_gender, mood, rng, n_anchors=max(count*3, 6), stratify=True)
  -> layer2_compose_variants(anchor, pool, ..., n_variants=COMPOSE_VARIANTS_PER_ANCHOR=2)
```

Synthetic womenswear wardrobes: every item `versatility=5`, `formality=5`,
`visual_weight=3`, `pattern=SOLID`; colors cycled over neutrals+cools so every pair
classifies SAFE (no spurious HIGH_RISK filter); silhouettes varied; bottoms
`MID_RISE`, tops `REGULAR` length (so the CROPPED+LOW_RISE R6 filter never fires);
≥6 FOOTWEAR and ≥6 OUTER so slots never starve. This isolates **mechanism #1 (anchor
bias)** with all the other L2 filters deliberately satisfied.

Measurement point: candidate set **after L2, before L4/L5/L6**. This is correct — the
ranking/diversity/novelty layers never change a candidate's *anchor family*, and the
whole premise of M3 is that L5 novelty has no family field to throttle on.

**Driver note:** I drove the layer functions rather than `engine.build()` because the
full build path requires a DB `Session` (signal-vector lookup + common-item
injection). The layer-level loop is byte-faithful to the orchestration for the anchor
+ compose stages, which is exactly what the three metrics measure.

**M3 approximation (stated explicitly):** the live `/try_another` path is
Redis/DB-coupled (session cache, SETNX lock, pool). I approximated it faithfully by
replicating the engine recompose loop: cycle the real `_AXIS_CYCLE` order
`[silhouette, layering, color, footwear, accessory]`
(`services/v05_try_another_service.py:107-113`); on each step drive the engine
recompose branch (`force_axis` + `current_signature` + the `force_layering`/
`append_accessory` flags `_build_recompose_input` would set) and exclude the prior
outfit's exact item-id set (whole-outfit dedupe, like `exclude_hashes`). Same anchor-
bias + compose code, force_axis path. **Caveat:** this is a structural sim, not live
prod data — pool-cache hits, LLM-3 picking, and cross-session lockout are out of
scope; the point is the *engine's* structural behavior, which is what those layers
sit on top of.

All cells: **N=250 seeds** for M1/M2, **N=120 seeds × 8-step sequences** for M3
(both exceed the ≥200 / ≥100 requirement).

---

## M1 — FULL_BODY-anchor share vs fair baseline

Fair baseline = `FULL_BODY / (FULL_BODY + TOP)`. BALANCED fair = 50%, DRESS-LIGHT =
20%, DRESS-HEAVY = 80%.

| mix | temp | gender | fb | top | total | **fb_share** | fair | **lift** | outfits/call |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| BALANCED | 30C | **W** | 4495 | 0 | 4495 | **100.0%** | 50% | **2.00** | 17.98 |
| BALANCED | 30C | M | 0 | 2073 | 2073 | 0.0% | 50% | 0.00 | 8.29 |
| BALANCED | 30C | U | 0 | 2073 | 2073 | 0.0% | 50% | 0.00 | 8.29 |
| BALANCED | 20C | **W** | 4495 | 0 | 4495 | **100.0%** | 50% | **2.00** | 17.98 |
| BALANCED | 20C | M | 0 | 2073 | 2073 | 0.0% | 50% | 0.00 | 8.29 |
| BALANCED | 20C | U | 0 | 2073 | 2073 | 0.0% | 50% | 0.00 | 8.29 |
| BALANCED | 10C | **W** | 2818 | 0 | 2818 | **100.0%** | 50% | **2.00** | 11.27 |
| BALANCED | 10C | M | 0 | 1080 | 1080 | 0.0% | 50% | 0.00 | 4.32 |
| BALANCED | 10C | U | 0 | 1080 | 1080 | 0.0% | 50% | 0.00 | 4.32 |
| DRESS-LIGHT | 30C | **W** | 1996 | 1466 | 3462 | **57.7%** | 20% | **2.88** | 13.85 |
| DRESS-LIGHT | 30C | M | 0 | 2686 | 2686 | 0.0% | 20% | 0.00 | 10.74 |
| DRESS-LIGHT | 30C | U | 0 | 2686 | 2686 | 0.0% | 20% | 0.00 | 10.74 |
| DRESS-LIGHT | 20C | **W** | 1996 | 1466 | 3462 | **57.7%** | 20% | **2.88** | 13.85 |
| DRESS-LIGHT | 10C | **W** | 1205 | 587 | 1792 | **67.2%** | 20% | **3.36** | 7.17 |
| DRESS-HEAVY | 30C | **W** | 4495 | 0 | 4495 | **100.0%** | 80% | **1.25** | 17.98 |
| DRESS-HEAVY | 20C | **W** | 4495 | 0 | 4495 | **100.0%** | 80% | **1.25** | 17.98 |
| DRESS-HEAVY | 10C | **W** | 2759 | 0 | 2759 | **100.0%** | 80% | **1.25** | 11.04 |
| DRESS-HEAVY | 30C | M | 0 | 932 | 932 | 0.0% | 80% | 0.00 | 3.73 |
| DRESS-HEAVY | 30C | U | 2496 | 929 | 3425 | 72.9% | 80% | 0.91 | 13.70 |
| DRESS-HEAVY | 10C | U | 1562 | 425 | 1987 | 78.6% | 80% | 0.98 | 7.95 |

(MILD rows for M/U are identical to HOT — temperature only changes pool size via
warmth, not the anchor-family ratio. Full matrix in stdout.)

### Headline (BALANCED / MILD)
- **W: 100.0% one-piece vs 50% fair → 2.00× lift, but effectively a complete
  takeover** (TOP anchors produce ZERO outfits).
- **M: 0.0%** — hard gate (`forbid_family={"FULL_BODY"}` for menswear,
  `engine_v05_layers.py:165`) is clean. Sanity confirmed.
- **U: 0.0%** at BALANCED/DRESS-LIGHT — unisex has FB bonus = 1.0, so with equal
  versatility TOP and FB tie at weight 5.0; the score-sort + cutoff is then
  order-stable and TOP items (added to the candidate list first,
  `engine_v05_layers.py:274` before `:283`) win the stable sort, so dresses fall
  below the cutoff. U only surfaces dresses in DRESS-HEAVY (72.9%, *below* its 80%
  fair → lift 0.91), i.e. unisex is mildly *anti*-dress, the opposite of W.

### Why 100% and not 67% (the key finding)
The review predicted "≈2× lift" assuming proportional reweighting. The engine is
**winner-take-all** because `select_anchors` applies a hard top-N cutoff
(`engine_v05_layers.py:315-326`) *after* the 2× weighting:

- Candidates: 10 TOP @ weight `5.0`, 10 FB @ weight `5.0 × W_FB_BIAS(2.0) = 10.0`.
- Sort descending → all 10 FB precede all 10 TOP.
- `cutoff = max(int(20 × 0.30), min(n_anchors=9, 20)) = 9` → `top_pool` = the 9
  highest = **all FB**. TOP is never in the reachable set.

Verified directly: across 8 seeds, `select_anchors` returned 9 FB / 0 TOP every time.
So in any womenswear wardrobe where `dress_count ≥ anchor_cutoff`, separates are
**structurally excluded**, not merely down-weighted. The 2.00× lift figure is a
red herring (it's just 100%/50%); the real damage is the categorical exclusion.

The clean 2.00× *floor* shows up only in DRESS-LIGHT (4 FB, 16 TOP): there the 4
weighted FB (weight 10.0) take 4 of the 9 cutoff slots and 5 TOP fill the rest, so
~58-67% of *anchors* are dresses → 2.88–3.36× lift on output share. As dresses get
rarer the lift *rises* (3.36× at COOL DRESS-LIGHT) because each dress is
disproportionately likely to clear the cutoff.

---

## M2 — Cold-weather torso-piece distribution (temp=10C COOL, gender=W)

Pooled across all 3 mixes, N=250 seeds each. Two FB-warmth variants.

### Variant A — thin dresses (FB warmth < `WARM_FULL_BODY_THRESHOLD=4`)
OUTER is genuinely required (no warm-FB substitution path).

- torso-piece distribution `{2: 7369}` — **every** cold outfit has exactly 2 torso
  pieces (FULL_BODY + OUTER, or TOP + OUTER).
- **max torso pieces = 2. 3-piece torso: 0 occurrences.** ✅
- **OUTER present: 100.0%** (7369/7369).
- cold layer present (OUTER or warm-FB): 100.0%.

### Variant B — warm dresses (FB warmth ≥ `WARM_FULL_BODY_THRESHOLD=4`)
`fb_substitutes_outer` path active (`engine_v05_layers.py:439-442`).

- torso distribution `{1: 10986, 2: 660}` — warm dresses stand alone as 1 torso
  piece (self-sufficient L3 substitute); the 660 two-piece cases are TOP+OUTER
  outfits where a TOP anchor was chosen.
- **max torso = 2. 3-piece torso: 0.** ✅
- warm-FB substitute present in 10986 outfits; OUTER present in 5.7%; **cold layer
  (OUTER or warm-FB) present: 100.0%** — no user is left without a cold layer.

**M2 verdict:** torso cap holds (max 2, never 3), and 100% of cold outfits carry
adequate cold-weather coverage in both variants. The `fb_substitutes_outer` logic
works as designed. No cold-weather safety defect.

---

## M3 — Consecutive-dress (novelty-can't-throttle), gender=W, BALANCED, temp=20C MILD

N=120 seeds × 8-step axis-cycling sequences.

| metric | value |
|---|---|
| total outfits across sequences | 960 |
| base dress rate | **99.9%** |
| P(dress_{i+1} \| dress_i) | **99.9%** (839/840) |
| longest consecutive-dress run | **max=8, avg=7.99** |
| avg per-sequence dress rate | 99.9% |
| P(d\|d) − base_rate | **+0.0 pp** |

**M3 verdict:** the novelty layer does **NOT** reduce dress-after-dress below the
base rate (`P(d|d) − base ≈ 0`). 8-step try_another sequences are **all dresses**
in essentially every seed (longest run avg 7.99 of 8). Root cause confirmed by
inspection: `compute_vibe_signature` (`engine_v05_signature.py:76-82`) carries
`dominant_color_family / dominant_silhouette / formality_band / statement_level_avg /
aesthetic_tags` — **no garment-family field**. L5 novelty
(`layer5_novelty_score`) therefore has nothing to penalize "another dress" on; two
distinct dresses with different silhouette/color read as fully novel. The user
asking "try another" gets dress → dress → dress → dress indefinitely. Because BALANCED
W is already 100% dress at the anchor stage (M1), the base rate is ~100% and the
sequence has no chance to escape to separates.

---

## Caveats

- **Structural sim, not prod data.** Synthetic wardrobes are deliberately
  pairing-friendly (uniform versatility/formality, SAFE colors) to isolate the
  anchor-bias mechanism. Real wardrobes with skewed versatility/formality will shift
  absolute numbers, but the winner-take-all cutoff dynamic is structural and
  versatility-driven, so the direction and magnitude hold wherever dresses aren't
  starved by L1.
- M1/M2 measure the post-L2 candidate set; L6 packaging picks a subset for the user,
  but never changes anchor family, so the *share* is representative of what the user
  can be served.
- M3's try_another approximation drives the engine recompose path directly (not the
  Redis pool / LLM-3 picker). The family-blind signature is in the engine layer
  either way, so the throttle-absence conclusion is unaffected by that boundary.
- `U` behavior is sensitive to candidate-list insertion order (stable-sort tie-break
  favors TOP). With real non-uniform versatility this tie won't be exact, so U's 0%
  at BALANCED is a uniform-data artifact — but it still shows U has NO pro-dress bias,
  which is the relevant qualitative result.

---

## Recommendation surface (for tech-lead, not acted on here)

The bias is real and severe for womenswear. Three independent levers, all in
`engine_v05_constants.py` / `engine_v05_layers.py` (NOT touched here):

1. **The cutoff, not the weight, is the dominant lever.** `W_FB_BIAS=2.0` would be
   merely a 2× *proportional* nudge if anchor selection sampled proportionally over
   the full candidate set. The top-N cutoff (`select_anchors:315-326`) converts it
   into categorical exclusion. Consider sampling FB vs separates as separate streams
   with a target ratio, or applying the bias as a sampling probability rather than a
   pre-cutoff score multiplier.
2. **No counterweight after a dress is served.** Add a garment-family field to
   `compute_vibe_signature` so L5 novelty can throttle consecutive one-pieces (fixes
   M3 directly).
3. **Mood stacking** (`MOOD_FB_BIAS=1.3` on `calm`) compounds #1 to 2.6× — not
   exercised in these runs (mood=None) but would push DRESS-HEAVY-U and DRESS-LIGHT-W
   further toward 100%.

---

**Status:** DONE
**Summary:** Built + ran a real-engine structural sim; womenswear dress bias confirmed
**materially larger than predicted** — BALANCED/W = 100% dresses (categorical TOP
exclusion via the anchor cutoff, not a 2× nudge), M-gate clean (0%), cold torso cap
holds (max 2, OUTER 100%), and novelty cannot throttle consecutive dresses
(P(d|d)≈base, 8-long all-dress runs).
**Concerns/Blockers:** none — measurement-only; no engine code changed.
