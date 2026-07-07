# Phase 04 — BodyScreen.tsx (P1)

**File:** `auxi/src/screens/BodyScreen.tsx` · **1016 → <200 target** · Severity 5/5
**Status:** ⬜ todo

## Current problems
- **One component serves 3 routes** via runtime `mode` switch: `manage` / `tryOn` / `photoDetail`. The photoDetail branch (L410–545) is a whole alternate screen with its own retake Modal.
- 10 useState; image upload/camera + async try-on job submit & polling (`pollJob` L301–340) + 3 presentations + 2 modal state machines fused.
- **Photo-source Modal written twice near-identically** (retake 493–542 == upload 683–731). Grid placeholder dup (loading == empty). Both modals are raw `Modal`+`TouchableWithoutFeedback`+`TouchableOpacity` where `MActionSheet`/`MBottomSheet`/`MSheetOption` exist — and `see-this-on-me/components.tsx` already has a `PhotoSourceSheet` doing the same job.
- Lightbox is a raw `Modal`. Buttons use `PillButton`/`TopIconButton` (legacy) not `MButton`/`MIconButton`.

## Extractions (new files)
1. `screens/body/BodyPhotoDetailScreen.tsx` — lift the whole photoDetail branch (410–545) + `detail*` styles (949–1015) as a standalone route (not a mode). **~-200**
2. Replace BOTH photo-source Modals with the existing `PhotoSourceSheet` / `MActionSheet`; delete `modal*` styles (891–932). **~-90 + kills dup**
3. `components/BodyImageLightbox.tsx` — extract 733–756 + `largeImage*` styles. **~-40**
4. `screens/body/BodyTryOnView.tsx` + `BodyManageView.tsx` + `BodyPhotoGrid.tsx` (renderBodyGrid). **~-180**
5. Move module helpers (`formatPhotoTimestamp`/`MONTHS`/`getErrorStatus`/`resolveImageUrl`) to `utils`. **~-40**

## Steps
1. Split photoDetail out to its own screen/route first (largest, cleanest boundary) — update navigation to route instead of mode-switch.
2. Swap both modals for `PhotoSourceSheet`/`MActionSheet` (dedup + DS fix in one move).
3. Extract lightbox, then tryOn/manage views + grid.
4. Move helpers to utils.

## Success criteria
- Host screen < 200; photoDetail is its own screen; each new file < 200.
- Upload/camera, try-on generate + poll, delete, lightbox behave identically on sim. `track()` preserved.
- Zero raw photo-source Modals remain (consolidated in phase 08 cross-file check).

## Risks
- Routing change (mode→route) is the only non-pure step — verify back-nav + deep-links to photoDetail still land correctly.
- Try-on pipeline here is **synchronous** (differs from SeeThisOnMe background store) — do NOT unify in this phase, that's phase 08.
