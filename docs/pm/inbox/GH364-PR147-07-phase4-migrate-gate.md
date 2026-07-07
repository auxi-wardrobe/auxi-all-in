---
id: WAR-GH364-PR147-07
parent: WAR-GH364-PR147-00
type: chore
title: "Phase 4 — migrate MyCreations/canvas + Favourite family onto ds.*+M*; flip primitives lint warn→error"
state: Backlog
priority: P2
labels: [type:chore, area:mobile, design-system, role:mobile-dev, design-review, source:pr147-analysis]
team: Auxi
workspace: duncan-1
owner: mobile-dev + designer (hard gate)
estimate: L
linear_parent_url: TBD — GH-364 parent
created: 2026-06-26
linear_sync_status: pending
blocked_by: WAR-GH364-PR147-01 (D1,D4), -03, -04, -05, -06
---

## Context

Final phase. Migrate #147's surfaces AND the Favourite family they mirror onto
`ds.*` tokens + the 4 new components, as a **single batch** (do NOT leave #147 as a
lone `M*` island next to still-legacy Favourite siblings). Then flip the primitives
lint to error so the standard is mechanically enforced. The "mirrors a shipped
legacy sibling = MINOR" pass expires here. Confirmed Phase 4 via `-01` D4.

## Acceptance criteria

- [ ] `MyCreationsScreen` + `FavouriteScreen` consume `MEmptyState` (`-03`) and
      `BlurMenuHeader` (`-05`); no local empty-state or blur-header styles remain.
- [ ] `DiscardCreationDialog` + `RemoveFavouriteDialog` deleted, both replaced by
      `MConfirmSheet` (`-04`); no raw `Modal`/`TouchableOpacity` CTA styles remain.
- [ ] `CreationCollageCard` + `FavouriteOutfitCard` render `CollageSurface` (`-06`);
      no duplicate `collageSurface` styles remain.
- [ ] All `figma*/uac*` tokens removed from `MyCreations`/canvas + `Favourite` screens
      — only `ds.*` (+ generic spacing) remain. Tag pills → `MChip`/`MTag`.
- [ ] Canvas editor toolbar icon buttons → `MIconButton` (toolbar itself may stay bespoke).
- [ ] Add error state on canvas save/remove (PR #147 MINOR: none today).
- [ ] Flip `auxi-lint-ds-primitives.sh` from warn → error; CI/PR gate green on the
      migrated screens.
- [ ] `npx tsc --noEmit` + `yarn lint` + `./scripts/auxi-lint-tokens.sh` +
      `auxi-lint-ds-primitives.sh` all clean.
- [ ] designer design-review PASS recorded at
      `auxi/docs/design-reviews/<date>-myc-favourite-canvas-migration.md` (hard gate).
- [ ] qa-mobile smoke: My Creations, Favourite, canvas save + discard flows.
- [ ] Analytics: any new error-state surfaces ship Mixpanel events + tracking-plan
      doc update (per analytics rule).

## Out of scope

- New canvas/creations features — once this lands, new surfaces build on `ds.*`+`M*`
  directly (no more legacy-mirror pass).
- App-wide token unification beyond these screens (broader GH-364 Phase 1 work).

## Dependencies

- `-01` D1 (danger) + D4 (Phase-4 confirm). All 4 primitives done: `-03`, `-04`,
  `-05`, `-06`.

## Verification

- `cd auxi && npx tsc --noEmit` · `yarn lint` · `yarn test`
- `./scripts/auxi-lint-tokens.sh` · `auxi-lint-ds-primitives.sh` (now error mode)
- designer gate PASS doc + qa-mobile sim screenshots.

## Refs

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/plan.md` (sequencing §)
- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/token-map.md`
- Migration plan: `/Users/nguyenminhduc/dev/wardrobe_project/plans/260624-1110-GH-364-ds-primitive-migration/plan.md` (Phase 4)
- Lint: `auxi/scripts/auxi-lint-ds-primitives.sh`
- PRs: `auxi-wardrobe/auxi-all-in#29`, `auxi-wardrobe/auxi-mobile#149`, ref `auxi-wardrobe/auxi-mobile#147`
