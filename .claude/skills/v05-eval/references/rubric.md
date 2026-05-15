# Outfit Recommendation Eval Rubric

> **Status**: Official — approved by Viet (AU-259, 2026-05-13).
> This rubric is **system-agnostic**: it evaluates outfit quality regardless of which recommendation engine produced the outfit.
> Swap the engine; keep this rubric.

---

## Philosophy

Auxi evaluates outfits for **real wearability**, not fashion competition.

We are NOT judging:
- Runway creativity
- Trendiness or "drip"
- Internet fashion aesthetics

We ARE evaluating:
> "Would a real person realistically WANT to wear this outfit in this context?"

Optimize for:
1. Psychological confidence
2. Wearability
3. Context correctness
4. Identity coherence
5. Low-friction decision making

An outfit can be simple and still score extremely high.

---

## Inputs to the evaluator

Per outfit being evaluated:
- **Item images**: one image per item (TOP / BOTTOM / FOOTWEAR / OUTER / FULL_BODY / ACCESSORY)
- **Item metadata**: category, color, any style tags available
- **Outfit context**: `gender` (M|W|U), `temp_c`, `occasion`, `mood`, `style_direction`
- **Try Another flag**: `is_try_another: bool` + `previous_outfits: list` (if applicable)

System-specific metadata (e.g. item source, pool events) is passed separately and does NOT affect rubric scoring.

---

## P0 — Structural Validity (Hard Gate)

**Not scored. Binary PASS / HARD_REJECT.**

Valid structures:
- TOP + BOTTOM + FOOTWEAR
- FULL_BODY (one-piece) + FOOTWEAR

Optional (never required): OUTER, ACCESSORY

**HARD_REJECT if:**
- Missing FOOTWEAR
- Missing core body coverage (no top, no bottom, no full-body)
- Duplicate conflicting garments (two bottoms of different types)
- Impossible layering (coat under t-shirt)

Structural failure → `hard_reject: true`. Skip all scoring.

---

## P1 — Weather Safety & Thermal Logic

**Weight: 30%**

> "Would a human feel physically comfortable wearing this?"

Evaluate:
- Temperature compatibility with `temp_c`
- Rain compatibility (if `is_rainy`)
- Layering realism
- Fabric seasonality signal
- Exposed skin amount
- Thermal balance across items

Scale 1–5:
- **5** — Outfit feels right for the weather
- **4** — Slightly over/under-dressed but realistic
- **3** — Marginal; user would feel uncomfortable
- **2** — Weather safety borderline
- **1** — Real-world failure (cold/hot/wet)

Hard reject triggers within this dimension (mark `hard_reject: true`):
- Winter layering (heavy coat, boots) at temp_c > 30°C
- Sandals / open shoes + no outer at temp_c < 10°C AND `is_rainy: true`
- Severe exposure in freezing weather (< 5°C, no outer)

Note: weather fit is physical comfort prediction, NOT fashion.

---

## P2 — Outfit Coherence

**Weight: 25%**

> "Does this visually feel like ONE outfit?"

Evaluate:
- Silhouette harmony
- Color compatibility
- Fit compatibility (oversized + oversized vs oversized + slim)
- Visual rhythm and texture balance
- Footwear alignment with upper garments
- Layering consistency

Scale 1–5:
- **5** — Strong style story; items feel intentionally paired
- **4** — Items work together; balanced
- **3** — Items don't clash but no clear statement
- **2** — One item feels off-context
- **1** — Multiple items clash visually or stylistically

Good example: relaxed hoodie + relaxed cargos + chunky sneakers
Bad example: business blazer + gym shorts + hiking sandals

---

## P3 — Occasion Appropriateness

**Weight: 20%**

> "Would this feel socially appropriate in this situation?"

Evaluate:
- Formality level vs `occasion`
- Environment compatibility
- Overdressed / underdressed balance
- Social expectation fit

Scale 1–5:
- **5** — Fits occasion perfectly
- **4** — Slight under/overdressing; tolerable
- **3** — Noticeable mismatch; raises eyebrows
- **2** — Clear occasion failure
- **1** — Hard social violation

Tolerate slight under/overdressing. Do NOT overfit rigid fashion rules.

**Occasion calibration** (interpretation shifts, dimensions stay fixed):

| Occasion | Prioritize | Tolerance | Penalty sensitivity |
|---|---|---|---|
| `casual` | comfort, wearability | HIGH | LOW |
| `work` / `office` | appropriateness, structure, clean silhouette | MEDIUM | HIGH for sloppy / extreme casual |
| `event` / `dinner` / `party` | statement level, emotional resonance, visual impact | HIGH for bold | HIGH for boring |
| `travel` | comfort, weather adaptability, practicality | MEDIUM | HIGH for restrictive |
| `date` | emotional resonance, personality expression, confidence | MEDIUM | LOW for formality |
| `gym` / `active` | movement compatibility, functional wearability | LOW | HIGH for non-functional items |

---

## P4 — Identity & Emotional Resonance

**Weight: 15%**

> "Does this feel emotionally aligned with the requested vibe/person?"

Evaluate:
- `mood` alignment (confident / playful / low_energy / grounded / calm)
- `style_direction` alignment (minimalist / streetwear / bold / soft / etc.)
- Personality continuity
- Emotional energy of the outfit

Scale 1–5:
- **5** — Outfit clearly embodies the requested mood and style
- **3** — Neutral; mood neither honored nor violated
- **1** — Outfit contradicts mood or style_direction

Skip dimension (mark `N/A`) if both mood and style_direction are null.

Good example (mood=confident, style=bold minimal): monochrome structured silhouette
Bad example (mood=confident, style=bold minimal): pastel soft-girl outfit

This is where the recommendation becomes personal instead of generic.

---

## P5 — Wearability / Friction Score

**Weight: 10%**

> "Would a normal person actually choose this quickly in real life?"

Evaluate:
- Practicality
- Ease of wear
- Cognitive simplicity (not visually exhausting)
- Movement comfort
- Styling effort required

Scale 1–5:
- **5** — Easy, practical, grab-and-go
- **3** — Wearable but requires effort
- **1** — Unrealistic in daily life; too complex or uncomfortable

Penalize outfits requiring excessive effort, unrealistic layering, or visual overload.
This dimension matters heavily for daily-use apps.

---

## P6 — Variation Quality (Try Another only)

**Separate metric — does NOT contribute to outfit score.**

Only evaluate when `is_try_another: true` AND `previous_outfits` is provided.

> "Does this variation feel meaningfully different from previous outfits?"

Evaluate:
- Silhouette change
- Color / tone shift
- Vibe / energy shift
- Layering shift
- Anchor item replacement
- Styling energy change

Verdict:
- **PASS** — Clear and meaningful shift across at least 2 dimensions
- **PARTIAL** — Minimal change; same vibe with superficial swaps
- **FAIL** — Same outfit + random accessory; fake diversity

Good Try Another: hoodie + cargos + sneakers → knit polo + pleated trousers + loafers (silhouette + energy + vibe all shifted)
Bad Try Another: white tee + black jeans + sneakers → white tee + black jeans + sneakers + cap

---

## Hard Rules vs Soft Rules

### HARD REJECT (`hard_reject: true`)

**Structural failures** (P0):
- Missing shoes, missing top/bottom, invalid one-piece + bottom combo, impossible layering

**Severe weather violations** (P1):
- Winter layering in extreme heat (>30°C)
- Sandals in snow / heavy rain at low temp
- Severe skin exposure in cold (<5°C, no outer)

**Severe occasion violations** (P3):
- Swimwear at office / formal event
- Pajamas at formal occasion
- Pool slides + business shirt at any professional setting (breaks occasion + coherence + social simultaneously)

**Metadata contradictions**:
- Item category mismatch with stated role in outfit

---

### SOFT PENALTIES (score low, do NOT reject)

| Case | Penalty | Not reject because |
|---|---|---|
| White tank + jeans at 15°C | weather_fit ↓ | Humans realistically still wear this |
| Slightly underdressed at casual office | occasion_fit ↓ | Tolerable social mismatch |
| Loud colors / unusual silhouette | coherence ↓ | Auxi should not be conservative |
| Complex layering but logically valid | wearability ↓ | Structurally fine |

---

## Final Score Formula

```
final_score = (
  weather_fit        × 0.30 +
  coherence          × 0.25 +
  occasion_fit       × 0.20 +
  identity_resonance × 0.15 +
  wearability        × 0.10
) × 20
```

Scale per dimension: **1–5**
Final score: **0–100**

If `hard_reject: true` → `final_score: 0`, skip all soft scoring.

### Score interpretation

| Range | Verdict | Ship decision |
|---|---|---|
| 90–100 | **Exceptional** | Intentional, wearable, emotionally aligned |
| 75–89 | **Strong** | Good recommendation. Safe to ship. |
| 60–74 | **Acceptable** | Wearable but weak in one dimension |
| 40–59 | **Poor** | Noticeable mismatch / problem |
| 0–39 | **Bad** | Should not surface to user |
| Hard Reject | **Auto-fail** | Reject regardless of other scores |

---

## Output schema (evaluator must return JSON)

```json
{
  "outfit_idx": 0,
  "hard_reject": false,
  "hard_reject_reason": null,
  "scores": {
    "weather_fit": 4,
    "coherence": 5,
    "occasion_fit": 4,
    "identity_resonance": 3,
    "wearability": 4
  },
  "variation_quality": "N/A",
  "final_score": 82,
  "verdict": "Strong",
  "notes": "Oversized black tee + relaxed grey trousers + white sneakers. Coherent casual silhouette. Weather fine at 22°C. Could push identity alignment more for 'bold minimal' direction — items are safe rather than intentional."
}
```

`variation_quality` values: `"PASS"` | `"PARTIAL"` | `"FAIL"` | `"N/A"` (non-TA outfits)

---

## Aggregation rules (per eval run)

Per scenario (across N outfits):
- **Hard reject rate**: count of `hard_reject: true` / total
- **Avg final_score**: mean across non-rejected outfits
- **Avg per dimension**: mean of each P1–P5 score
- **Variation quality rate**: PASS / total TA outfits (skip N/A)
- **Verdict distribution**: count per verdict tier

Per matrix (across scenarios):
- Cross-tabulate: climate × gender × avg_score
- Flag outlier scenarios: avg_score < 60 or hard_reject_rate > 20%

---

## Calibration examples (from Viet, AU-259)

### Example A — EXCEPTIONAL (92)
- Input: casual / 22°C / confident / minimal streetwear
- Outfit: oversized black tee + relaxed gray trousers + white sneakers + silver watch
- Why: weather excellent, coherent silhouette, emotionally aligned, extremely wearable

### Example B — ACCEPTABLE (63)
- Input: casual / 15°C
- Outfit: white tank + denim shorts + sneakers
- Why: realistic but cold → weather_fit low. Still believable. Not rejected.

### Example C — HARD REJECT
- Input: office / 18°C
- Outfit: business oxford shirt + gym shorts + pool slides
- Why: occasion failure + coherence failure + unrealistic social wearability simultaneously

### Example D — STRONG (90+)
- Input: dinner event / confident / bold minimal
- Outfit: black structured blazer + black wide trousers + leather loafers + silver chain
- Why: strong emotional coherence, good statement level, occasion appropriate

### Example E — Variation FAIL
- Outfit A: white tee + black jeans + white sneakers
- Outfit B: white tee + black jeans + white sneakers + random cap
- Why: no meaningful silhouette / vibe shift

### Example F — Variation PASS
- Outfit A: hoodie + cargos + sneakers
- Outfit B: knit polo + pleated trousers + loafers
- Why: clear identity / silhouette / energy shift across all axes

---

## System-level principle

Evaluator must prioritize:

**REAL HUMAN BELIEVABILITY** over **PURE AESTHETIC PERFECTION**

- Outfit slightly imperfect but believable → **GOOD**
- Outfit "AI fashionable" but unrealistic → **BAD**

This is critical for user trust in Auxi.
