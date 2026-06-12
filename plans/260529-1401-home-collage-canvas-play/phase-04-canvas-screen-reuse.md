# Phase 04 — Refactor OutfitCanvasScreen dùng lại surface + real items

**Priority:** P1 (DRY + đẩy item thật vào Remix editor). **Depends:** P01. **Status:** pending.

## Context
- `OutfitCanvasScreen.tsx` đang: dùng inline `DraggableItem`/`GridBackground`/`CanvasItemData`,
  state items=`INITIAL_MOCK_ITEMS` (mock `test_jeans.png`), **bỏ qua route params** dù route đã khai báo
  `OutfitCanvas: { outfitId?, items?: {id, imageUrl}[] }` (`types/navigation.ts:101-106`).
- `handleRemix` ở HomeScreen (`HomeScreen.tsx:1124`) navigate `OutfitCanvas` — hiện không truyền items.

## Steps
- [ ] **S1** Trong `OutfitCanvasScreen.tsx`: xoá inline `CanvasItemData`/`GridBackground`/`DraggableItem`,
  `import { OutfitCanvasSurface, CanvasItemData } from '../components/features/OutfitCanvasSurface';`.
- [ ] **S2** Thay khối render canvas card (L478–495) bằng:
  ```tsx
  <View style={[styles.canvas,{width:CANVAS_WIDTH,height:CANVAS_HEIGHT}]} pointerEvents="box-none">
    <OutfitCanvasSurface
      items={sortedItems} width={CANVAS_WIDTH} height={CANVAS_HEIGHT}
      selectedId={selectedId} onSelect={handleSelect} onPositionChange={handlePositionChange}
      showGrid itemTestIDPrefix="canvas-item" />
  </View>
  ```
  Giữ nguyên toolbar/undo/redo/tags/save state ở screen (parent vẫn sở hữu `items`/history).
- [ ] **S3** Đọc route params + map item thật:
  ```tsx
  const route = useRoute<RouteProp<AppStackParamList,'OutfitCanvas'>>();
  const seeded = route.params?.items?.map((it, i) => ({
    id: it.id, imageSource: { uri: it.imageUrl },
    x: 20 + i*24, y: 20 + i*28, zIndex: i+1, width: ITEM_DEFAULT_SIZE, height: ITEM_DEFAULT_SIZE,
  }));
  const [items, setItems] = useState<CanvasItemData[]>(seeded?.length ? seeded : INITIAL_MOCK_ITEMS);
  ```
  History khởi tạo theo `items` ban đầu (không cứng `INITIAL_MOCK_ITEMS`).
- [ ] **S4** HomeScreen `handleRemix`: truyền items thật của outfit hiện tại:
  `navigation.navigate('OutfitCanvas', { items: currentItems.map(it => ({ id: it.id, imageUrl: getImageUrl(it.image_url)||it.image_url })) })`.
  (Lấy `currentItems` từ outfit đang hiển thị — xác nhận biến outfit hiện tại trong scope `handleRemix`.)
- [ ] **S5** `cd auxi && npx tsc --noEmit && yarn lint` → PASS/không tăng baseline.
- [ ] **S6** Commit: `refactor(canvas): reuse OutfitCanvasSurface + accept real outfit items via params`.

## Success criteria
- Remix editor vẫn drag/select/layer/duplicate/delete/undo/redo như cũ (regression sạch).
- Mở Remix từ Home → hiện **item thật** của outfit, không còn mock jeans.
- Một nguồn drag-drop duy nhất (surface) cho cả 2 màn.

## Notes
- Save vẫn no-op (out of scope). Swap vẫn TODO (out of scope).
