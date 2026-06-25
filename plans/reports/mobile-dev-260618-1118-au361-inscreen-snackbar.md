# AU-361 — item-ready snackbar: in-screen overlay (definitive fix)

**Date:** 2026-06-18
**Branch:** `fix/au361-toast-config-wiring` (PR #90) — did NOT switch branches
**Commit:** `482825cb9e7959ac7d98e3046dc6f7189ee8b113`

## Approach
`react-native-toast-message`'s custom-config type `successSnackbar` never
mounted (proven across ~9 live-sim cycles) while built-in toast types render
fine through the same `<Toast>`. Per decision, bypassed the library's
custom-config path entirely and render the snackbar as a self-controlled,
absolutely-positioned in-screen overlay in `WardrobeScreen`. The
preparing→ready detection, dedup refs and `item_ready_toast_shown` analytics
are unchanged.

## Files changed
- **NEW** `auxi/src/components/feedback/ItemReadySnackbar.tsx` — presentational
  M3 snackbar extracted verbatim from the deleted `toastConfig.tsx`'s
  `SuccessSnackbar`. Prop `message: string`. Keeps exact Figma styling
  (`figmaSnackbarSuccessBg`, 24px check-circle container / 16px glyph, 4px
  radius, Inter 14/20, M3 Elevation Light/3 shadow), `testID="wardrobe-item-ready-snackbar"`,
  `accessible` + `accessibilityRole="alert"` + `accessibilityLabel={message}`.
- **DELETED** `auxi/src/components/feedback/toastConfig.tsx` — its only consumer
  was App.tsx; its `SuccessSnackbar` styling moved to ItemReadySnackbar.tsx.
  (git records it as a rename → ItemReadySnackbar.tsx at 64% similarity.)
- **MODIFIED** `auxi/App.tsx:17,84` — dropped the `toastConfig` import; reverted
  `<Toast config={toastConfig} />` back to bare `<Toast />` (built-in
  error/success/info presets the rest of the app uses still need `<Toast />`).
- **MODIFIED** `auxi/src/screens/WardrobeScreen.tsx`:
  - `:29` import `ItemReadySnackbar`.
  - `:103` `READY_SNACKBAR_MS = 4000` constant.
  - `:126-153` new state `readySnackbarVisible` + `readySnackbarMessage`,
    `snackbarTimerRef`, `showReadySnackbar()` helper, and unmount-cleanup
    `useEffect`.
  - `:175-185` (`reconcileReadyItems`) replaced the `Toast.show({ type:
    'successSnackbar', ... })` call with `showReadySnackbar(t('wardrobe.list.item_ready_title'))`;
    added `showReadySnackbar` to the callback dep array. Detection / dedup /
    `track('item_ready_toast_shown', ...)` untouched.
  - `:633-645` render: `{readySnackbarVisible ? (<View style={styles.readySnackbarOverlay}
    pointerEvents="none" testID="wardrobe-item-ready-snackbar-overlay"><ItemReadySnackbar
    message={readySnackbarMessage} /></View>) : null}` placed inside the
    SafeAreaView root, after the AI-processing Modal.
  - `:656-665` `readySnackbarOverlay` style: `position:'absolute', left:0,
    right:0, bottom:24, alignItems:'center', zIndex:1000, elevation:1000`.

(Line numbers are post-edit approximate.)

## How the snackbar is shown / hidden
- **Show:** on a preparing→ready transition (same condition as before:
  `prevPreparing.has(id) && !readyToastedIdsRef.current.has(id)`), the id is
  added to `readyToastedIdsRef` (once-per-item dedup, unchanged), then
  `showReadySnackbar(title)` runs: it clears any prior timer, sets the message,
  flips `readySnackbarVisible` true, and schedules a 4000ms auto-hide stored in
  `snackbarTimerRef`.
- **Hide:** the stored timeout flips `readySnackbarVisible` false after 4s. A
  re-trigger clears the previous timer first (no overlap/leak). An unmount
  `useEffect` cleanup clears any pending timer.
- **Touch pass-through:** overlay is `pointerEvents="none"` so it never blocks
  the grid. Bottom-anchored + centred (`bottom:24`, `alignItems:'center'`),
  `zIndex/elevation:1000` so it floats above the grid.
- **Dedup loop guard:** `readyToastedIdsRef` still gates per item, so polling /
  refocus cannot re-fire it for the same item.

## Custom-toast path removal (confirmed, no dangling refs)
- `grep "toastConfig"` → only a doc-comment mention inside the new
  ItemReadySnackbar.tsx; no live import anywhere.
- `grep "successSnackbar"` → NONE.
- Remaining `Toast.show` calls in WardrobeScreen (`error`/`info`/`success`) are
  all built-in types and still rely on bare `<Toast />` — correct, untouched.
- i18n: reused existing `wardrobe.list.item_ready_title` (present in en/vi/fr);
  no new keys.

## Verification
- `nvm use 20` (Node v20.12.2).
- `npx tsc --noEmit` → **clean** (zero errors across the project).
- `npx eslint` on the three touched files → **no errors, no warnings**.
- Live-sim verification not run here (handled by qa-mobile per instruction).

## Constraints honoured
- Branch unchanged (`fix/au361-toast-config-wiring`).
- `ios/auxi.xcodeproj/project.pbxproj`, `ios/auxi/Info.plist`, and
  `.github/workflows/auxi-testflight-beta.yml` left uncommitted / unstaged.
- Staged only the specific code files (no `git add -A`). Detection / dedup /
  analytics semantics unchanged.

## Open questions
- None. Live-sim confirmation of the overlay mounting is the only remaining
  step (qa-mobile).
