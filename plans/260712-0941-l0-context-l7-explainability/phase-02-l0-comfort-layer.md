---
phase: 2
title: L0 Comfort Layer (metadata-gated, never-starve)
status: planned
priority: P1
repos: [wardrobe-backend]
dependencies: [1]
---

# Phase 2: L0 Comfort Layer

## Overview

Turn the enriched context (P1) into scoring. Add a **soft Comfort multiplier** per candidate
plus a small set of **metadata-gated hard excludes** for clear safety/discomfort cases. Design
posture copies the shipped mood learning (AU-318): conservative map, rides the existing scoring
clamp `[0.5,1.5]`, **never starves the pool**, and is a **no-op wherever the item metadata is
absent** (so untagged wardrobes degrade gracefully to today's behavior). No change to L1/L2 core rules.

## Requirements

Functional:
- New `context_comfort.py`: `comfort_multiplier(item, ctx) -> float` in `[0.5, 1.5]`, and
  `comfort_excludes(candidate, ctx) -> bool` (hard, metadata-gated only).
- **Soft rules (multiplier), each gated on metadata presence:**
  - Heat+humidity high (e.g. `feels_like_c >= 30` or `humidity_pct >= 75`): up-weight `breathability` high, down-weight `heavy_layering` axis and high `warmth_level` tops. (Complements existing warmth *cold* filter — this is the hot side.)
  - `mobility == motorbike`: down-weight very loose/flowing silhouettes (wind/safety), up-weight secure/closed footwear; never hard-reject (still just a multiplier).
  - `duration == full_day|day_to_night`: mild up-weight for comfort-friendly (breathable, lower heel), mild down-weight for known high-effort items.
  - `uv_index` high: gentle up-weight for coverage (long sleeve) only when temp allows — skip if it fights the heat rule (heat rule wins; avoid contradiction).
- **Hard excludes (only where metadata is unambiguous AND present):**
  - `rain_prob >= 0.6` (heavy): exclude footwear known `waterproof == false` / `material == suede` — ONLY if that attribute exists on the item; otherwise no exclude.
  - Never exclude on inferred/missing metadata (fail-open for excludes to protect pool).
- Comfort enters scoring as one more multiplier alongside the mood/signal re-weight — same clamp, applied per candidate. **Emit the per-candidate comfort contribution into `trace`** (P3 reads it).
- A `comfort_reason` breadcrumb per candidate (`{rule, evidence}`) recorded in trace for the explanation layer.

Non-functional:
- Never raise (mirror v05 never-raise): comfort failure → multiplier 1.0, log, continue.
- No measurable increase in `pool_insufficient` / starvation vs baseline (verify P5).
- Deterministic (same item+ctx → same multiplier). No randomness.

## Architecture

```
engine_v05 scoring loop (per candidate)
  base_score
   × identity/affinity (L3)          # existing
   × signal_reweight (mood, L4)      # existing, clamp [0.5,1.5]
   × comfort_multiplier(item, ctx)   # NEW, clamp [0.5,1.5], metadata-gated
   → trace.comfort = {multiplier, rule, evidence}   # NEW, feeds P3

feasibility (L1) pre-filter
   + comfort_excludes(candidate, ctx)  # NEW hard, metadata-present-only, fail-open
```

Metadata used (grep actual `models/wardrobe.py` + `to_dict` first — gate on what EXISTS):
- Present today (per usage-frequency scout): `warmth_level`, `is_common_item`, `style_tags`.
- Likely present / verify: `breathability`, `waterproof`, `material`, silhouette tags.
- If a field is absent project-wide → that rule is dormant (documented, not silently wrong).
  File a metadata-backfill follow-up (feeds L1 richness later) rather than inventing values.

## Related Code Files

- Create: `wardrobe-backend/blueprints/recommendation/context_comfort.py` — `COMFORT_RULES` map + `comfort_multiplier()` + `comfort_excludes()`.
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05.py` — apply comfort multiplier in the scoring loop (near existing `apply_signal_reweight` ~:708-741); write `trace.comfort`.
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py` — call `comfort_excludes()` in L1 feasibility (near `_has_cool_weather_layer` / warmth filter), metadata-present-only.
- Read: `wardrobe-backend/models/wardrobe.py` + `to_dict` — confirm which comfort attributes exist (gate rules on reality).
- Create tests: `wardrobe-backend/tests/test_context_comfort.py` — rule table, clamp bound, metadata-absent no-op, exclude fail-open.

## Implementation Steps

1. **Metadata audit.** Grep `models/wardrobe.py`/`to_dict()` for `breathability`, `waterproof`, `material`, silhouette. Rules only reference fields that exist; dormant otherwise (comment + follow-up ticket).
2. **Comfort module.** `COMFORT_RULES` as data (ctx-predicate → axis/attr → direction), conservative (≤2 axes per rule, many contexts map to nothing — YAGNI). `comfort_multiplier` composes present-metadata rules, clamps `[0.5,1.5]`. `comfort_excludes` returns True only on unambiguous+present attribute.
3. **Wire scoring.** Multiply comfort into the per-candidate score right where signal re-weight applies; keep it inside the SAME clamp philosophy. Record `trace.comfort`.
4. **Wire feasibility.** Add `comfort_excludes` to L1 pre-filter; fail-open on missing metadata; ensure starvation/common-injection still backfills if a slot empties.
5. **Never-raise.** Wrap comfort in try/except → 1.0 + log.
6. **Tests + doc.** Rule table tests + clamp + no-op + starvation-neutral assertion. Note comfort in `API_DOCUMENTATION.md` behavior section (not a new endpoint).

## Success Criteria

- [ ] `feels_like_c=36, humidity_pct=85` → `heavy_layering` candidate multiplier < 1.0, breathable candidate > 1.0, both within `[0.5,1.5]`.
- [ ] `mobility=motorbike` → loose/flowing down-weighted, never hard-rejected.
- [ ] `rain_prob=0.7` → a footwear item with `waterproof=false` excluded; an item WITHOUT the attribute NOT excluded.
- [ ] Untagged wardrobe (no comfort metadata) → output identical to today (all multipliers 1.0).
- [ ] Comfort exception simulated → no 500, multiplier 1.0, request succeeds.
- [ ] `pool_insufficient` rate on the P5 eval set ≤ baseline.
- [ ] `pytest tests/test_context_comfort.py` green; `python test_server.py` green.

## Risk Assessment

- **Pool starvation from over-filtering** (High — same risk class as AU-306 warmth). Mitigation: comfort is soft (multiplier) except unambiguous+present-metadata excludes; excludes fail-open; P5 verifies `pool_insufficient`.
- **Rule contradictions** (heat vs UV coverage). Mitigation: explicit precedence (heat > UV); unit test the conflict case.
- **Diversity collapse.** Mitigation: clamp `[0.5,1.5]`, conservative map — identical guardrail to shipped mood layer.
- **Missing metadata everywhere → feature silently dormant.** Mitigation: audit in Step 1, log dormant rules, file backfill follow-up; don't fabricate attributes.
