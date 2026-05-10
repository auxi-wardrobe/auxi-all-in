---
id: WAR-AUDIT-006
type: feature
title: "[Favorites] Add Love-collection screen (list of liked outfits)"
state: Backlog
priority: P1
labels: [audit, figma, area:mobile, role:mobile-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "909:7793"
figma_frame: "1667:2731"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Heart action exists on Home (`heartButton` at `HomeScreen.tsx:325`) and
backing service is wired (`STYLE_TAG_FAVORITE` at `wardrobeService.ts:7`,
`toggleWardrobeItemFavorite` at `wardrobeService.ts:394`). What's missing
is the **destination**: the screen that lists every outfit the user has
liked. Figma has a dedicated frame for it.

## Designer note (verbatim)

> "When user clicks the heart icon → the app lists all outfits they
> clicked Yes"

Source: Figma sticky note `909:7793` (section `909:7328` "Home adjust").
Dedicated frame: `1667:2731` ("love collection").

## Code reference checked

- `auxi/src/screens/HomeScreen.tsx:325` — heart button present.
- `auxi/src/services/wardrobeService.ts:7,394` — favorite tag + toggle
  service present.
- No `FavoritesScreen` / `LoveCollectionScreen` exists.
- No route registered in `src/types/navigation.ts` or `AppNavigator.tsx`.

## Acceptance criteria

- [ ] New screen (working name `LoveCollectionScreen.tsx`) listing all
      outfits the user has favorited, matching Figma frame `1667:2731`.
- [ ] Screen registered in `src/types/navigation.ts` `AppStackParamList`
      AND in `src/navigation/AppNavigator.tsx` (skipping either causes
      cold-start runtime breakage per `auxi/CLAUDE.md`).
- [ ] Entry point: tapping heart icon (or a sidebar item — designer
      to confirm) navigates to the screen.
- [ ] Each row shows the outfit and supports unlike (uses existing
      `toggleWardrobeItemFavorite`).
- [ ] Empty state: copy + artwork when user has no favorites yet.
- [ ] Pull-to-refresh fetches latest favorites via TanStack Query.
- [ ] Theme tokens; SVG icons; no hex literals.
- [ ] qa-mobile flow: favorite 2 outfits on Home, navigate to collection,
      confirm both appear; unlike 1, confirm it disappears.

## Out of scope

- Sharing / exporting favorites.
- Filtering / sorting controls (unless designer specs them).

## Dependencies

- Designer confirmation on entry-point: heart icon vs sidebar.
- Backend endpoint to list favorites — verify `wardrobe-backend/` already
  exposes one; if not, file follow-up.

## Verification

- `npx tsc --noEmit` clean.
- `yarn lint` no new errors.
- qa-mobile manual on iOS sim.
