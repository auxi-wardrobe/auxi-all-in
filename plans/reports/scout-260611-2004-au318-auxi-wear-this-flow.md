# Scout: auxi "Wear this" flow (AU-318)

## Wear this CTA
- `auxi/src/screens/HomeScreen.tsx:2077-2087` — PillButton inside OptionSheet, label toggles "Wear this" ↔ "Saved to favourite", testID `home-this-works-<cellKey>`
- onConfirm → `handleHeartTapForOutfit(outfit)` (line 1795) → saves favorite IMMEDIATELY (lines 966-984)
- Flow: `saveStateByHash[hash]='saving'` → `favouriteService.saveFavourite()` → `'saved'` + track('outfit_favorited') | error → `'error'` + retry text

## Save service
- `auxi/src/services/favouriteService.ts` — `saveFavourite(payload)` → `POST /favourites`
- Payload: `{ outfit_hash, item_ids[], source:'home' }`; resp `{ id, outfit_hash, created_at }`
- NOT TanStack mutation — imperative .then/.catch. Save state: `saveStateByHash: Record<string,'idle'|'saving'|'saved'|'error'>` (line 395) + ref mirror (451)

## Bottom sheet / modal infra
- No @gorhom/bottom-sheet. Custom `<Modal transparent>` + Animated translateY
- `src/components/features/ItemDetailBottomSheet.tsx` — slide-up 300ms, backdrop dismiss
- `src/components/features/ContextChipsModal.tsx:102-145` — NEAREST PATTERN: modal + selectable chips + submit. Chip style: inactive `theme.colors.figmaCardTag`, selected `figmaChipBg` (#5b5550), 40px height, testID `context-chip-<id>`, disabled during isSubmitting

## Analytics
- `src/services/analytics.ts` — Mixpanel, consent-gated, `track(name, props)` fire-and-forget
- Example: `track('outfit_favorited', {outfit_hash, item_count, source})` HomeScreen:975
- Existing: refine_modal_opened (1072), refine_submitted (1272); several `home.*` console.info TODOs

## Recommendation state (HomeScreen)
- All component-local state+refs (389-549): listOutfits, setIndex/outfitIndex (AU-303), selectedMode, styleFeedback
- `recordBrowse` (1101-1148) swipe tracking; opens context modal on 3rd unfavorited swipe
- Prefetch: `ensureBuffer()` (881-931), TARGET_AHEAD=3, fetchGenerationRef stale guard, poolDepletedRef
- Recommendation mutation: useMutation buildViaV05 (661-783)

## i18n
- `src/translations/{en-EN,vi-VN,fr-FR}.json` under `boilerplate` namespace; runtime i18next NOT wired yet (static imports)

## Conventions (auxi/CLAUDE.md)
- Primitives-first: reuse PillButton/FigmaPrimitives; theme tokens only, no hex (lint-tokens gate)
- Every interactive element needs testID `<feature>-<element>-<purpose>` (Maestro depends on it)
- No global state — component state + TanStack for server state
- Services wrap apiClient, never axios in screens
- Verify: `npx tsc --noEmit && yarn lint` (baseline: 4 errors legacy _HomeScreen.tsx)

## Insertion point
Modal = sibling of OptionSheet in HomeScreen (no nav change). Re-route "Wear this" onPress → open mood sheet → on Done chain existing save mutation with mood payload.
