---
id: WAR-GH364-PR147-06
parent: WAR-GH364-PR147-00
type: feature
title: "Phase 2-3 — extract CollageSurface feature component"
state: Backlog
priority: P2
labels: [type:feature, area:mobile, design-system, role:mobile-dev, design-review, source:pr147-analysis]
team: Auxi
workspace: duncan-1
owner: mobile-dev
estimate: M
linear_parent_url: TBD — GH-364 parent
created: 2026-06-26
linear_sync_status: pending
blocked_by: WAR-GH364-PR147-02 (tokens)
---

## Context

PR #147 `CreationCollageCard` and existing `FavouriteOutfitCard` render the SAME
cream 3:4 collage tile — the PR comment says it is "identical look to
FavouriteOutfitCard.collageSurface". One surface, two copies → extract a shared
component. NOT a generic `M*` primitive — it's a feature composite, so it lives
under `components/features/`, not `design-system/lib/`.

## Acceptance criteria

- [ ] Create `auxi/src/components/features/CollageSurface.tsx` (alongside
      `collage-seed-layout`).
- [ ] API: `{ tiles: CollageTile[], canvasWidth: number, testID? }`;
      `CollageTile = { id, imageUri, x, y, width, height, zIndex, scale?, rotation? }`.
      Surface takes already-resolved tiles + canvasWidth; CALLER decides how tiles
      were produced (favourite re-seed vs creation replay) — keeps surface dumb.
- [ ] Surface: `width:'100%'`, `aspectRatio: 1 / COLLAGE_ASPECT` (reuse existing
      `collage-seed-layout` constant), `backgroundColor: ds.color.cream` (=
      `figmaCardSurface`), `borderRadius: ds.radius.sm` (= `figmaTile` 12),
      `overflow:'hidden'`. No `figmaCardSurface`/`figmaTile` literals.
- [ ] Tiles absolute, `left/top/width/height = value * factor`, `transform:[{scale},{rotate}]`,
      `zIndex` from tile; image `resizeMode="contain"`. Internal `onLayout` measures
      rendered width; `factor = renderedWidth / canvasWidth`; guard `canvasWidth<=0`
      → render nothing (PR #147 already does this).
- [ ] States: empty tiles (bare cream surface) / pre-measure (factor 0) / normal.
- [ ] Decorative surface exposes `testID`; caller adds the card's `accessibilityLabel`.
- [ ] Visual parity test — rescale + transform replay identical to PR #147.
- [ ] `npx tsc --noEmit` + `yarn lint` clean.

> Swapping `CreationCollageCard` + `FavouriteOutfitCard` onto it happens in Phase 4
> (`-07`). Card chrome (title block, tag pills, ⊖/heart) stays per-card — share the
> SURFACE only; tag pills → `MChip`/`MTag` tracked separately in `-07`.

## Out of scope

- Migrating the two cards to consume it (Phase 4, `-07`).
- Sharing the card chrome (title/pills/remove) — surface only.

## Dependencies

- `-02` (cream/radius tokens stable).

## Refs

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/spec-collage-surface.md`
- Files: `auxi/src/components/features/` + `collage-seed-layout`
- PRs: `auxi-wardrobe/auxi-all-in#29`, ref `auxi-wardrobe/auxi-mobile#147`
