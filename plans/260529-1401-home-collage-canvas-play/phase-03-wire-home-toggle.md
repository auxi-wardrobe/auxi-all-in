# Phase 03 — Wire HomeScreen `homeView` + footer toggle + swap

**Priority:** P0. **Depends:** P01, P02. **Status:** pending.

## Context
- Footer hiện hardcode `activeView="grid"` tại `HomeScreen.tsx:1327-1330`, chưa wire state.
- Mỗi `OptionSheet` render grid qua `renderLayout()` trong `<View testID={`home-outfit-grid-${itemCount}`}>`
  tại `HomeScreen.tsx:1666`. Đây là **điểm swap** grid ⟷ collage.
- `OptionSheet` nhận props quanh L1455–1473; render quanh L1648–1668.
- `HomeViewToggleFooter` (`src/components/features/HomeViewToggleFooter.tsx`) đã có props
  `activeView?: HomeView`, `onSelectView?`; type `HomeView = 'grid' | 'alt'`.

## Create: `auxi/src/components/features/CollageSheetCanvas.tsx`
Wrapper **stateful nhẹ** bọc `OutfitCanvasSurface` cho collage-play (giữ HomeScreen mỏng):
```ts
type Props = { outfitItems: Item[]; surfaceWidth: number; surfaceHeight: number; testID?: string };
```
- `useState<CanvasItemData[]>(() => seedFromOutfit(outfitItems, surfaceWidth))`.
- `useEffect` re-seed khi `outfitItems` đổi (Show another).
- `onPositionChange` → cập nhật local state.
- Render `<OutfitCanvasSurface items=... selectedId={null} showGrid={false} itemTestIDPrefix="home-collage-item" onPositionChange=... width=surfaceWidth height=surfaceHeight testID="home-collage-surface"/>`.

## Modify: `HomeViewToggleFooter.tsx`
- [ ] Đổi type `HomeView = 'grid' | 'collage'` (đổi `'alt'`→`'collage'`).
- [ ] Tab 2: testID `home-footer-tab-collage(-active)`, a11yLabel "Collage view".
- [ ] Bỏ default no-op — đã có `onSelectView`; giữ controlled `activeView`.

## Modify: `HomeScreen.tsx`
- [ ] **S1** Import `CollageSheetCanvas`, `HomeView`.
- [ ] **S2** Thêm state: `const [homeView, setHomeView] = useState<HomeView>('grid');`.
- [ ] **S3** Footer (L1327): `activeView={homeView}` + `onSelectView={setHomeView}` (bỏ hardcode `"grid"`).
- [ ] **S4** Truyền `homeView` xuống `OptionSheet` (thêm vào props type + call site L1300–1314).
- [ ] **S5** Trong `OptionSheet` render (L1666), swap:
  ```tsx
  <View testID={`home-outfit-grid-${itemCount}`}>
    {homeView === 'collage'
      ? <CollageSheetCanvas outfitItems={items} surfaceWidth={SURFACE_W} surfaceHeight={SURFACE_H} testID={`home-collage-${sheetIndex}`} />
      : renderLayout()}
  </View>
  ```
  - `SURFACE_W` = bề rộng content (screen − 2×padding); tái dùng hằng đã có hoặc tính `Dimensions`. `SURFACE_H` = `SURFACE_W*4/3` (Figma Image 3:4) hoặc chiều cao grid hiện có.
- [ ] **S6** `cd auxi && npx tsc --noEmit && yarn lint` → không tăng baseline (4 lỗi `_HomeScreen.tsx` cho phép).
- [ ] **S7** Commit: `feat(home): wire collage view toggle (grid ⟷ canvas-play)`.

## Success criteria
- Bấm icon collage ở footer → vùng giữa mỗi sheet đổi sang surface kéo-thả seed theo outfit; bấm grid → về grid.
- Show another / Wear this / Remix vẫn chạy. Đổi sheet → collage seed theo outfit của sheet đó.

## Edge
- `items` rỗng → `seedFromOutfit` trả `[]`, surface trống; cân nhắc giữ grid khi count 0 (optional).
