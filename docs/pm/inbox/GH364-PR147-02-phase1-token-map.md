---
id: WAR-GH364-PR147-02
parent: WAR-GH364-PR147-00
type: chore
title: "Phase 1 — apply PR #147 token map: fix 2 theme.ts bugs + add ds tokens + start typography consolidation"
state: Backlog
priority: P2
labels: [type:chore, area:mobile, design-system, role:mobile-dev, source:pr147-analysis]
team: Auxi
workspace: duncan-1
owner: mobile-dev
estimate: M
linear_parent_url: TBD — GH-364 parent
created: 2026-06-26
linear_sync_status: pending
blocked_by: WAR-GH364-PR147-01 (D1)
---

## Context

Phase 1 of the PR #147 standardization: token-layer fixes only, no screen logic.
Apply `token-map.md` so the `ds.*` canonical layer is correct and complete before
the primitives (`-03`..`-06`) and the migration (`-07`) build on it. Centralized
in `auxi/src/theme/theme.ts` — wide reach, single file.

Blocked by `-01` D1 (`figmaItemDetailDanger` fate decides whether we recolor or
add a documented second red).

## Acceptance criteria

- [ ] **theme.ts bug #1:** fix the `ds.color.cream` alias comment — `figmaBackground`
      = `#FFFFFF` (white), so its canonical is `ds.color.white`, NOT `cream`. Only
      `figmaCardSurface` is `#f2efec`. (theme.ts:426 / :21)
- [ ] **theme.ts bug #2 (per D1):** reconcile `figmaItemDetailDanger` (#c0392b) vs
      `ds.color.danger` (#bb251a) — either alias+recolor (D1=A) or document the
      second red (D1=B).
- [ ] Add `ds.color.scrim` = `rgba(38,36,33,0.7)` (= `figmaOverlayScrim`).
- [ ] Add `ds.color.headerBlurTint` = `rgba(255,255,255,0.9)` (= `figmaItemDetailHeaderBg`).
- [ ] Add `spacing.sm` = 12 to the generic spacing scale (sits between `s`=8 and
      `m`=16, on the 4px grid); begin migrating `uacDimension12` onto it.
- [ ] Start typography consolidation: `inter*`/`manrope*`/`archivo*`/`playfair*`
      aliases already render Poppins — collapse into a single Poppins-named type
      scale, keep thin back-compat re-exports during migration. (Naming cleanup,
      NOT a font change — render output is unchanged.)
- [ ] `cd auxi && npx tsc --noEmit` clean.
- [ ] `yarn lint` baseline preserved.
- [ ] `./scripts/auxi-lint-tokens.sh` clean (no new hex/font drift).
- [ ] No screen `.tsx` logic touched in this ticket (token layer only).

## Out of scope

- Building the 4 primitives (`-03`..`-06`).
- Migrating screens off `figma*/uac*` (that's Phase 4, `-07`).
- Full typography migration of all call sites — only start it + keep re-exports.

## Dependencies

- `-01` D1 (danger token decision).

## Notes for the implementer

- Source of truth for every mapping: `token-map.md` §0-§5. Do not improvise tokens.
- This is additive — keep legacy aliases working so `-07` can migrate call sites later.
- Already-canonical (do NOT touch): `ds.shadow.headerIcon`, `theme.zIndex.toast`,
  `motion.duration.*`/`easing.*`, `useReducedMotion()`.

## Refs

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/token-map.md`
- File: `auxi/src/theme/theme.ts`
- PRs: `auxi-wardrobe/auxi-all-in#29`, ref `auxi-wardrobe/auxi-mobile#147`
