# Phase 01 — HomeScreen/index.tsx (P0)

**File:** `auxi/src/screens/HomeScreen/index.tsx` · **1709 → ~280 target** · Severity 5/5
**Status:** ⬜ todo

## Current problems
- God-component: ~22 useState + ~33 useRef + ~22 useEffect + ~31 useCallback in one function; 400-line JSX return.
- Raw networking/data-transform in the screen: `buildViaV05` (API+transform), mutation `onSuccess` (~100 lines), pin-regenerate effect calling `recommendV05` with 30s abort + HTTP→state mapping (~100 lines), `handleHeartTapForOutfit` (favouriteService + cache invalidation).
- Duplication: "reset+regenerate" primitive ×3, `requestRecommendation({...})` shape ×5–6, toast timer pattern ×3, `recommendV05` weather-param object twice, 6 identical state-mirror effects, `pinBannerFloat` wrapper ×4.
- Pattern already exists: `HomeScreen/` has `styles.ts`, `outfit-normalize.ts`, `components/`, `hooks/` — just left this file behind.

## Extractions (new files)
Hooks → `HomeScreen/hooks/`, components → `HomeScreen/components/`:
1. `useOutfitFeed.ts` — `buildViaV05`, mutation + onSuccess/onError, `requestRecommendation`, `ensureBuffer`, ~12 feed refs, reset-regenerate primitive. **~-400**
2. `usePinnedOutfit.ts` — pin-regenerate effect, `pinnedItem`/`pinDialogItem` memos, wardrobe-existence effect, pin toggle/confirm/dont-show handlers, pin error/gone state. **~-280**
3. `useTemperatureFlow.ts` — temp sheet/apply/error/toast state + open/close/select/apply. **~-100**
4. `useHomeToasts.ts` — collapse 3 duplicated toast timers (mood/refine/temp). **~-90**
5. `components/HomeHeader.tsx`, `components/PinStatusBanners.tsx`, `components/WearThisFooter.tsx`, `components/HomeToastLayer.tsx`, `components/DeckCue.tsx` (renderCue). **~-200 JSX**

## Steps
1. Check `_HomeScreen.tsx` (legacy) for shared blocks (decision #5) — de-dupe or confirm deletion first.
2. Extract hooks bottom-up: `useHomeToasts` → `useTemperatureFlow` → `usePinnedOutfit` → `useOutfitFeed` (each a commit; app still runs between).
3. Extract presentational components; wire props from the hooks.
4. Collapse remaining duplication (reset-regenerate → one helper in useOutfitFeed; requestRecommendation param builder).
5. `index.tsx` becomes a composition shell (~280 lines: layout + hook wiring + deck).

## Success criteria
- `index.tsx` < 300; every new hook/component < 200.
- No behavior change: feed generation, pinning, temp override, refine gating, favouriting, toasts all identical on sim.
- All `track()` calls preserved. tsc clean, lints clean, archive builds.

## Risks
- Effect ordering / ref-mirroring is subtle — extract refs WITH their effects, keep the same dependency arrays. Test on sim after each hook.
- Buffer trampoline refs (`ensureBufferRef`, `showRefineToastRef`) cross hooks — expose via returned refs, don't duplicate.
