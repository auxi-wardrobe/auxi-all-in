---
id: WAR-AU243-006
type: spike
title: "[V05] Track Sporty/Athleisure vocabulary gap — v0.6 candidate"
state: Backlog
priority: P3
labels: [type:spike, vocabulary, research, role:design]
parent: WAR-AU243-000
linear_parent: AU-243
assignee: viet
created: 2026-05-07
estimate: research
---

## Context

V05 5-style vocabulary (Minimal / Casual / Soft / Bold / Formal) is
intentionally narrow but **does not include Sporty/Athleisure** — one of
three primary vibes from Hằng-persona research.

Locked decision (Viet 2026-05-07): keep 5 styles for V05 ship; track
Sporty as v0.6 candidate. Mitigation in V05: 3-option diversity rule
(§6.7 / R11) ensures 3 distinct style_tags surface where wardrobe
supports it.

Spec references:
- `WARDROBE_GENERATION_SPEC.md` §3.5 — vocabulary deferred decision
- `RECOMMEND_V05_SPEC.md` §5.2 R11 — diversity mitigation note

## Why this needs tracking (not just a doc note)

1. Active-lifestyle users (gym + WFH + weekend) currently get routed
   into Casual + Soft, which may feel **wrong** (athleisure vibes don't
   read as "soft")
2. Persona research already flagged Sporty for Hằng-tier users
3. If user feedback surfaces this gap before Phase 3 affinity infra
   lands, em may need to add Sporty earlier than v0.6 — tracking ensures
   we notice

## Acceptance criteria (this ticket = research/decision)

- [ ] Watch user feedback / qualitative signal for Sporty-shaped requests
      during Phase 1-2 rollout
- [ ] Decision gate: when wardrobes feel Sporty-deficient (signal
      threshold TBD), Viet locks v0.6 vocab expansion:
      - Add 6th style tag "Sporty"
      - Update locked list in WGS §3.1
      - Plan re-tag pass on all items (low cost via gpt-5-nano)
      - File implementation ticket as WAR-AU243-006 child or new epic
- [ ] If signal stays low through Phase 2 ship, defer to v1.0 review

## Out of scope

- Implementation of Sporty vocab (will be its own ticket if/when triggered)
- Other vocabulary expansions (e.g. "Edgy", "Romantic") — track separately
- Change to V05 schema fields

## Dependencies

- User feedback infra (Phase 3 — WAR-AU243-004) for quant signal
- Or: Viet's qualitative review at end of Phase 1 ship

## Verification

- This ticket lives Backlog until trigger event
- On trigger: spec doc + child implementation ticket filed

## Hand-off

Primary: Viet (vocabulary call).
Backend (Duc): on Viet's signal, scope re-tag pass + spec update.

## Linear sync note

Subtask of AU-243. Backlog/research — promote when signal triggers.
