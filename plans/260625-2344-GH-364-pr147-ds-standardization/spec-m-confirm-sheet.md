# Spec — `MConfirmSheet` (or `MBottomSheet` "confirm" preset)

> **Status:** proposed (GH-364). PR #147 `DiscardCreationDialog` and the existing
> `RemoveFavouriteDialog` are near-identical hand-rolled bottom sheets. The PR
> comment literally says it mirrors RemoveFavouriteDialog "so the two read as the
> same component family" — that family should be ONE primitive, enforced by code.

## Purpose
Bottom-anchored confirm/destructive sheet: a panel (title + body) over a blurred
button slab with 1–2 CTAs. Slide-up motion off the shared `motion` tokens,
instant under Reduce Motion. The canonical "are you sure you want to leave /
delete?" surface.

## Replaces
- `screens/canvas/DiscardCreationDialog.tsx` (PR #147 — entire file, 245 lines)
- `RemoveFavouriteDialog.tsx`
- Future leave/delete confirms (don't hand-roll another)

## Location
Prefer extending `auxi/src/components/design-system/lib/MBottomSheet.tsx` with a
`variant="confirm"` preset, OR a thin `MConfirmSheet.tsx` that composes
`MBottomSheet` + `MButton`. Export from `lib/index.ts`.

## API
```ts
type MConfirmAction = {
  label: string;
  onPress: () => void;
  /** maps to MButton variant — 'dangerOutline' | 'danger' | 'secondary' | 'text' */
  variant: MButtonVariant;
  testID: string;
  accessibilityLabel?: string;
};

type MConfirmSheetProps = {
  visible: boolean;
  title: string;
  body?: string;
  /** 1–2 actions, top-to-bottom; first is the affirmative/primary. */
  actions: MConfirmAction[];
  isBusy?: boolean;            // disables actions
  onRequestClose: () => void; // backdrop / hardware back → stay
  testID?: string;
};
```

PR #147's Discard sheet becomes:
```ts
<MConfirmSheet
  visible={discardVisible}
  title={t('outfitCanvas.discard_title')}
  body={t('outfitCanvas.discard_body')}
  isBusy={isBusy}
  onRequestClose={handleDiscardCancel}
  actions={[
    { label: t('outfitCanvas.discard_save'),    variant: 'secondary', onPress: handleDiscardSave,    testID: 'canvas-discard-save' },
    { label: t('outfitCanvas.discard_discard'), variant: 'danger',    onPress: handleDiscardConfirm, testID: 'canvas-discard-confirm' },
  ]}
/>
```

## Tokens / motion (all canonical)
- Buttons: **`MButton`** — Save = `secondary`/`dangerOutline` (outlined), Discard = `danger`/`text` (destructive). Kills the hand-rolled `outlinedAction`/`ghostAction`/`saveLabel`/`dangerLabel` + `borderWidth:1.5` + raw `height:56`.
- Panel surface `ds.color.white`/`surface`, radius `ds.radius.md` (top corners), scrim `ds.color.scrim` (new token, = `figmaOverlayScrim`).
- Blurred button slab: BlurView + `ds.color.headerBlurTint` (new token, = `figmaItemDetailHeaderBg`).
- Motion: OPEN `duration.medium`+`easing.enter`, CLOSE `duration.normal`+`easing.exit`, `useReducedMotion()` → instant. Sheet travel as a `motion`/`ds` constant (replaces raw `320`).
- Safe-area bottom padding via `useSafeAreaInsets`.

## States
- visible/hidden (mount-gated) · busy (actions disabled, opacity 0.55) · reduce-motion (instant).

## A11y
- Each action: `testID` + `accessibilityLabel`. Sheet `accessibilityViewIsModal`. Backdrop press = close.

## Acceptance criteria
- [ ] Both DiscardCreationDialog and RemoveFavouriteDialog deleted, replaced by `MConfirmSheet`.
- [ ] Buttons are `MButton`; no raw `TouchableOpacity` CTA styles remain.
- [ ] Motion asymmetry + reduce-motion preserved; no raw `320`/`56`/`1.5` literals.
- [ ] Destructive label uses `ds.color.danger` (see token-map bug #2).
- [ ] Unit test: open/close, busy disables, reduce-motion path.

## Open questions
- Keep `MConfirmSheet` as its own export, or fold into `MBottomSheet variant="confirm"`? (Lean: thin composer for clarity.)
- Does any caller need a 3rd "Cancel" button rendered (vs backdrop-only cancel)? PR #147 uses backdrop-cancel only.
