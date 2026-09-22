# Build-Around linen short → first outfit has no top (34°C) — Root-Cause Investigation

- **Date:** 2026-07-13
- **User:** vietdesign81@gmail.com
- **Symptom:** Uploads linen shorts (display tag **`bottom`**, correct). Uses **Build around this**. First suggestion = **short + sandal only (2 items, no top)**. After swiping 3–4× → **short + shirt + sandal (3 items, ok)**. Weather **34°C**.

> **⚠️ SUPERSEDED — read §FINAL first.** §1–§5 below were an early hypothesis
> (HOT warmth-gate starvation) written before the backend repo was accessible.
> Once `auxi-wardrobe/auxi-backend` was cloned, the warmth-gate fix was found
> **already merged to `main`**, and the true root cause was located in code and
> **fixed**. §FINAL is authoritative; §1–§5 kept only as investigation trail.

---

## FINAL — confirmed root cause + fix delivered

**Root cause (confirmed in code):** `utils/category_taxonomy.py :: resolve_category_family`
had a blind-trust hole. It validates a `category_family='FULL_BODY'` claim against
structured codes, but when an item has **no `category_code`/`layer_code`** it
**trusted the FULL_BODY column** (old line 125-126) and **never consulted the
display `category` column**. The linen short was auto-tagged
`category_family='FULL_BODY'` with null codes while its display `category='bottom'`
was correct. So the engine bucketed it as a **one-piece anchor** → composed
`[short, sandal]` (2 items, no top). The swipe's `try_another` recompose cycled to
the **`layering` axis**, which adds an **OUTER** over the "one-piece" → the 3-item
`[short, shirt, sandal]` the user saw (the "shirt" is an outer layered on the
mis-classified short). This is why the primary was broken but the swipe looked ok.

My first instinct (engine treats the short as a one-piece) was right about the
*mechanism*; it was wrong about the *layer* — not the Gemini tag (`bottom` is
correct) but a `category_family` column drift the resolver failed to catch.

**Fix (delivered — repo `auxi-wardrobe/auxi-backend`, branch `claude/short-linen-build-outfit-g50r9x`, commit `1c47b6d`):**
- `resolve_category_family(...)` now takes the display `category` and uses it as a
  tiebreaker when a FULL_BODY claim has **no structured codes**: a non-one-piece
  display (`bottom`, `top`, …) contradicts the claim → re-derive family; a
  one-piece display (`dress`, `onepiece`) corroborates → keep FULL_BODY. Structured
  codes stay the strongest signal (checked first). Rows with no codes AND no
  known display value are unchanged (legacy/fixtures). Added
  `DISPLAY_CATEGORY_TO_FAMILY` (structured enum, not name-parsing — AU-299 safe).
- Threaded `item.category` through the 3 resolver call sites: engine L1 bucketing
  (`engine_v05_layers._category_family`), signature `is_one_piece`
  (`engine_v05_signature`), onboarding quota (`v05_onboarding_service`).
- **Read-side fix → repairs existing drifted rows (incl. this user's) at query
  time**, no data backfill needed to stop the bad outfit.
- Tests: resolver display-tiebreaker cases + engine regression that a drifted
  linen short at 34°C buckets `BOTTOM` and is never served as `[short, sandal]`.
  Verified green: `test_category_taxonomy` 23 passed, engine-unit 93, onboarding 22,
  build+try-another 65. (7 unrelated failures confirmed pre-existing on clean `main`.)

**Follow-ups (not required to fix this bug, worth a ticket):**
1. Data backfill: re-derive `category_family` for rows where it's `FULL_BODY` but
   `category` is a separates value + codes are null (data hygiene; the read-side
   fix already neutralizes them at runtime).
2. Write-side: `ai_service._validate_taxonomy` could cross-check a FULL_BODY
   extraction against the display category too, to stop new drift at the source.

- **Scope note (original):** the §1–§5 analysis below reasoned from on-file reports
  before backend code access; superseded by §FINAL.

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
