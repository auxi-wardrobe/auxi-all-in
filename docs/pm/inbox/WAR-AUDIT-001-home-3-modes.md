---
id: WAR-AUDIT-001
type: feature
title: "[Home] Add 3 modes selector (Safe / Power / Creative)"
state: Backlog
priority: P1
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "1752:28109"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer flagged 3 user modes as a core UX feature on the Home surface.
No mode selector currently exists in `auxi/src/screens/HomeScreen.tsx`.

## Designer note (verbatim)

> "**3 modes**: Safe Choice (lazy/blend in) / Power Choice (impressive/energy)
> / Creative Choice (refresh/experiment)"

Source: Figma sticky note `1752:28109` (page `470:1121`, section `909:7328`
"Home adjust").

## Code reference checked

- `auxi/src/screens/HomeScreen.tsx` — no mode selector, no mode state.
- `auxi/src/services/recommendation.ts` — recommendation call has no mode parameter.
- `auxi/src/services/valenGetRecommendation` — no `mode` arg.

## Acceptance criteria

- [ ] Mode selector UI added to `HomeScreen.tsx` exposing 3 options:
      Safe / Power / Creative.
- [ ] Each mode has a designer-confirmed visual treatment (icon, copy,
      colour) matching Figma node `1752:28109`.
- [ ] Selected mode persists for the session and is sent to backend
      recommendation endpoint as a parameter.
- [ ] Backend contract updated: a follow-up sub-issue filed for
      `wardrobe-backend/` to accept and honour the mode parameter — see
      "Dependencies" below.
- [ ] Screen registered correctly (no new screen needed; modify existing
      Home — but if a sub-screen is added, register in
      `src/types/navigation.ts` AND `AppNavigator.tsx`).
- [ ] Theme tokens in `src/theme/theme.ts` used; no hex literals.
- [ ] qa-mobile flow: select each mode, confirm UI feedback + recommendation
      payload reflects selection.

## Out of scope

- Backend-side recommendation logic per mode (separate ticket once contract
  is signed off by tech-lead).
- Persisting mode across sessions (default per session unless designer
  confirms otherwise).

## Dependencies

- Designer decision: is this in MVP? Audit flagged it as "almost certainly
  required" but unconfirmed.
- Tech-lead sign-off on recommendation contract change.
- Follow-up backend sub-issue once mobile contract is agreed.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile manual: switch modes on iOS sim, confirm payload via
  `apiClient` interceptor logs.
