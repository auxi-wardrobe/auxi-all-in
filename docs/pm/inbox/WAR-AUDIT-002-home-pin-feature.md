---
id: WAR-AUDIT-002
type: feature
title: "[Home] Add Pin feature — pin item then mix"
state: Backlog
priority: P1
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "1672:11783"
figma_frame: "1711:17062"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer specced a "pin" interaction on Home: user pins a favorite item,
then the recommender mixes other items around the pinned one. Figma has
both a sticky note explaining the behavior AND a dedicated frame showing
the pinned-state UI. Code has neither.

## Designer note (verbatim)

> "**Pin feature** — keep favorite item then mix with other items"

Source: Figma sticky note `1672:11783`.
Dedicated frame: `1711:17062` ("Welcome Home / pin item").

## Code reference checked

- `auxi/src/screens/HomeScreen.tsx` — no pin state, no pin button, no
  pinned-item rendering.
- `auxi/src/services/recommendation.ts` — recommendation call has no
  `pinned_item_id` parameter.

## Acceptance criteria

- [ ] Pin action (tap target + icon) on the outfit/item view in Home,
      matching Figma frame `1711:17062`.
- [ ] Pinned item is visually distinct in the next mix (sticky across
      reshuffles until unpinned).
- [ ] Recommendation call includes the pinned item id; backend mixes
      around it.
- [ ] Unpin action available.
- [ ] Pin state cleared on session end (unless designer confirms persist).
- [ ] Backend contract update tracked as a follow-up sub-issue once mobile
      contract is signed off.
- [ ] Theme tokens used; SVG icon imported via
      `react-native-svg-transformer` (no `<Image>` for SVG).
- [ ] qa-mobile flow: pin an item, reshuffle, confirm pinned item remains;
      unpin and confirm rotation resumes.

## Out of scope

- Backend mixing-around-pinned logic (separate ticket).
- Persisting pin across sessions (default off; designer to confirm).
- The "DO NOT BUILD IN MVP" note `1752:27660` ("mix with selected item")
  is a different feature — exclude.

## Dependencies

- Designer confirmation that pin is in MVP scope.
- Tech-lead review of recommendation contract change.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile manual smoke on iOS sim against live backend.
