---
id: WAR-AU243-001
type: chore
title: "[V05/Phase 0] Inventory import + audit gate (61 items)"
state: Blocked
priority: P1
labels: [type:chore, area:backend, role:backend-dev, source:linear, blocker]
parent: WAR-AU243-000
linear_parent: AU-243
assignee: ducga1998
co_owner: viet
created: 2026-05-07
blocks: [WAR-AU243-002, WAR-AU243-003, WAR-AU243-004]
---

## Context

V05 generation algorithm needs **166 SYSTEM items** in DB. Currently
**105 items** present. **61 items missing**, sources shared by Viet on
Linear AU-243:

- Excel: https://docs.google.com/spreadsheets/d/1scKlmdCjrornrmgigdhWRfkIq1tvpnQS/edit
- PNG drive: https://drive.google.com/drive/folders/1DVaFgTiYjwYBO6JA9dJUSC1-DmkschgS

All downstream phases blocked until 166 items in DB with valid
`style_tags` (5-vocab) + `gender_tags` + fit category.

Spec: `wardrobe-backend/docs/WARDROBE_GENERATION_SPEC.md` §4.

## Acceptance criteria

- [ ] Excel parsed → 61 new rows validated against required field schema
      (name, category_code, layer_code, gender, fit, style, image filename)
- [ ] 61 PNG files uploaded to R2 bucket, URLs back-referenced
- [ ] `import_from_excel.py` script idempotent (re-run safe)
- [ ] DB has 166 SYSTEM items, all `is_common_item=True`, `owner_id=SYSTEM`
- [ ] All 166 items re-tagged with `style_tags` (5-vocab via gpt-5-nano)
      + `gender_tags` + `fit_category`
- [ ] **Audit gate (Viet, ~20min)**: 15-20 random items reviewed
      manually → tag accuracy ≥ 90%
- [ ] If audit fails: prompt iterated (few-shot/edge cases) → re-tag →
      re-audit until gate passes
- [ ] **Per-item confidence tracking**: items with confidence below
      threshold flagged in DB, surfaced to user at onboarding for verify
- [ ] Cost log: total tagging spend ≤ \$0.10 (per spec)
- [ ] `python test_server.py` green
- [ ] Final stats commented on this ticket: 166/166, audit pass rate, cost

## Out of scope

- Inventory expansion beyond 166 items (Viet locked: "166 enough")
- New color codes for sub-shades (burgundy/dusty-pink/etc) — folded into
  parent codes per V05 spec §5.2 R1 note
- Onboarding API implementation (WAR-AU243-002)

## Dependencies

- Excel + PNG drive access (shared by Viet on AU-243)
- R2 bucket credentials present in env
- gpt-5-nano API key (already configured per PR #38)
- Viet availability for ~20min audit

## Verification

Backend:
  - cd wardrobe-backend && python scripts/audit_inventory.py  # report 166/166
  - pytest tests/test_import_excel*.py  # if tests added
  - python test_server.py
  - SQL: SELECT COUNT(*) FROM wardrobe_items WHERE owner_id='SYSTEM' AND is_deleted=false  # = 166
  - SQL: SELECT COUNT(*) FROM wardrobe_items WHERE style_tags IS NULL  # = 0
  - SQL: SELECT COUNT(*) FROM wardrobe_items WHERE confidence < 0.X  # tracked, exposed

## Notes for the implementer

- Use `EphemeralFileManager` for any temp PNG processing per backend rules
- Re-tagging existing 105 items is part of this work (consistency — same
  prompt path for all 166). Cost ~\$0.075 total.
- Viet's strict bar: "wrong tag once = trust drops" (Hằng persona
  research). Don't ship to engine until gate passes.
- 87% needs_review rate in current v0.5 tagger output is the baseline
  risk — gpt-5-nano with new 5-vocab prompt should improve, audit will
  measure.

## Hand-off

Primary: `backend-dev` (Duc) — script + import + tagging.
Secondary: Viet — audit gate, prompt iteration feedback if fail.

## Linear sync note

Subtask of AU-243. Phase 0 — explicit BLOCKER for Phases 1-3.
