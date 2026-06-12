# Phase 01 — Tách `OutfitCanvasSurface` component

**Priority:** P0 (mọi phase sau phụ thuộc). **Status:** pending.

## Context
- Drag-drop core hiện nằm inline trong `auxi/src/screens/OutfitCanvasScreen.tsx`:
  - type `CanvasItemData` (L43–51), `GridBackground` (L88–127), `DraggableItem` (L137–212).
- Mục tiêu: tách thành component **presentational thuần** dùng lại cho cả Remix editor lẫn collage-play.
  State (items/selection/history) do **parent sở hữu** — surface chỉ render + báo sự kiện. (DRY, KISS)

## Create: `auxi/src/components/features/OutfitCanvasSurface.tsx`

Di chuyển nguyên `CanvasItemData`, `GridBackground`, `DraggableItem` sang đây và export.
Thêm component `OutfitCanvasSurface` (controlled):

```ts
export type CanvasItemData = {
  id: string;
  imageSource: ImageSourcePropType; // chấp nhận require() lẫn { uri } → dùng được cho item thật
  x: number; y: number; zIndex: number; width: number; height: number;
};

type SurfaceProps = {
  items: CanvasItemData[];
  width: number;
  height: number;
  selectedId?: string | null;            // collage-play truyền null
  onSelect?: (id: string) => void;
  onPositionChange: (id: string, x: number, y: number) => void;
  showGrid?: boolean;                    // editor=true; collage-play=false (nền kem trơn như Figma)
  itemTestIDPrefix?: string;             // editor='canvas-item'; collage='home-collage-item'
  testID?: string;
};
```

- Render: `<View style={{width,height, overflow:'hidden', borderRadius: figmaTile, backgroundColor: figmaCardSurface}}>`
  + (showGrid && `<GridBackground/>`) + `items` sort theo zIndex → map `<DraggableItem/>`.
- `DraggableItem`: thêm prop `testIDPrefix` (default `'canvas-item'`), đổi `testID={`${prefix}-${item.id}`}`.
  Giữ nguyên logic PanResponder/Animated.

## Steps
- [ ] **S1** Tạo `OutfitCanvasSurface.tsx`, move `CanvasItemData`/`GridBackground`/`DraggableItem` vào, export `CanvasItemData` + `OutfitCanvasSurface`.
- [ ] **S2** Thêm `testIDPrefix` vào `DraggableItem` + `itemTestIDPrefix`/`showGrid`/`overflow:hidden` vào surface.
- [ ] **S3** `cd auxi && npx tsc --noEmit` → PASS (chưa ai dùng surface, chỉ compile module mới).
- [ ] **S4** Commit: `feat(home): extract OutfitCanvasSurface drag-drop component`.

## Success criteria
- File mới compile sạch, export đúng type/component. Chưa đụng behavior màn nào (OutfitCanvasScreen vẫn dùng bản inline cho tới P04).
- Không thêm lib mới.

## Notes
- `ImageSourcePropType` đã bao `{ uri: string }` → item thật map thẳng `imageSource: { uri }`.
- KHÔNG đưa toolbar/SafeAreaView/navigation vào surface.
