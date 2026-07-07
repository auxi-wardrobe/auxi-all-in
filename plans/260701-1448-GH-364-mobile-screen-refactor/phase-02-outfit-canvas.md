# Phase 02 — OutfitCanvasScreen.tsx (P0)

**File:** `auxi/src/screens/OutfitCanvasScreen.tsx` · **1555 → <200 shell** · Severity 5/5
**Status:** ⬜ todo

## Current problems
- 3 inline components: `ItemPickerPanel` (L176–376, own state+fetch+anim), `TagChip` (378–401), `ToolbarBtn` (403–430).
- Main component: 12 useState + 9 useRef + 28 useCallback + **0 useMemo** (canUndo/canRedo/actionDisabled recomputed every render).
- 6+ fused concerns: image prefetch/cache, collage-seed orchestration, undo/redo history, item transforms, persistence (creationsService + invalidation + analytics), nav exit-guard (beforeRemove + module `canvasExitGuard` + focus gating), discard-sheet state machine, tag editing, snackbar timing.
- Duplication: item-mutation `prev.map(...)` shape ×3, header icon-button style array ×4, "Adding…" pill ×2, two coupled add-timing effects.
- Two StyleSheets in-file (styles ~190 + pickerStyles ~104). `DiscardCreationDialog` already extracted → pattern proven.

## Extractions (new files → `screens/canvas/`)
1. `ItemPickerPanel.tsx` + its `pickerStyles` + picker constants (self-contained, prop-controlled). **~-330** — highest value, lowest risk.
2. `useCanvasHistory.ts` — history ref/index, pushHistory, undo/redo, transform handlers (pos/scale/rotation/layer/dup/delete). Kills 3× map dup + adds `useMemo(canUndo/canRedo)`. **~-200**
3. `useCanvasExitGuard.ts` — beforeRemove listener, focus guard, pendingAction/proceed refs, sheetIntent, resolveSheet + discard handlers. **~-150**
4. `useCanvasAddItems.ts` — module prefetch helpers, handlePickerConfirm, addingIds/addStatusVisible + two timing effects + handleItemImageLoad. **~-150**
5. `useCreationPersistence.ts` (persistCreation/handleSave + extractUri) + move `TagChip`/`ToolbarBtn` to `screens/canvas/`; split `styles`. **~-120**

## Steps
1. Extract `ItemPickerPanel` first (isolated, controlled via props) — biggest single win.
2. `useCanvasHistory` (also fixes the 3× duplication + memoizes derived flags).
3. `useCanvasExitGuard` (trickiest state machine — isolate + test discard/back/menu paths on sim).
4. `useCanvasAddItems` + `useCreationPersistence`.
5. Move TagChip/ToolbarBtn; split StyleSheet with each component.

## Success criteria
- Screen < 500 after 1–4, < 200 after 5; each new file < 200.
- Undo/redo, add-item, discard-guard, save, tag edit behave identically on sim.
- `OutfitCanvasSurface.tsx` (467) noted for a follow-up (extract `DraggableItem` L117–382; dedup scale-clamp; fix stale "Multiply by 4" comment) — optional, not in this phase.

## Risks
- Exit-guard touches module-global `canvasExitGuard` + navigation `beforeRemove` — verify no double-fire after extraction.
- Refs shared between add-flow and history — pass explicitly, don't re-create.
