---
id: WAR-GH364-PR147-05
parent: WAR-GH364-PR147-00
type: feature
title: "Phase 2-3 — build BlurMenuHeader layout component"
state: Backlog
priority: P2
labels: [type:feature, area:mobile, design-system, role:mobile-dev, design-review, source:pr147-analysis]
team: Auxi
workspace: duncan-1
owner: mobile-dev
estimate: M
linear_parent_url: TBD — GH-364 parent
created: 2026-06-26
linear_sync_status: pending
blocked_by: WAR-GH364-PR147-01 (D2 shape), WAR-GH364-PR147-02 (headerBlurTint token)
---

## Context

The blurred menu-header look is an APPROVED variant per `header-footer-rules.md`,
but there is NO shared component — so `FavouriteScreen` hand-rolls it and PR #147
`MyCreationsScreen` hand-rolls it again (BlurView + tint + menu button + title).
Codify the approved variant. **D2 decides the shape before building.**

## Acceptance criteria

- [ ] **Per D2:** build either (A) new `BlurMenuHeader` in `src/components/layout/`
      (sibling to `Header.tsx`, analysis lean) or (B) `Header.tsx` `variant="blur"`.
- [ ] API: `{ title, leading: 'menu' | 'back', onLeadingPress, trailing?, testID? }`.
- [ ] BlurView `blurType="light"`, `blurAmount` = `ds` blur constant (8),
      `pointerEvents="none"` so it does NOT swallow the menu tap.
- [ ] Tint overlay + `reducedTransparencyFallbackColor` = `ds.color.headerBlurTint`
      (new token from `-02`) — no `figmaItemDetailHeaderBg` in the component.
- [ ] Leading button is `MIconButton size="lg"` (44×44) with `ds.shadow.headerIcon`
      — no `TopIconButton`, no raw `Pressable` menu.
- [ ] Title Poppins-SemiBold 24/32, `ds.color.ink`; `paddingTop: insets.top +
      spacing.s`, `paddingHorizontal/Bottom: spacing.sm` (12), `overflow:'hidden'`.
- [ ] States: leading=menu / leading=back / with-without trailing / reduce-transparency
      fallback (solid tint).
- [ ] Leading button `testID` + `accessibilityLabel` (`open_menu`/`go_back`); blur
      + tint `accessibilityElementsHidden`.
- [ ] Unit test incl. "decorative layers don't capture touches (menu tap works)".
- [ ] `npx tsc --noEmit` + `yarn lint` clean.

> Swapping `MyCreationsScreen` + `FavouriteScreen` onto it happens in Phase 4 (`-07`).
> The canvas editor header (toolbar) likely stays bespoke but its icon buttons
> should still become `MIconButton` — track in `-07`.

## Out of scope

- Migrating screens to consume it (Phase 4, `-07`).
- The canvas editor toolbar redesign.

## Dependencies

- `-01` D2 (shape A vs B). `-02` (`ds.color.headerBlurTint`).

## Refs

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/spec-blur-menu-header.md`
- Doc: `auxi/docs/design-system/header-footer-rules.md`; file `auxi/src/components/layout/Header.tsx`
- PRs: `auxi-wardrobe/auxi-all-in#29`, ref `auxi-wardrobe/auxi-mobile#147`
