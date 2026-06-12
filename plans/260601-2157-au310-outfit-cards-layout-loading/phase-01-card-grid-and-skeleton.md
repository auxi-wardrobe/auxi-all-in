# Phase 01 — OutfitCardGrid + OutfitCardSkeleton (AU-310)

> Implementation brief for `mobile-dev`. Read together with `plan.md` and the research report
> `plans/reports/research-260601-2127-au310-outfit-cards-layout-loading-spec.md` (+ `au310-*.png`).
> Scope: `auxi/` only. JS-only change — RN `Animated`, **no new native deps**.

## Files to CREATE (`auxi/src/components/features/`)
1. `outfit-card-layouts.ts` — pure, testable count->layout descriptor (no JSX).
2. `OutfitCardGrid.tsx` — renders cards for an outfit from the descriptor + reveal/fade animations.
3. `OutfitCardSkeleton.tsx` — renders the matching skeleton (same slots) with opacity-breathing.

## File to MODIFY
- `auxi/src/screens/HomeScreen.tsx` — replace the inline grid layout logic (`twoRowOneLarge`/`twoByTwo`/`heroStackPlusRows` around `:74-165`, `computeHeroRowHeight` `:1520`, `GarmentPreview` `:1900-1921`, the loading placeholder `:1873-1881`) with `<OutfitCardGrid>` / `<OutfitCardSkeleton>`. **Keep everything else**: caption pill (`OutfitCardCaption`), `OutfitActionRow`, the Remix/`Show (n/3)`/dots control row, `Wear this` CTA, collage mode + `CollageSheetCanvas`, the grid<->collage footer toggle, AU-303 swipe wiring if present.

## Geometry (from real frames — drive off screen width, don't hardcode 189)
- `PAGE_PADDING = 16`, `GAP = 4`, `RADIUS = theme.borderRadii.figmaTile (12)`, surface = `theme.colors.figmaCardSurface (#f2efec)`.
- `contentW = screenWidth - 2*PAGE_PADDING`.
- **Two-col family (1-4 items):** `colW = (contentW - GAP)/2`, card 3:4 -> `h = colW*4/3`. Full/hero width = `contentW`.
- **Hero-three-col family (5+):** `colW = (contentW - 2*GAP)/3`; `smallH = colW*4/3`; `heroW = 2*colW + GAP`; `heroH = 2*smallH + GAP` (so hero height == the 2 stacked right-column smalls). All small cards are `colW x smallH`.

## Layout descriptors (count -> rows; matches the 6 screenshots)
Model as ordered rows of cells. Each cell: `{ size: 'standard'|'large'|'medium'|'small', widthFraction, revealGroup }`.
`revealGroup`: 0 = hero, 1 = supporting, 2 = accessory (drives stagger order).
- **1:** Row[ standard(full, g0) ]  *(defensive; not in Figma)*
- **2:** Row[ standard(full, g0) ] · Row[ small(1/3, **centered**, g2) ]
- **3:** Row[ medium(1/2, g1), medium(1/2, g1) ] · Row[ medium(1/2, **left**, g1), EMPTY ]
- **4:** Row[ medium, medium (g0,g1) ] · Row[ medium, medium (g1,g1) ]  *(2x2)*
- **5:** TopSection[ large(2/3, g0) + rightCol( small(g1), small(g1) ) ] · Row[ small, small (g2, left-aligned) ]
- **6:** TopSection[ large + rightCol(small,small) ] · Row[ small, small, small (g2) ]
- **>6 (7+):** TopSection[ large + rightCol(small,small) ] · then Rows of 3 small (g2) until items exhausted; last row left-aligned, may hold 1-2. **Scrolls** (wrap grid in the existing scroll container; top section + first rows visible above the fold).

The skeleton uses the SAME descriptor (by count) so slots are identical -> zero layout shift.

## Animations (RN `Animated` only)
- **Content reveal (per card):** `opacity 0->1` + `translateY 8->0`, `300ms`, `Easing.out`. Stagger by `revealGroup`: delay = `revealGroup * 45ms` (within 30-60ms range; cards in same group reveal together). Run once on mount/when items change.
- **Image fade-in:** each card image starts `opacity 0`; on `Image onLoad` animate to `1` over `~200ms`. Card slot keeps fixed dimensions before load (no resize / white flash). Keep fallback tile for missing `resolveItemImage`.
- **Skeleton (Option B opacity-breathing):** one shared `Animated.Value` looping `0.92<->1`, `~1700ms`, `Easing.inOut(ease)`, applied to all skeleton cells. Soft neutral surface, radius 12 — NO high-contrast gray, no movement.
- **Reduced motion:** read `AccessibilityInfo.isReduceMotionEnabled()` + subscribe to change event. When ON -> reveal is opacity-only (drop translateY), skeleton holds static `1.0` (no breathing), image still fades (opacity is allowed). Thread a `reduceMotion` boolean into both components (small hook `useReduceMotion()` is fine).

## Card visual (reuse current chrome)
Each card: image via `resolveItemImage(item)` (`src/utils/url.ts`, prefer `image_png`), `resizeMode:'contain'`, surface bg, radius 12, plus the existing **pin icon** (top-right) and **"common" rarity tag** (bottom-center) exactly as `GarmentPreview` renders today. Don't invent new styling — lift current styles. Preserve any onPin/onPress handlers HomeScreen passes today.

## Figma extraction (do FIRST)
Run `figma-design-extraction` on node `2850-11205` (loading) + one loaded count frame (`2850:9580`), and `get_design_context`/`get_variable_defs` to confirm: skeleton surface color, card radius, the "Generating" pill + control-row + `Wear this` CTA tokens, fonts. Save the extraction note to `plans/260601-2157-au310-outfit-cards-layout-loading/figma-extraction-outfit-cards.md`. Map every value to an existing `theme.ts` token; if a token is genuinely missing, add it to `theme.ts` (no raw hex/font literals — `auxi-lint-tokens.sh` must stay clean).

## Verify before reporting back
1. `cd auxi && npx tsc --noEmit` — zero errors.
2. `yarn lint` — no new errors.
3. `./scripts/auxi-lint-tokens.sh` (from project root) — clean (no hex/font drift).
4. Confirm by reading the code that collage mode, captions, action row, CTA, view toggle are still wired.
Do NOT run the simulator or commit — orchestrator handles QA (qa-ui/qa-mobile) and commit/PR.

## Acceptance criteria
- [ ] `outfit-card-layouts.ts` returns correct descriptors for counts 1-8 (8 -> >6 family, 2 extra-row).
- [ ] All 6 layouts render matching `au310-count-*.png`; 2-item = full-width hero + centered small (NOT 2 equal); 3-item = 2-over-1-left; 4 = 2x2; 5/6 = hero + right stack + bottom row; >6 scrolls.
- [ ] Skeleton matches final layout per count; opacity-breathing; zero layout shift on load.
- [ ] Staggered reveal hero->supporting->accessory; image fade-in; reduced-motion path.
- [ ] tsc + lint + token-lint clean; existing Home chrome preserved.

## Report back
Files created/modified (paths), the layout-descriptor approach, token additions (if any), verify results (tsc/lint/token-lint output), and Status: DONE | DONE_WITH_CONCERNS | BLOCKED.

**Env:** macOS · project root `/Users/nguyenminhduc/Desktop/wardrobe_project` · auxi is a git submodule on branch `feat/au-310-outfit-cards-layout-loading` · RN 0.83 · TS 5.8 · TanStack Query 5 · yarn.
