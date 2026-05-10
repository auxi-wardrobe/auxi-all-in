---
id: WAR-AUDIT-011
type: feature
title: "[Home] Add download-AI-photo action"
state: Backlog
priority: P2
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "909:7805"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer wants users to be able to save the AI-generated outfit photo to
their device camera roll. Not implemented.

## Designer note (verbatim)

> "User can download the AI photo"

Source: Figma sticky note `909:7805` (section `909:7328` "Home adjust").

## Code reference checked

- `auxi/src/screens/HomeScreen.tsx` — no save / download / share
  affordance.
- No `@react-native-camera-roll/camera-roll` (or equivalent) import in
  the codebase.

## Acceptance criteria

- [ ] Save / download button (or icon) on the AI photo view, position
      per Figma — request asset spec from designer if unclear.
- [ ] Tap saves the rendered image to device camera roll on iOS and
      Android.
- [ ] iOS: request photo-library add-only permission (Info.plist string
      added). Android: request `WRITE_EXTERNAL_STORAGE` for ≤ API 28 or
      use the scoped storage path for ≥ API 29.
- [ ] Success feedback: existing snackbar pattern (see `HomeScreen.tsx`
      success handling).
- [ ] Error feedback: distinct copy on permission-denied vs save-failed.
- [ ] qa-mobile flow: tap download on iOS sim → confirm Photos has the
      image; on Android emulator → confirm Gallery has the image.

## Out of scope

- Sharing to social platforms (separate ticket).
- Saving wardrobe items (this is for the AI-generated outfit photo only).

## Dependencies

- Designer: confirm icon / position / copy.
- Tech-lead: review camera-roll dependency choice.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile manual on iOS sim + Android emulator (or device).
