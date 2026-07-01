# Spec — `BlurMenuHeader` (layout component)

> **Status:** proposed (GH-364). The blurred menu-header look is an APPROVED
> variant per `header-footer-rules.md`, but there is NO shared component for it —
> so `FavouriteScreen` hand-rolls it and PR #147 `MyCreationsScreen` hand-rolls it
> again (BlurView + tint + menu button + title). Codify the approved variant.

## Purpose
The translucent list-screen header: a `BlurView` bar with a tint overlay, a
left menu (hamburger) or back button, and a title. Distinct from the canonical
opaque `components/layout/Header.tsx` (76px) — this is the see-through variant
used on Favourite / My Creations.

## Replaces
- `MyCreationsScreen.tsx` header block (PR #147 diff lines ~126-146 + `header`/`headerBlur`/`headerTint`/`menuButton`/`headerTitle` styles ~158-184)
- `FavouriteScreen` blurred header (lines ~220-246)

## Decision (CEO/designer)
Two viable shapes — pick one:
- **(A) New `BlurMenuHeader` layout component** in `src/components/layout/` (sibling to `Header.tsx`). Cleanest separation.
- **(B) `Header.tsx` gains a `variant="blur"` prop.** One header component, two looks. Risk: bloats Header.

Lean **(A)** — the blur header has its own safe-area/tint/pointer-events concerns that don't belong in the opaque Header.

## API
```ts
type BlurMenuHeaderProps = {
  title: string;
  /** 'menu' opens the sidebar; 'back' calls onBack. */
  leading: 'menu' | 'back';
  onLeadingPress: () => void;
  /** Optional right-side action (e.g. an MIconButton). */
  trailing?: React.ReactNode;
  testID?: string;
};
```

## Tokens (all `ds.*`)
- BlurView `blurType="light"`, `blurAmount` = `ds` blur constant (currently 8), `pointerEvents="none"` (must NOT swallow the menu tap — PR #147 got this right).
- Tint overlay: `ds.color.headerBlurTint` (NEW token = `figmaItemDetailHeaderBg` rgba(255,255,255,0.9)); also the `reducedTransparencyFallbackColor`.
- Leading button: **`MIconButton` `size="lg"`** (44×44) with `ds.shadow.headerIcon` — replaces the hand-rolled `TopIconButton` (legacy FigmaPrimitives) / raw `menuButton` style (44×44, `borderRadius.m`, `white`).
- Title: Poppins-SemiBold 24/32 (`poppinsH4SemiBold`), `ds.color.ink`.
- `paddingTop: insets.top + spacing.s`, `paddingHorizontal/Bottom: spacing.sm` (12), `overflow:'hidden'`.

## States
- leading=menu · leading=back · with/without trailing · reduce-transparency fallback (solid tint).

## A11y
- Leading button `testID` + `accessibilityLabel` (`open_menu` / `go_back`). Title is static text. Blur + tint `accessibilityElementsHidden` (decorative).

## Acceptance criteria
- [ ] `MyCreationsScreen` + `FavouriteScreen` render `BlurMenuHeader`; no local blur-header styles remain.
- [ ] Leading is `MIconButton` (no `TopIconButton`, no raw `Pressable` menu).
- [ ] Tint via `ds.color.headerBlurTint`; no `figmaItemDetailHeaderBg` in screens.
- [ ] Decorative layers don't capture touches (menu tap works).

## Open questions
- Does the canvas editor header (left group: menu/undo/redo + right: My Creations) also adopt this, or stay bespoke? It's an editor toolbar, not a list header → likely stays bespoke but its icon buttons should still become `MIconButton`.
