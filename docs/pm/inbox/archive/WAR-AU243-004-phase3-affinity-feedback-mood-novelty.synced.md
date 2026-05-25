---
id: WAR-AU243-004
type: feature
title: "[V05/Phase 3] Style affinity persistence + mood/novelty layers + feedback infra"
state: Backlog
priority: P2
labels: [type:feature, area:backend, role:backend-dev, source:linear]
parent: WAR-AU243-000
linear_parent: AU-243
assignee: ducga1998
created: 2026-05-07
blocked_by: [WAR-AU243-003]
estimate: 1w
---

## Context

Phase 3 unifies three V05 spec items that share the feedback-infra base:
1. **Style affinity persistence** (WGS §8) — per-user weights for the
   5 styles, EMA-updated from behavior signals
2. **Layer 4 (mood) + Layer 5 (novelty)** wiring (V05 spec §8 Phase 2)
3. **Outfit feedback table** (V05 spec §15.7.1) — base for color-pair
   learning system in Phase 4+

Bundling them: affinity weights, mood activation, novelty memory, and
feedback events all need the same DB foundation (per-user behavior
events). Splitting wastes infra.

Em propose this be a **separate Linear epic** at the time of Phase 2
sign-off — track this ticket here as a placeholder; convert to live
Linear epic when Phase 2 lands. PM (anh) decides timing.

## Acceptance criteria

### Affinity persistence
- [ ] DB migration: `user_style_affinity` table per WGS §8 schema
- [ ] On onboarding completion: insert 5 rows for user with weights from
      initial style picks (style_1=1.0, style_2=0.7, style_3=0.4, others=0)
- [ ] Service to read/write affinity (used by V05 engine L3)
- [ ] V05 engine reads `user_style_affinity` at recommend time — items
      tagged with high-affinity styles get versatility-equivalent boost
      (per V05 spec §5.2 R8)

### Mood activation (L4)
- [ ] `intent.mood` parameter wired to scoring in `engine_v05_layers.py`
- [ ] 5 mood profiles per V05 spec §5.2 R9 implemented
- [ ] Mood-tagged requests show measurable shift toward profile (e.g.
      "calm" requests → 2x higher quiet/minimal vibe rate vs untagged)

### Novelty pressure (L5)
- [ ] `memory.recent_signatures[]` parameter wired
- [ ] novelty_score per §5.2 R10
- [ ] Sequential calls with recent_signatures show <10% vibe repetition
      (per success metric §10 Phase 2)

### Feedback infrastructure
- [ ] DB migration: `outfit_feedback` table per V05 spec §15.7.1
- [ ] Endpoint `POST /api/v05/feedback` accepting
      `{outfit_id_or_hash, action: thumbs_up|thumbs_down|wore|dismissed,
       color_pairs[], shown_at, acted_at}`
- [ ] On feedback receipt: trigger EMA update on `user_style_affinity`
      using items in the outfit (favorited → boost their style_tags;
      dismissed → reduce)
- [ ] `API_DOCUMENTATION.md` updated for `/api/v05/feedback`

### Tests + verification
- [ ] Unit tests: EMA update math, mood profile activation, novelty
      score with various recent_sigs lengths
- [ ] Integration: thumbs_up on a Minimal-tagged outfit raises user's
      Minimal weight on next request
- [ ] `python test_server.py` green

## Out of scope (explicit)

- Color-pair promotion/demotion job (V05 spec §15.7.2-3) — Phase 4+
- LLM narration side-endpoint — defer until tone copy stabilizes in prod
- Multi-outfit batch reasoning_human freshness — handled in MVP via
  recent_used parameter
- ML-based ranking
- Mobile UI for feedback gestures — separate ticket

## Dependencies

- WAR-AU243-003 (Phase 2 V05 MVP) COMPLETE
- Style_tags populated on all items (Phase 0)

## Verification

Backend:
  - cd wardrobe-backend && pytest tests/test_user_style_affinity*.py
  - pytest tests/test_engine_v05_mood*.py
  - pytest tests/test_engine_v05_novelty*.py
  - pytest -m integration tests/test_feedback_*.py
  - python test_server.py
  - API_DOCUMENTATION.md diff includes `/api/v05/feedback`
  - Repetition test: 10 sequential calls passing recent_signatures →
    <10% vibe repeat rate

## Notes for the implementer

- EMA formula per WGS §8: `weight_new = 0.9 * weight_old + 0.1 * signal`
- Feedback events deduplicated by (user, outfit_hash, action) within
  some window — detail spec'd at implementation time
- Outfit hash = serialized vibe_signature (already computed in MVP)
- Color pairs extracted per outfit at feedback receipt — feeds learning
  system in Phase 4+
- This ticket may convert to its own Linear epic if scope grows

## Hand-off

Primary: `backend-dev` (Duc).
PM (anh) — call timing: convert to standalone Linear epic when Phase 2
lands, or keep as AU-243 child.

## Linear sync note

Subtask of AU-243 for now. Convert to standalone epic
(`AU-XXX [V05/Phase 3] Affinity + feedback infra`) at Phase 2 sign-off
gate.
