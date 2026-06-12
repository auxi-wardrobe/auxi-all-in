---
id: WAR-V05-FU-05
parent: V05-LLM-pivot
type: improvement
title: "[V05] Persist wardrobe_direction on User so the womenswear recommendation lean reaches ALL users on Home (interim AsyncStorage ships now)"
state: Backlog
priority: P2
labels: [type:improvement, area:backend, area:mobile, role:backend-dev, role:mobile-dev, v05, recommendation, gender]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 1d
linear_sync_status: pending
created: 2026-05-31
---

## Context

The V05 womenswear dress-exclusion fix (proportional anchor cutoff + one-piece
novelty + L6 family floor) landed in `wardrobe-backend` (in-tree, see plan
`plans/260531-1534-v05-dress-exclusion-fix/`). It keys on the `/build` request's
`gender` (`M|W|U`).

Cross-repo review found Home was hardcoding `gender:'U'`, so the fix never
applied there. The auxi interim (shipped same session) derives gender from the
onboarding `wardrobe_direction` and **persists it to AsyncStorage** at onboarding
completion (`auxi/src/services/wardrobeDirection.ts`,
`OnboardingOutroScreen.tsx`, `HomeScreen.tsx`).

**Gap this ticket closes:** `wardrobe_direction` is NOT persisted on the `User`
(only onboarding route params → sent raw to `/onboarding/generate`, derived
server-side). Consequences of the AsyncStorage-only interim:
- **Existing users** (onboarded before the interim shipped) have nothing
  persisted → Home falls back to `U` until they re-onboard (no regression — they
  still get the U no-exclusion fix — but no W-lean retroactively).
- **Local-only**: lost on reinstall, not cross-device, invisible to backend
  analytics/admin.
- `PUT /me` currently rejects unknown `user_metadata` keys (422), so persisting
  it is a deliberate backend contract change, not a config tweak.

## Acceptance criteria

- [ ] Persist `wardrobe_direction` (Womenswear|Menswear|Mixed) on the `User`
      (model + migration), settable at onboarding completion and returned by
      `GET /me`. (Contract change → tech-lead sign-off.)
- [ ] Backend derives/accepts the `M|W|U` mapping from the stored direction
      consistently with the engine (Womenswear→W, Menswear→M, Mixed→U).
- [ ] auxi reads gender from the profile (`/me`) instead of AsyncStorage; keep
      the AsyncStorage path only as an offline fallback (or remove once profile
      is canonical). Single source of truth: `wardrobeDirection.ts`.
- [ ] Update `API_DOCUMENTATION.md` (§Auth/§V05) + sync auxi `v05Api.ts` /
      profile types per the two-repo contract.
- [ ] Verify a W user on Home gets the ~67% surfaced lean + separates (qa-mobile
      sim), and an existing migrated user gets it without re-onboarding.

## Related hygiene (split into own tickets if PM prefers)

- **Dead `FEMININE` mapping:** prod `users.gender` has zero `FEMININE` rows; the
  engine keys on the `M|W|U` payload, so any code gating on `gender=="FEMININE"`
  is dead. Audit + remove. (backend-dev, P3, non-blocking.)
- **`Mixed → "U"` product confirmation:** the interim treats a Mixed wardrobe as
  unisex on Home (no lean, no exclusion). Confirm this is the intended product
  behavior (vs Mixed→W). (PM/CEO, quick.)

## Out of scope

- The dress-exclusion engine fix itself (done — FU-05 only makes the W-lean
  reach all users on Home).
- Tuning the lean magnitude / candidate-share dampener (separate if desired).
- The base/mid/outer cold-weather layering epic (separate confirmed finding).

## Refs

- Plan/spec: `wardrobe-backend/plans/260531-1534-v05-dress-exclusion-fix/`
- Reports: `plans/reports/architecture-260531-1439-v05-engine-ceo-analysis-verification.md`,
  `plans/reports/backend-dev-260531-1439-v05-fullbody-exposure-sim.md`,
  `plans/reports/backend-dev-260531-1439-v05-dress-blastradius.md`,
  `plans/reports/tech-lead-260531-1534-v05-dress-fix-review.md`
- Interim files (auxi, uncommitted): `auxi/src/services/wardrobeDirection.ts`,
  `auxi/src/screens/HomeScreen.tsx`, `auxi/src/onboarding/v2/OnboardingOutroScreen.tsx`
- Backend fix files (uncommitted): `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py`,
  `engine_v05_signature.py`, `engine_v05_constants.py`, `tests/test_engine_v05_unit.py`
