# V05 Outfit Eval Rubric (Preliminary)

> ⚠️ **Status**: Preliminary — pending anh Viet's final rubric from AU-259.
> Use this rubric only as interim. Note "preliminary rubric" in every report header.

## Inputs to evaluator (multimodal subagent)

Per outfit:
- N item images (TOP/BOTTOM/FOOTWEAR/OUTER/FULL_BODY/ACCESSORY)
- Item metadata: `human_readable_id`, `category_family`, `color_code`, `style_tags`, `source` (user|common_essential)
- Outfit context: `gender`, `temp_c` + climate bucket, `occasion`, `mood`, `force_axis` (if TA)

## Dimensions

### 1. Coherence (1-5)
Visual harmony of items as a styled outfit.
- 5 — Items intentional pairing, strong style story
- 4 — Items work together, balanced
- 3 — Items don't clash but no statement
- 2 — One item feels off-context
- 1 — Multiple items clash visually or stylistically

### 2. Weather fit (1-5)
Appropriateness for stated temp_c.
- 5 — Outfit feels right for the weather
- 4 — Slightly over/under-dressed but wearable
- 3 — Marginal, user would feel uncomfortable
- 2 — Weather safety borderline (e.g. exposed limbs at COOL)
- 1 — Real-world failure (user would be cold/hot/wet)

**Hard rule** (auto-reject regardless of other scores):
- Sandals/open shoes at temp_c < 15°C → score 1
- No OUTER / no warm FB at temp_c < 15°C → score 1
- Heavy coat at temp_c > 28°C → score 1

### 3. Structural validity (PASS/FAIL)
- PASS: Structure A (TOP + BOTTOM + FOOTWEAR) OR Structure B (FULL_BODY + FOOTWEAR)
- FAIL: missing required slot, duplicate bottoms, conflicting structures (dress + jeans)

### 4. Variation honor (PASS/FAIL — Try Another only)
For TA responses with `axis_requested`:
- PASS: requested axis demonstrably flipped (e.g. axis=color → dominant color changed)
- PARTIAL: axis claimed honored by engine but visually minimal change
- FAIL: requested axis identical to prior outfit

Per AU-252 §19 spec.

### 5. Mood honor (1-5)
If `mood` is set (confident|playful|low_energy|grounded|calm):
- 5 — Outfit clearly embodies the mood
- 3 — Neutral, mood neither honored nor violated
- 1 — Outfit contradicts mood (e.g. low_energy with maximal statement pieces)

Skip if mood=null.

### 6. Source distribution (informational, no score)
Count items where `source == "common_essential"`. Report:
- 0 — pure user wardrobe outfit
- 1-2 — partial common injection (typical safety scaffolding)
- 3+ — heavy common reliance (wardrobe sparsity flag)

## Output schema (subagent must return JSON)

```json
{
  "outfit_idx": 0,
  "scores": {
    "coherence": 4,
    "weather_fit": 5,
    "structural": "PASS",
    "variation_honor": "PASS",
    "mood_honor": 4
  },
  "source_distribution": {
    "user": 2,
    "common_essential": 1
  },
  "notes": "Red wrap dress + grey wool coat + Chelsea boot. Cohesive winter look. Common-injected coat fits color palette."
}
```

## Aggregation rules

Per scenario (across N outfits):
- **Build success rate**: % of build calls returning HTTP 200 with outfit (vs wardrobe_gap or 422)
- **TA success rate**: % of try_another calls returning outfit (vs fallback message)
- **Avg coherence**: mean of coherence scores
- **Avg weather_fit**: mean
- **Hard rule violations**: count of score=1 in weather_fit
- **Variation honor rate**: PASS / total TA calls
- **Source breakdown**: total items by source

Per matrix (across scenarios):
- Cross-tabulate: climate × gender × success rate
- Identify outlier scenarios (rate < 50% or coherence < 3.0)

## Limitations

- LLM-based rubric not calibrated to anh Viet's product intuition (AU-259 pending)
- Outfit "coherence" inherently subjective — same outfit may score 3-5 across runs
- Mood honor especially noisy — recommend cross-check against larger sample
- Variation honor "PARTIAL" verdict is hard to score consistently — defer to anh Viet's spec when available
