# Phase 05 — FE ItemDetail Wiring + Edge Cases

## Context links

- Spec: [`spec.md`](./spec.md) §3 (locked decision: navigate Home + auto-pin), §5 (`AUTH_BLOCK`, `PINNED_ITEM_GONE`), §9 (stale ref, guest, IDOR FE side)
- Existing "Coming soon" alert: `auxi/src/screens/ItemDetailScreen.tsx:907`
- HomeScreen reducer (phase 03): `auxi/src/hooks/usePinReducer.ts`
- Wardrobe query source: `auxi/src/services/wardrobeApi.ts` (existing items hook)
- Navigation types: `auxi/src/navigation/types.ts`

## Overview

- **Priority:** P2 (final ItemDetail flow + edge-case wiring; depends on phases 03+04)
- **Status:** pending
- **Brief:** Replace ItemDetail "Build around this" alert with navigation to Home carrying `pinFromDetail` param. Home mount effect: if param present → dispatch `CONFIRM_PIN` (skip modal). Hide pin icon on `source="common_essential"` tiles. Wardrobe sync watcher: if pinned id no longer in items → `PINNED_ITEM_GONE`. Guest 401 → `AUTH_BLOCK`.

## Key insights

- Spec §3: ItemDetail entry SKIPS the confirm modal — user already showed intent on the detail screen. Direct `CONFIRM_PIN`.
- `pinFromDetail` param consumed once on mount, then cleared (avoid re-trigger on re-render).
- Common-essential items belong to SYSTEM, not user. Pin icon hidden — defense-in-depth; BE also rejects (phase 01 422).
- Wardrobe sync (delete, refresh) can orphan a `pinnedItemId`. Watcher dispatches `PINNED_ITEM_GONE`.
- 401 path is in phase 04's generation `catch`; this phase ensures `AUTH_BLOCK` opens the existing auth wall modal.

## Requirements

**Functional:**
- ItemDetail "Build around this" CTA → `navigation.navigate('Home', { pinFromDetail: itemId })`. No alert.
- Home mount: read `route.params?.pinFromDetail`; if set → `dispatch({ type: 'CONFIRM_PIN_FROM_DETAIL', itemId })` (new action type), then clear param via `navigation.setParams({ pinFromDetail: undefined })`.
- Pin icon overlay hidden on outfit tiles where `item.source === 'common_essential'`.
- Wardrobe items query result includes (or no longer includes) `pinnedItemId`: if missing → dispatch `PINNED_ITEM_GONE`.
- 401 from generation → `AUTH_BLOCK` → opens existing AuthWall modal.

**Non-functional:**
- `pinFromDetail` consumed exactly once per navigation entry.
- Wardrobe sync check runs on query data change, not on every render.
- No double-modal flicker (modal stays `closed` for ItemDetail path).

## Architecture

```
ItemDetailScreen
  └── "Build around this" CTA
        ↓ navigation.navigate('Home', { pinFromDetail: item.id })

HomeScreen
  ├── useEffect(on mount + route.params change):
  │     if (route.params?.pinFromDetail) {
  │       dispatch({ type: 'CONFIRM_PIN_FROM_DETAIL', itemId: route.params.pinFromDetail });
  │       navigation.setParams({ pinFromDetail: undefined });
  │     }
  │
  ├── useEffect(on wardrobeItems change):
  │     if (pinState.pinnedItemId && !items.find(i => i.id === pinState.pinnedItemId)) {
  │       dispatch({ type: 'PINNED_ITEM_GONE' });
  │     }
  │
  └── OutfitTile rendering:
        showPinIcon = item.source !== 'common_essential'

AUTH_BLOCK transition
  └── HomeScreen effect on pinState.outfit === 'auth_required'
        ↓ open <AuthWallModal /> (existing component)
```

## Related code files

**Modify:**
- `auxi/src/screens/ItemDetailScreen.tsx:907` — replace `Alert.alert('Coming soon', ...)` with `navigation.navigate('Home', { pinFromDetail: item.id })`
- `auxi/src/screens/HomeScreen.tsx`:
  - Add ItemDetail-entry mount effect
  - Add wardrobe sync watcher effect
  - Add AUTH_BLOCK effect → open AuthWall
  - `OutfitTile` invocation: pass `showPinIcon={item.source !== 'common_essential'}`
- `auxi/src/components/features/OutfitTile.tsx` (or wherever pin badge renders) — gate badge on `showPinIcon` prop
- `auxi/src/hooks/usePinReducer.ts` — add `CONFIRM_PIN_FROM_DETAIL` action (variant of `CONFIRM_PIN` that bypasses modal precondition; snapshot + transition same)
- `auxi/src/navigation/types.ts` — add `pinFromDetail?: string` to `HomeStackParamList.Home` (or equivalent)

**Do not touch:**
- AuthWall modal component — reuse existing.

## Implementation steps

1. **Reducer addition** in `usePinReducer.ts`:
   ```ts
   | { type: 'CONFIRM_PIN_FROM_DETAIL'; itemId: string }
   ```
   Reducer handler:
   ```ts
   case 'CONFIRM_PIN_FROM_DETAIL':
     // skips modal; mirror CONFIRM_PIN body
     return {
       ...state,
       pinnedItemId: action.itemId,
       pendingPinnedItemId: null,
       pinReplaceCandidate: null,
       modal: 'closed',
       outfit: 'generating',
       lastOutfitSnapshot: state.lastOutfitSnapshot ?? null,
       // snapshot may be null if Home not yet hydrated — that's OK; error path will fall back to empty
     };
   ```
2. **Nav types** — add `pinFromDetail?: string` to Home param list.
3. **ItemDetail CTA** — at `ItemDetailScreen.tsx:907`, replace alert:
   ```ts
   navigation.navigate('Home', { pinFromDetail: item.id });
   ```
   Remove "Coming soon" copy + i18n key if unused elsewhere.
4. **HomeScreen mount effect**:
   ```ts
   useEffect(() => {
     const pinFromDetail = route.params?.pinFromDetail;
     if (!pinFromDetail) return;
     dispatch({ type: 'CONFIRM_PIN_FROM_DETAIL', itemId: pinFromDetail });
     navigation.setParams({ pinFromDetail: undefined });
   }, [route.params?.pinFromDetail]);
   ```
5. **Wardrobe sync watcher**:
   ```ts
   useEffect(() => {
     if (!pinState.pinnedItemId) return;
     const stillExists = wardrobeItems.some(i => i.id === pinState.pinnedItemId);
     if (!stillExists) dispatch({ type: 'PINNED_ITEM_GONE' });
   }, [wardrobeItems, pinState.pinnedItemId]);
   ```
6. **AUTH_BLOCK handler**:
   ```ts
   useEffect(() => {
     if (pinState.outfit === 'auth_required') {
       openAuthWall(); // existing helper / setState
     }
   }, [pinState.outfit]);
   ```
7. **Pin icon visibility** — in outfit tile render map, pass `showPinIcon={item.source !== 'common_essential'}`. In tile/badge component, `if (!showPinIcon) return null` before rendering pin badge.
8. **Edge — Home cold start from ItemDetail**:
   - User has no current Home session (just opened app, went to ItemDetail).
   - `CONFIRM_PIN_FROM_DETAIL` transitions outfit to `generating`.
   - Phase 04 effect fires `/build` with `pinned_item_id` only. BE returns full outfit.
   - On render, no skeleton-vs-existing-tile conflict because grid was empty.
9. **Edge — snapshot null on error from ItemDetail path** — reducer `GENERATE_ERROR` handler tolerates null snapshot (no restore, just show error UI).
10. **Run gates:** `npx tsc --noEmit && yarn lint && yarn jest src/hooks/__tests__/usePinReducer.test.ts` — add new tests for `CONFIRM_PIN_FROM_DETAIL`, `PINNED_ITEM_GONE` triggered by sync watcher.

## Todo

- [ ] Add `CONFIRM_PIN_FROM_DETAIL` action type + reducer case
- [ ] Add `pinFromDetail?: string` to Home nav params
- [ ] Replace ItemDetail line 907 alert with `navigation.navigate('Home', { pinFromDetail })`
- [ ] Add HomeScreen mount effect consuming `pinFromDetail` then clearing
- [ ] Add wardrobe sync watcher → `PINNED_ITEM_GONE`
- [ ] Add AUTH_BLOCK effect → open AuthWall
- [ ] Gate pin icon on `item.source !== 'common_essential'`
- [ ] Reducer tests for new action + sync watcher
- [ ] tsc + lint clean

## Success criteria

- ItemDetail "Build around this" navigates Home, no alert.
- On Home arrival, outfit grid enters generating state immediately (no modal).
- After clearing param, re-entering Home does NOT re-trigger pin.
- Deleting pinned item from wardrobe → `PINNED_ITEM_GONE` fires → grid clears pin state + shows inline unavailable message (UI from phase 04).
- Pin icon does NOT render on common-essential tiles (verified by inspection).
- Guest user attempting generation → 401 → `AUTH_BLOCK` → AuthWall opens.

## Risk assessment

| Risk (from spec §9) | Mitigation |
|---|---|
| Stale pinned ref after wardrobe sync | `useEffect` watcher dispatches `PINNED_ITEM_GONE` |
| User pins SYSTEM common-essential (FE side) | Pin icon hidden via `showPinIcon` prop |
| ItemDetail re-trigger on re-render | `navigation.setParams({ pinFromDetail: undefined })` after dispatch |
| Snapshot null on cold-start ItemDetail entry | Reducer tolerates null snapshot in error path |
| Race: ItemDetail entry + existing pin | `CONFIRM_PIN_FROM_DETAIL` overwrites — UAC accepts this (intent expressed on detail screen) |
| Guest pin attempt | 401 → `AUTH_BLOCK` → existing AuthWall |

## Security considerations

- 401 routes to existing AuthWall — no bypass.
- FE pin-icon gating is UX; BE 422 is the authoritative defense (phase 01).
- Nav param `pinFromDetail` is opaque id string; no payload smuggling vector.

## Next steps

- Ships in **PR-FE-core** with phases 03, 04, 06.
- Phase 06 supplies i18n key `pin.item_unavailable` (sync-watcher inline message).
- Phase 07 Maestro flow covers ItemDetail → Home auto-pin path.
