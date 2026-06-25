# Phase 03 — FE Reducer + PinConfirmModal

## Context links

- Spec: [`spec.md`](./spec.md) §5 (state machine), §7 (UX details), §4.1 (file table)
- Existing `pinnedItemId` useState: `auxi/src/screens/HomeScreen.tsx:437`
- Existing pin tile fill: `HomeScreen.tsx:2503` (`figmaAction` charcoal)
- Modal overlay pattern reference: `auxi/src/components/features/ContextChipsModal.tsx`
- Existing `spliceAndBalancePinnedItem` fallback: HomeScreen (keep as fallback path; reducer drives primary path)

## Overview

- **Priority:** P2 (blocks phases 04, 05 — they dispatch into this reducer)
- **Status:** pending
- **Brief:** Create canonical state machine (`usePinReducer`), pin confirm/replace modal, and snapshot helper. Refactor HomeScreen's `pinnedItemId` useState into the reducer. Wire `PIN_TAP` / `CANCEL_MODAL` / `CONFIRM_PIN` / `CONFIRM_REPLACE` events. Generation firing wired in phase 04.

## Key insights

- Spec §5 state machine is **the** contract. No ad-hoc state added in HomeScreen on top.
- Reducer is the single dispatcher — every pin-related event goes through it.
- Modal has 2 variants (`confirm` | `replace`) — same component, prop switches copy + CTA behavior.
- Snapshot is taken on `CONFIRM_PIN` / `CONFIRM_REPLACE`, restored on `GENERATE_ERROR`. Deep clone for safety; spec §13 flags perf check.
- Existing `pinnedItemId` scaffolding (icon, badge, `onTogglePin`) wired through the reducer — don't delete, repoint.

## Requirements

**Functional:**
- Reducer state shape exactly per spec §5.
- `PIN_TAP(itemId)` dispatches:
  - `null` pinned → modal=`confirm`, `pendingPinnedItemId=itemId`
  - same itemId pinned → fires `UNPIN` (queued if generating)
  - different pinned → modal=`replace`, `pinReplaceCandidate=itemId`
- `CANCEL_MODAL` closes modal + clears pending refs.
- `CONFIRM_PIN` / `CONFIRM_REPLACE` snapshot outfit, set `pinnedItemId`, transition `outfit='generating'` (firing wired phase 04).
- Modal CTAs debounced — primary disabled on first tap until state transitions.
- Reducer guard: `PIN_TAP` no-op when `outfit==='generating'`.

**Non-functional:**
- Reducer pure (no side effects); generation firing handled by HomeScreen effect watching `outfit==='generating'`.
- TypeScript strict — discriminated union on action types.
- Snapshot deep clone perf ≤ 1ms for typical outfit (spec §13).

## Architecture

```
HomeScreen
  ├── useReducer(pinReducer, initialPinState)
  │     ↓ state, dispatch
  ├── OutfitTile onPress → dispatch({ type: 'PIN_TAP', itemId })
  ├── PinConfirmModal
  │     ├── variant={state.modal}        // 'confirm' | 'replace'
  │     ├── onConfirm → dispatch({ type: 'CONFIRM_PIN' | 'CONFIRM_REPLACE' })
  │     └── onCancel  → dispatch({ type: 'CANCEL_MODAL' })
  └── useEffect (phase 04) — when outfit==='generating', fire /build mutation
```

## Related code files

**Create:**
- `auxi/src/hooks/usePinReducer.ts` — reducer + types + initial state + selector helpers
- `auxi/src/components/features/PinConfirmModal.tsx` — modal component (variants `confirm` + `replace`)
- `auxi/src/utils/snapshotOutfit.ts` — `snapshotOutfit(o: Outfit): Outfit` deep clone

**Modify:**
- `auxi/src/screens/HomeScreen.tsx` — remove `useState<string|null>(null)` for `pinnedItemId` at line 437; replace with `useReducer(pinReducer, initialPinState)`; repoint `onTogglePin` → `dispatch({ type: 'PIN_TAP', itemId })`; render `<PinConfirmModal>` when `state.modal !== 'closed'`.

**Do not touch:**
- Existing pin icon/badge overlay rendering — keeps reading `state.pinnedItemId` from reducer.
- `spliceAndBalancePinnedItem` — stays as a local fallback path; not removed in this phase.

## Implementation steps

1. **`usePinReducer.ts`** — define types:
   ```ts
   export type PinState = {
     pinnedItemId: string | null;
     pendingPinnedItemId: string | null;
     pinReplaceCandidate: string | null;
     modal: 'closed' | 'confirm' | 'replace';
     outfit: 'idle' | 'generating' | 'fallback' | 'error' | 'auth_required';
     lastOutfitSnapshot: Outfit | null;
     pendingUnpin: boolean;
   };

   export type PinAction =
     | { type: 'PIN_TAP'; itemId: string }
     | { type: 'CONFIRM_PIN' }
     | { type: 'CONFIRM_REPLACE' }
     | { type: 'CANCEL_MODAL' }
     | { type: 'UNPIN' }
     | { type: 'GENERATE_SUCCESS'; outfit: Outfit }
     | { type: 'GENERATE_FALLBACK'; outfit: Outfit }
     | { type: 'GENERATE_ERROR' }
     | { type: 'RETRY' }
     | { type: 'PINNED_ITEM_GONE' }
     | { type: 'AUTH_BLOCK' }
     | { type: 'SNAPSHOT'; outfit: Outfit };
   ```
2. Implement `pinReducer(state, action): PinState` per spec §5 transitions verbatim. Pure function — no effects.
3. Guards:
   - `PIN_TAP` while `outfit==='generating'` → return state unchanged (no double-fire).
   - `UNPIN` while `outfit==='generating'` → set `pendingUnpin=true`.
   - `GENERATE_SUCCESS` while `pendingUnpin` → apply unpin (clear `pinnedItemId`, `pendingUnpin=false`).
4. **`snapshotOutfit.ts`** — `export const snapshotOutfit = (o: Outfit): Outfit => structuredClone(o);` (RN 0.83 + Hermes supports `structuredClone`; fallback `JSON.parse(JSON.stringify(o))` if not). Add perf comment per spec §13.
5. **`PinConfirmModal.tsx`** — props:
   ```ts
   type Props = {
     variant: 'confirm' | 'replace';
     onConfirm: () => void;
     onCancel: () => void;
     pinnedItemImageUri?: string; // for thumbnail in modal
   };
   ```
   - Layout per spec §7 (overlay `rgba(0,0,0,0.5)`, title, subtitle, filled pin svg `IconHomePin`, primary + secondary CTAs).
   - i18n keys (added in phase 06): `pin.modal_title`, `pin.modal_subtitle`, `pin.build_cta`, `pin.cancel_cta`, `pin.replace_title`.
   - For `variant='replace'`, title swaps to `pin.replace_title`; subtitle + CTAs same copy.
   - Primary CTA disabled flag on tap to prevent double-fire.
6. **HomeScreen refactor**:
   - Replace `const [pinnedItemId, setPinnedItemId] = useState<string|null>(null);` at line 437 with `const [pinState, dispatch] = useReducer(pinReducer, initialPinState);`.
   - All reads of `pinnedItemId` → `pinState.pinnedItemId`.
   - `onTogglePin` (existing) → `(itemId) => dispatch({ type: 'PIN_TAP', itemId })`.
   - Render `<PinConfirmModal variant={pinState.modal === 'replace' ? 'replace' : 'confirm'} onConfirm={...} onCancel={() => dispatch({ type: 'CANCEL_MODAL' })} />` when `pinState.modal !== 'closed'`.
   - Hook up `pinnedItemImageUri` from current outfit's matched item.
7. **Unit tests** for reducer — `auxi/src/hooks/__tests__/usePinReducer.test.ts`:
   - `PIN_TAP null → confirm modal`
   - `PIN_TAP same → UNPIN`
   - `PIN_TAP different → replace modal`
   - `CONFIRM_PIN sets pinnedItemId + outfit='generating' + snapshot`
   - `CANCEL_MODAL clears pending`
   - `UNPIN while generating queues pendingUnpin`
   - `GENERATE_SUCCESS clears snapshot + applies pendingUnpin`
   - `GENERATE_ERROR restores snapshot`
8. **Run gates:** `cd auxi && npx tsc --noEmit && yarn lint && yarn jest src/hooks/__tests__/usePinReducer.test.ts`.

## Todo

- [ ] Create `src/hooks/usePinReducer.ts` with types + pure reducer
- [ ] Create `src/utils/snapshotOutfit.ts`
- [ ] Create `src/components/features/PinConfirmModal.tsx` (confirm + replace variants)
- [ ] Refactor HomeScreen useState → useReducer at line 437
- [ ] Repoint `onTogglePin` to `dispatch(PIN_TAP)`
- [ ] Render `PinConfirmModal` from reducer state
- [ ] Add reducer unit tests covering 8+ scenarios
- [ ] `tsc` + `yarn lint` + `jest` green

## Success criteria

- HomeScreen has zero local `useState` for pin-related state; reducer owns all of it.
- Modal opens on `PIN_TAP null`; replace variant opens on `PIN_TAP different`.
- Tap pinned item dispatches `UNPIN`.
- Reducer unit tests cover all transitions in spec §5.
- TypeScript strict, no `any` on action types.

## Risk assessment

| Risk (from spec §9) | Mitigation |
|---|---|
| Duplicate generation from rapid taps | Reducer guard: `PIN_TAP` while generating is no-op; modal CTA disable-on-first-tap |
| Cached outfit overwritten on failure | `lastOutfitSnapshot` saved on `CONFIRM_PIN`; restored on `GENERATE_ERROR` (phase 04) |
| Race remix vs unpin | `pendingUnpin` queue on `UNPIN` while generating |
| Stale snapshot ref / memory leak | Snapshot cleared on `GENERATE_SUCCESS` |
| Snapshot deep-clone perf | `structuredClone` preferred; spec §13 perf check |

## Security considerations

- No new auth surface (pure FE state).
- Modal renders item thumbnail from existing outfit data — no extra fetch, no extra PII surface.

## Next steps

- Ships in **PR-FE-core** (phases 03-06 together).
- Branch: `duc2820/au-307-uac-pin-item-build-around-outfit` (existing Linear branch).
- Phase 04 plugs generation firing into reducer's `outfit==='generating'` transition.
- Phase 05 dispatches `CONFIRM_PIN` directly from ItemDetail entry effect.
- Phase 06 supplies the i18n keys this modal reads.
