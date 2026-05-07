---
id: WAR-AUDIT-008
type: feature
title: "[Splash] Implement flash-screen / splash flow (9 Figma frames)"
state: Backlog
priority: P2
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_nodes: ["1727:19422", "1727:19462", "1727:19442", "1977:4683", "1977:4733", "1977:4783", "1977:4633", "1727:19270", "1783:11535"]
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Figma includes 9 splash / flash-screen frames. Not implemented in RN.
Likely the cold-start brand intro + animation sequence.

## Designer note (verbatim)

No sticky-note text on these frames; the visuals are the spec.

Frames:
- `1727:19422`, `1727:19462`, `1727:19442` — flash-screen group A
- `1977:4683`, `1977:4733`, `1977:4783`, `1977:4633` — flash-screen group B
- `1727:19270`, `1783:11535` — additional splash variants

## Code reference checked

- `auxi/index.js` and root layout — no custom splash. Default RN splash
  only.
- No `react-native-bootsplash` or equivalent integration found.
- No splash artwork in `auxi/src/assets/`.

## Acceptance criteria

- [ ] Designer provides exported splash assets (or confirms which Figma
      frame is the canonical one of the 9).
- [ ] Splash is shown on cold start, replaced when JS bundle is ready.
- [ ] Solution works for both iOS (LaunchScreen.storyboard) and Android
      (drawable).
- [ ] If animated splash is required, `react-native-bootsplash` (or
      similar) added; bootstrap sequence reviewed by tech-lead.
- [ ] No flicker / white frame between native splash and JS-rendered
      first screen.
- [ ] qa-mobile: cold-launch on iOS sim and on a low-end Android device,
      record video, designer signs off on visual fidelity.

## Out of scope

- Onboarding screens themselves — those are tracked in WAR-AUDIT-007.

## Dependencies

- Designer: confirm canonical splash frame + export assets.
- Tech-lead: approve splash library choice if one is added.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile cold-launch on iOS + Android.
