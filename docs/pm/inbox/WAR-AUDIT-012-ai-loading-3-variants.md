---
id: WAR-AUDIT-012
type: chore
title: "[Home] Differentiate 3 AI loading state variants"
state: Backlog
priority: P2
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_nodes: ["1671:5470", "1671:5693", "1671:5623"]
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Figma defines three distinct loading states for the AI item-detail view.
Code currently has a single generic loading. Either differentiate them
or confirm with designer that one shared loading is acceptable.

## Designer note (verbatim)

No sticky-note text on these frames; the visual variants are the spec.

Frames:
- `1671:5470` — detail AI loading variant 1
- `1671:5693` — detail AI loading variant 2
- `1671:5623` — detail AI loading variant 3

## Code reference checked

- `auxi/src/components/features/ItemDetailBottomSheet.tsx` and
  `auxi/src/screens/ItemDetailScreen.tsx` — single shared loading
  treatment.

## Acceptance criteria

- [ ] Designer confirms whether all 3 loading states are required or one
      shared is acceptable. If shared is OK, close this ticket "won't fix"
      with a comment linking the decision.
- [ ] If 3 are required: identify the trigger condition for each variant
      (e.g., short-wait / medium-wait / long-wait, or different AI ops:
      generate / refine / re-render). Designer to confirm mapping.
- [ ] Implement the 3 visual states matching Figma `1671:5470`,
      `1671:5693`, `1671:5623`.
- [ ] Theme tokens; SVG illustrations imported via
      `react-native-svg-transformer`.
- [ ] qa-mobile: simulate each trigger condition on iOS sim, screenshot
      each variant, designer signs off.

## Out of scope

- Backend changes to surface a "loading-stage" signal — only do that work
  if designer confirms it's required.

## Dependencies

- Designer decision: 3 distinct states vs single shared.
- If 3 are required: trigger-condition mapping.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile manual + designer sign-off.
