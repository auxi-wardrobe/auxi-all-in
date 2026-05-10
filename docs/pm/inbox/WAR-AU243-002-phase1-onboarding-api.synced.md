---
id: WAR-AU243-002
type: feature
title: "[V05/Phase 1] Onboarding API + wardrobe generation algorithm"
state: Backlog
priority: P1
labels: [type:feature, area:backend, role:backend-dev, source:linear]
parent: WAR-AU243-000
linear_parent: AU-243
assignee: ducga1998
created: 2026-05-07
blocked_by: [WAR-AU243-001]
estimate: 1w
---

## Context

After Phase 0 lands 166 items, ship the onboarding generation pipeline:
3-question flow (gender/fit/styles) → deterministic generation of 30-60
items → cloned to user's wardrobe.

Spec: `wardrobe-backend/docs/WARDROBE_GENERATION_SPEC.md` §5-§7.

## Acceptance criteria

- [ ] DB migration: `style_tags` JSON column on `wardrobe_items` (or
      reuse `styling_metadata` — implementer's call, document choice)
- [ ] DB migration (optional but recommended): `user_onboarding_state`
      table for completion tracking + analytics
- [ ] `services/onboarding_service.py` implements §6.2 algorithm:
      Phase 1 domain filter → Phase 2 fit-aware ranking → Phase 3 style
      affinity ranking → Phase 4 combined score → Phase 5 diversification
      with per-category quotas → Phase 6 fallback if min unmet → Phase 7
      outfit-combinability sanity check
- [ ] `services/wardrobe_clone_service.py` clones SYSTEM → user with
      `is_common_item=False`, fresh `human_readable_id` prefix `USR_`
- [ ] Endpoint `POST /api/v05/onboarding/generate` accepting:
      `{user_id, wardrobe_direction, fit_preference, style_preferences[2-3]}`
- [ ] Response includes `wardrobe_items[]`, `profile_classification`,
      and `trace` (pool sizes, fallback flags, distribution)
- [ ] Pydantic models for request/response with validation:
      direction in {Menswear/Womenswear/Mixed}, fit in 3-set,
      styles count between 2-3, all values from 5-vocab
- [ ] Style-tag diversity rule: every generated wardrobe contains items
      spanning ≥3 distinct style_tags (§6.5)
- [ ] FULL_BODY quota: 2-6 for Womenswear/Mixed, 0 for Menswear (§6.2)
- [ ] Determinism: same `(gender, fit, ranked_styles)` → same set of
      SYSTEM IDs (Phase 5 greedy deterministic by sorted score)
- [ ] User retake handling: replaces previous generated wardrobe cleanly
- [ ] `API_DOCUMENTATION.md` updated with new `/api/v05/onboarding/*`
      endpoints + request/response schemas + error codes
- [ ] Unit tests per §10.1 of WGS (8 listed test names minimum)
- [ ] Integration tests per §10.2 (6 listed test names)
- [ ] Quality smoke matrix §10.3 passes (3 personas)
- [ ] p95 latency < 500ms on Railway DB
- [ ] `python test_server.py` green

## Out of scope

- Mobile UI integration — separate ticket once endpoint stable
- Style affinity persistence + EMA updates → WAR-AU243-004 (Phase 3)
- Onboarding analytics dashboard
- Multi-language onboarding text
- Climate / season / occasion / age awareness (Viet excluded explicitly)
- AI-generated wardrobe (deterministic only — Viet's choice)

## Dependencies

- WAR-AU243-001 — Phase 0 inventory import + audit COMPLETE
- 166 items with valid `style_tags` populated in DB
- Existing v0.5 schema columns (PRs #35-#39 merged)

## Verification

Backend:
  - cd wardrobe-backend && pytest tests/test_onboarding_service*.py
  - pytest tests/test_wardrobe_clone*.py
  - pytest -m integration tests/test_onboarding_*.py
  - python test_server.py
  - API_DOCUMENTATION.md diff includes `/api/v05/onboarding/generate`
  - Manual smoke: `curl POST .../generate` with each of 3 quality matrix
    personas → returns 30-60 items with expected distribution

## Notes for the implementer

- Single-endpoint design (Viet preference per WGS Q6) — mobile keeps
  step state locally, one request finalizes the flow
- Mobile registration: when mobile picks this up, screen must be in
  BOTH `auxi/src/types/navigation.ts` AND `AppNavigator.tsx` (project
  rule — most common silent-bug source)
- Backend lands first, then mobile pins new submodule HEAD
- Audit confidence flag from Phase 0: surface low-confidence items to
  user at onboarding for verify (per WGS §4.3 step 6)
- Do not introduce shared SDK or codegen — `API_DOCUMENTATION.md` is
  the contract per umbrella CLAUDE.md
- V2 engine remains running in parallel; this is additive (`/api/v05/*`)

## Hand-off

Primary: `backend-dev` (Duc).
Architectural review on contract: `tech-lead` before mobile syncs.

## Linear sync note

Subtask of AU-243. Estimated 1 week post Phase 0 unblock.
