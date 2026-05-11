---
title: "Auxi Web — Marketing Homepage (Astro)"
description: "Editorial/minimal marketing homepage for Auxi. New repo (sibling to auxi/ and wardrobe-backend/). Astro + Tailwind, deployed to Cloudflare Pages. Primary CTAs: App Store + TestFlight."
status: in-progress
priority: P2
branch: "docs/style-picker-consolidation-spec"
tags: [marketing, web, astro, tailwind, cloudflare-pages]
blockedBy: []
blocks: []
created: "2026-05-10T14:36:36.435Z"
createdBy: "ck:plan"
source: skill
---

# Auxi Web — Marketing Homepage (Astro)

## Overview

Build a standalone marketing homepage for the Auxi brand, separate from the
React Native app (`auxi/`) and FastAPI backend (`wardrobe-backend/`). Lives at
`auxi-web/` in the umbrella, eligible for promotion to a git submodule once
stable. Astro + Tailwind, deployed to Cloudflare Pages.

**Audience:** prospective users discovering Auxi via search, social, or word
of mouth. **Goal:** drive App Store + TestFlight installs.
**Voice:** editorial, minimal, fashion-magazine-adjacent. Not playful, not
enterprise.

## Decisions Locked
- **Stack:** Astro 6.3.1 + TypeScript strict + Tailwind CSS 4 (CSS-first via
  `@theme` in `src/styles/global.css`). Deviation from original plan (which
  said Astro 4 + Tailwind 3) — `create-astro@^4` installed latest stable
  Astro 6, and Tailwind 4 is the recommended pairing. No client framework
  (React/Vue/Svelte) — sections are static, FAQ uses native `<details>`.
- **Deploy:** Cloudflare Pages via `wrangler pages` (matches umbrella's
  existing Cloudflare flow used by `wardrobe-admin`).
- **Location:** `/Users/nguyenminhduc/Desktop/wardrobe_project/auxi-web/`
  as a new top-level directory. Initialize as standalone git repo; user can
  later `git submodule add` to umbrella.
- **No backend coupling.** No Valen API calls. Email capture (if added later)
  goes through a Cloudflare Worker, not the FastAPI server.
- **CTAs:** App Store badge + TestFlight invite link. App Store URL is a
  placeholder until app is live; TestFlight URL stubbed.

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Repo & Tooling](./phase-01-repo-tooling.md) | ✅ Completed |
| 2 | [Design System](./phase-02-design-system.md) | ✅ Completed |
| 3 | [Page Sections](./phase-03-page-sections.md) | ✅ Completed |
| 4 | [SEO Performance A11y](./phase-04-seo-performance-a11y.md) | ✅ Completed (config; Lighthouse audit pending live URL) |
| 5 | [Deploy](./phase-05-deploy.md) | 🟡 Config complete; awaiting `wrangler login` to ship preview URL |

## Dependencies

No cross-plan dependencies. Independent of:
- `260510-1542-remix-mobile-phase3` (RN HomeScreen work — different surface).
- Backend / mobile contract (no API consumption).

## Out of Scope (YAGNI)
- Blog / CMS — single landing page only. Add later if content grows.
- Email capture backend — placeholder mailto until product needs waitlist.
- Internationalization — English only for v1 (auxi RN app is also EN-only
  per Remix memory).
- Auth, dashboards, account pages.
- A/B testing, marketing analytics beyond a single Plausible/Umami snippet.

## Success Criteria
- [x] `auxi-web/` repo builds: `pnpm build` produces static output (2 pages, ~1s).
- [ ] Lighthouse mobile ≥95 — **deferred until preview URL is live** (run on `*.pages.dev`).
- [x] All copy + assets ship as placeholders the brand owner can swap (`src/data/copy.ts`, `src/data/faq.ts`).
- [x] Deployable to Cloudflare Pages with one command (`pnpm deploy`).
- [x] README documents local dev, build, deploy, and copy/asset swap surface.

## Manual Steps Still Owed
- [ ] `sudo xcodebuild -license` then `cd auxi-web && git init && git add . && git commit -m "chore: scaffold auxi-web (astro 6 + tailwind 4)"`
- [ ] `pnpm dlx wrangler login` then `pnpm deploy` (creates Cloudflare project + preview URL)
- [ ] Replace `public/og-image.png` placeholder (1200×630) — currently missing
- [ ] Designer/CEO sign-off on the preview URL before any custom domain
- [ ] Real App Store + TestFlight URLs in `src/data/copy.ts` (currently `#hero` placeholders)
- [ ] Real product screenshot inside `PhoneMockup.astro`'s slot
- [ ] Run Lighthouse on the deployed preview URL; gap any score <95 in a follow-up

## Risk Register
- **Brand drift:** designer (CEO) may reject the editorial direction once seen.
  Mitigation: ship behind a preview URL only; do not point custom domain
  until designer signs off on the look.
- **App Store URL placeholder:** must not 404 in production. Mitigation: link
  to brand homepage anchor until live.
- **Asset gap:** no real product screenshots yet. Mitigation: use device
  mockup frames with neutral placeholder content; document swap location.
