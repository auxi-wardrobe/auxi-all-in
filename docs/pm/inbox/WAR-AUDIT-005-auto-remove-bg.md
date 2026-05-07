---
id: WAR-AUDIT-005
type: feature
title: "[Backend/Mobile] Auto-remove background on item upload"
state: Backlog
priority: P1
labels: [audit, figma, area:backend, area:mobile, role:backend-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "1064:1168"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer specced auto-removal of photo background when a user uploads a
new wardrobe item. Likely a backend job (image processing pipeline), but
needs verification. Audit found no remove-bg call in mobile code.

## Designer note (verbatim)

> "**Auto remove background**"

Source: Figma sticky note `1064:1168` (section `909:11258` "wardrobe").

## Code reference checked

- `auxi/src/services/itemService.ts` — no remove-bg call.
- `auxi/src/services/wardrobeService.ts` — no remove-bg call.
- `wardrobe-backend/` — **NOT YET INSPECTED**. This is the verify step.

## Acceptance criteria

- [ ] Backend audit: confirm whether `wardrobe-backend/` already runs a
      remove-bg step on upload. Comment findings on this ticket.
- [ ] If backend handles it: confirm processed image is what mobile
      receives + displays. No mobile work needed beyond verification.
- [ ] If backend does NOT handle it: implement remove-bg pipeline in
      `wardrobe-backend/` (likely in the upload service / item-create
      route). Update `wardrobe-backend/API_DOCUMENTATION.md` if the
      response shape changes.
- [ ] If implementation is mobile-side: file a follow-up sub-issue for
      `auxi/` covering the call.
- [ ] qa-mobile flow: upload an item with a clearly-non-white background
      (e.g., a shirt on a wooden floor) → confirm the stored thumbnail
      shows the item on a clean background.

## Out of scope

- Manual background-edit UI (separate ticket if designer wants it).

## Dependencies

- Backend audit (assign to `backend-dev`).
- Possibly: a background-removal library or service decision (rembg,
  remove.bg API, Gemini vision, etc.) — tech-lead approval.

## Verification

- `cd wardrobe-backend && python test_server.py` green.
- `wardrobe-backend/API_DOCUMENTATION.md` updated if route shape changed.
- qa-mobile manual smoke after backend ships.

## Hand-off

Primary: `backend-dev` for verification + implementation in
`wardrobe-backend/`. Secondary: `mobile-dev` if/when contract change
requires client update.
