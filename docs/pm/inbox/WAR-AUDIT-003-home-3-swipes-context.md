---
id: WAR-AUDIT-003
type: feature
title: "[Home] Auto-open 'find more context' after 3 unsuccessful swipes"
state: Backlog
priority: P1
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "1727:19257"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer wants the context-chips modal to open automatically when a user
swipes past 3 outfits without favoriting. Helps unstuck users who can't
find a match. No swipe counter currently exists.

## Designer note (verbatim)

> "Auto-open this screen when user swipes/tries **3 times** without finding
> a favorite outfit"

Source: Figma sticky note `1727:19257` (section `909:7328` "Home adjust").

## Code reference checked

- `auxi/src/screens/HomeScreen.tsx` — no swipe counter, no auto-open
  trigger. Manual `handleOpenContextEdit` exists at `:244`.
- `auxi/src/components/features/ContextChipsModal.tsx` — modal works,
  triggered manually only.

## Acceptance criteria

- [ ] Counter increments on each "next outfit / dismiss" action when no
      favorite was tapped.
- [ ] Counter resets to 0 when user favorites an outfit.
- [ ] After 3 consecutive non-favorited dismissals, `ContextChipsModal`
      opens automatically.
- [ ] User can dismiss the modal without picking a chip; counter resets to
      0 either way (designer to confirm reset behavior on dismiss).
- [ ] Counter is per-session (resets on Home unmount / app cold start).
- [ ] No regression on manual context-edit button.
- [ ] qa-mobile flow: swipe 3 outfits without favoriting → confirm modal
      opens. Favorite the 2nd outfit → confirm counter resets.

## Out of scope

- AI free-text context input (deferred per note `909:7796`; predefined
  chips only).
- Persisting counter across sessions.

## Dependencies

- Designer confirmation on counter-reset behavior when modal is dismissed.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile manual on iOS sim.
