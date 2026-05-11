---
phase: 2
title: "Design System"
status: pending
priority: P1
effort: "3h"
dependencies: [1]
---

# Phase 2: Design System

## Overview
Establish the editorial/minimal visual language as Tailwind theme tokens and
a small set of layout primitives. No page content yet — just the toolkit
phase 3 will compose with.

## Requirements
- **Functional:** tokens + primitives reusable across all sections; a
  `/styleguide` route that renders every primitive for visual audit.
- **Non-functional:** zero literal hex/px in section components after this
  phase — everything via tokens.

## Architecture

**Tokens (in `tailwind.config.mjs`):**
```
colors:
  ink:      #14110F   (primary text)
  paper:    #FAF7F2   (background)
  ash:      #6F6A63   (secondary text)
  accent:   #B5532A   (terracotta — used sparingly)
  hairline: #E6E1D8   (borders)

fontFamily:
  display:  ['Fraunces', 'serif']      # weighted serif, optical sizing
  sans:     ['Inter', 'system-ui', 'sans-serif']

fontSize:  fluid clamp() via `text-display-{xl,lg,md}` utilities
spacing:   8px base scale (4,8,12,16,24,32,48,64,96,128)
maxWidth:  prose 640, content 1120, wide 1280
```

**Primitives (`src/components/`):**
```
Container.astro     # max-w-content, px-6 md:px-8, mx-auto
Section.astro       # vertical rhythm wrapper (py-24 md:py-32), id slot
Eyebrow.astro       # small uppercase label above headings
Heading.astro       # h1/h2/h3 props, display font, fluid size
Text.astro          # body text variants (lead, body, caption)
Button.astro        # primary (ink bg) + ghost (outline) variants
Badge.astro         # App Store / TestFlight badge wrappers
Header.astro        # sticky-on-scroll, logo + nav anchors + CTA
Footer.astro        # 3-col: brand, links, legal
```

**Fonts:** self-host via `@fontsource-variable/fraunces` and
`@fontsource-variable/inter`. Preload the two weights actually used
(Fraunces 500 italic for display, Inter 400 + 600 for body).

## Related Code Files
- Modify: `tailwind.config.mjs` — full theme extension.
- Create: `src/components/{Container,Section,Eyebrow,Heading,Text,Button,Badge,Header,Footer}.astro`.
- Create: `src/styles/global.css` — `@font-face` via Fontsource imports, base resets.
- Modify: `src/layouts/BaseLayout.astro` — wire Header + Footer slots, font preload links.
- Create: `src/pages/styleguide.astro` — render every primitive, every variant. Excluded from prod via `index: false` in robots phase.

## Implementation Steps
1. `pnpm add @fontsource-variable/fraunces @fontsource-variable/inter`
2. Extend `tailwind.config.mjs` with the token block above. Use `theme.extend`, not full overrides.
3. Define fluid type via Tailwind plugin (function in config, not arbitrary values everywhere): `text-display-xl` → `clamp(2.5rem, 5vw + 1rem, 4.5rem)`, etc.
4. Write `global.css`: import Fontsource files, `body { @apply bg-paper text-ink font-sans antialiased; }`.
5. Build each primitive in order: Container → Section → Eyebrow → Heading → Text → Button → Badge.
6. Build Header (sticky after 80px scroll, logo wordmark "Auxi" in display font, nav: Features / How it works / FAQ, CTA: "Get the app").
7. Build Footer (brand block, link columns, year + legal text).
8. Wire BaseLayout: Header above `<slot />`, Footer below. Add `<link rel="preload" as="font">` for the 3 weights.
9. Build `/styleguide` page rendering everything; verify in browser.
10. Run `pnpm build` — confirm dist size sane (<200KB total CSS+HTML for styleguide page).

## Success Criteria
- [ ] `/styleguide` renders all primitives in all variants without overflow on 360px viewport.
- [ ] No literal hex codes in any `.astro` file outside `tailwind.config.mjs`.
- [ ] Fonts load locally (no Google Fonts CDN); FOIT < 200ms.
- [ ] Header sticks correctly after scroll; mobile menu (if needed) is a `<details>` for zero-JS.
- [ ] `astro check` passes.

## Risk Assessment
- **Type-scale fluid math:** clamp() boundaries can produce ugly mid-sizes.
  Mitigation: test `/styleguide` at 360, 768, 1024, 1440 widths before
  committing the curve.
- **Sticky header on Safari iOS:** known z-index quirks with backdrop-blur.
  Mitigation: use solid `bg-paper/95` not blur until tested on real iOS.
- **Accent color overuse:** terracotta should be ≤5% of any viewport. Lint
  by code review in phase 3, not automated.
