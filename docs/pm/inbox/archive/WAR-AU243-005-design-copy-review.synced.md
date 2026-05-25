---
id: WAR-AU243-005
type: chore
title: "[V05] Design copy review — 2 borderline reasoning_human strings"
state: Open
priority: P3
labels: [type:chore, design-review, copy, role:design]
parent: WAR-AU243-000
linear_parent: AU-243
assignee: viet
created: 2026-05-07
estimate: 30min
---

## Context

Viet locked 25 reasoning_human strings (5 variations × 5 styles) for V05
recommendation engine output. Two strings are borderline against ToV 1.2
rules — surface for explicit review before Phase 2 ships.

Spec: `wardrobe-backend/docs/RECOMMEND_V05_SPEC.md` §6.4 — locked list.

## Strings flagged

| Style | String | Concern |
|---|---|---|
| Formal | "Sharper today." | "Sharper" close to "sharp" (used in §5.2 R9 mood profile). May read as fashion-judgment. ToV Rule 5: suggest, never command — borderline. |
| Soft | "Quiet warmth." | Adjective + noun fragment without verb. Other Soft variations are full short sentences. May feel out of pattern. |

## Acceptance criteria

- [ ] Viet reviews both strings on this ticket (or directly on PR #40)
- [ ] Decision recorded:
      - Keep as-is, OR
      - Revise (provide replacement string), OR
      - Remove from pool (drop count from 5 → 4 for that style)
- [ ] If revised: update `wardrobe-backend/docs/RECOMMEND_V05_SPEC.md`
      §6.4 with new string + commit on `docs/recommend-v05-spec` branch
- [ ] Decision propagated to Phase 2 implementation
      (`engine_v05_constants.py`) when WAR-AU243-003 ships

## Out of scope

- Whole-pool review (other 23 strings already approved)
- Runtime tone tuning beyond these 2 strings
- LLM narration approach (Phase 3 stretch only)

## Dependencies

- None — pure design decision

## Verification

- Decision noted in this ticket comments + spec doc updated if revised
- Final 25-string list locked before WAR-AU243-003 starts

## Hand-off

Primary: Viet.
Backend (Duc): wait for decision before locking
`engine_v05_constants.py` template list.

## Linear sync note

Subtask of AU-243. Low priority — non-blocking but should land before
Phase 2 codes the templates.
