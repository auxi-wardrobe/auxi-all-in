# Wardrobe design-review v2 fixes — mobile-dev

Branch: `fix/wardrobe-design-review-260619` (no commit; orchestrator commits after gates).
Source review: `auxi/docs/design-reviews/2026-06-19-wardrobe.md`.

## Per-finding changes

### F7 (MAJOR) — Wardrobe error state + journey continuity
- New `loadError` state; `fetchItems` catch sets it (non-silent only) and clears on retry/start. `WardrobeScreen.tsx` (`fetchItems`, new `handleRetryLoad`).
- New render branch `loadError ? <error state> : hasItems ? … : <empty>` — dedicated error UI (`testID=wardrobe-error-state`) with title `common.load_wardrobe_failed_title`, body `wardrobe.list.error_body`, and Retry CTA (`testID=wardrobe-error-retry`, `accessibilityLabel=common.a11y_retry_load`). Distinct from the genuine empty state.
- Error-state styles mirror HomeScreen's error layout (outline Retry pill) for cross-screen consistency.
- Analytics (per rule): `wardrobe_load_failed` (in catch) + `wardrobe_load_retry_tapped` (in `handleRetryLoad`), both `{ category }`, literal names, no PII. Wired via `track()`. Tracking-plan §5.4 + §10 funnel updated (`docs/analytics/mixpanel-tracking-plan.md`).

### F6 (MAJOR) — safe-area family consistency
- `WardrobeScreen.tsx:8` now imports `SafeAreaView` + `useSafeAreaInsets` from `react-native-safe-area-context` (matches DatabaseScreen). `<SafeAreaView edges={['top']}>`.
- Snackbar overlay `bottom` now inline `insets.bottom + 24` (was static `bottom:24`; removed dead static value from `readySnackbarOverlay` style).
- Add-sheet: new `Animated.View` wrapper carries `paddingBottom: insets.bottom` (surface keeps its own 36 content pad), so the sheet clears the home indicator.

### F1 (MAJOR) — add-item sheet motion
- Converted the add-item `<Modal animationType="slide">` to `animationType="none"` driven by `Animated` translateY (`addSheetSlide`) with `addSheetMounted` keep-alive. OPEN `medium 350 + easing.enter`, CLOSE `normal 250 + easing.exit`, `useReducedMotion` → instant set. Mirrors `ContextChipsModal` / `MoodFeedbackSheet`. Did NOT touch the dead `ItemDetailBottomSheet` (deleted, see F10).
- AI-processing fade modal left as-is (a full-screen processing overlay, not the bottom sheet flagged; lower priority and `fade` is acceptable for a full-screen scrim).

### F2 (MAJOR) — press-feedback motion
- New shared primitive `src/components/primitives/PressableScale.tsx`: timing dip to `motion.scale.press` (0.97) on press-in, `Animated.spring` + `spring.standard` back to 1 on release, reduce-motion no-op; preserves `activeOpacity` dim. Single helper (DRY).
- Applied to: grid tile, header add button, empty-state CTA, error Retry CTA, and `AddMethodRow` (all in `WardrobeScreen.tsx`). All keep their existing `testID` / `accessibilityLabel`.

### F4 (MAJOR) — i18n
- Hardcoded `"Preparing this item"` → `t('wardrobe.list.preparing_tile')`. Added `preparing_tile` to en/fr/vi.

### F3 (MINOR) — CategoryTabs selection motion
- `CategoryTabs.tsx` refactored: extracted `CategoryChip` with an `Animated` scale that animates to `motion.scale.select` (1.03) over `fast` (120ms) when selected, rest at 1; reduce-motion sets instantly. Benefits Wardrobe + Database (shared component). testIDs/a11y unchanged.

### F5 (MINOR) — token tier / DRY
- `tileBadge.backgroundColor` was a re-inlined `rgba(18,18,18,0.75)` duplicate → now `theme.colors.figmaCardTag` (the existing named token, theme.ts:23).
- Did NOT churn the wider `figma*`/`uac*` → `ds.*` alias migration: review marks that MINOR/non-blocking, the aliases are on-system values, and a blanket swap would balloon the diff with no behavioral change. The two `rgba()` overlay tints (`sheetOverlay`, `tilePreparingOverlay`) are pre-existing and use the whitelisted `rgba()` form — left as-is (no scrim token exists; introducing one is a separate token-system decision, flagged below).

### F10 (MINOR) — delete dead code
- Deleted `src/components/features/ItemDetailBottomSheet.tsx`. Confirmed unused: `grep -rn ItemDetailBottomSheet src/ __tests__/ maestro/` → only comments in HomeScreen + its own def; no live import, no test import, no Maestro reference. Clears its 2 token-lint reds (raw `#000`/`#FFF`).

## Not touched (per dispatch — pending decision)
- F8 (preparing tiles tappable / no disabled treatment) — CEO product call. Left as-is.
- F9 (header title Playfair vs `interSemiboldSm`) — qa-ui Figma confirmation. Left as-is.

## Verification (Node 20)
- `npx tsc --noEmit` → **TSC_EXIT=0** (clean).
- `yarn lint` → **8 problems (1 error, 7 warnings)** — identical to pre-change baseline; all in untouched files (HomeScreen `react-hooks/exhaustive-deps`, DatabaseScreen/OutfitCanvasScreen inline-style warnings, usePinReducer/SignInScreen no-void). **No new issues.** (Note: dispatch quoted "4 errors + 3 warnings"; actual measured baseline on this branch is 1 error + 7 warnings — reporting against measured.)
- `./scripts/auxi-lint-tokens.sh` → **34 → 32 violations** (F10 removed the 2 ItemDetailBottomSheet reds; F5 badge swap added none). **Zero violations in any file I touched/created.**
- Prettier run on the 3 edited TS files; tsc + lint re-verified green afterward.

## Files changed
- `src/screens/WardrobeScreen.tsx` (F1,F2,F4,F5,F6,F7)
- `src/components/features/CategoryTabs.tsx` (F3)
- `src/components/primitives/PressableScale.tsx` (new — F2 shared helper)
- `src/translations/{en-EN,fr-FR,vi-VN}.json` (F4 `preparing_tile` + F7 `error_body`)
- `docs/analytics/mixpanel-tracking-plan.md` (F7 events §5.4 + funnel §10)
- Deleted: `src/components/features/ItemDetailBottomSheet.tsx` (F10)

## Could-not-do / flags
- **No simulator verification.** mobile-dev has no sim/mobile-mcp; the review itself notes the Xcode 26.5 ↔ RN 0.83.1 cold-launch redbox blocks a warm Auxi process. Work is **code complete, visual verification pending** — hand to qa-ui (Compare) / qa-mobile (smoke) once the toolchain is fixed. The animated sheet, press-scale, and error-state all need a rendered pass.
- F5 scrim token: the two `rgba()` overlay tints have no theme equivalent. Introducing a `scrim`/`overlay` token is a token-system call (designer/CEO) — left out of this pass to avoid unilaterally adding tokens.

## Open questions
- F5 alias→`ds.*` migration: do a separate dedicated pass for the whole `figma*`/`uac*` surface, or leave until each screen is next touched? (I left it, per "non-blocking when next touching the file".)

**Status:** DONE — 8 actionable findings (F1–F7, F10) fixed; tsc clean, lint at baseline, token-lint reduced; F8/F9 left per dispatch; visual verification pending toolchain.
