# Phase 07 — Tests + Maestro + QA

## Context links

- Spec: [`spec.md`](./spec.md) §8 (Maestro coverage default: 3 flows), §10 (verification gates), §11 (PR-FE-polish), §12 (Definition of done)
- Maestro convention: `auxi/tests/maestro/*.yml`
- Token lint: `./scripts/auxi-lint-tokens.sh`
- qa-ui agent: `auxi-figma-audit` skill (3-pass Compare mode)
- qa-mobile agent: `auxi-qa-test` skill (mobile-mcp exploratory smoke)

## Overview

- **Priority:** P3 (polish + sign-off; depends on phases 01-06)
- **Status:** pending
- **Brief:** Author Maestro flow covering primary pin + replace + error retry. qa-ui runs Compare mode (Figma vs sim 3-pass). qa-mobile runs smoke verify. Token-lint clean. Capture sim screenshot for PR.

## Key insights

- Maestro selects by a11y label — phase 06 i18n + a11y labels MUST be merged first.
- 3 Maestro flows in one YAML file using `runFlow` blocks; keeps single artifact for CI.
- qa-ui Compare mode = 3 passes per spec workflow: (1) extraction-vs-Figma, (2) code-vs-Figma, (3) sim screenshot-vs-Figma.
- Error retry flow needs network mock — use Maestro's `mockServer` or backend kill-switch for 30s timeout sim.
- Backend gate (`pytest`) re-runs here as cross-check before merge.

## Requirements

**Functional:**
- Maestro YAML covers:
  1. **Primary** — tap pin tile → confirm modal → tap Build around this → skeleton visible → outfit renders → pinned item present.
  2. **Replace** — pin item A → pin item B → replace modal → confirm → outfit contains B.
  3. **Error retry** — pin → force generation error → inline error visible → Retry → success.
- qa-ui Compare mode PASS (3-pass).
- qa-mobile smoke PASS on iOS sim.
- Token-lint clean (`./scripts/auxi-lint-tokens.sh`).
- BE tests re-run green.
- FE typecheck + lint re-run green.

**Non-functional:**
- Maestro flow runs ≤ 90s wall-clock.
- All 14 UAC scenarios manually checked (mobile-dev or qa-mobile owns checklist).

## Architecture

```
PR-FE-polish
  ├── tests/maestro/pin-build-around.yml
  │     ├── runFlow: primary-pin
  │     ├── runFlow: replace-pin
  │     └── runFlow: error-retry
  ├── qa-ui Compare mode 3-pass
  │     ├── Pass 1 — extraction note vs Figma (already done pre-impl?)
  │     ├── Pass 2 — code vs Figma
  │     └── Pass 3 — sim screenshot vs Figma
  ├── qa-mobile smoke
  │     └── mobile-mcp exploratory: pin + unpin + replace + error + ItemDetail flow
  └── PR description + artifacts:
        ├── Figma URL + node-id
        ├── Extraction artifact path
        ├── Maestro pass screenshot/log
        ├── qa-ui PASS report path
        └── qa-mobile PASS report path
```

## Related code files

**Create:**
- `auxi/tests/maestro/pin-build-around.yml`

**No code modifications** — this phase is verification + reporting only.

## Implementation steps

1. **Maestro YAML** — `tests/maestro/pin-build-around.yml`:
   ```yaml
   appId: com.auxi.app
   ---
   - launchApp
   - assertVisible: "Home"
   - runFlow: flows/primary-pin.yml
   - runFlow: flows/replace-pin.yml
   - runFlow: flows/error-retry.yml
   ```
   Sub-flows in `auxi/tests/maestro/flows/`:
   - `primary-pin.yml`:
     ```yaml
     - tapOn:
         id: "outfit-tile-0"
     - assertVisible: "Keep this item"
     - tapOn: "Build around this"
     - assertVisible:
         id: "skeleton-tile"
     - extendedWaitUntil:
         notVisible:
           id: "skeleton-tile"
         timeout: 30000
     - assertVisible:
         id: "pin-badge"
     ```
   - `replace-pin.yml`:
     ```yaml
     - tapOn:
         id: "outfit-tile-1"
     - assertVisible: "Replace pinned item?"
     - tapOn: "Build around this"
     - extendedWaitUntil:
         notVisible:
           id: "skeleton-tile"
         timeout: 30000
     ```
   - `error-retry.yml`:
     ```yaml
     # Requires backend in error mode (env flag or proxy)
     - tapOn:
         id: "outfit-tile-2"
     - tapOn: "Build around this"
     - extendedWaitUntil:
         visible: "We couldn't build an outfit"
         timeout: 35000
     - tapOn: "Retry"
     - assertVisible:
         id: "skeleton-tile"
     ```
2. **Error-mode toggle** — for `error-retry`, either:
   - Backend env flag `V05_BUILD_FORCE_ERROR=true` (cheapest; coordinate with backend-dev)
   - OR Maestro `mockServer` intercept (more complex; use only if env flag rejected)
3. **qa-ui Compare mode dispatch** — invoke `qa-ui` agent with:
   - Figma node-id `3140-5959`
   - Sim build commit hash
   - Screens to compare: Home with pinned tile, PinConfirmModal (confirm + replace variants), skeleton state, error state
   - Output report saved to `plans/reports/qa-ui-260615-au-307-pin-compare.md`
4. **qa-mobile smoke dispatch** — invoke `qa-mobile` agent with task: verify pin + unpin + replace + error retry + ItemDetail auto-pin on iOS sim. Report saved to `plans/reports/qa-mobile-260615-au-307-pin-smoke.md`.
5. **Token-lint** — `./scripts/auxi-lint-tokens.sh` MUST be clean (no hex literals, no font family drift in new components).
6. **BE re-run** — `cd wardrobe-backend && pytest tests/test_v05_build_service.py tests/test_v05_recommendation_router.py -v`.
7. **FE re-run** — `cd auxi && npx tsc --noEmit && yarn lint && yarn jest`.
8. **14 UAC scenarios manual checklist** — mobile-dev runs through and ticks DoD list in spec §12.
9. **PR description** for PR-FE-polish:
   - Figma URL + node-id
   - Extraction artifact path
   - Maestro log + sim screenshot
   - qa-ui PASS report
   - qa-mobile PASS report
   - Token-lint clean confirmation
10. **Linear** — transition AU-307 to In Review, then Done after merge.

## Todo

- [ ] Create `tests/maestro/pin-build-around.yml` + 3 sub-flows
- [ ] Coordinate backend error-mode toggle for error-retry flow
- [ ] Run Maestro suite locally — all 3 flows green
- [ ] Dispatch qa-ui Compare mode (3-pass)
- [ ] Dispatch qa-mobile smoke verify
- [ ] Run `./scripts/auxi-lint-tokens.sh` clean
- [ ] Re-run BE pytest green
- [ ] Re-run FE tsc + lint + jest green
- [ ] Tick 14 UAC scenarios manual checklist
- [ ] Capture sim screenshots for PR
- [ ] Open PR-FE-polish with all artifacts
- [ ] Transition AU-307 → Done on merge

## Success criteria (Definition of Done — spec §12)

- [ ] BE tests pass; API_DOCUMENTATION.md updated; PR-BE merged
- [ ] FE typecheck + lint + token-lint clean
- [ ] All 14 UAC scenarios manually verified on iOS sim
- [ ] Maestro 3 flows pass
- [ ] qa-ui Compare mode PASS
- [ ] qa-mobile smoke PASS
- [ ] i18n 3 locale parity
- [ ] a11y labels on pin badge, modal CTAs, tooltip
- [ ] PR description includes Figma URL + extraction artifact + sim screenshot
- [ ] Linear AU-307 → Done

## Risk assessment

| Risk | Mitigation |
|---|---|
| Maestro flaky on long generation | `extendedWaitUntil` 30s + retry once on CI flake |
| Error-mode toggle requires BE change post-merge | Use env flag (no code change after PR-BE merge) |
| qa-ui finds Figma drift | Block PR; mobile-dev fixes; re-dispatch qa-ui |
| qa-mobile crash | Capture `get_crash`; file follow-up; do not ship |
| Maestro selectors miss after i18n change | Selectors use stable `testID`s + visible i18n text; phase 06 must merge first |

## Security considerations

- Maestro flow MUST NOT log or assert against any auth tokens.
- Error-mode env flag MUST be off in prod; gate in CI config.

## Next steps

- Ships in **PR-FE-polish** (separate from PR-FE-core).
- Branch: `duc2820/au-307-fe-polish`.
- Final merge → Linear AU-307 → Done.
- Post-merge: monitor Sentry for 24h for any pin-related crashes; revert plan = revert PR-FE-polish first (Maestro is non-load-bearing), then PR-FE-core, then PR-BE.
