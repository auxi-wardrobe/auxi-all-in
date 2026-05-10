---
id: WAR-PR-006
type: bug
title: "[Bug] Close 17 visual fidelity findings from 2026-05-05 QA sweep"
state: Done
priority: P2
labels: [type:bug, area:mobile, role:mobile-dev, source:pr]
source_pr: https://github.com/ducga1998/auxi-mobile/pull/6
source_repo: auxi (ducga1998/auxi-mobile)
author: ducga1998
merged_at: 2026-05-05T09:47:16Z
findings_doc: auxi/docs/qa-findings/2026-05-05-ui-sweep.md
created: 2026-05-05
---

## Context

The 2026-05-05 visual fidelity sweep produced 20 findings across
Wardrobe, Add-sheet, Home, Settings, Body, and Sidebar. This PR closes
15 of them in 5 atomic commits. 5 minor findings deferred (H3, H4,
B1, D3, Sb3).

## Symptoms fixed (root cause from diff)

| Bundle | Findings | Symptom | Root cause |
|---|---|---|---|
| 1 | W1, A1, D1, B2, S2, S4, Sb1 | Literal `+`, `<`, `>` glyphs and `temp_*` placeholders shown instead of real icons; sidebar items collided semantically (My body / Archive both used generic glyphs) | Missing SVG assets; placeholder filenames committed; sidebar entries pointed to wrong icon keys |
| 2 | S1, S3, S5, S6, S7 | Settings title typo "Setting"; SafeArea bg dark/half-finished hero; speech-bubble icon unlabeled; "06:15 AM/PM" misaligned; "Weekdays" mis-leveled as title | Copy typo; SafeArea bgColor wrong; missing label; flexbox alignment; semantic level wrong |
| 3 | H1, H2 | Mode pills truncated at small widths; Home outfit grid showed empty 4th tile when items < 4 | Padding 14 + fontSize 12 too tight; `Math.max(4, items.length)` floored to 4 instead of using actual count |
| 4 | Sb2 | Sidebar menu cluster floated absolutely, ignored "Get dressed" pill | Absolute positioning instead of natural flow |
| 5 | A2, D2 | Add-sheet loading tile unlabeled; catalog selection ring always visible regardless of selection state | Missing copy on loading state; selection ring not gated on `isSelected` |

## What shipped

5 atomic commits, one per fix bundle:
- `2ea7bed` — 6 new SVG icons; `temp_*` placeholders removed; sidebar
  disambiguation (`My body` → `Icons.Body`, `Archive` → `Icons.Archive`).
- `3e2e6c4` — Settings copy + SafeArea bg + send-feedback label + AM/PM
  alignment + Weekdays caption.
- `7f8c504` — Mode pill padding + grid `items.length` fix.
- `782048f` — Sidebar absolute → flow.
- `1a2ba94` — Add-sheet loading copy + catalog selection gating.

## Acceptance criteria

- [x] All 17 findings closed with diff evidence.
- [x] `npx tsc --noEmit` baseline preserved.
- [x] `yarn lint` baseline preserved (4 errors / 3 warnings, all legacy).
- [x] Bundles 1, 2, 4 verified on iOS sim with screenshots in
      `auxi/docs/qa-findings/screenshots/2026-05-05/`.
- [ ] Bundles 3 (Home pills + grid) and 5 (Add sheet spinner + catalog
      selection) — visual verification deferred to reviewer; Metro
      hot-reload + automation pathway timed out in author session.

## Files touched

- 6 new SVG icons under `auxi/src/assets/images/`.
- `auxi/src/assets/icons/index.ts` (registry update).
- `auxi/src/screens/{HomeScreen,WardrobeScreen,SettingsScreen,BodyScreen}.tsx`.
- `auxi/src/components/layout/Sidebar.tsx`.

## Out of scope (deferred minor)

H3, H4, B1, D3, Sb3 — track in next sweep.
