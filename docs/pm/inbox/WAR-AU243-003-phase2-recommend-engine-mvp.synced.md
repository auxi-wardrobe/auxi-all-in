---
id: WAR-AU243-003
type: feature
title: "[V05/Phase 2] Recommendation engine MVP — 6-layer pipeline (L1/L2/L6 + skeleton L3)"
state: Backlog
priority: P1
labels: [type:feature, area:backend, role:backend-dev, source:linear]
parent: WAR-AU243-000
linear_parent: AU-243
assignee: ducga1998
created: 2026-05-07
blocked_by: [WAR-AU243-002]
estimate: 1w
---

## Context

V05 outfit recommendation engine — runtime, stateless, returns 1-3
candidate outfits with vibe_signature + reasoning_human. Coexists with
V2/V3 engines (additive, separate file + endpoint). Built on user's
generated wardrobe from Phase 1.

Spec: `wardrobe-backend/docs/RECOMMEND_V05_SPEC.md` §5-§7, §8 Phase 1
scope.

This Phase 2 ticket = V05 spec's "Phase 1 MVP" (5-7 days). Phase 3-2
mood/novelty etc. ships separately in WAR-AU243-004 (consolidated with
affinity).

## Acceptance criteria

- [ ] `blueprints/recommendation/engine_v05.py` (~250 LOC) — pipeline
      coordinator
- [ ] `blueprints/recommendation/engine_v05_constants.py` — color tiers
      (SAFE/CLASSIC/HIGH_RISK with 30 locked classic pairs from §5.2 R1),
      silhouette score table, mood profiles, aesthetic vocab
- [ ] `blueprints/recommendation/engine_v05_layers.py` — L1 feasibility,
      L2 compatibility, L3 identity (skeleton — uses style_tags from
      Phase 0 retag), L6 packaging
- [ ] `blueprints/recommendation/engine_v05_signature.py` — vibe
      signature compute + similarity for Layer 5/6 use
- [ ] Endpoint `POST /api/v05/recommendation/build` in
      `routers/recommendation.py`
- [ ] Pydantic models per spec §6.2 + §6.3
- [ ] Multi-outfit return: `count` 1-3, default 3
- [ ] Style-tag diversity in 3-outfit response (§5.2 R11): forced
      distinct dominant_style_tag when pool supports it
- [ ] `vibe_signature` returned per outfit (used downstream by mobile
      memory)
- [ ] Why-not log (`trace.skipped_log`) records rejected items + reason
- [ ] `reasoning_human` template engine: 5 variations × 5 styles per
      §6.4 (template list locked by Viet 2026-05-07)
- [ ] Pick rule respects `recent_used` to avoid back-to-back repetition
- [ ] FB anchor bias 2× for Womenswear users (§5.2 R7)
- [ ] Color compatibility: whitelist EXTENSION (base safe rule + 30
      CLASSIC pairs) — not replacement (§5.2 R1)
- [ ] All Layer 1+2 rules covered in unit tests (§9.1)
- [ ] Integration tests pass §9.2 (8 listed test names)
- [ ] Quality smoke matrix §9.3 passes (6 personas)
- [ ] Repetition test §9.4 — 10 sequential calls, ≥5 distinct vibes
- [ ] `seed` reproducibility: same seed → same outfits twice
- [ ] `API_DOCUMENTATION.md` updated for `/api/v05/recommendation/build`
- [ ] p95 latency < 250ms
- [ ] `python test_server.py` green

## Out of scope (explicit)

- Layer 4 (mood profiles) — wired in Phase 3 (WAR-AU243-004)
- Layer 5 (novelty pressure) — wired in Phase 3
- LLM narration side-endpoint — Phase 3 stretch
- Migration of V2 callers / deprecation of V2 engine — Phase 4 (separate ticket)
- Mobile feature flag canary rollout — separate Linear when both repos ready
- Color-pair learning system (§15.7) — Phase 3+ post feedback infra

## Dependencies

- WAR-AU243-002 (Phase 1 onboarding) COMPLETE — users have wardrobes
  to recommend from
- 166 items tagged with `style_tags` (5-vocab) from Phase 0
- v0.5 schema fields populated (already merged in PRs #35-#39)

## Verification

Backend:
  - cd wardrobe-backend && pytest tests/test_engine_v05_unit.py
  - pytest tests/test_engine_v05_integration.py
  - pytest tests/test_engine_v05_repetition.py
  - python test_server.py
  - API_DOCUMENTATION.md diff includes `/api/v05/recommendation/build`
  - Quality smoke: 6 personas from §9.3 → expected vibe distribution
    visually checked

## Notes for the implementer

- New file paths only — do NOT touch `engine_v2.py` / `engine_v3.py`
- `style_tags` from Phase 0 retag is the L3 input; if any item missing
  tags, fallback per §7 (`aesthetic_tags_missing` flag)
- Aesthetic_memory passed by mobile in request — backend stays stateless
- 30 CLASSIC color pairs locked by Viet — list in spec §5.2 R1, copy
  into `engine_v05_constants.py` verbatim
- Reasoning templates locked by Viet (5×5=25 strings) — copy verbatim
  into `engine_v05_constants.py`. Two strings flagged for review on
  WAR-AU243-005, ship initial then update if Viet revises
- ToV 1.2 rules: NO "elevated"/"pulled-together"/"statement piece"/
  "refined"/"chic"/"on-trend"/"curated" — enforced in code review
- Don't introduce LLM in hot path — Phase 1 deterministic only

## Hand-off

Primary: `backend-dev` (Duc).
Pre-implementation: `tech-lead` reviews engine_v05 contract design.
Post-implementation: tech-lead signs off before mobile integration spec.

## Linear sync note

Subtask of AU-243. Estimated 1 week post Phase 1 ship.
