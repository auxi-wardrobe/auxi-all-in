---
phase: 3
title: "Page Sections"
status: pending
priority: P1
effort: "5h"
dependencies: [2]
---

# Phase 3: Page Sections

## Overview
Compose the single `/` route from five sections using phase 2 primitives.
All copy is placeholder-quality but production-shaped (real lengths, no
lorem ipsum). All imagery is device-frame mockups with neutral content.

## Requirements
- **Functional:** five sections render in order; anchor links from header
  scroll-snap to each section's `id`.
- **Non-functional:** total page weight < 600KB on first paint, < 1.2MB
  full load including hero imagery.

## Architecture

**Section order (top → bottom):**
1. **Hero** (`#hero`)
   - Eyebrow: "Now in TestFlight"
   - H1: "Outfits, sorted." (display, italic)
   - Lead: 1 sentence — "Auxi turns the clothes you already own into outfits worth wearing."
   - CTA row: App Store badge + TestFlight pill button
   - Right column: phone mockup (iPhone 15 frame, 9:19.5 aspect) showing a stylized outfit card placeholder
   - Layout: 2-col on ≥1024px, stacked on mobile (image first → copy)

2. **Problem → Promise** (`#why`)
   - Eyebrow: "Why Auxi"
   - Two-column editorial: left = problem ("A wardrobe of decisions made every morning"), right = promise ("One tap. One outfit. Built from what you own.")
   - No imagery. Type-driven.

3. **How it works** (`#how`)
   - Eyebrow: "Three steps"
   - 3 numbered cards: (01) Snap your clothes, (02) Tell us the day, (03) Wear the result
   - Each card: numeral in display serif, 2-line copy, faint hairline border

4. **Features** (`#features`)
   - Eyebrow: "Built for daily wear"
   - 4 feature blocks in a 2x2 grid (1-col on mobile): Weather-aware, Occasion-aware, Wardrobe memory, Style direction
   - Each: short title (display) + 2 sentences (sans), no icons (editorial = no clipart)

5. **FAQ** (`#faq`)
   - Eyebrow: "Questions"
   - 5 questions using native `<details><summary>` for zero-JS accordion:
     - Is Auxi free?
     - Do I need to photograph every item?
     - What if I don't like the outfit?
     - Will it learn my style?
     - When will Android arrive?

6. **Footer-CTA strip** (above Footer)
   - Single-line: "Ready to dress easier?" + App Store + TestFlight buttons
   - Background: ink, text: paper (visual full-stop before footer)

## Related Code Files
- Create: `src/components/sections/{Hero,WhyAuxi,HowItWorks,Features,Faq,FooterCta}.astro`
- Create: `src/components/PhoneMockup.astro` — SVG iPhone frame with `<slot />` for screen content
- Create: `src/data/copy.ts` — all marketing strings exported as typed objects (single edit surface for non-devs later)
- Create: `src/data/faq.ts` — array of `{ q, a }`
- Modify: `src/pages/index.astro` — assemble sections in order
- Add to `public/`: App Store badge SVG (Apple's official asset, downloaded), TestFlight wordmark
- Add to `public/img/`: 1 placeholder outfit-card PNG (or SVG) for the hero phone screen

## Implementation Steps
1. Write `src/data/copy.ts` with every string as a typed const. No copy lives inside .astro files.
2. Build `PhoneMockup.astro` — fixed-aspect SVG frame, slot for screen content, drop-shadow for depth.
3. Build Hero with copy from `copy.hero`, App Store badge as `<img>` (alt="Download on the App Store"), TestFlight as `<a>` styled via Button primitive.
4. Build WhyAuxi (no imagery, pure type).
5. Build HowItWorks (3 cards in flex-row md:gap-12, gap-8 on mobile).
6. Build Features (CSS grid 2x2 ≥md, 1-col mobile).
7. Build Faq using `<details>` — style summary marker via `details > summary::-webkit-details-marker { display: none }` and a custom `+` rotated to `×` on `[open]`.
8. Build FooterCta (full-bleed dark band, single line + buttons).
9. Wire `index.astro`: `<Hero /><WhyAuxi /><HowItWorks /><Features /><Faq /><FooterCta />`.
10. Verify anchor scrolling from Header nav works.
11. Verify mobile (DevTools 360px) — no horizontal scroll, type readable, CTAs reachable.

## Success Criteria
- [ ] `/` renders all 6 sections in order on desktop and mobile.
- [ ] All copy sourced from `src/data/`; grep for the literal "Outfits, sorted" returns only `copy.ts`.
- [ ] FAQ accordion works without JS (DevTools → Disable JavaScript → still functional).
- [ ] Header nav links scroll to correct sections on click.
- [ ] No images > 200KB; phone mockup is SVG, not raster.
- [ ] Lighthouse "Best Practices" passes (no console errors, no mixed content).

## Risk Assessment
- **App Store badge legal:** Apple requires their official badge artwork
  unmodified. Mitigation: download from Apple's marketing toolkit, store
  unaltered SVG, do not recolor.
- **Hero imagery is placeholder-shaped:** real screenshot will need a swap.
  Mitigation: PhoneMockup takes a slot — swapping a single SVG/PNG inside
  is the only edit needed.
- **FAQ copy makes claims app may not deliver** (e.g., "Yes, Android is
  coming"). Mitigation: hedge with "TestFlight first, App Store next" and
  flag for product owner review before deploy.
