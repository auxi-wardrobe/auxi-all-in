# Phase 06 — Verification Gates + PR

**Context:** [plan.md](plan.md) · CLAUDE.md "Figma → mobile UI workflow" steps 5–8 · rule `.claude/rules/design-review-required.md`

## Overview
- **Priority:** P0 (release gate). **Status:** ☐. **Depends on:** Phases 02–05 complete.
- Runs the mandatory post-code gates in order; a designer FAIL blocks the PR.

## Gate sequence (canonical)
1. **token-lint:** `./scripts/auxi-lint-tokens.sh` clean (no hex / font-family / raw zIndex / motion-literal drift).
2. **Type/lint:** `cd auxi && npx tsc --noEmit && yarn lint` (Node 20 — `nvm use 20`; default shell Node 16 breaks yarn).
3. **qa-ui Compare (Pass 2+3):** code-vs-Figma 3906-8765, sim screenshots of all 3 states (home/sheet/override) → PASS.
4. **designer design-review (step 6.5, HARD GATE):** 6-lens craft pass (tokens → motion → color → header/footer/layout → cross-screen → states). PASS recorded at `auxi/docs/design-reviews/2026-06-18-temperature-override.md`. FAIL → back to mobile-dev. Taste → CEO.
5. **qa-mobile smoke:** exploratory on iOS sim — open sheet, select, apply, header swaps, "Show another" keeps override, weather-select clears, error path. Capture verify ID.
6. **PR:** template checklist all green.

## PR template checklist (must be green)
- [ ] Figma URL + node-id (3906-8765)
- [ ] Extraction artifact path (Phase 01)
- [ ] qa-ui review-extraction PASS (Phase 01)
- [ ] `auxi-lint-tokens.sh` clean
- [ ] designer design-review PASS (step 6.5)
- [ ] Sim screenshot / qa-mobile verify ID
- [ ] Analytics events + tracking-plan doc updated (Phase 05)

## Verification (umbrella gates)
- Mobile-only change → no backend e2e needed unless Phase 07 taken.
- Smoke against backend on :5001 (real HTTP) — confirm `/build` honors the sent temp_c and "Show another" reuses it.

## Todo
- [ ] token-lint clean
- [ ] tsc + lint clean (Node 20)
- [ ] qa-ui Compare PASS (3 states)
- [ ] designer PASS recorded
- [ ] qa-mobile smoke PASS + verify ID
- [ ] PR opened on branch `duc2820/au-362-…`, base main, template green
- [ ] Linear AU-362 → In Review (pm)

## Success Criteria
All gates green; designer PASS on file; PR open with complete checklist; ticket moved.

## Risks
- Designer FAIL on motion/reduce-motion or hand-rolled header → pre-empted in Phases 03/04.
- Node-version trap → always `nvm use 20` before yarn/tsc.
