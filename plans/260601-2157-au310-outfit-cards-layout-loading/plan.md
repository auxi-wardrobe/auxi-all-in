# AU-310 — Outfit Recommendation Cards: Layout + Loading

**Linear:** AU-310 · **Branch:** `feat/au-310-outfit-cards-layout-loading` (off `feat/home-collage-canvas-play`)
**Design:** Figma `0nXXMAR4Arf1ZfjtQvtBh0` nodes `2850-11205` (loading), count series `3230:35149`/`2850:9613`/`3104:5907`/`2850:9580`/`2850:9508`/`2850:9542`
**Research:** `plans/reports/research-260601-2127-au310-outfit-cards-layout-loading-spec.md` (+ `au310-*.png` screenshots)

## Goal
Extract the inline outfit-card grid out of the 2,200-line `HomeScreen.tsx` into reusable, count-driven
`OutfitCardGrid` + `OutfitCardSkeleton` components matching the AU-310 spec exactly: 3:4 cards, count layouts
2/3/4/5/6/>6, layout-matched loading skeleton with opacity-breathing, staggered content reveal, image fade-in,
reduced-motion support. JS-only (RN `Animated`, **no new native deps**).

## Decisions (locked)
- Animation: built-in RN `Animated` (no Reanimated/Moti). Skeleton = **Option B opacity-breathing 0.92→1**, no gradient lib.
- Card geometry from real frame: card 189×252 (3:4), gap **4px**, page padding **16px** (drive from screen width, don't hardcode 189).
- Preserve existing chrome: caption pill (`OutfitCardCaption`), action row (`OutfitActionRow`), control row (Remix/Show/dots), `Wear this` CTA, grid↔collage footer toggle, collage mode.
- 1-item outfit → single full-width hero card (defensive; not in spec).

## Phases
| # | Phase | Status |
|---|---|---|
| 0 | Branch + plan + Figma token extraction artifact | branch/plan done; extraction = mobile-dev |
| 1 | `outfit-card-layouts.ts` (count→layout descriptor) + `OutfitCardGrid` + `OutfitCardSkeleton` + reveal/fade/reduced-motion, wire into HomeScreen | see `phase-01-card-grid-and-skeleton.md` |
| 2 | Verify: `npx tsc --noEmit`, `yarn lint`, `./scripts/auxi-lint-tokens.sh` clean | pending |
| 3 | qa-ui Compare (Figma vs sim) on all count layouts + loading; qa-mobile smoke | pending |
| 4 | PR (target = `feat/home-collage-canvas-play`; confirm w/ tech-lead) | pending |

## Acceptance (definition of done)
- All count layouts (2,3,4,5,6,>6) render per the real frames; 4 = 2x2 baseline; >6 scrolls.
- Skeleton occupies identical slots as final layout (zero layout shift on load).
- Reveal: hero->supporting->accessories, opacity 0->1 + translateY 8->0, 250-400ms, 30-60ms stagger.
- Reduced-motion: opacity-only, no translate, no breathing movement.
- No hex/font drift (`auxi-lint-tokens.sh` clean); `tsc`+`lint` green.
- collage mode, captions, actions, CTA, view toggle all still work.

## Open (non-blocking; confirm w/ Viet)
- 1-item floor exists in V05? · "Wear this" literal label · moving-shimmer (Option A) wanted later -> would add `react-native-linear-gradient`.
