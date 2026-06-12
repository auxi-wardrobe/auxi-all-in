# Design — Home Collage View (canvas-play)

> Status: APPROVED (verbal, CEO, 2026-05-29). Design-only doc. No code yet.
> Repo: `auxi/` (React Native). Figma: `0nXXMAR4Arf1ZfjtQvtBh0`, section `2850:13589` "Home | Collage View".

## Problem / Intent

Home đang có **grid view** (read-only, đã ship) + footer 2-icon toggle (grid ⟷ alt) trong đó
**tab alt là no-op** (TODO AU-253 — alternate view chưa định nghĩa).

Figma "Collage View" chính là định nghĩa cho tab alt đó. Bản chất của nó:
**đẩy các món của outfit hiện tại vào một bề mặt canvas, user kéo-thả để "chơi"/phối lại** —
tái dùng drag-drop của OutfitCanvas (AU-285) đã build, dưới **dạng component**, **không** toolbar editor.

## Scope

**In:**
- Tách drag-drop core của `OutfitCanvasScreen` → component dùng lại `OutfitCanvasSurface`
  (kéo-thả + layering, KHÔNG toolbar undo/layer/duplicate/delete).
- Feed **item thật** của outfit hiện tại (image url) vào surface (thay mock `test_jeans.png`).
- Seed vị trí ban đầu theo layout Figma cho 3/4/5/6 món; count khác → scatter fallback.
- Wire footer toggle: icon grid ⟷ icon collage **đổi vùng giữa Home tại chỗ** (in-place),
  giữ nguyên header + caption + action row + CTA + footer.

**Out (YAGNI — không làm trong phạm vi này):**
- Lưu canvas xuống backend (canvas hiện cũng chưa lưu — giữ nguyên).
- Swap-item picker.
- Toolbar editor trong collage-play (để dành cho Remix → full editor).
- Đổi grid view logic.

## Architecture

### Component split
`OutfitCanvasScreen.tsx` hiện gói cả screen chrome (SafeAreaView, back, toolbar, tag chips)
lẫn drag-drop core (`DraggableItem`, `CanvasItemData`, position/undo state).

→ Tách phần **drag-drop core** thành `src/components/features/OutfitCanvasSurface.tsx`:
- Props: `items: CanvasSeedItem[]`, `onLayoutChange?`, `testID`.
- Render: nền + các `DraggableItem` (PanResponder, `Animated.ValueXY`, absolute x/y/zIndex).
- **Không** chứa: SafeAreaView, navigation, toolbar, tag chips.

`OutfitCanvasScreen` (full editor, Remix) **dùng lại** `OutfitCanvasSurface` + bọc thêm
toolbar/undo/back → giảm trùng lặp, một nguồn drag-drop duy nhất (DRY).

### Seed item contract
```ts
type CanvasSeedItem = {
  id: string;
  imageUrl: string;   // item thật từ outfit hiện tại
  x: number;          // normalized theo Figma container 382w
  y: number;
  width: number;
  height: number;
  zIndex: number;
};
```
Vị trí Figma đo trong container **382w × 509.33h** (Image 3:4). Trên device, surface rộng
≈ screen − padding → seed scale theo tỉ lệ `surfaceWidth / 382`. Item bleed ngoài mép
(x âm / x+w > 382) → giữ nguyên, surface `overflow: hidden` clip như Figma.

### Seed positions (Figma, container 382×509.33)
| Count | Items (x, y, w, h) — theo thứ tự lớp dưới→trên |
|---|---|
| 3 | (17,−25,240,320) · (137,156,276,368) · (36,248,163,217) |
| 4 | (5,−19,230,306) · (157,−33,240,320) · (137,156,276,368) · (36,248,163,217) |
| 5 | (5,−19,230,306) · (157,−33,240,320) · (137,156,276,368) · (38,201,156,208) · (48,324,146,194) |
| 6 | (−71,1,300,399) · (79,−19,230,306) · (177,−6,220,293) · (137,156,276,368) · (79,236,123,164) · (31,330,146,194) |
| <3 hoặc >6 | scatter fallback (xếp lệch đều theo count), không có bảng Figma |

zIndex tăng dần theo thứ tự trong bảng (item sau đè item trước).
Mapping item→slot: theo thứ tự items trả về từ outfit (item[0] → slot đầu bảng).

### Data flow
1. Home có sẵn outfit hiện tại (V05 outfit, item image url) cho grid.
2. State `homeView: 'grid' | 'collage'` (đổi tên từ `'alt'`), default `'grid'`,
   chỉ sống trong HomeScreen (không persist — KISS).
3. Footer toggle `onSelectView('collage')` → set state → vùng giữa render
   `<OutfitCanvasSurface items={seedFromOutfit(currentOutfit, count)} />` thay grid.
4. Kéo-thả cập nhật local position trong surface. Đổi về grid rồi quay lại → reset seed.
5. Show another / Wear this / Remix giữ nguyên handler.

## Reuse vs New
| Phần | Trạng thái |
|---|---|
| `OutfitCanvasSurface` (drag-drop core) | **Tách mới** từ `OutfitCanvasScreen` |
| `OutfitCanvasScreen` full editor | **Refactor** để dùng lại surface (giữ behavior) |
| Header / caption / action row / CTA / footer toggle | **Reuse** (đã có ở Home grid) |
| `homeView` state + render switch | **New** (wire toggle, hiện là no-op) |
| Seed layout 3/4/5/6 + scale | **New** |
| Item thật vào canvas | **New wiring** (canvas đang mock) |

## Edge cases / error handling
- Outfit chưa load / 0 item → giữ grid, toggle collage no-op (hoặc empty state nhẹ).
- Count ngoài 3–6 → scatter fallback (không crash, không cần bảng Figma).
- Image url lỗi → placeholder nền (như GarmentPreview hiện có).
- Đổi outfit (Show another) khi đang ở collage → re-seed theo outfit mới.

## Testing
- `testID` mọi phần kéo-thả: `home-collage-item-<i>`, footer `home-footer-tab-collage`.
- Maestro flow (qa-ui author): toggle grid→collage, assert surface + items hiển thị, drag 1 item.
- `npx tsc --noEmit` + `yarn lint` (không tăng baseline lỗi).
- qa-ui Compare mode vs Figma (seed layout 3/4/5/6); qa-mobile smoke trên sim.

## Open questions (default đã chọn, anh veto nếu cần)
1. Đổi view có **animation** không? → Default: cross-fade nhẹ / hoặc đổi cứng. (chốt khi impl)
2. Kéo-thả trong collage có giữ khi Show another không? → Default: re-seed (không giữ).
3. "Wear this" ở collage có lưu layout đã phối không? → Default: KHÔNG (out of scope, như canvas).
