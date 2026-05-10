---
id: WAR-AUDIT-010
type: feature
title: "[Items] Verify AI auto-tag for material / price"
state: Backlog
priority: P2
labels: [audit, figma, area:backend, role:backend-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "1699:16659"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer note says AI may auto-tag many fields (material, price, etc.)
but the current UI only surfaces 4 fields (Type, Color, Fit, Style).
The UI matches the spec exactly. The question is whether AI is
auto-tagging the additional fields server-side for future use.

## Designer note (verbatim)

> "AI may auto-tag many tags (material, price...) but the current
> UI/design only shows **Type, Color, Fit, Style**"

Source: Figma sticky note `1699:16659` (section `909:11258` wardrobe).

## Code reference checked

- `auxi/src/screens/ItemDetailScreen.tsx:40` —
  `EditableField = 'category' | 'color' | 'fit' | 'style'`. Matches
  Figma's 4 fields exactly. ✅
- `wardrobe-backend/` — **AI tagging path NOT INSPECTED**.

## Acceptance criteria

- [ ] Backend audit: does the item-create / item-update Gemini prompt
      already extract material / price (and other) tags into the model?
      Comment findings here.
- [ ] If yes: document the extra fields in
      `wardrobe-backend/API_DOCUMENTATION.md` even if the mobile UI
      doesn't render them yet — that's the contract.
- [ ] If no: open a backend follow-up sub-issue scoped at adding those
      tags to the AI extraction step.
- [ ] No mobile UI change in this ticket (per designer: "current UI/design
      only shows Type, Color, Fit, Style"). Surfacing material/price in
      UI would need a fresh designer ticket.

## Out of scope

- UI changes to expose material / price.
- Pricing-source / pricing-API integration.

## Dependencies

- Backend audit (assign to `backend-dev`).

## Verification

- `cd wardrobe-backend && python test_server.py` green.
- `wardrobe-backend/API_DOCUMENTATION.md` updated with current AI tag
  output shape.
