---
id: WAR-AUDIT-004
type: feature
title: "[Onboarding/Home] Add mood-check screens (Light/Sharp, Energy)"
state: Backlog
priority: P1
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_nodes: ["1977:4834", "1977:4835"]
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Two standalone mood-check TEXT notes sit at page level (outside any
section), suggesting they're either onboarding additions or daily
check-ins on Home. No corresponding screen in code.

## Designer notes (verbatim)

> "Light or sharp today? — Light / Sharp"

Source: Figma TEXT node `1977:4834`.

> "Where's your energy today? — Low / Steady / High"

Source: Figma TEXT node `1977:4835`.

## Code reference checked

- `auxi/src/onboarding/config.ts` — no mood-check copy.
- `auxi/src/screens/` — no mood-check screen.
- `auxi/src/screens/HomeScreen.tsx` — no daily prompt UI.

## Acceptance criteria

**Blocked by designer decision** on placement (see Dependencies). Once
resolved, AC will be:

- [ ] Two mood-check questions implemented as a screen or modal:
      - "Light or sharp today?" → options: Light / Sharp
      - "Where's your energy today?" → options: Low / Steady / High
- [ ] Copy matches Figma TEXT nodes `1977:4834` and `1977:4835` exactly.
- [ ] Selected answers passed to recommendation call as inputs.
- [ ] If placed in onboarding: registered in `src/types/navigation.ts` AND
      `AppNavigator.tsx`. Copy added to `src/onboarding/config.ts`.
- [ ] If placed as daily Home prompt: shown once per day, dismissable.
- [ ] Theme tokens; no hex literals.
- [ ] qa-mobile flow: walk through onboarding (or trigger daily prompt),
      confirm both answers reach the recommendation payload.

## Out of scope

- "NOT in MVP" mood-check sub-section in section `1777:8121` (different
  scope — explicitly excluded by designer).

## Dependencies

- **BLOCKER**: Designer decision on placement — onboarding step? daily
  Home prompt? Sidebar setting? Audit recommends asking before code.
- Backend contract: recommendation endpoint must accept these signals.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile manual on iOS sim.
