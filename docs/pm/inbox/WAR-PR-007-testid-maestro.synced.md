---
id: WAR-PR-007
type: chore
title: "[Task] Backfill testIDs + scaffold Maestro flows on auxi"
state: Done
priority: P2
labels: [type:chore, area:mobile, role:mobile-dev, source:pr]
source_pr: https://github.com/ducga1998/auxi-mobile/pull/7
source_repo: auxi (ducga1998/auxi-mobile)
author: ducga1998
merged_at: 2026-05-05T10:30:21Z
created: 2026-05-05
---

## Context

QA verification was running on a screenshot-LLM loop — slow, expensive,
non-deterministic. This PR replaces it with binary pass/fail Maestro
execution. Maestro reads `testID` selectors and either matches or it
doesn't.

## What shipped

- 14 canonical `testID` props across `LoginScreen.tsx`, `HomeScreen.tsx`,
  `ContextChipsModal.tsx`, plus `PillButton` (FigmaPrimitives) now
  forwards `testID` (interface + destructure + JSX).
- Conditional testIDs (heart saved-state, pin badge) flip via ternary so
  Maestro sees them appear/disappear with state, driving
  `assertVisible` / `assertNotVisible` directly.
- `auxi/maestro/` scaffolding:
  - `README.md` — install, run, JAVA_HOME setup
  - `config.yaml` — shared appId + env defaults
  - `flows/_shared/login.yaml` — sub-flow used by every post-login flow
  - `flows/auth/login.yaml` — login persists across cold relaunch
  - `flows/home/swipe.yaml` — full Phase A/B/C coverage from
    `docs/HOME_SWIPE_PLAN.md` section 6
- testID convention codified in `auxi/CLAUDE.md`:
  `<feature>-<element>-<state-or-purpose>`.

## testIDs added

| File | testIDs |
|---|---|
| `LoginScreen.tsx` | `auth-email-input`, `auth-password-input`, `auth-login-submit` |
| `HomeScreen.tsx` | `home-screen-root`, `home-outfit-sheet-{idx}`, `home-mode-pill-{safe,power,creative}`, `home-heart-toggle{,-saved}`, `home-tile-{idx}`, `home-tile-pin-{idx}-set`, `home-show-another`, `home-this-works`, `home-edit-context` |
| `ContextChipsModal.tsx` | `context-chips-modal-{root,close}` |
| `FigmaPrimitives.tsx` | `PillButton` forwards `testID` |

## Acceptance criteria

- [x] `npx tsc --noEmit` clean (legacy errors only).
- [x] `yarn lint` baseline preserved (4 errors / 3 warnings).
- [x] Maestro flows exist for login + Home swipe (full Phase A/B/C).
- [ ] Reviewer to install Maestro CLI locally and run both flows after
      `./scripts/qa-boot.sh` from umbrella root — both should pass.

## Out of scope

- Cloud device farm or CI orchestration — local-only.
- Coverage of screens beyond Login + Home + ContextChipsModal — staged
  in follow-ups as features land.

## Notes

Companion to umbrella PR #6 (chore: bump auxi pointer for testID +
Maestro flows) which pins the auxi submodule HEAD.
