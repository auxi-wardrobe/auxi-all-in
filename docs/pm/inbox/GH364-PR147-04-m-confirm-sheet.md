---
id: WAR-GH364-PR147-04
parent: WAR-GH364-PR147-00
type: feature
title: "Phase 2-3 — build MConfirmSheet primitive"
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
blocked_by: WAR-GH364-PR147-01 (D1 danger, D3 cancel), WAR-GH364-PR147-02 (tokens)
---

## Context

PR #147 `DiscardCreationDialog` and existing `RemoveFavouriteDialog` are
near-identical hand-rolled bottom sheets — the PR comment literally says it mirrors
RemoveFavouriteDialog "so the two read as the same component family". That family
should be ONE primitive enforced by code.

## Acceptance criteria

- [ ] Build either `MConfirmSheet.tsx` (thin composer over `MBottomSheet` + `MButton`)
      or `MBottomSheet variant="confirm"` preset; export from `lib/index.ts`.
      Lean: thin composer for clarity (open question in spec — pick one, justify).
- [ ] API: `{ visible, title, body?, actions: MConfirmAction[] (1-2), isBusy?,
      onRequestClose, testID? }`; `MConfirmAction = { label, onPress, variant, testID, accessibilityLabel? }`.
- [ ] CTAs are `MButton` (Save = `secondary`/`dangerOutline`, Discard =
      `danger`/`text`) — kills hand-rolled `outlinedAction`/`ghostAction`/`saveLabel`/
      `dangerLabel` + `borderWidth:1.5` + raw `height:56`.
- [ ] Panel `ds.color.white`/`surface`, top corners `ds.radius.md`; scrim
      `ds.color.scrim`; blurred button slab BlurView + `ds.color.headerBlurTint`
      (both new tokens from `-02`).
- [ ] Motion: OPEN `duration.medium`+`easing.enter`, CLOSE `duration.normal`+`easing.exit`,
      `useReducedMotion()` → instant. Sheet travel as a `motion`/`ds` constant
      (replaces raw `320`).
- [ ] Safe-area bottom padding via `useSafeAreaInsets`.
- [ ] **Per D1:** destructive label uses `ds.color.danger`.
- [ ] **Per D3:** support an explicit Cancel button vs backdrop-only — match decision.
- [ ] Each action: `testID` + `accessibilityLabel`; sheet `accessibilityViewIsModal`;
      backdrop press = close.
- [ ] Unit test: open/close, busy disables actions, reduce-motion path.
- [ ] `npx tsc --noEmit` + `yarn lint` clean.

> Deleting `DiscardCreationDialog` + `RemoveFavouriteDialog` and swapping callers
> happens in Phase 4 (`-07`). This ticket builds + tests the primitive.

## Out of scope

- Migrating callers / deleting the two legacy dialogs (Phase 4, `-07`).

## Dependencies

- `-01` D1 + D3. `-02` (scrim + headerBlurTint tokens).

## Refs

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/spec-m-confirm-sheet.md`
- Files: `auxi/src/components/design-system/lib/MBottomSheet.tsx`, `MButton.tsx`
- PRs: `auxi-wardrobe/auxi-all-in#29`, ref `auxi-wardrobe/auxi-mobile#147`
