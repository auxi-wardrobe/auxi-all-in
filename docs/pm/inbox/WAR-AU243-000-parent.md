---
id: WAR-AU243-000
type: epic
title: "[V05] Personalized onboarding + outfit recommendation engine"
state: In Progress
priority: P1
labels: [type:feature, area:backend, role:backend-dev, source:linear]
linear_url: https://linear.app/duncan-1/issue/AU-243
linear_id: AU-243
assignee: ducga1998
parent: null
created: 2026-05-07
source: docs/pm/inbox (Linear MCP not surfaced in session — fallback)
companion_pr: https://github.com/ducga1998/wardrobe-backend/pull/40
spec_branch: docs/recommend-v05-spec
specs:
  - wardrobe-backend/docs/WARDROBE_GENERATION_SPEC.md
  - wardrobe-backend/docs/RECOMMEND_V05_SPEC.md
---

## Context

V05 recommendation system planning ratified by Viet (designer/CEO) on
2026-05-07. Two locked specs on branch `docs/recommend-v05-spec` (PR #40):

- `WARDROBE_GENERATION_SPEC.md` — onboarding flow + wardrobe generation
  (one-time, persistent, 30-60 items per user)
- `RECOMMEND_V05_SPEC.md` — runtime outfit recommendation engine
  (per-request, stateless, 6-layer pipeline)

Vocabulary locked, single source of truth in WGS §3:
- 5 styles: Minimal / Casual / Soft / Bold / Formal
- 3 fits: Slim / Classic / Relaxed
- 3 directions: Menswear / Womenswear / Mixed
- 6 item types incl. Dresses (FULL_BODY) — first-class slot per Viet

Parent ticket AU-243 owns full scope. This epic groups subtask tracking
in our PM inbox; live Linear board is the source of truth.

## Phasing (proposed by ducga1998, awaiting owner sign-off)

| Phase | Subtask | Owner | Est | Status |
|---|---|---|---|---|
| 0 | WAR-AU243-001 — Inventory import + audit gate | Viet + Duc | 2-3d | BLOCKER |
| 1 | WAR-AU243-002 — Onboarding API + generation algo | Duc | 1w | Blocked by P0 |
| 2 | WAR-AU243-003 — V05 outfit recommend MVP (L1/L2/L6) | Duc | 1w | Blocked by P1 |
| 3 | WAR-AU243-004 — Style affinity + feedback infra | Duc | 1w | Blocked by P2 |
| - | WAR-AU243-005 — Design copy review (2 borderline) | Viet | 30min | Open |
| - | WAR-AU243-006 — Sporty/athleisure v2 vocabulary tracker | Viet | research | Backlog |

## Acceptance criteria (parent)

- [ ] Phase 0 inventory imported: 166/166 items in DB with style_tags
      (5-vocab) + gender_tags + fit_category populated, ≥90% audit pass
- [ ] Phase 1 onboarding endpoint live: `POST /api/v05/onboarding/generate`
      returns 30-60 user-cloned items per valid input, deterministic
- [ ] Phase 2 recommendation endpoint live:
      `POST /api/v05/recommendation/build` returns 1-3 outfit candidates
      with vibe_signature + reasoning_human
- [ ] Phase 3 affinity persistence: `user_style_affinity` table populated
      from onboarding + EMA-updated from feedback signals
- [ ] `API_DOCUMENTATION.md` updated for both new endpoint groups
- [ ] `python test_server.py` green
- [ ] V2 dress regression remains accepted trade-off until V05 cutover
      (documented, not silently deferred)

## Out of scope

- Mobile (auxi) integration — separate Linear ticket once backend stable
- Try-on integration with V05 recommendations
- ML-based ranking
- Multi-day calendar planning
- LLM narration side-endpoint (Phase 2 stretch only)
- Color-pair learning system (V05 spec §15.7 — Phase 3+)

## Dependencies

- Excel + PNG drive shared by Viet on Linear AU-243 (61 missing items)
- Existing v0.5 schema + tagger pipeline (PRs #35-#39 already merged)
- Railway DB access for integration tests

## Verification (rolled up from subtasks)

Backend:
  - cd wardrobe-backend && pytest -m unit
  - pytest -m integration
  - python test_server.py
  - API_DOCUMENTATION.md diff included for `/api/v05/onboarding/*`
    and `/api/v05/recommendation/*`

## Risks tracked

| Risk | Severity | Mitigation owner |
|---|---|---|
| 87% needs_review rate in v0.5 tagger output | High | Viet — Phase 0 audit gate strict ≥90% accuracy |
| V2 engine drops 10 dresses (existing prod regression) | Medium-Accepted | Backend-dev — accepted trade-off, V05 rewrites cleanly |
| 5-vocab missing "Sporty" for Hằng-persona | Medium | Viet — WAR-AU243-006 tracker, may surface earlier from user feedback |
| Color whitelist becomes frozen-rule debt | Medium | Viet — V05 spec §15.7 learning system, Phase 3+ |
| 2 borderline copy items unreviewed | Low | Viet — WAR-AU243-005, ~30min |

## Open questions (parent-level)

- Q: Does owner (ducga1998) batch-fetch Excel/PNG himself or hand back?
  → Asked on Linear AU-243 latest comment, awaiting response
- Q: Phase 3 ships in same epic or splits to a child Linear epic for
  feedback infra? Em propose split-once Phase 2 lands (cleaner scope)

## Hand-off

This is the umbrella. Each phase has its own subtask ticket with focused
AC + verification. Backend-dev (Duc) implements after Viet + owner
sign-off scope per phase.

## Linear sync note

Linear MCP not surfaced in this PM session — used `docs/pm/inbox/`
fallback. When session has Linear access, sync this parent + 6
subtasks to live Linear (AU-243 already exists; subtasks land as
children of AU-243).
