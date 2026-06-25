# Phase 04 — FE Skeleton + Generation Flow

## Context links

- Spec: [`spec.md`](./spec.md) §5 (state machine — `outfit` lifecycle), §7 (skeleton + header + error UX), §9 (timeout, abort, race)
- API client: `auxi/src/services/v05Api.ts` (`pinned_item_id` already threaded through types)
- Existing `MacgieLoader` inline pattern — reuse for "Generating" header (spec §7)
- Reducer created in phase 03: `auxi/src/hooks/usePinReducer.ts`

## Overview

- **Priority:** P2 (consumer of phase 03 reducer; producer for phase 05 ItemDetail effect)
- **Status:** pending
- **Brief:** Create `SkeletonTile`. Wire non-pinned outfit slots → skeleton when `outfit==='generating'`. Implement generation effect (snapshot already done in reducer → fire `/build` mutation with `pinned_item_id` → success/error dispatch). Header shows "Generating" status. Disable "Wear this" + Remix during generating. 30s AbortController timeout. Inline error message + Retry CTA. Inline fallback message for `low_confidence`.

## Key insights

- Skeleton replaces ALL non-pinned slots — pinned slot stays rendered with its tile (no skeleton).
- Generation is fired by `useEffect` watching `pinState.outfit === 'generating'`, not directly by the dispatcher (reducer must stay pure per phase 03).
- Snapshot already captured by reducer on `CONFIRM_PIN`; this phase only consumes it on error.
- AbortController + 30s timeout → `GENERATE_ERROR` via `dispatch`.
- Unmount path must abort in-flight request (spec §9 "orphaned request on exit").
- `low_confidence=True` from BE → `GENERATE_FALLBACK` (success path with inline message, not error).
- "Wear this" + Remix disabled = visual disabled state + onPress no-op while generating.

## Requirements

**Functional:**
- When `pinState.outfit === 'generating'`: render `SkeletonTile` in every grid slot EXCEPT pinned slot.
- Header shows "Generating" status text (i18n key from phase 06).
- "Wear this" + Remix CTAs disabled (visual + tap no-op) while generating.
- POST `/api/v05/recommendation/build` with `pinned_item_id` on `CONFIRM_PIN`/`CONFIRM_REPLACE`/`RETRY`.
- Success → `GENERATE_SUCCESS(outfit)` (or `GENERATE_FALLBACK(outfit)` if `low_confidence: true`).
- HTTP 410 → `PINNED_ITEM_GONE` event + inline "This item is no longer available."
- HTTP 401 → `AUTH_BLOCK` event.
- Other errors + network failure + 30s timeout → `GENERATE_ERROR`; show inline message + Retry.
- Unmount → abort in-flight request.

**Non-functional:**
- Skeleton shimmer matches tile dimensions (no layout shift on success swap).
- Single source of truth — request fires only via `outfit==='generating'` effect.
- AbortController cleanup on every path (success/error/unmount).

## Architecture

```
HomeScreen
  ├── useEffect on pinState.outfit:
  │     when transition → 'generating':
  │       abortRef.current = new AbortController();
  │       timeoutId = setTimeout(() => abortRef.current.abort('timeout'), 30000);
  │       buildOutfit({ pinned_item_id, signal: abortRef.current.signal })
  │         .then(r => r.low_confidence
  │           ? dispatch(GENERATE_FALLBACK)
  │           : dispatch(GENERATE_SUCCESS))
  │         .catch(err => {
  │           if (err.status === 410) dispatch(PINNED_ITEM_GONE);
  │           else if (err.status === 401) dispatch(AUTH_BLOCK);
  │           else dispatch(GENERATE_ERROR);
  │         })
  │         .finally(() => clearTimeout(timeoutId));
  │
  │     cleanup: abort + clearTimeout
  │
  ├── Outfit grid:
  │     for each slot:
  │       if slot.itemId === pinState.pinnedItemId → render real tile
  │       else if pinState.outfit === 'generating' → <SkeletonTile />
  │       else → real tile
  │
  ├── Header:
  │     pinState.outfit === 'generating' → "Generating"
  │
  └── Footer:
        outfit === 'error' → InlineError + Retry CTA
        outfit === 'fallback' → InlineFallback message
        outfit === 'auth_required' → reuse existing auth wall
```

## Related code files

**Create:**
- `auxi/src/components/features/SkeletonTile.tsx` — match tile dims, shimmer animation (use existing animation pattern referenced in spec §7)
- `auxi/src/components/features/InlineGenerationError.tsx` — error message + Retry button (small component; OK to inline if <50 lines)

**Modify:**
- `auxi/src/screens/HomeScreen.tsx`:
  - Add `abortRef = useRef<AbortController | null>(null)`
  - Add `useEffect` watching `pinState.outfit === 'generating'` → fire `/build` mutation
  - Replace non-pinned tiles with `<SkeletonTile />` while generating
  - Add "Generating" header status branch
  - Disable "Wear this" + Remix while generating
  - Render `InlineGenerationError` when `outfit === 'error'`
  - Render fallback inline message when `outfit === 'fallback'`
  - Add cleanup effect — abort on unmount
- `auxi/src/services/v05Api.ts` — confirm `buildOutfit` accepts `signal: AbortSignal` (axios supports via config); add if missing.

## Implementation steps

1. **`SkeletonTile.tsx`**:
   - Same width/height as `OutfitTile`. Use theme spacing (no hex literals — token-lint).
   - Shimmer: `Animated.loop` with opacity 0.3 → 0.7 → 0.3, 1500ms. Cleanup on unmount.
   - a11y: `accessible={true}`, `accessibilityLabel={t('pin.skeleton_loading')}`, `accessibilityRole="progressbar"`.
2. **Service signal threading** (`v05Api.ts`):
   - Update `buildOutfit(payload, options?: { signal?: AbortSignal })` to pass `signal` into axios config.
   - Error mapping: keep axios error shape; HomeScreen reads `err.response?.status`.
3. **HomeScreen generation effect**:
   ```ts
   useEffect(() => {
     if (pinState.outfit !== 'generating') return;
     const controller = new AbortController();
     abortRef.current = controller;
     const timeoutId = setTimeout(() => controller.abort('timeout'), 30000);
     buildOutfit({ pinned_item_id: pinState.pinnedItemId, /* existing payload */ }, { signal: controller.signal })
       .then(res => {
         if (res.low_confidence) dispatch({ type: 'GENERATE_FALLBACK', outfit: res.outfit });
         else dispatch({ type: 'GENERATE_SUCCESS', outfit: res.outfit });
       })
       .catch(err => {
         const status = err?.response?.status;
         if (status === 410) dispatch({ type: 'PINNED_ITEM_GONE' });
         else if (status === 401) dispatch({ type: 'AUTH_BLOCK' });
         else dispatch({ type: 'GENERATE_ERROR' });
       })
       .finally(() => clearTimeout(timeoutId));
     return () => {
       controller.abort('unmount');
       clearTimeout(timeoutId);
     };
   }, [pinState.outfit]);
   ```
4. **Slot rendering** — in outfit grid map, branch:
   ```tsx
   pinState.outfit === 'generating' && slot.itemId !== pinState.pinnedItemId
     ? <SkeletonTile key={slot.slotIndex} />
     : <OutfitTile ... />
   ```
5. **Header "Generating" status** — extend existing header status switch with a `generating` branch reading i18n `pin.generating_status` (key added phase 06).
6. **Disable CTAs** — "Wear this" + Remix buttons add `disabled={pinState.outfit === 'generating'}`; pressHandler early-returns when disabled.
7. **Error UI** — `InlineGenerationError` shows i18n `pin.error_message` (or `pin.network_error` if axios `ERR_NETWORK`) + Retry button → `dispatch({ type: 'RETRY' })`.
8. **Fallback UI** — below grid, render `Text` with i18n `pin.fallback_message`. No CTA.
9. **PINNED_ITEM_GONE UI** — inline `Text` with `pin.item_unavailable` shown briefly (auto-clear via timer or persists until next pin tap).
10. **Run gates:** `npx tsc --noEmit && yarn lint && ./scripts/auxi-lint-tokens.sh`.

## Todo

- [ ] Create `SkeletonTile.tsx` matching tile dims + shimmer
- [ ] Create `InlineGenerationError.tsx` with Retry CTA
- [ ] Thread `signal` through `buildOutfit` in `v05Api.ts`
- [ ] Add generation `useEffect` in HomeScreen watching `outfit === 'generating'`
- [ ] AbortController + 30s timeout + cleanup on unmount
- [ ] Replace non-pinned slots with `SkeletonTile` while generating
- [ ] Header "Generating" status branch
- [ ] Disable "Wear this" + Remix while generating
- [ ] Render error / fallback / pinned-gone inline messages
- [ ] tsc + lint + token-lint clean

## Success criteria

- Tap pin tile → confirm CTA → grid replaces non-pinned slots with shimmer skeletons within 1 frame.
- Header reads "Generating" during request.
- Success response: skeletons swap to real tiles, no layout shift.
- `low_confidence: true` response: skeletons swap + inline fallback message renders.
- Forced timeout (mock 31s delay): GENERATE_ERROR fires, inline error + Retry visible.
- Retry tap re-fires request, shows skeletons again.
- Backgrounding/navigating away mid-request: no orphaned axios call (verified via network log).

## Risk assessment

| Risk (from spec §9) | Mitigation |
|---|---|
| Loading infinite | 30s AbortController timeout |
| Orphaned request on exit | Cleanup aborts on unmount |
| Cached outfit overwritten on failure | Reducer restores snapshot on `GENERATE_ERROR` (phase 03) |
| Duplicate generation | Reducer guard + effect dep on `outfit` (only fires on transition into 'generating') |
| Layout shift skeleton↔tile | `SkeletonTile` dims match `OutfitTile` exactly |
| Race remix vs unpin | Reducer `pendingUnpin` queue (phase 03); applied on `GENERATE_SUCCESS` |

## Security considerations

- 401 routed to existing auth wall via `AUTH_BLOCK` — no token leak.
- AbortController prevents post-logout late-response leaking outfit data into stale screen.

## Next steps

- Ships in **PR-FE-core** with phases 03, 05, 06.
- Phase 05 ItemDetail entry effect dispatches `CONFIRM_PIN` → triggers this generation flow.
- Phase 06 supplies i18n keys: `pin.generating_status`, `pin.error_message`, `pin.network_error`, `pin.fallback_message`, `pin.item_unavailable`, `pin.skeleton_loading`.
- Phase 07 Maestro flow asserts skeleton appears + error retry path works.
