# Phase 02 — Seed layout module + map item thật

**Priority:** P0. **Depends:** P01 (`CanvasItemData`). **Status:** pending.

## Context
Figma collage đo trong container **382w × 509.33h** (section `2850:13589`). Các món bleed ngoài
mép (x âm / x+w>382) → clip bởi `overflow:hidden`. Cần module thuần (no JSX) sinh seed positions
+ scale theo bề rộng surface thật trên device.

## Create: `auxi/src/components/features/collage-seed-layout.ts`

```ts
import type { Item } from '../../types/...'; // dùng đúng path Item như HomeScreen
import { getImageUrl } from '...';            // helper HomeScreen dùng: getImageUrl(item.image_url)
import type { CanvasItemData } from './OutfitCanvasSurface';

const FIGMA_REF_WIDTH = 382;

// (x, y, w, h) theo thứ tự lớp dưới→trên (zIndex tăng dần). Nguồn: Figma metadata 2850:13589.
const SEED_TABLE: Record<number, Array<[number, number, number, number]>> = {
  3: [[17,-25,240,320],[137,156,276,368],[36,248,163,217]],
  4: [[5,-19,230,306],[157,-33,240,320],[137,156,276,368],[36,248,163,217]],
  5: [[5,-19,230,306],[157,-33,240,320],[137,156,276,368],[38,201,156,208],[48,324,146,194]],
  6: [[-71,1,300,399],[79,-19,230,306],[177,-6,220,293],[137,156,276,368],[79,236,123,164],[31,330,146,194]],
};
```

- `seedFromOutfit(items: Item[], surfaceWidth: number): CanvasItemData[]`:
  - `filled = items.filter(Boolean)`; `count = filled.length`; `scale = surfaceWidth / FIGMA_REF_WIDTH`.
  - Nếu `SEED_TABLE[count]` tồn tại → zip filled[i] với slot[i]: `{ id: item.id, imageSource:{uri:getImageUrl(item.image_url)||item.image_url}, x:px*scale, y:py*scale, width:pw*scale, height:ph*scale, zIndex:i+1 }`.
  - Else (count<3 hoặc >6) → `scatterFallback(filled, surfaceWidth, scale)`: xếp lệch đều (vd mỗi món lệch `(i*28, i*36)`, width≈`200*scale`, aspect 3:4), zIndex i+1. Không crash.
  - Nếu thừa/thiếu slot (count khớp table thì bằng nhau): map theo `Math.min(len, slots)`; dư item → scatter nối tiếp.

## Steps
- [ ] **S1** Tạo `collage-seed-layout.ts` với `SEED_TABLE` + `seedFromOutfit` + `scatterFallback`.
- [ ] **S2** Xác nhận import `Item` type và `getImageUrl` đúng path (grep trong HomeScreen.tsx: `getImageUrl`, `image_url`, `import { Item }`).
- [ ] **S3** `cd auxi && npx tsc --noEmit` → PASS.
- [ ] **S4** Commit: `feat(home): add collage seed-layout (figma 3/4/5/6 + scatter fallback)`.

## Success criteria
- `seedFromOutfit` trả mảng `CanvasItemData` đúng số lượng = số item filled, scale theo width.
- Không hardcode hex; không lib mới.

## Edge
- count 0 → trả `[]` (caller giữ grid / no-op).
- image_url rỗng → `{uri:''}` (DraggableItem/Image hiển thị nền trống — chấp nhận, như tile lỗi hiện tại).
