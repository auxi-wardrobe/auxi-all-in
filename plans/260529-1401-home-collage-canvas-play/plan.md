# Home Collage View (canvas-play) — Implementation Plan

> **For agentic workers:** Implement via `mobile-dev` (auxi/ only) following the project's
> `figma-to-rn-workflow`. Verify on iOS sim + Maestro (project uses Maestro, not unit TDD, for RN UI).
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Footer 2-icon toggle bật bề mặt "canvas-play": đẩy item thật của outfit hiện tại vào
một canvas kéo-thả (tái dùng drag-drop của OutfitCanvas, dạng component, không toolbar), seed
vị trí theo layout Figma collage.

**Architecture:** Tách drag-drop core của `OutfitCanvasScreen` → component `OutfitCanvasSurface`.
HomeScreen giữ state `homeView`; footer toggle đổi vùng giữa mỗi `OptionSheet` (grid `renderLayout()`
⟷ `<OutfitCanvasSurface>`) tại chỗ. Seed positions từ bảng Figma 3/4/5/6 + scale theo bề rộng surface.
OutfitCanvasScreen (Remix editor) refactor để dùng lại cùng surface (DRY).

**Tech Stack:** React Native 0.83, TS 5.8, PanResponder + Animated (đã có), react-native-svg,
theme tokens (`src/theme/theme.ts`), Maestro.

**Design spec:** `./design.md`
**Figma:** `0nXXMAR4Arf1ZfjtQvtBh0` section `2850:13589` (collage 3/4/5/6 items).

---

## Files (create / modify)

| File | Action | Responsibility |
|---|---|---|
| `auxi/src/components/features/OutfitCanvasSurface.tsx` | **Create** | Drag-drop surface tái dùng: grid bg + `DraggableItem` (PanResponder). Props-driven, no nav/toolbar. |
| `auxi/src/components/features/collage-seed-layout.ts` | **Create** | Bảng seed positions Figma 3/4/5/6 + scale + scatter fallback; map outfit `Item[]` → `CanvasSeedItem[]`. |
| `auxi/src/screens/OutfitCanvasScreen.tsx` | **Modify** | Dùng lại `OutfitCanvasSurface` (DRY); nhận item thật qua route params thay mock. |
| `auxi/src/screens/HomeScreen.tsx` | **Modify** | `homeView` state; truyền vào `OptionSheet`; swap grid↔collage; wire footer `onSelectView`. |
| `auxi/src/components/features/HomeViewToggleFooter.tsx` | **Modify** | Đổi label/testID tab alt → collage; controlled `activeView` + `onSelectView`. |
| `auxi/maestro/flows/home/collage-toggle.yaml` | **Create** (qa-ui) | Flow: toggle grid→collage, assert surface + items, drag 1 item. |

## Phases

- [x] **Phase 01** — Tách `OutfitCanvasSurface` component ✅
- [x] **Phase 02** — Seed layout module + map item thật ✅
- [x] **Phase 03** — Wire HomeScreen `homeView` + footer toggle + swap ✅
- [x] **Phase 04** — Refactor OutfitCanvasScreen dùng lại surface + real items ✅
- [x] **Phase 05** — Verify + QA ✅ (tsc/lint/token clean; Maestro `collage-toggle.yaml` PASS; sim compare vs Figma)

## Result (2026-05-29)
- Commits (branch `feat/home-collage-canvas-play`): `2c2205b8` feat + `<fix>` footer no-op.
- e2e `maestro/flows/home/collage-toggle.yaml` PASS all steps on iPhone 16 Pro sim.
- Bug found+fixed during QA: footer decorative absolute-fill layers swallowed taps → `pointerEvents="none"`.
- Color/layout match Figma (token `figmaCardSurface` #f2efec, seed arrangement matches 3-item frame).
- KNOWN CAVEAT: item images are product photos WITH backgrounds (not cutouts), so collage shows
  rectangular photo bleed vs Figma's transparent-PNG mockup. Background removal = backend/ML task, out of scope.
- NOT pushed: active gh account is `0xduc98`; project memory requires pushes as `ducga1998`. Awaiting account switch.

## Key dependencies / order
- P01 trước P02/P03 (cả hai dùng `OutfitCanvasSurface` + type `CanvasSeedItem`).
- P02 trước P03 (HomeScreen cần `seedFromOutfit`).
- P04 sau P01 (dùng lại surface đã tách).
- P05 cuối.

## Out of scope (YAGNI)
- Lưu canvas layout xuống backend; swap-item picker; toolbar trong collage-play; đổi grid logic.

## Risks
- HomeScreen lớn (~2000 LOC) — chỉ chèn tối thiểu tại điểm swap (`renderLayout()` trong OptionSheet) + footer.
- Item bleed ngoài mép (x âm) phải clip bằng `overflow:hidden` trên surface (Figma đúng vậy).
- Carousel 3 sheet: `homeView` global, mỗi sheet seed theo outfit của chính nó.
