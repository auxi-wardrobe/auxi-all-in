---
title: "New Onboarding Redesign (Welcome → Step1/2/3 → Loading → Completed → Outro)"
description: "Replace the V05 onboarding UI with the 8-screen Figma redesign behind a feature flag; backend contract already exists."
status: pending
priority: P2
effort: ~26h
branch: feat/au-253-home-grid-view
tags: [auxi, onboarding, figma, mobile, v05]
created: 2026-05-26
---

# New Onboarding Redesign — Implementation Plan

8-screen Figma redesign of first-login onboarding in `auxi/`. Replaces the
current V05 chat-bubble/pill UI with tile-grids + pin-badge multi-select +
Loading/Completed/Outro screens. **Backend contract is READY** — reuses
`POST /api/v05/onboarding/generate` (no backend work). Gated behind a new
`ONBOARDING_V2_ENABLED` flag; legacy V05 screens kept as fallback until cutover.

## Source artifacts
- Figma extraction: `plans/260526-1443-onboarding-figma-extraction/figma-extraction-onboarding.md`
- Backend contract: `wardrobe-backend/API_DOCUMENTATION.md` §`POST /api/v05/onboarding/generate` (L3373)
- V05 client: `auxi/src/services/v05Api.ts`

## Backend-contract verdict: **NO backend change required**
`/onboarding/generate` already accepts `Mixed`, `fit_preference` (`Slim Fit`/
`Classic Fit`/`Relaxed Fit`), and 2-3 ranked style picks. Figma labels
("Regular"/"Slim"/"Relaxed", pick-2) are a **display→wire mapping** in
`config.ts`, not a contract change. See Phase 0 for the one open mismatch.

## Critical architecture insight (drives Phase 2)
Today `completeOnboarding()` flips `is_first_login=false`, which makes
`AppNavigator` (`auxi/src/navigation/AppNavigator.tsx:54`) **remount into the
Home stack**, unmounting all onboarding screens. The redesign's Loading/
Completed/Outro must render AFTER generation but BEFORE the stack swap.
Resolution: defer `completeOnboarding()` until the user taps "See my outfit"
on the Outro screen — generation result is held in route params/local state.

## Phases

| # | Phase | Status | Effort | Blocks |
|---|---|---|---|---|
| 0 | [Decision gates + contract resolution](phase-00-decision-gates.md) | pending | 2h | ALL |
| 1 | [Theme tokens + icons](phase-01-theme-and-icons.md) | pending | 3h | 0 |
| 2 | [Config + state + navigation scaffold](phase-02-config-state-nav.md) | pending | 4h | 0,1 |
| 3 | [Welcome + Step screens (1/2/3)](phase-03-welcome-and-steps.md) | pending | 6h | 1,2 |
| 4 | [Loading + Completed + Outro](phase-04-loading-completed-outro.md) | pending | 4h | 2,3 |
| 5 | [Service wiring + persistence](phase-05-service-wiring.md) | pending | 3h | 3,4 |
| 6 | [Tests + QA gates](phase-06-tests-and-qa.md) | pending | 4h | 5 |

## Figma→RN workflow gates (canonical — enforced in phases)
extraction (DONE) → **qa-ui review-extraction PASS** (Phase 0) →
figma-to-rn impl (Phases 3-4) → `auxi-lint-tokens.sh` clean (Phase 3-4 exit) →
qa-ui Compare Pass2/3 (Phase 6) → qa-mobile smoke (Phase 6) → PR.

## Key dependencies
- Phase 0 gate MUST clear before any code (CEO copy + 5 design decisions).
- `mobile-dev` owns all `auxi/` code; `qa-ui`/`qa-mobile` own QA; `tech-lead`
  signs the (no-op) contract verdict.
- Both fonts (Poppins, Inter) already bundled — verify in Phase 1.

## Decision gates (must resolve before Phase 1 — see Phase 0)
1. Copy/typos ("MACGIE", "Minmal", "in you profile", subject/verb slips) — CEO.
2. Fit label mismatch: Figma "Regular" vs contract `Classic Fit` — confirm display label.
3. Caption-pill color: `rgba(18,18,18,0.75)` vs `rgba(39,42,50,0.9)` — canonical?
4. Pin badge: styled View+number (recommended) vs fixed SVG.
5. Replace-vs-keep legacy V05 + flag cutover plan.
6. Location-permission prompt placement in the new flow.
