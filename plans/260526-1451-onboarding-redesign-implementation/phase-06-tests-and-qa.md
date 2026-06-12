# Phase 6 — Tests + QA Gates

**Priority:** P1 · **Status:** pending · **Effort:** ~4h · **Blocks:** PR/merge
**Owner:** mobile-dev (unit) + qa-ui (Compare) + qa-mobile (Maestro)

## Context links
- Existing flow: `auxi/maestro/flows/onboarding/v05.yaml` (extend/branch this)
- Figma→RN gate: CLAUDE.md "Figma → mobile UI workflow (canonical)"
- testIDs defined in Phases 3-4

## Overview
Close the canonical Figma→RN gates: token lint (done in Phase 3-4), qa-ui Compare
Pass2/3 (code vs Figma screenshot), qa-mobile Maestro smoke, plus unit tests for
the pure logic (selection ranking, label↔wire mapping). Both flag states verified.

## Test matrix
| Layer | What | Tool | Owner |
|---|---|---|---|
| Unit | max-2 pin ordering, deselect collapses rank | jest | mobile-dev |
| Unit | fit label→wire mapping (`Regular`→`Classic Fit`), wardrobe/style enums match v05Api | jest | mobile-dev |
| Unit | config.ts copy has no placeholder leftovers ("MACGIE"/"Minmal") post-D3/D4 | jest (snapshot/assert) | mobile-dev |
| Integration | /generate mutation success→Completed nav; error→error block | jest + RTL (mock apiClient at boundary) | mobile-dev |
| E2E | full new flow Welcome→Outro→Home (flag ON), real backend | Maestro | qa-mobile |
| E2E (regression) | legacy V05 flow still works (flag OFF) | Maestro (existing v05.yaml) | qa-mobile |
| Visual | code vs Figma per screen (Pass 2+3) | qa-ui Compare (mobile-mcp screenshot) | qa-ui |

Note: unit/integration may mock the apiClient HTTP boundary (allowed for jest);
the E2E smoke MUST hit the real backend (umbrella gate — no mocked backend).

## Maestro
- CREATE `auxi/maestro/flows/onboarding/onboarding-v2.yaml` — new-flow journey using
  the new testIDs (`onboarding-wardrobe-tile-*`, `onboarding-fit-tile-*`,
  `onboarding-style-pin-*`, `onboarding-completed-cta`, `onboarding-outro-see-outfit`),
  waiting on `home-screen-root` post-state (mirror v05.yaml:146-149 pattern).
- Account precondition: `is_first_login=true` (v05.yaml header documents the reset).
- Assert Completed + Outro are REACHED before Home (the new architecture's key
  invariant) — wait on `onboarding-outro-see-outfit` before the Home swap.
- Keep `v05.yaml` runnable (flag OFF) for regression.

## qa-ui Compare (Pass 2/3)
- Dispatch qa-ui Compare mode against each of the 8 screen types (sim screenshot
  vs Figma node). Alignment / typography / color / icon / overflow checks.
- Gate: PASS on all, or logged deltas accepted by CEO.

## Implementation steps
1. Write jest units for selection logic + label/enum mapping.
2. Write RTL integration for the Styles mutation (success + 422 + 401 paths).
3. Author `onboarding-v2.yaml` (qa-ui authors, qa-mobile executes).
4. Run `auxi-lint-tokens.sh` (final), `npx tsc --noEmit`, `yarn lint` (baseline).
5. qa-mobile: run onboarding-v2 (flag ON) + v05 (flag OFF) on sim.
6. qa-ui Compare Pass2/3 screenshots for all 8 screens.
7. Fill PR template (Figma URL+node, extraction artifact path, qa-ui PASS,
   lint-tokens clean, sim verify ID).

## Todo
- [ ] Unit: pin ordering + deselect collapse
- [ ] Unit: fit label→wire + enum parity with v05Api
- [ ] Unit: config copy no-placeholder assertion
- [ ] Integration: Styles mutation success/error
- [ ] Maestro onboarding-v2.yaml authored + green
- [ ] Maestro v05.yaml regression green (flag OFF)
- [ ] qa-ui Compare Pass2/3 PASS (8 screens)
- [ ] auxi-lint-tokens clean + tsc + lint baseline
- [ ] PR template all green

## Success criteria
- All matrix rows pass.
- New flow E2E lands on Home with a materialised wardrobe (real backend).
- Legacy flow unaffected (flag OFF regression green).
- qa-ui Compare PASS or CEO-accepted deltas.
- No failing tests skipped to pass CI.

## Risks
| Risk | L×I | Mitigation |
|---|---|---|
| Loading view too transient for Maestro | M×L | Don't assert Loading; assert Outro reached then Home (post-states). Documented in v05.yaml:33-40. |
| qa-test account already onboarded | M×M | Reset `is_first_login=true` via DB (v05.yaml header) or register fresh. |
| Style-tile art placeholders fail visual Compare | M×M | If art not yet supplied, scope Compare to layout/typography; flag art as pending CEO. |
| Backend slow/cold → E2E timeout | L×M | `V05_GENERATE_TIMEOUT_MS=60000` already sized (v05.yaml:54). |

## Docs impact
- `auxi/CLAUDE.md` "Active work" note: update onboarding-redesign status once merged.
- API_DOCUMENTATION.md: no change (no contract change — confirmed Phase 0 D1).
