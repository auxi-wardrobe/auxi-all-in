# Spec — `MEmptyState` primitive

> **Status:** proposed (GH-364 DS gap). **Genuine gap** — no `MEmptyState` in the
> `M*` barrel. Hand-rolled in PR #147 `MyCreationsScreen` and (separately) in
> `FavouriteScreen`. Two copies → one primitive.

## Purpose
Centered "nothing here yet" state: optional icon + a short message (and optional
action slot). Used by any list/collection screen with an empty result.

## Replaces
- `MyCreationsScreen.tsx` `centerFill` + `IconMyCreation` + `emptyText` (PR #147 diff lines ~94-104, 194-205)
- The equivalent hand-rolled empty block in `FavouriteScreen`

## Location
`auxi/src/components/design-system/lib/MEmptyState.tsx` + export from `lib/index.ts`.

## API
```ts
type MEmptyStateProps = {
  /** Optional leading glyph; rendered at 24×24 in ds.color.black. */
  icon?: React.ReactNode;
  /** Primary message (required). */
  message: string;
  /** Optional secondary line. */
  caption?: string;
  /** Optional action (e.g. an MButton). Rendered below the text. */
  action?: React.ReactNode;
  testID?: string;
  accessibilityLabel?: string;
};
```

## Tokens (all `ds.*`)
- Container: `flex:1`, center/center, `gap: spacing.sm` (12), `paddingHorizontal: spacing.l`.
- Icon tint: `ds.color.black`.
- `message`: Poppins-Regular 12/16 type alias (current `uacBodyXsRegular`), `ds.color.ink`, centered.
- `caption`: same family one tone lighter (`ds.color.onVariant`).

## States
- icon-only-omitted (message-only) · with-action · loading is NOT this component (use the screen's loader).

## A11y
- `accessibilityLabel` defaults to `message`. Container `accessibilityRole="text"`.
- Decorative icon `accessibilityElementsHidden`.

## Acceptance criteria
- [ ] Renders icon + message + optional caption/action, all from `ds.*` tokens (no `figma*`/`uac*`/hex).
- [ ] `MyCreationsScreen` and `FavouriteScreen` both consume it; no local empty-state styles remain.
- [ ] `testID` + `accessibilityLabel` pass-through.
- [ ] Snapshot + a11y unit test.

## Open questions
- Does Favourite's empty state need an action button (e.g. "Browse")? If yes, the `action` slot covers it.
