# Spec — `CollageSurface` (feature component)

> **Status:** proposed (GH-364). PR #147 `CreationCollageCard` and the existing
> `FavouriteOutfitCard` render the SAME cream 3:4 collage tile — the PR comment
> says it is "identical look to FavouriteOutfitCard.collageSurface". One surface,
> two copies → extract a shared component so the cream tile is ONE definition.

## Purpose
The cream, locked-3:4, overflow-clipped surface that lays out absolutely-
positioned outfit item tiles (re-seeded for favourites, replayed-verbatim for
saved creations). NOT a generic `M*` primitive — it's a feature composite, so it
lives under `components/features/`, not `design-system/lib/`.

## Replaces
- `CreationCollageCard.tsx` `collageSurface` + `collageItem` + `collageImage` styles + the item `.map()` layout (PR #147 diff lines ~922-955, 1012-1027)
- `FavouriteOutfitCard` `collageSurface` (the duplicate)

## Location
`auxi/src/components/features/CollageSurface.tsx` (alongside `collage-seed-layout`).

## API
```ts
type CollageTile = {
  id: string;
  imageUri: string;
  x: number; y: number; width: number; height: number;
  zIndex: number;
  scale?: number; rotation?: number;
};

type CollageSurfaceProps = {
  tiles: CollageTile[];
  /** editor-space width the tiles were authored at; surface rescales by (renderedWidth / canvasWidth). */
  canvasWidth: number;
  testID?: string;
};
```

The favourite path (re-seeds positions) and the creation path (replays saved
transforms) both reduce to "absolute tiles + a rescale factor" — so the surface
takes already-resolved `tiles` + `canvasWidth` and the CALLER decides how tiles
were produced (seed vs saved). Keeps the surface dumb + reusable.

## Tokens (all `ds.*`)
- Surface: `width:'100%'`, `aspectRatio: 1 / COLLAGE_ASPECT` (reuse existing `collage-seed-layout` constant), `backgroundColor: ds.color.cream` (= `figmaCardSurface`), `borderRadius: ds.radius.sm` (= `figmaTile` 12), `overflow:'hidden'`.
- Tiles: absolute, `left/top/width/height = value * factor`, `transform:[{scale},{rotate}]`, `zIndex` from tile. Image `resizeMode="contain"`.
- Internal `onLayout` measures rendered width; `factor = renderedWidth / canvasWidth`; guards `canvasWidth<=0` → render nothing (PR #147 already does this).

## States
- empty tiles (renders bare cream surface) · pre-measure (factor 0 → no tiles yet) · normal.

## A11y
- Decorative surface; expose `testID`. Caller adds the card's `accessibilityLabel`.

## Acceptance criteria
- [ ] `CreationCollageCard` and `FavouriteOutfitCard` both render `CollageSurface`; no duplicate `collageSurface` styles remain.
- [ ] Tokens are `ds.color.cream` + `ds.radius.sm`; no `figmaCardSurface`/`figmaTile` in screens.
- [ ] Rescale + transform replay behave identically to PR #147 (visual parity test).

## Open questions
- Should `CreationCollageCard`'s title block (date + tag pills) + ⊖ remove also be a shared `CollageCard`, or is sharing just the SURFACE enough? (Lean: share the surface only; the card chrome differs — Favourite has no remove-by-⊖, has a heart.)
- Tag pills inside the card should become `MChip`/`MTag` (separate from this spec).
