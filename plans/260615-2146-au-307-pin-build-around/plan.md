---
title: "AU-307 Pin Item & Build Around Outfit"
description: "Lock one outfit item; backend regenerates the rest around it. Home grid + Item Detail entry points."
status: in-review
priority: P2
effort: ~5d (2d BE, 2.5d FE, 0.5d QA)
branch: duc2820/au-307-uac-pin-item-build-around-outfit
tags: [au-307, pin, v05, build, home-grid, item-detail, i18n, a11y]
created: 2026-06-15
updated: 2026-06-16
prs:
  backend: https://github.com/auxi-wardrobe/auxi-backend/pull/104
  mobile:  https://github.com/auxi-wardrobe/auxi-mobile/pull/80
---

# AU-307 — Pin Item & Build Around Outfit — Implementation Plan

Canonical spec: [`spec.md`](./spec.md). Figma node-id `3140-5959`. UAC = Linear AU-307.

Pin scaffolding (icon, badge overlay, `pinnedItemId` useState, `onTogglePin`, fallback splice) already exists in HomeScreen. This plan refactors to reducer, adds modal + skeleton + tooltip, and wires BE `pinned_item_id` end-to-end. Three PRs: PR-BE → PR-FE-core → PR-FE-polish.

## Phases

| # | Phase | Owner | Status | PR |
|---|---|---|---|---|
| 01 | [BE schema + validation](./phase-01-be-schema-and-validation.md) | backend-dev | shipped → review | [BE #104](https://github.com/auxi-wardrobe/auxi-backend/pull/104) |
| 02 | [BE engine integration + fallback](./phase-02-be-engine-integration.md) | backend-dev | shipped → review | [BE #104](https://github.com/auxi-wardrobe/auxi-backend/pull/104) |
| 03 | [FE reducer + PinConfirmModal](./phase-03-fe-reducer-and-modal.md) | mobile-dev | shipped → review | [FE #80](https://github.com/auxi-wardrobe/auxi-mobile/pull/80) |
| 04 | [FE skeleton + generation flow](./phase-04-fe-skeleton-and-generation.md) | mobile-dev | shipped → review | [FE #80](https://github.com/auxi-wardrobe/auxi-mobile/pull/80) |
| 05 | [FE ItemDetail wiring + edge cases](./phase-05-fe-itemdetail-wiring-and-edge-cases.md) | mobile-dev | shipped → review | [FE #80](https://github.com/auxi-wardrobe/auxi-mobile/pull/80) |
| 06 | [i18n + a11y + tooltip](./phase-06-i18n-a11y-tooltip.md) | mobile-dev | shipped → review | [FE #80](https://github.com/auxi-wardrobe/auxi-mobile/pull/80) |
| 07 | [Tests + Maestro + QA](./phase-07-tests-and-qa.md) | qa-ui, qa-mobile | Maestro authored; Compare + smoke blocked on BE #104 merge + sim setup | [FE #80](https://github.com/auxi-wardrobe/auxi-mobile/pull/80) (YAML) |

## Key dependencies

- **PR-BE (phases 01-02) MUST merge before PR-FE-core (phases 03-06).** FE generation flow calls `/api/v05/recommendation/build` with `pinned_item_id`; without BE merged, FE 422s.
- Phase 02 depends on phase 01 (schema + validation gates engine work).
- Phase 03 (reducer) blocks phases 04, 05 — they all dispatch into the reducer.
- Phase 04 (generation flow) blocks phase 05 ItemDetail auto-pin effect (needs `CONFIRM_PIN` to fire generation).
- Phase 06 (i18n) blocks phase 07 Maestro (Maestro selects by accessibility labels which read from i18n).
- Phase 07 ships in PR-FE-polish, separate from PR-FE-core.

## Verification gates (umbrella)

Per spec §10 — must be all green before AU-307 → Done:
1. `cd wardrobe-backend && pytest tests/test_v05_build_service.py tests/test_v05_recommendation_router.py -v`
2. `cd auxi && npx tsc --noEmit && yarn lint`
3. `./scripts/auxi-lint-tokens.sh`
4. `cd auxi && maestro test tests/maestro/pin-build-around.yml`
5. qa-ui Compare mode PASS (Figma fidelity 3-pass)
6. qa-mobile smoke PASS (iOS sim)

## Out of scope (UAC locked)

Multi-pin, cross-session persistence, accessory pinning, auto-save pinned outfits, hard remix cap.

## Open items (deferred)

- Low-pool relax threshold (3 candidates suggested in spec §13; backend-dev to tune with real wardrobe data).
- Snapshot deep-clone perf — measure outfit object size; switch to shallow + immutable if >5KB.
- ItemDetail nav param shape — `{ pinFromDetail: itemId }` vs deeplink (mobile-dev chooses in phase 05).
