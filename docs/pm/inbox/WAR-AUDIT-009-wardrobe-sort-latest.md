---
id: WAR-AUDIT-009
type: chore
title: "[Wardrobe] Verify wardrobe sort by latest"
state: Backlog
priority: P2
labels: [audit, figma, area:backend, area:mobile, role:backend-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "909:7803"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer wants wardrobe items sorted newest-first so a user's latest
upload surfaces immediately. Audit found no client-side sort in
`WardrobeScreen.tsx`; backend may already do this — needs confirmation.

## Designer note (verbatim)

> "Wardrobe sorted by latest items so what user uploaded has more priority"

Source: Figma sticky note `909:7803` (section `909:7328` "Home adjust" /
wardrobe).

## Code reference checked

- `auxi/src/screens/WardrobeScreen.tsx` — no `sort` / `orderBy` logic
  client-side.
- `auxi/src/services/wardrobeService.ts` — list call has no `sort` param
  visible.
- `wardrobe-backend/` — **NOT YET INSPECTED**.

## Acceptance criteria

- [ ] Backend audit: confirm whether the wardrobe-list endpoint orders by
      `created_at DESC`. Comment findings here.
- [ ] If backend sorts already: confirm response order is preserved by
      mobile (no sort-clobber in TanStack Query selector).
- [ ] If backend does NOT sort: add `ORDER BY created_at DESC` (or
      equivalent) in the appropriate repo / service in
      `wardrobe-backend/`. Update `wardrobe-backend/API_DOCUMENTATION.md`
      to document the sort guarantee.
- [ ] Verify the rule also covers items added from "Auxi's database"
      (note `1688:13996`).

**Bonus** (related sticky note `909:7801`):

- [ ] Confirm the UI rule "user cannot edit/delete common (system)
      items, only items they uploaded" is enforced end-to-end. Audit
      found `STYLE_TAG_LESS_USED` in code but did not verify the
      edit/delete permission rule. File a follow-up bug ticket if
      missing.

## Out of scope

- Custom sort options (alphabetical, by colour). Out of scope unless
  designer specs.

## Dependencies

- Backend audit (assign to `backend-dev`).

## Verification

- `cd wardrobe-backend && python test_server.py` green.
- `wardrobe-backend/API_DOCUMENTATION.md` updated if sort guarantee added.
- qa-mobile: upload an item, confirm it appears at the top of the
  wardrobe grid on next refresh.
