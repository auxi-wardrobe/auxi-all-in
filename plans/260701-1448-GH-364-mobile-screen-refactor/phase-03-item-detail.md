# Phase 03 — ItemDetailScreen.tsx (P1)

**File:** `auxi/src/screens/ItemDetailScreen.tsx` · **1407 → ~250 target** · Severity 5/5
**Status:** ⬜ todo

## Current problems
- 10 useState; fetch effect (w/ fallback) + 3 separate mutations (updateUsageFrequency, deleteWardrobeItem, updateWardrobeItemAttributes) with optimistic update + rollback + toast + analytics — all inline.
- 13 module-level label↔API/tag codec helpers (L79–238) = domain logic in the screen.
- Raw `<Modal>` picker (L1062–1131) hand-rolled where `MBottomSheet`/`MSheetOption` exist; 6 raw `TouchableOpacity`, **0 `M*`**. Also uses `FigmaPrimitives` (BottomSheetSurface/PillButton/TopIconButton) → straddles 2 non-canonical systems.
- Duplication: 3 parallel `switch(field)` (getPickerOptions / getPickerFieldLabel / handleSelectOption) over same 4 fields → collapse to a field-config map; secondary-action row ×3; `toast error` block ×5; category/formality normalize↔toApi mirror pairs.

## Extractions (new files)
1. `components/OptionPickerSheet.tsx` on `MBottomSheet`/`MSheetOption` — removes raw Modal + 3 Touchable + ~120 lines. **~-120** + fixes DS violation.
2. `utils/wardrobeItemMappers.ts` — move the 13 codec/tag helpers (check test imports first, decision #4). **~-160**
3. `hooks/useItemDetail.ts` — fetch effect + 3 mutation handlers + drafts + optimistic/rollback. **~-250**
4. `components/ItemDetailActions.tsx` on `MButton`/`MIconButton` — dedups 3 Touchable action rows. **~-70**
5. `components/ItemDetailEditPanel.tsx` + `ItemDetailRow.tsx` (on `MListRow`) — split edit/read branches + renderDetailRow. **~-90**
6. Collapse the 3 field-switches into one `FIELD_CONFIG` map (in the picker or mappers).

## Steps
1. Grep for external imports of the exported helpers; relocate to `wardrobeItemMappers.ts` + update imports (decision #4).
2. Build `useItemDetail` hook (data + mutations); screen consumes it.
3. Extract `OptionPickerSheet` on `M*`; delete raw Modal + its styles.
4. Extract action buttons + edit/read panels; introduce `FIELD_CONFIG` map.

## Success criteria
- Screen ~250; each new file < 200; raw `Modal` gone; picker + actions on `M*`.
- Edit/save/delete/less-used toggle behave identically (optimistic + rollback intact). All `track()` preserved.
- `auxi-lint-ds-primitives.sh` shows fewer violations for this file.

## Risks
- Optimistic-update rollback ordering — keep exact sequence when moving into the hook.
- Decision #1 (Figma* vs M*): if keeping Figma*, target those instead — but rule says migrate to M*.
