# Build-Around linen short → first outfit has no top (34°C) — Root-Cause Investigation

- **Date:** 2026-07-13
- **User:** vietdesign81@gmail.com
- **Symptom:** Uploads linen shorts (tagged **`BOTTOM`**, correct). Uses **Build around this**. First suggestion = **short + sandal only (2 items, no top)**. After swiping 3–4× → **short + shirt + sandal (3 items, ok)**. Weather **34°C**.
- **Scope:** findings only. Backend code (`wardrobe-backend`) is a separate submodule, not clonable in this session — reasoned from umbrella reports + deployed-code analysis already on file. DB/prod-event verification requires backend-dev/devops.

---

## 0. Correction to earlier hypothesis (retracted)

Initial theory was **Gemini auto-tag mislabeled the shorts as `FULL_BODY` (one-piece)** → engine needs only footwear → short + sandal. **This is WRONG.** User confirms the tag shown is **`BOTTOM`**, and a later swipe pairs the short *with a top*, which a one-piece structure forbids. The category is correct. The bug is **downstream in the recommendation engine, not the tagger.**

---

## 1. Root cause (primary): HOT warmth-gate starves TOPs at 34°C

34°C → climate bucket **HOT** (`temp_c > 28`). The deployed L1 warmth gate admits **only `warmth_level==1`** for TOP/BOTTOM/OUTER/FULL_BODY, and treats missing/`0` warmth as **excluded at all temps** (fail-closed default `0`, AU-306). Refs (deployed code, per `plans/reports/v05-eval-260602-1353-hot-warmth-zero-exclusion.md`):

- `engine_v05_constants.py:266-267` `warmth_constraint` → HOT = `([1], False)`; no bucket contains `0`.
- `engine_layers_deployed.py:100-107` `_warmth` → missing → `0`.
- `engine_layers_deployed.py:214-219` L1 gate → `if _warmth(it) not in allowed_warmth: skip`.

**This is a known, live, SYSTEMATIC prod defect (V05-1, "critical").** Blast radius from that report: 25.9% of all TOP/BOTTOM/OUTER anchors are permanently excluded at every temperature; at HOT only 8.3% survive; **4 of 7 active users have ZERO surviving tops at HOT.** `warmth_level` is NULL/`'0'` on ~96 items due to a systematic extraction-prompt skew (real mislabels, not just missing data).

**Consequence for this case:** at 34°C, vietdesign81's tops are almost entirely filtered out at L1 before composition ever runs. Build-around pins the short (a BOTTOM) and then **cannot find a TOP to complete `TOP + BOTTOM + FOOTWEAR`** → the outfit surfaces without a top.

## 2. Root cause (secondary): a structurally-incomplete outfit is allowed to surface

Per the official rubric P0 hard gate (`.claude/skills/v05-eval/references/rubric.md:54-60`), an outfit missing a TOP (with no FULL_BODY) is a **HARD_REJECT**. Yet the Build-around primary surfaced `BOTTOM + FOOTWEAR` (2 items). So when the TOP slot is starved, the pinned/build path emits a **degenerate 2-item outfit instead of hard-rejecting or repairing the slot.** That structural-completeness gap on the pinned-anchor build path is the second defect — it turns "no valid top at HOT" (a should-be gap/CTA) into "here is a broken outfit."

## 3. Why swiping "fixes" it

Swipe → `try_another` → **recompose** path, which differs from the primary `/build`:

- Recompose runs with `widen_candidates=LLM3_ENABLED` and oversamples anchors, and **cycles a variation axis** `[silhouette, layering, color, footwear, accessory]` (`flow-map-260529-1428-try-another-cross-repo.md` §3–5; `backend-dev-260527-1541-v05-tryanother-pool-analysis.md`).
- On the **`layering`** axis the engine forces an **OUTER** into the outfit. So the "shirt" that appears after 3–4 swipes may be an **OUTER layered over the short**, or a TOP recovered via the wider/common-injected search — either way the later path fills the middle slot the narrow primary left empty.

This cleanly explains the observed asymmetry: **primary build = narrow, top-starved → 2 items; later recompose = wider + axis-driven → 3 items.**

> ⚠️ Open point that changes the fix surface: **is the swipe "shirt" a `TOP` or an `OUTER`?** If `OUTER`, the 3-item outfit is a short + jacket + sandal with *still no top underneath* — only cosmetically "ok." Confirm via item categories in the served outfit (check #2 below).

---

## 4. Verification checks (need DB + prod events — backend-dev/devops)

1. **Top warmth distribution for this user at HOT** — confirms top starvation:
   ```sql
   SELECT category_family,
          styling_metadata->>'warmth_level' AS warmth, count(*)
   FROM wardrobe_items
   WHERE user_id = (SELECT id FROM users WHERE email='vietdesign81@gmail.com')
     AND is_active
   GROUP BY 1,2 ORDER BY 1,2;
   -- expect: few/zero TOP rows with warmth_level='1' → tops filtered out at 34°C
   ```
2. **Structure of the first vs later served outfit** — did the first outfit truly lack a TOP, and is the later "shirt" a `TOP` or `OUTER`? Pull the recommendation/`v05_pool_insufficient_events` rows for this user (filter `climate_bucket=HOT`), inspect item `category_family` per outfit + any `wardrobe_gap`/`starved` flags.
3. **The uploaded short's own `warmth_level`** — if NULL/`'0'` it's also a candidate to be wrongly excluded as the pinned BOTTOM at some point.

---

## 5. Fix recommendations

**Root (already specified, high-confidence) — widen HOT/WARM warmth buckets to include `0`.** Per the hot-warmth report §5 PRIMARY: change `warmth_constraint` (and its mirror `utils/item_derivations.py:get_warmth_constraint`) so HOT → `([0,1], False)`, WARM → `([0,1,2], False)`; MILD/COOL unchanged (cold safety preserved). Backend-only, behavior-additive (more outfits surface). Plus the **`warmth_level` backfill/extraction-prompt fix** for the ~96 mis-tagged items.

**Secondary (this case specifically) — enforce structural completeness on the Build-around primary.** When the TOP slot can't be filled (starved), the pinned/build path must **hard-reject → wardrobe_gap CTA**, or repair via the widened/common-injection search **before** returning — never surface `BOTTOM + FOOTWEAR`. Bringing `/build` to parity with the recompose widen path (or gating the primary through the same completeness check the swipe path effectively passes) removes the "first card is broken, later cards are fine" asymmetry.

**Tertiary — disambiguate the swipe result.** If check #2 shows the "shirt" is an OUTER, add a garment-family/`is_one_piece`-aware coherence rule so a bare short never reads as fully dressed via an outer alone at HOT.

---

## 6. Unresolved questions

1. Is the middle item in the "ok" 3-item outfit a **TOP** (composition recovered) or an **OUTER** (layering axis) — decides whether check #2 confirms a true fix or a cosmetic one, and whether fix #3 is needed.
2. Exact code path by which the Build-around **primary** emits a 2-item outfit rather than hard-rejecting — needs the `wardrobe-backend` build/compose + pinned-item source (not accessible here).
3. Does vietdesign81's own uploaded short carry a valid `warmth_level`, or is it part of the untagged-`0` cohort?
