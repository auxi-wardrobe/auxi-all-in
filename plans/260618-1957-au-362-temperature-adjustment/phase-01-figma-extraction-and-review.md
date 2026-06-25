# Phase 01 — Figma Extraction + qa-ui Review (canonical steps 2–3)

**Context:** [plan.md](plan.md) · Figma [3906-8765](https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=3906-8765) · skills `figma-design-extraction`, `auxi-figma-audit`

## Overview
- **Priority:** P0 (gates all impl). **Status:** ☐ not started.
- Pre-code gate. mobile-dev pulls the full Figma spec; qa-ui audits the extraction vs Figma (Pass 1, no code). PASS unblocks Phase 02–04.

## Key Insights (from planning recon)
- Section has **3 frames**: `Home 1/3` (weather mode), `degree change` (the sheet over dimmed Home), `degree selected` (override mode). Extract all three.
- Sheet content (verbatim): title **"Outfit Temperature"**, subtitle *"We'll adjust outfit recommendations based on your preferred temperature."*, radios **Use current weather (32°C)** [default] · **28–40°C** · **10 - 25°C** · **0 - 7°C** · **-10 - 0°C**, **Apply** (primary full-width) + **Cancel** (text).
- Trigger = **lightbulb icon** beside the "Clean. Ready for today" status pill (NOT the top header).
- Override header = weather icon → override-indicator icon + range label + chevron; lightbulb pill renders **active/highlighted**.

## Requirements
- Extraction note saved to `plans/260618-1957-au-362-temperature-adjustment/figma-extraction-temperature-sheet.md` covering: tokens (color/spacing/radius/typography), radio control variants (selected/unselected), Apply enabled/disabled, sheet container + backdrop, lightbulb idle vs active, override-indicator icon (export SVG if missing, `currentColor` convention), exact header layout deltas.
- Resolve **D4**: capture the real override-indicator icon + confirm the displayed label is the selected bucket string.

## Related Code Files (targets to map against, not edit here)
- `auxi/src/components/features/ContextChipsModal.tsx` (sheet token reference)
- `auxi/src/components/features/WeatherWidget.tsx` (header element being swapped)
- `auxi/src/theme/theme.ts`, `auxi/src/theme/motion.ts` (token tiers)

## Implementation Steps
1. mobile-dev: invoke `figma-design-extraction` on 3906-8765 (all 3 frames); write extraction artifact.
2. `figma-theme-sync` / `figma-icons-sync`: list any missing tokens or icons (esp. override indicator + lightbulb-active).
3. Auto-dispatch **qa-ui (review-extraction mode)** — Pass 1 only, audit note vs Figma → PASS / FAIL / ESCALATE.
4. If FAIL/ESCALATE → fix extraction or escalate D1/D4 to CEO before proceeding.

## Todo
- [ ] Extraction artifact written (3 frames, tokens, variants, icons)
- [ ] Missing icons/tokens enumerated (override indicator, lightbulb-active)
- [ ] qa-ui review-extraction PASS recorded
- [ ] D4 (icon + header label) resolved or escalated

## Success Criteria
qa-ui review-extraction = **PASS** and extraction artifact path exists. No code written in this phase.

## Risks
- Override-indicator icon may not exist as a token/asset → export via `figma-icons-sync`.
- Bucket label/format ambiguity (Figma `10 - 35°C` mock) → confirm in extraction, don't hardcode the mock.

## Next
→ Phase 02 (state/mapping) and Phase 03 (sheet) can start in parallel once PASS.
