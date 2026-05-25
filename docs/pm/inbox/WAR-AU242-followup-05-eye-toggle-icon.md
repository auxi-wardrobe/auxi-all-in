---
id: WAR-AU242-FU-05
parent: AU-242
type: chore
title: "[M4] Eye-toggle icon SVG asset"
state: Backlog
priority: P2
labels: [type:chore, area:mobile, role:designer, role:mobile-dev, assets, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: Viet (export) + mobile-dev (swap)
estimate: 0.5d
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

`SignInScreen` and `ResetNewPasswordScreen` show password-visibility
toggles as text buttons ("Show" / "Hide"). Figma specs 09 and 12 use
24×24 eye / eye-off glyphs. Replacing text with the real glyph is the
last visual polish gap before the screens match design.

## Acceptance criteria

- [ ] Designer (Viet) exports `icon_eye_open.svg` + `icon_eye_closed.svg`
      from Figma (24×24, stroke 1.5, currentColor compatible).
- [ ] Assets placed in `auxi/src/assets/icons/`.
- [ ] SignInScreen + ResetNewPasswordScreen swap text buttons for
      `<IconEyeOpen width={24} height={24} />` / `<IconEyeClosed ... />`.
- [ ] Tap target stays ≥44pt (wrap icon in 44pt touchable).
- [ ] Existing testIDs preserved (`password-visibility-toggle`,
      `new-password-visibility-toggle`).
- [ ] Dark-mode color follows theme.text.primary via currentColor.

## Out of scope

- Animated transitions between open/closed states.
- Other icon swaps (separate tickets per icon set).

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding M4
- Figma specs: 09 (sign-in), 12 (reset-new-password)
- Files: `auxi/src/screens/auth/SignInScreen.tsx`,
  `auxi/src/screens/auth/ResetNewPasswordScreen.tsx`,
  `auxi/src/assets/icons/`
- Parent: AU-242
