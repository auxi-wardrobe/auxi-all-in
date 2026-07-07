# Phase 06 — WardrobeScreen.tsx (P2)

**File:** `auxi/src/screens/WardrobeScreen.tsx` · **1044 → ~350 target** · Severity 5/5
**Status:** ⬜ todo

## Current problems
- 10 useState + 3 useRef; `renderGridTile` = 94-line render fn; `handleImageSelection` = 77-line upload handler.
- Concern soup: fetch/polling (`fetchItems` + poll effect + `wardrobeService`), image-picker + upload orchestration, preparing→ready reconciliation + dedup refs + timers, 10+ `track()`, toast/snackbar, plus grid/tiles/2 sheets/processing Modal/snackbar overlay.
- Duplication: 3 near-identical status-pill badges (new / less_use / common, L484–524) — differ only by style/label → one `TileStatusBadge`.
- Mostly DS-compliant already (uses `MBottomSheet`/`MActionSheet`/`MButton`, migration comments present). Gaps: status pills raw `View`+`Text` → `MChip`; AI-processing overlay raw `Modal` (L709) → `MBottomSheet`/overlay (decision #3); `AddMethodRow` raw (acknowledged acceptable — two-line layout, no M* row fits).

## Extractions (new files)
1. `components/WardrobeGridTile.tsx` + fold 3 badges into `TileStatusBadge.tsx` (status-driven). **~-120**
2. `hooks/useAddWardrobeItem.ts` (handleImageSelection + handleTakePhoto + uploading state + processing Modal) + `components/PreparingOverlay.tsx`. **~-110**
3. `hooks/useItemReadySnackbar.ts` — reconcileReadyItems + showReadySnackbar + 2 refs + timer + overlay. **~-80**
4. `wardrobeGrid.ts` — pure helpers/constants L50–142 (FILTER_TABS, tile math, resolveFilterQuery, isCommonItem, resolveTileStatus). **~-60**
5. `components/AddItemSheet.tsx` (`MBottomSheet` + 2 `AddMethodRow`). **~-50**

## Steps
1. Move pure helpers → `wardrobeGrid.ts`.
2. Extract `WardrobeGridTile` + `TileStatusBadge` (collapse 3 pills; consider `MChip`).
3. Extract upload flow hook + `PreparingOverlay` (decision #3: migrate raw processing `Modal`?).
4. Extract ready-snackbar hook; extract add-item sheet.

## Success criteria
- Screen ~350; each new file < 200; no 90+-line render fn or 77-line handler in the screen.
- Grid render, upload+preparing→ready flow, polling, snackbar behave identically on sim. All `track()` preserved.

## Risks
- Preparing→ready reconciliation uses dedup refs + timers — extract ref+timer+effect together; verify no double-snackbar.
- Poll effect + focus effect interplay — keep same deps.
