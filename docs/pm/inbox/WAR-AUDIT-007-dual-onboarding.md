---
id: WAR-AUDIT-007
type: chore
title: "[Onboarding] Resolve dual onboarding flow (gender variants vs single shared)"
state: Backlog
priority: P2
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_nodes: ["909:7193", "909:7210", "909:7227"]
figma_section: "470:1122"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Figma shows three gender-specific onboarding variants
(`auxi-ask01-m / -w / -u`). Code has a single shared
`GenderPreferenceScreen.tsx`. `auxi/CLAUDE.md` already flags this:

> "Onboarding redesign... Product decision pending: swap the flow, run
> both, or delete the legacy two."

## Designer notes (verbatim)

The relevant Figma frames:
- `909:7193` — `auxi-ask01-m` (male variant)
- `909:7210` — `auxi-ask01-w` (female variant)
- `909:7227` — `auxi-ask01-u` (unisex variant)

No sticky-note text; the variants themselves are the spec.

## Code reference checked

- `auxi/src/screens/GenderPreferenceScreen.tsx` — single shared file
  (legacy flow).
- `auxi/src/screens/PreferenceSeedScreen.tsx`,
  `auxi/src/screens/FitPreferenceScreen.tsx`,
  `auxi/src/screens/OutfitApprovalScreen.tsx`,
  `auxi/src/screens/OnboardingConfirmationScreen.tsx` — new flow,
  registered as routes but **entry point still points at legacy**.
- `auxi/CLAUDE.md` (Active work / known unfinished section) — flagged.

## Acceptance criteria

**Blocked on product decision**. Once resolved:

- [ ] Decision recorded in this ticket: (a) swap entry point to new flow
      and delete legacy; (b) keep both behind a flag; (c) delete new and
      keep legacy.
- [ ] Per decision (a): update `WelcomeScreen` → `LocationPermissionScreen`
      → next-route to point at new flow. Remove
      `GenderPreferenceScreen.tsx` and `StylePreferenceScreen.tsx` (or
      whichever legacy screens are dropped). Remove their entries from
      `navigation.ts` + `AppNavigator.tsx`.
- [ ] If gender variants are required by Figma, branch the new flow's
      first step on user's gender choice and render the appropriate
      copy/artwork from `src/onboarding/config.ts`.
- [ ] All copy lives in `src/onboarding/config.ts` (no inline strings).
- [ ] qa-mobile flow: fresh install, walk through onboarding, confirm
      data persists to backend.

## Out of scope

- Re-designing the screens themselves; this is purely a flow-resolution
  ticket.

## Dependencies

- **BLOCKER**: Product decision (CEO/designer).
- See `auxi/CLAUDE.md` "Active work / known unfinished" section for the
  current state.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors (note: legacy `_HomeScreen.tsx` errors are
  expected per repo CLAUDE.md baseline).
- qa-mobile manual on fresh-install iOS sim.
