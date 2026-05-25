---
id: WAR-AU242-FU-03
parent: AU-242
type: feature
title: "[M2] Welcome screen UX: split Sign Up vs Sign In CTAs"
state: Backlog
priority: P2
labels: [type:feature, area:mobile, role:mobile-dev, design-review, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: mobile-dev + Viet (design sign-off)
estimate: 1d
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

Current Welcome screen has a single "Continue with Email" CTA. An
existing user must submit a password on PasswordCreation, wait for
the backend to return 409 (account exists), then get redirected to
SignIn. The intermediate 409 step is a dead-end UX confusing for
returning users.

Linear AC #6 on AU-242 allowed either "redirect to sign-in flow OR
show account exists error" — splitting the CTAs eliminates the
ambiguity at the source.

## Acceptance criteria

- [ ] Welcome screen shows 4 buttons (top to bottom, per Figma):
      1. Continue with Google
      2. Continue with Apple
      3. Sign Up with Email
      4. Sign In with Email
- [ ] EmailInput screen receives `mode: 'signup' | 'signin'` route param.
- [ ] `mode: 'signup'` → PasswordCreation (current flow).
- [ ] `mode: 'signin'` → SignIn directly (skip precheck for password flow).
- [ ] Maintain backward compat with phase 04 routing — existing deeplinks
      still resolve.
- [ ] Designer (Viet) sign-off on 4-button layout, spacing, and visual
      hierarchy before merge.
- [ ] Register any new route variants in `src/types/navigation.ts` and
      `AppNavigator.tsx` (project convention — silent-bug source if missed).
- [ ] Maestro flow: welcome → signin path covers happy + wrong-password.

## Out of scope

- Magic-link sign-in (not in MVP).
- Phone-number sign-in.

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding M2
- Figma specs: `plans/260521-2335-au-242-figma-spec/01-welcome-screen.md`,
  `plans/260521-2335-au-242-figma-spec/02-email-input-screen.md`
- Files: `auxi/src/screens/auth/WelcomeScreen.tsx`,
  `auxi/src/screens/auth/EmailInputScreen.tsx`,
  `auxi/src/types/navigation.ts`, `auxi/src/navigation/AppNavigator.tsx`
- Parent: AU-242
