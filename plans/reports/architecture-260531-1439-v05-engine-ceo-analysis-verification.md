# V05 Recommendation Engine — CEO Analysis vs Real Code (Verification)

**Date:** 2026-05-31 · **Method:** 8 adversarial verifiers, each with `file:line` evidence, cross-checked by hand · **Engine:** `wardrobe-backend/blueprints/recommendation/engine_v05*.py` + `services/v05_*.py`

> The CEO shared a fashion-architecture critique (two main claims + a rules wishlist). It uses vocabulary `L1/L2/L3/BT/SH` and `MODE A/B`. This doc grounds every claim against the actual V05 "Try Another" engine.

---

## 0. The vocabulary reframe (load-bearing)

The analysis says **"L1 = dress/jumpsuit."** That is wrong in both engines:

| Analysis term | V2 engine (`SYS_L2_TEE_…` item IDs) | V05 "Try Another" engine (active) |
|---|---|---|
| L1 | **base** layer (tee) | — (no L-codes) |
| L2 | mid layer | — |
| L3 | outer | — |
| dress/jumpsuit | (FULL_BODY-ish) | **`FULL_BODY`** family |

V05 has **no L1/L2/L3** — it uses families `TOP / BOTTOM / FOOTWEAR / OUTER / FULL_BODY / ACCESSORY`. The analysis is really talking about V05 (axes, controlled variation) but borrows V2 vocabulary and mis-defines L1. **Translate every "L1" in the analysis → `FULL_BODY` (one-piece).**

---

## 1. Verdict table

| # | Claim | Verdict | One-line reality |
|---|---|---|---|
| 1 | Womenswear over-indexes to one-piece; no exposure cap | ✅ **CONFIRMED** | Bias is **explicit** (`W_FB_BIAS=2.0`) + 2 structural amplifiers; **zero counterweight** |
| 2 | Cold weather can't stack base+mid+outer | ✅ **CONFIRMED** | Torso = max `{1 TOP}+{1 OUTER}`; L1+L2 collapsed into one TOP family |
| — | MODE A / MODE B exist & how it picks | 🟡 PARTIAL | Two paths real, but no "mode chooser" — emergent from a weighted anchor draw |
| — | Flat family code, no base/mid sub-role | 🟡 PARTIAL | True (flat), but **cardigan = OUTER not TOP** — analysis mislabels it |
| — | Footwear is secondary, no identity pull | 🟡 PARTIAL | Last-picked TRUE; "no identity pull" **FALSE** (feeds formality_band + style tag) |
| — | None of the 7 "MUST HAVE" rules exist | 🟡 PARTIAL | texture/per-user-temp/hero/seasonal **absent**; visual-weight + occasion **already exist** |
| — | Layering axis "only adds a jacket" | 🟡 PARTIAL | It's **count-based**, add-only, fires only when prior layers=0; cardigan already works |
| — | "~70-80% core logic covered" | 🟡 PARTIAL | 6/7 real; "expression" is a weak-stub; dresses skip fit-balance entirely |

---

## 2. The two CONFIRMED claims (worth a ticket)

### 2.1 Womenswear → one-piece bias is real **and explicit** — no counterweight

Four mechanisms push dresses up; **nothing pushes back**:

1. **Explicit 2× anchor weight.** `W_FB_BIAS = 2.0` (`engine_v05_constants.py:173`, comment *"Womenswear users get 2× weight on FULL_BODY"*), ×`MOOD_FB_BIAS=1.3` if calm → up to **2.6×** dress-anchor probability vs an equally-versatile top (`engine_v05_layers.py:277-284`). Men are hard-blocked from FULL_BODY (`:165`), so this is womenswear-specific by design.
2. **"Completes faster."** Dress path = 1 non-anchor slot (`FULL_BODY,FOOTWEAR`); separates = 2 (`TOP,BOTTOM,FOOTWEAR`) (`constants.py:424-425`). Fewer pairing constraints → composition aborts less often.
3. **"Scores higher" (structural).** Outfit score = mean of non-anchor slot scores; **anchor is never scored** (`:465-466,561-562`). Dress = mean of 1 pairing; separates = mean of 2 → dress has less downside variance → ranks ≥ separates.
4. **Dresses skip fit-balance.** Silhouette contrast fires **only TOP×BOTTOM** (`:704-707`); FULL_BODY gets flat `sil=1.0`. So dresses dodge a scoring dimension that could penalize them.

**No exposure/frequency control exists:** `vibe_signature` has **no garment-family field** (`engine_v05_signature.py:76-82`); Layer-5 novelty penalizes only color/silhouette/formality/tags (`:1007-1031`) → **two different-colored dresses read as "fully novel"**, so novelty pressure can never throttle "another dress." No axis swaps dress↔separates; no per-response dress quota.

> **Caveat — this is intentional tuning, not a bug.** `W_FB_BIAS=2.0` is a deliberate product lean. The defensible critique is: the lean has **zero counterweight** and isn't **context-modulated** (work vs casual vs cold). The analysis's context-ratio table (work 20-30%, casual-hot 50%, cold 15-20%) is a reasonable design target — but it's *re-tuning + adding a cap*, a product decision for the CEO.

### 2.2 Cold-weather 3-layer stacking is structurally impossible (strongest point)

Torso = **at most `{1 TOP} + {1 OUTER}`**. Root cause is two-fold:
- Only **one** TOP slot + **one** OUTER slot in the slot order; no MID slot (`engine_v05_layers.py:434-498`).
- **L1 (base) and L2 (mid) are collapsed into a single `TOP` family** at tagging time (`migrations/.../v05a1b2c3d4e_…:80-81`: `L1,L2 → 'TOP'`). So a tee and a knit can never coexist — they fight for the one TOP slot.

Correction to the analysis: a **cardigan is tagged `OUTER`** (`commonItems/generate_manifest.py:23`), not a mid — so `tee+cardigan+coat` is *doubly* impossible (cardigan vs coat for the one OUTER slot). Only knit/sweater/hoodie/turtleneck are TOP-family "mids," and they can't stack over a base tee.

> Validates the analysis's **"Layer Role (base/mid/outer)"** proposal. Real fix = (a) un-collapse TOP into base vs mid roles, (b) add a MID torso slot in cold buckets. **Deepest change of all** — touches schema, backfill, scoring, *and* the try_another layering axis.

---

## 3. Where the analysis is WRONG / already done (don't rebuild)

- **Visual Weight — ALREADY EXISTS.** `_visual_weight()` int 1-5, outfit-level summed cap `VISUAL_WEIGHT_CAP=16` (COOL 20), per-slot running enforcement (`layers.py:103-104,458,535,680-681`). Only the categorical LIGHT/MED/HEAVY banding + "max-2-heavy count" is missing → **extend, don't add.**
- **Occasion/effort — ALREADY MODELED** as formality windows `OCCASION_FORMALITY` (`constants.py:272-289`), gates + scores. Only the literal "1-5 effort integer" is missing. (Effort ≠ formality exactly, but the window does most of the work.)
- **Footwear "no identity pull" — FALSE.** Footwear feeds `formality_band` (flat mean over all items, incl. footwear) and the dominant style tag (`signature.py:61-62`). It already pulls identity; the open question is only whether to *over-weight* it — debatable, and ironically the analysis's "most important" item is its weakest claim.
- **Silhouette memory — PARTIAL.** Silhouette is tracked (`dominant_silhouette`, novelty pressure, force_axis bias). Missing = a **durable per-user** shape profile across sessions. Add a persistence layer, not the concept.
- **Layering axis "add a jacket" — imprecise.** Measures **layer COUNT** of `{OUTER,FULL_BODY}` (`engine_v05_axis.py:55-56,87-92`); `force_layering` fires **only when prior layers=0** and only **adds** (`engine_v05.py:619-628`). "Add cardigan" already works (cardigan=OUTER). Real gaps: count-only, add-only-from-zero, no drop/swap, silent no-op when prior already layered.

## 4. Genuinely ABSENT (greenlight to add, net-new)

- (c) **Texture conflict** — no fabric/texture field scored anywhere (`_score_pair_for_slot` reads only color/silhouette/formality/length-rise).
- (d) **Per-user temperature sensitivity** — `warmth_constraint(temp_c)` is global thresholds (28/20/15°C), no per-user offset.
- (f) **Hero-item rule** — no statement-piece designation.
- (g) **Seasonal palette drift** — color scoring is static, no season/month input.

---

## 5. The connective insight

The reason womenswear *feels* dress-heavy isn't one knob — it's **four mechanisms stacked one direction with zero pushback** (§2.1). Any fix that touches only one (e.g. just lowering `W_FB_BIAS`) leaves three intact. A real fix needs either a **counterweight** (one-piece exposure cap keyed on `FULL_BODY` in the signature/novelty layer) or **context modulation** of the bias — plus closing the fit-balance gap so dresses stop skipping a scoring dimension.

## 6. Suggested priority (engineering view, CEO decides)

1. **One-piece exposure counterweight** (§2.1) — small, high-impact, addresses the loudest symptom. Add `FULL_BODY` flag to `vibe_signature` + novelty penalty for repeated one-piece; optionally context-modulate `W_FB_BIAS`.
2. **base/mid/outer layer roles + cold MID slot** (§2.2) — high value, but deepest (schema + backfill + scoring + axis). Plan as its own epic.
3. **Net-new rules** (§4) — texture / per-user temp sensitivity / hero item — incremental, do after 1-2.
4. **Skip / re-frame:** visual-weight, occasion, footwear-gravity (already present — refine weighting only if eval shows need).

## Unresolved questions
- Is `W_FB_BIAS=2.0` a value the CEO wants to keep (product lean) or reduce/contextualize?
- User-uploaded items: where does the AI tagger map `subcategory` ("cardigan"/"blazer") → `category_family`? (Out of focus scope — affects whether the base/mid split needs a tagger change too.)
- Does eval data (`v05-eval`) actually show dress over-exposure in live sessions, or is this only structural? Worth a measurement before re-tuning.
