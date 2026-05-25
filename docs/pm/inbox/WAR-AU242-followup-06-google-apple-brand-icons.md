---
id: WAR-AU242-FU-06
parent: AU-242
type: chore
title: "[M5] Google G mark + Apple icon SVG assets"
state: Backlog
priority: P2
labels: [type:chore, area:mobile, role:designer, role:mobile-dev, assets, store-compliance, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: Viet (export) + mobile-dev (swap)
estimate: 0.5d
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

Welcome screen's "Continue with Google" / "Continue with Apple" CTAs
currently render placeholder circles. App Store and Play Store
guidelines require the real branded marks (Google G + Apple logo)
sized and used per each vendor's guidelines, otherwise app review can
reject the build.

## Acceptance criteria

- [ ] Designer (Viet) exports `icon_google_g.svg` + `icon_apple_logo.svg`
      from Figma at the sizes used on the Welcome CTAs.
- [ ] Google G follows Google's brand guidelines (colored variant on
      light bg, white-only variant on dark bg if dark mode supported on
      Welcome).
- [ ] Apple mark follows Apple HIG (white on black or black on white per
      button background).
- [ ] Assets placed in `auxi/src/assets/icons/`.
- [ ] WelcomeScreen swaps placeholder circles for branded icon
      components.
- [ ] Compliance confirmed: link to Google Brand Permissions page +
      Apple HIG "Sign in with Apple" section in PR description.

## Out of scope

- Other social providers (Facebook, etc.) — not in MVP.
- Branded loading spinners.

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding M5
- Figma spec: `plans/260521-2335-au-242-figma-spec/01-welcome-screen.md`
- Files: `auxi/src/screens/auth/WelcomeScreen.tsx`,
  `auxi/src/assets/icons/`
- Parent: AU-242
