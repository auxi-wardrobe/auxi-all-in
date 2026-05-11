---
phase: 4
title: "SEO, Performance, A11y"
status: pending
priority: P2
effort: "2h"
dependencies: [3]
---

# Phase 4: SEO, Performance, A11y

## Overview
Polish pass: meta tags, structured data, OG image, sitemap, robots,
Lighthouse audit, manual a11y sweep. Nothing visual changes; only the
quality bars get raised.

## Requirements
- **Functional:** crawlable, shareable on social, ready for App Store
  reviewers to land on.
- **Non-functional:** Lighthouse mobile ≥95 in all four categories;
  axe-core finds zero serious/critical issues.

## Architecture

**SEO surface:**
- `<title>`: "Auxi — Outfits from your own wardrobe"
- `<meta name="description">`: 155-char pitch from `copy.ts`
- `<link rel="canonical">`: production URL placeholder
- OpenGraph + Twitter card tags via `BaseLayout` props
- JSON-LD `MobileApplication` schema (App Store URL, app category, OS)
- `sitemap.xml` via `@astrojs/sitemap`
- `robots.txt` allowing all, disallowing `/styleguide`

**OG image:**
- 1200×630 PNG generated once via Astro endpoint or static file
- Editorial composition: "Auxi" in display serif on paper bg + small phone

**Performance:**
- Image: hero phone is SVG (already small)
- Fonts: subset Fraunces to display weights only, Inter to 400/600
- Tailwind: `content` glob ensures purge; check final CSS < 30KB gzipped
- Astro: `inlineStylesheets: 'auto'` to inline critical CSS

**A11y:**
- All images have meaningful `alt` (or `alt=""` for decorative)
- App Store / TestFlight buttons: text accessible via `aria-label` if image-only
- `<details>` summary has visible focus ring
- Color contrast: ink on paper = 16.4:1 (AAA); ash on paper = 5.3:1 (AA);
  paper on ink = 16.4:1 (AAA); accent on paper = 4.6:1 (AA — text only at large sizes)
- Skip-to-content link, hidden until focused
- `prefers-reduced-motion`: disable any sticky-header transition

## Related Code Files
- Modify: `src/layouts/BaseLayout.astro` — meta, OG, JSON-LD, skip link
- Modify: `astro.config.mjs` — add `@astrojs/sitemap` integration, set `site:` to production URL placeholder
- Create: `public/robots.txt`
- Create: `public/og-image.png` (1200×630)
- Modify: `src/data/copy.ts` — add `meta.title`, `meta.description`, `meta.url`
- Modify: every section component — add missing alt/aria where audit catches gaps

## Implementation Steps
1. `pnpm add @astrojs/sitemap` and wire into `astro.config.mjs`.
2. Add `site: 'https://auxi.app'` (placeholder) to astro config.
3. Extend `BaseLayout` props: accept `title`, `description`, `ogImage` with sane defaults.
4. Inject all meta tags + JSON-LD script in BaseLayout `<head>`.
5. Generate OG image (Figma export or any 1200×630 PNG, swap-ready).
6. Write `robots.txt` (User-agent: *, Allow: /, Disallow: /styleguide).
7. Subset fonts: import only the variable axes/weights actually used.
8. Add skip-to-content link as first focusable element in BaseLayout body.
9. Run Lighthouse (Chrome DevTools → mobile → throttled). Capture scores. Target ≥95 each.
10. Run axe DevTools on `/`. Capture findings, fix anything serious/critical.
11. Manual keyboard nav: tab through entire page, confirm visible focus on every interactive element.
12. Manual VoiceOver pass on macOS Safari: confirm headings flow, FAQ accordion announces state.

## Success Criteria
- [ ] Lighthouse mobile: Performance ≥95, A11y ≥95, Best Practices ≥95, SEO ≥95.
- [ ] axe-core: 0 serious, 0 critical issues.
- [ ] Tab order is logical; visible focus ring on every interactive element.
- [ ] OG image renders correctly in Facebook Sharing Debugger and Twitter Card Validator (or local preview).
- [ ] sitemap.xml generated in `dist/`; robots.txt copied to `dist/`.
- [ ] Final CSS bundle < 30KB gzipped.

## Risk Assessment
- **Lighthouse Performance < 95:** likely culprits are font loading or
  third-party analytics. Mitigation: defer analytics until phase 5, use
  `font-display: swap` + preload on the two critical weights only.
- **OG image quality:** crude OG hurts shareability. Mitigation: budget
  30 minutes for a deliberate composition; if no time, ship a clean
  type-only OG ("Auxi — Outfits, sorted") instead of a bad mockup.
- **JSON-LD errors:** Google's Rich Results Test will catch schema bugs.
  Mitigation: validate before deploy.
