---
title: "Phase 3 — Remix Mobile + Telemetry"
description: "Wire HomeScreen to V05 /start + /next, ship RemixButton + AxisChip, daily reset, edge cases, Mixpanel events"
status: pending
priority: P1
effort: 8pt (~12-14h dev)
branch: docs/style-picker-consolidation-spec
tags: [mobile, remix, v05, telemetry, AU-250]
created: 2026-05-10
---

# Phase 3 — Remix Mobile + Telemetry

**Linear**: AU-250 · **Parent**: AU-243 · **Cycle**: 11
**Launch target**: 2026-05-15 (5 days from today)
**Executor**: `mobile-dev` agent (Figma-fluent, sandboxed to `auxi/`)

## Goal

User taps Remix on HomeScreen → fresh same-vibe outfit + axis hint chip. Full Remix UX wired against live V05 backend, animated, and instrumented with Mixpanel.

## Hard upstream prerequisites (NOT in this plan — Phase 2 owns)

Phase 3 visual polish + telemetry tasks are **gated** behind these. Wave 1-3 scaffolds against placeholders; Wave 4-6 cannot ship without them.

| Prereq | Owner | Blocks waves | Fallback |
|---|---|---|---|
| **ENV-CONFIG** — kill hardcoded `localhost:5001` (`react-native-config`) | Phase 2 | Wave 3 staging smoke onward | Cannot test against staging without it |
| **TELEMETRY-SVC** — install `mixpanel-react-native`, scaffold `analytics.ts` hook | Phase 2 | Wave 6 entirely | Wave 6 produces stubs that no-op until SDK lands |
| **DESIGN-02** — Viet's RemixButton + AxisChip + tooltip assets | Phase 2 | Wave 2 visual polish, Wave 4 chip animation | Scaffold with placeholder copy + system colors; visual swap is a single edit |
| **AsyncStorage dependency** — `@react-native-async-storage/async-storage` not in package.json | Phase 2 (or first task of Wave 1) | Wave 1 Task 1.1 | If Phase 2 hasn't added it, Wave 1 first task adds the dep |

If Phase 2 slips past 2026-05-12 EOD, descope chain triggers (see "Descope path" below).

## Phases

| Wave | File | Status | Effort | Parallel? |
|---|---|---|---|---|
| 1 | [phase-01-service-memory-hooks.md](phase-01-service-memory-hooks.md) | Not started | ~110 min | Yes (3 tasks) |
| 2 | [phase-02-remix-button-axis-chip.md](phase-02-remix-button-axis-chip.md) | Not started | ~95 min | Yes (2 tasks) |
| 3 | [phase-03-homescreen-wireup.md](phase-03-homescreen-wireup.md) | Not started | ~165 min | No (sequential — same file) |
| 4 | [phase-04-forced-axis-sheet-animation.md](phase-04-forced-axis-sheet-animation.md) | Not started | ~120 min | Partial (sheet + animation parallel) |
| 5 | [phase-05-daily-reset-edit-context-edge-cases.md](phase-05-daily-reset-edit-context-edge-cases.md) | Not started | ~120 min | Partial |
| 6 | [phase-06-mixpanel-jest-tooltip.md](phase-06-mixpanel-jest-tooltip.md) | Not started | ~135 min | Yes (3 tasks) |

**Total**: 6 waves · 16 tasks · ~745 min (12.4h dev). Fits 8pt budget with light buffer.

## Dependency graph

```
Wave 1 (services + hooks) ──┐
Wave 2 (components)        ─┼──► Wave 3 (HomeScreen wire-up) ──► Wave 4 (forced-axis + animation)
                            │                                          │
                            │                                          ▼
                            └──────────────────────────────────► Wave 5 (daily reset + edge cases)
                                                                       │
                                                                       ▼
                                                                  Wave 6 (Mixpanel + Jest + tooltip)
```

Waves 1 and 2 can run in parallel. Wave 3 blocks everything downstream.

## Success criteria (all must be TRUE before Phase 3 closes)

1. HomeScreen mount calls V05 `/start` (NOT legacy `valenGetRecommendation`); `session_id` persists in `recommendationMemory.ts` and survives app backgrounding within the same calendar day.
2. Tapping RemixButton fires `/next`, outfit cross-fades in 250ms, AxisChip ("New top" / "New layer" / "New color" / "Full remix") appears and auto-fades after 3s.
3. Long-pressing RemixButton opens forced-axis sheet; selecting an axis sends `force_variation_axis` to `/next` and produces the correct swap.
4. Pull-to-refresh on HomeScreen triggers a Remix cycle (not a full `/start` reset); foregrounding after midnight discards session and shows "Today's outfit" header.
5. Mixpanel events `remix_tapped`, `remix_completed`, `v05_recommendation_shown`, `daily_reset_triggered` fire with correct properties (session_id, outfit_hash, variation_axis, latency_ms); Jest tests verify event emission.

## Verification gate (run before declaring Phase 3 done)

```bash
cd auxi && npx tsc --noEmit                                # 0 errors (legacy _HomeScreen.tsx errors expected)
cd auxi && yarn lint                                       # baseline ≤ 4 errors / 3 warnings
cd auxi && yarn test                                       # all Jest tests green
cd auxi && yarn ios:sim                                    # cold start → V05 /start fires; tap Remix → /next + chip
```

## Descope path (if Phase 1/2 slip into mobile time)

Per ROADMAP timeline-risk note, ship in this order:

1. **Cut first**: Wave 4 forced-axis sheet (REMIX-ME-04, picker is power-user feature)
2. **Cut second**: Wave 6 first-time tooltip (REMIX-ME-08)
3. **Cut third**: Wave 5 Edit Context wire (`style_feedback` thread-through)

Critical-path that MUST ship: Waves 1, 2, 3, plus daily-reset from Wave 5, plus core Mixpanel events from Wave 6 (`remix_tapped`, `remix_completed`, `v05_recommendation_shown`).

## Out of scope (Phase 5 owns)

- Maestro YAML authoring (qa-ui)
- Maestro flow execution (qa-mobile)
- Feature flag flip (ops)
- Production smoke (2 testers × 10 Remixes)
- API_DOCUMENTATION.md update for `/next` (backend Phase 1 owns)

## Top risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Phase 2 prereqs (Mixpanel SDK + ENV-CONFIG) slip past 5/12 | M | H | Wave 6 stubs telemetry behind a single `track(eventName, props)` shim — SDK swap is one-file edit. Staging smoke deferred to last day if needed. |
| HomeScreen.tsx already 1267 LOC; adding Remix logic blows past 200-line guideline | H | M | Hard rule: extract into `useRemix.ts`, `useTodayOutfit.ts`. HomeScreen edits are wire-up only — no business logic added inline. |
| Cross-fade animation conflicts with existing snap-paging ScrollView | M | M | Animate the `OutfitSheet` content (Animated.View opacity), NOT the ScrollView container. Wave 3 task 3.4 isolates this. |

## Context links

- `docs/pm/remix-feature-plan.md` §3.2 (mobile architecture), §4 (UX spec), §5 (telemetry)
- `.planning/ROADMAP.md` Phase 3 section
- `.planning/phases/01-remix-backend/01-01-PLAN.md` (Phase 1 BE plan — contract reference)
- `auxi/CLAUDE.md` (RN conventions, navigation registration, dual-Home migration status)
- `auxi/src/screens/HomeScreen.tsx` (current state — what to wire)
- `auxi/src/services/v05Api.ts` (V05 service — extend with `remixOutfit`)
- `auxi/src/services/recommendationService.ts` (legacy — to be replaced at HomeScreen mount call site only; keep service intact for now)
