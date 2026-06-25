# mobile-dev — AU-360 Canvas: arranging an item layer (bring to front / send to back)

Date: 2026-06-17
Bug: AU-360 "[bug] Canvas: arranging an item layer" — reporter Viet (CEO/designer): "I can not bring/send an item to front or back."

## Root cause

The live AU-350 Remix editor (`OutfitCanvasScreen.tsx` → `OutfitCanvasSurface.tsx`)
already had two toolbar buttons (`canvas-tool-layer-up` / `canvas-tool-layer-down`)
wired to `handleLayerUp` / `handleLayerDown`. Selection (tap-to-select) and the
disabled-when-nothing-selected gating worked. The defect was in the **z-index
math**, not missing controls:

- `handleLayerUp` did `zIndex = min(z + 1, maxZ + 1)`; `handleLayerDown` did
  `zIndex = max(z - 1, 1)`.
- Nudging a single item's z-index by ±1 **creates ties**. Example: items seeded
  `[A=1, B=2, C=3]`; select A, "layer up" → A becomes `2`, so A and B both = 2.
- `OutfitCanvasSurface` renders via `[...items].sort((a,b) => a.zIndex - b.zIndex)`
  (`OutfitCanvasSurface.tsx:412`). `Array.prototype.sort` is **stable** (Hermes/V8),
  so two items with equal z keep their original relative order → A stays under B.
  Result: the item visibly does **not** move. The button "did nothing" — exactly
  the CEO's complaint.

So the controls existed but the reorder was a no-op whenever the step landed on a
neighbour's z-value (the common case for contiguous seeds).

## Fix

Replaced the ±1 nudge with a **swap-with-adjacent-neighbour** in stacking order
(`OutfitCanvasScreen.tsx:411-455`):

- Sort items ascending by z (bottom→top), find the selected item's index.
- `forward` swaps z with the next item up; `backward` swaps with the previous item.
- Edge guard: at the front/back boundary there is no neighbour → return early
  (no state change, no analytics event).
- Swapping keeps z-indices a clean permutation (never ties), so the move is always
  visible and deterministic. Both directions covered ("to front or back" stepwise).

Consolidated the two handlers into one `moveLayer(direction)` (DRY); `handleLayerUp`
/ `handleLayerDown` are thin wrappers, preserving the existing toolbar wiring,
testIDs (`canvas-tool-layer-up` / `canvas-tool-layer-down`) and a11y labels
(`a11y_bring_forward` / `a11y_send_backward`). State update + `pushHistory` moved
out of the `setItems` updater so undo/redo captures the reorder and analytics fires
once (not double under StrictMode).

No new controls or icons needed — Figma toolbar already has the two layer buttons,
and the i18n labels already existed in en/vi-VN/fr-FR. **No new i18n keys required.**

## Files changed

- `auxi/src/screens/OutfitCanvasScreen.tsx`
  - `:30` add `import { track } from '../services/analytics';`
  - `:411-455` new `moveLayer('forward'|'backward')` swap logic; `handleLayerUp` /
    `handleLayerDown` now delegate to it (replaced the broken ±1 clamp handlers).
  - `:448` `track('canvas_item_layer_reordered', { direction })`.
- `auxi/docs/analytics/mixpanel-tracking-plan.md`
  - New §5.11 (Outfit Canvas — shipped `canvas_item_layer_reordered`, file:line).
  - New §6.6 (gap: other canvas toolbar/save actions un-instrumented until persist
    endpoint lands).

No edits to `OutfitCanvasSurface.tsx` (its sort is correct once z-indices are
distinct). `CollageSheetCanvas.tsx` (Home play view) is out of scope — it has no
layer toolbar and the bug is the Remix editor.

## Analytics

- Event: `canvas_item_layer_reordered` (past-tense, snake_case, literal string const).
- Property: `direction` ∈ `forward` | `backward` (lowercase string, no PII).
- Single integration seam: `src/services/analytics.ts` `track()`.
- Checked §5 taxonomy for collisions — none (no prior canvas/collage/remix/layer
  event). Fires only on an actual move (edge cases return before `track`).

## Verification (Node 20)

- `npx tsc --noEmit` → clean, no errors.
- `yarn lint` → 8 problems (1 error, 7 warnings). Baseline with my change stashed
  was 9 problems (2 errors, 7 warnings) — my consolidation **removed one error**
  and added zero findings. The remaining 1 error is in `HomeScreen.tsx`
  (pre-existing, owned by another agent). OutfitCanvasScreen's residual warnings
  (lines 179/194/551 inline styles) and font/hex token-lint hits (picker panel,
  lines 924/968/988) are all pre-existing and untouched by this change.
- `../scripts/auxi-lint-tokens.sh` → pre-existing repo-wide violations only; my edit
  added no hex/font literals (logic-only + one import).
- Simulator: **not run in this session** — no `yarn ios:sim` executed here. Work is
  code-complete; visual verification of the reorder pending. Recommend qa-mobile
  exploratory smoke (select item → layer-up/down → assert visible re-stack via the
  `canvas-item-<id>` testIDs) and a Maestro flow off the existing toolbar testIDs.

## Follow-ups

1. Visual sim verify of the reorder (qa-mobile / qa-ui) — not done here.
2. `canvas-tool-swap` is still a TODO stub (`OutfitCanvasScreen.tsx:~640`); unrelated
   to AU-360 but flagged.
3. Canvas Save is a TODO `goBack()` (no persistence). When the persist endpoint
   lands, wire `canvas_outfit_saved` + per-action events per tracking-plan §6.6.
4. Pre-existing pattern: `handleScaleChange` / `handlePositionChange` etc. call
   `pushHistory` inside the `setItems` updater (side-effect during reconcile). Not
   AU-360, but worth a cleanup pass if the canvas is revisited.

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Layer reorder was a no-op because ±1 z-index nudges created ties that a stable sort never re-ordered; replaced with a swap-with-adjacent-neighbour so bring-forward / send-backward visibly re-stack the selected item. Added `canvas_item_layer_reordered` analytics + tracking-plan doc. tsc clean; lint net −1 error.
**Files changed:** auxi/src/screens/OutfitCanvasScreen.tsx; auxi/docs/analytics/mixpanel-tracking-plan.md
**Concerns/Blockers:** Simulator not run this session — reorder is code-complete but visually unverified; needs qa-mobile/qa-ui sim smoke. Save persistence still absent (out of AU-360 scope, logged §6.6).
