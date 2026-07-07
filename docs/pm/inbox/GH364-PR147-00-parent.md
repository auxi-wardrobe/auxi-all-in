---
id: WAR-GH364-PR147-00
parent: GH-364
type: epic
title: "PR #147 → DS standardization follow-ups (GH-364)"
state: Backlog
priority: P2
labels: [type:chore, area:mobile, design-system, design-review, source:pr147-analysis]
team: Auxi
workspace: duncan-1
owner: mobile-dev (code) + designer/CEO (decisions)
estimate: L
linear_parent_url: TBD — attach to existing GH-364 DS-primitive-migration parent on board
created: 2026-06-26
linear_sync_status: pending
---

## Context

auxi PR #147 ("Add canvas save & My Creations screen") was analyzed against the
design system. Verdict: the feature is **mergeable** (designer gate =
PASS-WITH-MINORS, BLOCKER 0 / MAJOR 0 / MINOR 5 / NIT 3 / DS-gap 1), but its
**construction is NOT the DS standard** — it copies the already-legacy Favourite
pattern (`figma*/uac*` tokens + raw `Modal`/`TouchableOpacity`/`TopIconButton`)
instead of `ds.*` tokens + `M*` primitives.

This epic schedules the standardization follow-ups under the GH-364 DS-primitive
migration. #147 itself is treated as a **worklist, not a template** — merge it as
is (do NOT orphan it on `M*` next to still-legacy Favourite siblings); migrate the
whole family together at Phase 4.

## ⚠️ Parent linkage (action required when Linear MCP is restored)

Linear MCP tools were NOT surfaced in this session, so this was written to the
inbox fallback and **no Linear IDs were created**. When MCP is back:
1. Locate the existing GH-364 / DS-primitive-migration parent issue on the board.
   Do NOT create a duplicate parent.
2. Create the 7 child tickets below as sub-issues of that GH-364 parent.
3. Set the blocks/blocked-by links described in each child.

## Children (this batch)

| Inbox file | Title | Owner | Pri | Phase |
|---|---|---|---|---|
| `GH364-PR147-01-decisions.md` | Resolve 4 open DS decisions for PR #147 standardization | designer/CEO | P1 | gate — blocks all below |
| `GH364-PR147-02-phase1-token-map.md` | Phase 1 — apply PR #147 token map + fix 2 theme.ts bugs + add ds tokens | mobile-dev | P2 | 1 |
| `GH364-PR147-03-m-empty-state.md` | Phase 2-3 — build `MEmptyState` primitive | mobile-dev + CEO | P2 | 2-3 |
| `GH364-PR147-04-m-confirm-sheet.md` | Phase 2-3 — build `MConfirmSheet` primitive | mobile-dev | P2 | 2-3 |
| `GH364-PR147-05-blur-menu-header.md` | Phase 2-3 — build `BlurMenuHeader` layout component | mobile-dev | P2 | 2-3 |
| `GH364-PR147-06-collage-surface.md` | Phase 2-3 — extract `CollageSurface` feature component | mobile-dev | P2 | 2-3 |
| `GH364-PR147-07-phase4-migrate-gate.md` | Phase 4 — migrate MyCreations/canvas + Favourite family + flip lint to error | mobile-dev + designer | P2 | 4 |

Sequencing: **01 (decisions)** unblocks everything → **02 (token)** → **03-06
(primitives, parallel)** → **07 (migrate + gate)** last.

## Acceptance criteria (epic-level)

- [ ] All 4 decisions in `-01` answered by CEO/designer.
- [ ] Phase 1 token work merged (theme.ts bugs fixed, `ds.color.scrim` +
      `ds.color.headerBlurTint` + `spacing.sm`=12 added, typography consolidation started).
- [ ] All 4 primitives (`MEmptyState`, `MConfirmSheet`, `BlurMenuHeader`,
      `CollageSurface`) exist, exported, unit-tested.
- [ ] MyCreations/canvas + Favourite family migrated onto `ds.*`+`M*` as a batch;
      no `figma*/uac*` left in those screens.
- [ ] `auxi-lint-ds-primitives.sh` flipped warn→error.
- [ ] designer gate PASS recorded for the migrated screens.

## Refs

- Analysis (full): `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/plan.md`
- Token map: `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/token-map.md`
- 4 specs: same folder — `spec-m-empty-state.md`, `spec-m-confirm-sheet.md`, `spec-blur-menu-header.md`, `spec-collage-surface.md`
- Designer gate doc: `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/design-reviews/260625-pr147-my-creations-canvas-save.md`
- GH-364 migration plan: `/Users/nguyenminhduc/dev/wardrobe_project/plans/260624-1110-GH-364-ds-primitive-migration/plan.md`
- PRs: docs `auxi-wardrobe/auxi-all-in#29` (analysis + token map + specs) · `auxi-wardrobe/auxi-mobile#149` (gate doc) · reference `auxi-wardrobe/auxi-mobile#147` (the analyzed feature)
