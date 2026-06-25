# GH-364 Phase 3 — WardrobeScreen M* primitive migration

**Date:** 2026-06-24
**Agent:** mobile-dev
**Scope:** `auxi/src/screens/WardrobeScreen.tsx` (component layer only) + lint-script setup commit
**Status:** DONE

## Branch & commits

- Base: `feat/au-364-ds-page-claude-sync` (M* lib lives here)
- Stacked branch: `feat/au-364-wardrobe-m-migration`
- Commits (oldest → newest):
  - `938c52cc` chore(ds): add ds-primitive warn-lint  (commits the untracked `scripts/auxi-lint-ds-primitives.sh`)
  - `56404b36` feat(ds): migrate WardrobeScreen to M* primitives  (1 file, +85 / −171)

## Swap map (what → which M*)

| Region (old) | Old impl | New |
|---|---|---|
| Add-item sheet (was `WardrobeScreen.tsx:625–682`) | `<Modal animationType="none">` + `TouchableWithoutFeedback` scrim + `Animated.View` slide (`addSheetSlide`) + `BottomSheetSurface` | **`MBottomSheet`** — scrim, grab handle, slide/fade ENTER + faster CLOSE + reduce-motion fallback + backdrop-dismiss all encapsulated in the primitive. `visible={addSheetVisible} onDismiss={…} testID="wardrobe-add-sheet"` |
| Empty-state CTA (`emptyCta` PressableScale) | `PressableScale` + `Text` + bespoke `emptyCta`/`emptyCtaText` styles | **`MButton variant="primary"`** (wrapped in `emptyCtaWrap` for the `marginTop`) |
| Error-state Retry (`errorRetry` PressableScale) | `PressableScale` outline + `Text` + bespoke `errorRetry`/`errorRetryLabel` styles | **`MButton variant="secondary"`** (outline; wrapped in `errorRetryWrap`) |

Removed dead imports/state as a result: `Animated`, `TouchableWithoutFeedback`, `BottomSheetSurface`, `motion`, `useReducedMotion`, the `addSheetMounted`/`addSheetSlide` state + the ~40-line slide-motion `useEffect`, and the now-unused `screenHeight` destructure. Removed dead styles: `emptyCta`, `emptyCtaText`, `errorRetry`, `errorRetryLabel`, `sheetOverlay`, `addSheetAnim`, `addSheet`.

## Kept bespoke (and why)

- **`AddMethodRow`** (Wardrobe-only sub-component, rendered as children of `MBottomSheet`): carries a **title + description two-line** layout. No generic M* row primitive expresses that — `MSheetOption` and `MListRow` are both single-line label rows. Swapping to either would silently drop the `method_search_desc` / `method_photo_desc` copy (a content/behavior change, which the task forbids). So the sheet **container** is migrated to `MBottomSheet`, the rich rows stay as the feature composite. This is the documented "feature-specific composites may stay bespoke" carve-out.
- **Header add button** (`PressableScale` + `Plus` icon / `ActivityIndicator`): kept bespoke. `MIconButton` has **no `disabled` and no `loading`/spinner** props — migrating would drop the `disabled={uploading}` guard and the in-button `ActivityIndicator`, both required behavior. Justified raw primitive per the rule.
- **CategoryTabs filter row**: kept bespoke. It is a **wrapping, multi-row** 6-chip filter (`wrap` prop) with per-chip `category-tab-<name>` testIDs that Maestro selects on. `MSegmented` is a single-row sliding-thumb control that does not wrap and would collapse the layout + break those testIDs. (Note: the lint regex never flagged it anyway — it uses `Animated.createAnimatedComponent(TouchableOpacity)`, not a literal `<TouchableOpacity`.)
- **Grid image tiles / skeleton / preparing overlay / "New" + common badges / ready snackbar overlay**: feature-specific composites, not generic primitives — out of scope by the task's own KEEP list. `PressableScale` retained on tiles (no clean M* fit).
- **AI-processing `<Modal>`** (`WardrobeScreen.tsx:626`): a full-screen processing view (photo + MacgieLoader + step list), not a generic dialog/sheet. Stays bespoke — this is the one remaining DS-lint flag on the file (justified).

## testID / accessibility preservation

All preserved and passed through to the M*: `wardrobe-add-btn`, `wardrobe-empty-add-btn`, `wardrobe-error-retry`, `wardrobe-add-search`, `wardrobe-add-photo`, `wardrobe-error-state`, `wardrobe-grid-root`, the per-item `wardrobe-item-*`, the snackbar overlay, etc. New sheet container testID added: `wardrobe-add-sheet`. No `accessibilityLabel` changed.

## DS-primitive lint — before / after (Wardrobe-related)

Measured via `grep -nE '<TextInput|<Switch|<Modal|<TouchableOpacity|PillButton|TopIconButton'`:

| File | Before | After |
|---|---|---|
| `src/screens/WardrobeScreen.tsx` | **2** (`<Modal>` ×2 @625, @685) | **1** (`<Modal>` @626 — AI-processing overlay, justified) |
| `src/components/features/CategoryTabs.tsx` | 0 | 0 |

Repo-wide `./scripts/auxi-lint-ds-primitives.sh` total was 167 at baseline; the Wardrobe add-item `<Modal>` flag is now gone (−1).

## Verification

- `npx tsc --noEmit` — **clean** (only the expected pre-existing `_HomeScreen.tsx` errors; zero WardrobeScreen errors).
- `npx eslint src/screens/WardrobeScreen.tsx src/components/features/CategoryTabs.tsx` — **exit 0, clean** (zero new problems on touched files). Repo-wide `yarn lint` (`eslint .`) still reports its pre-existing `web/` + `_HomeScreen` baseline noise — none of it from this change.
- `yarn web:build` (`vite build`) — **succeeds** (`✓ built in 781ms`). Web-safe.
- `git diff --name-only` vs the setup commit → only `src/screens/WardrobeScreen.tsx`. Branch vs `feat/au-364-ds-page-claude-sync` = exactly the 2 commits above. **In scope.**

Did NOT touch: `src/theme/theme.ts`, `src/theme/motion.ts`, the M* lib, any other screen, navigation, services, data/upload flow.

## Open questions

- `MBottomSheet` renders its scrim as `absoluteFillObject` into the nearest positioned parent (here `SafeAreaView` container, flex:1) rather than via a true RN `<Modal>` host. Functionally correct for this screen, but a designer/qa-ui sim pass on the sandbox should confirm the scrim covers the header + status bar area as the old full-screen Modal did. Visual verification not run in this session (JS-only change; no sim).
- Migrated parts now carry m-tokens (warmer radii/colours) and will visually differ from the theme.ts-styled neighbours — expected per per-screen migration; CEO reviews on sandbox.

**Status:** DONE
**Summary:** WardrobeScreen migrated to `M*` primitives — add-item sheet → `MBottomSheet`, empty CTA → `MButton` primary, error retry → `MButton` secondary; header button / CategoryTabs / tiles / AI-modal kept bespoke with justification. tsc + changed-file eslint + web build all green; Wardrobe DS-lint flags 2→1; scope confined to the screen + the lint-script setup commit.
