---
type: cook-session
ticket: AU-307
date: 2026-06-16
duration: ~5h (planning + 7 phase implementations + 2 PRs)
status: in-review (BE+FE shipped; QA gated on BE merge + sim)
---

# AU-307 — Pin Item & Build Around Outfit — Cook Session

## Outcome

Two PRs open, awaiting review + merge:
- BE: https://github.com/auxi-wardrobe/auxi-backend/pull/104 (8 files, 726 insertions)
- FE: https://github.com/auxi-wardrobe/auxi-mobile/pull/80 (20 files, 1948 insertions inc. Maestro YAML)

All FE quality gates green in worktree: tsc clean, ESLint 0 errors (1 nit), Jest reducer 21/21, no hex literal drift. BE pytest 12 new tests pass + 476 unit-suite regression clean.

## Work breakdown

| Phase | Agent | Output |
|---|---|---|
| 01 BE schema + validation | backend-dev | `BuildRequest.pinned_item_id`, 410/422 IDOR + source guards, 5 service tests + 1 router test |
| 02 BE engine integration | backend-dev | L1 pool filter + L2 force-swap defense, `LOW_POOL_THRESHOLD=3` relax, `low_confidence` flag, 8 new tests |
| 03 FE reducer + modal | mobile-dev | `usePinReducer` (11 events), `PinConfirmModal` (2 variants), `snapshotOutfit` util, 16 reducer tests |
| 04 FE skeleton + generation | mobile-dev | `SkeletonTile`, AbortController + 30s timeout, error/fallback inline notices, disabled CTAs while generating |
| 05 FE ItemDetail + edge cases | mobile-dev | ItemDetail nav→Home with `pinFromDetail` + `CONFIRM_PIN_FROM_DETAIL` atomic event, wardrobe sync watcher, SYSTEM-tile pin hide, guest auth wall |
| 06 FE i18n + a11y + tooltip | mobile-dev | 16 `pin.*` keys × 3 locales (en/vi/fr), `PinnedItemTooltip` (3s auto-dismiss, session-cap 3) + a11y live regions |
| 07 Maestro authoring | qa-ui | 3 sub-flows (primary + replace + error-retry) + orchestrator + README + selector inventory |

## Architectural decisions worth remembering

1. **Snapshot moved out of CONFIRM_PIN into GENERATE_START** (mobile-dev phase 03 → phase 04). Lets the HomeScreen effect capture the outfit at *request time* not modal-confirm time. Cleaner separation of concerns; reducer stays pure.

2. **`CONFIRM_PIN_FROM_DETAIL` atomic event** (phase 05). Instead of routing ItemDetail entry through PIN_TAP → CONFIRM_PIN (two-step), added a single event that bypasses the modal. Maps cleanly to UAC's "user already confirmed by tapping CTA on Detail screen" semantic.

3. **L2 force-swap defense in depth** (BE phase 02). Spec said "log warning"; backend-dev escalated to actual recovery (swap pinned item into matching family slot if L1 filter missed it). Guarantees FE contract holds regardless of upstream engine bugs.

4. **Same 410 detail for missing + foreign-owned items** (BE phase 01). IDOR defense — no info leak via response shape or detail string.

5. **SYSTEM-tile pin hide at both FE display + BE 422 reject** (phase 05 + 01). Defense in depth — FE hides pin badge on `item.isSystem===true` tiles, BE returns 422 if FE guard ever fails.

6. **Worktree pattern continued** — both PRs developed in `worktrees/wt-au-307-{be,fe}` from `origin/main`. Local submodule checkouts kept untouched (had heavy WIP from other features).

## Known blockers for FE merge

- **BE PR #104 must merge first** — FE code calls `/build` with `pinned_item_id`; without BE, response shape doesn't include `low_confidence` and validators don't fire.
- **Maestro sub-flow C** (error-retry) requires BE `V05_BUILD_FORCE_ERROR` env flag — not yet implemented. Authored anyway; will fail loudly if precondition not met.
- **qa-ui Compare mode** (Figma fidelity 3-pass) — needs iOS sim + Figma access. Defer to human-driven session.
- **qa-mobile smoke** — needs iOS sim + app build + BE running locally with PR #104 changes.

## Follow-ups

1. **HomeScreen size** — grew ~2.7k → ~3.3k lines. Separate refactor ticket.
2. **BE force-error env flag** — backend-dev follow-up so Maestro sub-flow C can run deterministically.
3. **Maestro path consolidation** — flows currently split between `maestro/flows/<feature>/` (legacy) and `tests/maestro/au-307/` (new). Tech-lead ticket to consolidate.
4. **testID stabilization** — pin/skeleton testIDs are outfit-hash-keyed, forcing regex Maestro selectors. Slot-indexed aliases would simplify.
5. **`LOW_POOL_THRESHOLD=3` tuning** — currently a constant; promote to env knob after real-wardrobe distribution data.
6. **Linear status transition** — Linear MCP token expired mid-session; CEO to manually transition AU-307 → "In Review" and post PR comment.
7. **Umbrella submodule pin bump** — neither auxi nor wardrobe-backend submodule pointer bumped; do after both PRs merge.

## Files

- Spec: `plans/260615-2146-au-307-pin-build-around/spec.md`
- Plan + 7 phases: `plans/260615-2146-au-307-pin-build-around/`
- BE worktree: `worktrees/wt-au-307-be` (branch `duc2820/au-307-be-pin-build`)
- FE worktree: `worktrees/wt-au-307-fe` (branch `duc2820/au-307-uac-pin-item-build-around-outfit`)
- Phase 04 mobile-dev note: `worktrees/wt-au-307-fe/plans/reports/mobile-dev-260616-0032-au-307-phase-04.md`
- Maestro authoring report: `plans/reports/qa-ui-260616-0108-au-307-maestro-authoring.md`
