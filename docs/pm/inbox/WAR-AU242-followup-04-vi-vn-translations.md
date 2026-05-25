---
id: WAR-AU242-FU-04
parent: AU-242
type: chore
title: "[M3] vi-VN translations fill (133 keys)"
state: Backlog
priority: P1
labels: [type:chore, area:mobile, role:designer, i18n, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: Viet (vietdesign81@gmail.com)
estimate: 0.5d
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

`auxi/src/translations/vi-VN.json` has 133 keys currently set to
placeholder values of the form `[VI] <english>`. Anh Viet (designer)
to provide proper Vietnamese copy matching the Figma string layer
content — Viet wrote the Figma copy so he's the single source of truth.

This blocks the Vietnamese launch (vi-VN is the primary market locale).

## Acceptance criteria

- [ ] Replace every `[VI] *` value in `auxi/src/translations/vi-VN.json`
      with proper Vietnamese translation.
- [ ] Copy matches Figma string layers (no paraphrasing — designer copy
      wins).
- [ ] Vietnamese diacritics correct, no auto-correct corruption.
- [ ] Tone matches existing in-app Vietnamese (informal "bạn", not "anh/em").
- [ ] No truncation in iOS sim screenshots at 375pt width — flagged keys
      that overflow get a shorter alternative.
- [ ] Designer (Viet) sign-off committed in PR description.

## Out of scope

- Adding new locales (en-US + vi-VN only for MVP).
- Re-translating en-US strings.

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding M3
- File: `auxi/src/translations/vi-VN.json`
- Parent: AU-242
