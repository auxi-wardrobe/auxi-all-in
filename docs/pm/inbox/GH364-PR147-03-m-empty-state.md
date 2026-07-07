---
id: WAR-GH364-PR147-03
parent: WAR-GH364-PR147-00
type: feature
title: "Phase 2-3 — build MEmptyState primitive"
state: Backlog
priority: P2
labels: [type:feature, area:mobile, design-system, role:mobile-dev, design-review, source:pr147-analysis]
team: Auxi
workspace: duncan-1
owner: mobile-dev + CEO (new-pattern sign-off)
estimate: S
linear_parent_url: TBD — GH-364 parent
created: 2026-06-26
linear_sync_status: pending
blocked_by: WAR-GH364-PR147-01 (D3), WAR-GH364-PR147-02 (tokens)
---

## Context

Genuine DS gap — no `MEmptyState` in the `M*` barrel. PR #147 `MyCreationsScreen`
and `FavouriteScreen` each hand-roll a centered "nothing here yet" state. Two
copies → one primitive. New pattern, so needs CEO sign-off (D3).

## Acceptance criteria

- [ ] Create `auxi/src/components/design-system/lib/MEmptyState.tsx`, export from
      `lib/index.ts`.
- [ ] API: `{ icon?, message (required), caption?, action?, testID?, accessibilityLabel? }`.
- [ ] All styling from `ds.*` tokens — no `figma*/uac*/hex`. Container `flex:1`,
      center/center, `gap: spacing.sm` (12), `paddingHorizontal: spacing.l`; icon
      tint `ds.color.black`; message Poppins-Regular 12/16 `ds.color.ink`; caption
      `ds.color.onVariant`.
- [ ] **Per D3:** include/omit the `action` CTA slot per CEO decision (Favourite
      "Browse" CTA yes/no).
- [ ] `accessibilityLabel` defaults to `message`; container `accessibilityRole="text"`;
      decorative icon `accessibilityElementsHidden`.
- [ ] `testID` + `accessibilityLabel` pass-through.
- [ ] Snapshot + a11y unit test.
- [ ] `npx tsc --noEmit` + `yarn lint` clean.

> Consumption by `MyCreationsScreen` + `FavouriteScreen` (removing local empty-state
> styles) happens in Phase 4 (`-07`). This ticket builds + tests the primitive.

## Out of scope

- Migrating the screens to consume it (Phase 4, `-07`).
- Loading state (use the screen's loader, not this component).

## Dependencies

- `-01` D3 (CTA decision). `-02` (ds tokens present).

## Refs

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/spec-m-empty-state.md`
- PRs: `auxi-wardrobe/auxi-all-in#29`, ref `auxi-wardrobe/auxi-mobile#147`
