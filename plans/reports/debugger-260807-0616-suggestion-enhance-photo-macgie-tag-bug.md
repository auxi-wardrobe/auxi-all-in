# Bug: suggestion không dùng ảnh đã enhance + hiện sai tag "Macgie"

Repo bug thực sự nằm ở: `auxi-wardrobe/auxi-backend` (private) + `auxi-wardrobe/auxi-mobile` (public).
Cả hai KHÔNG nằm trong `auxi-all-in` (umbrella repo này chỉ chứa submodule rỗng — chưa init).
Report này lưu ở `auxi-all-in` vì đây là repo duy nhất session có quyền push; code fix đề xuất bên dưới
CHƯA được áp dụng (chỉ có quyền đọc `auxi-backend`/`auxi-mobile` trong session này).

## Bug report gốc (user, tiếng Việt)

> Đồ do user upload đã qua enhance image
> - Trong tủ đồ ko có tag Macgie → đúng
> - Trong suggestion lại có tag Macgie → không đúng
> Ngoài ra: đôi giày cũng của user upload, đã chọn xử lý Enhance image
> - Trong tủ đồ: đã enhance, không tag Macgie → đúng
> - Trong suggestion: chưa enhance (ảnh cũ) + có tag Macgie → không đúng

## Root cause #1 — CONFIRMED: ảnh enhance bị rớt khỏi response (`image_studio` thiếu trong schema)

`blueprints/recommendation/engine_v05.py::_serialize_outfit` (commit `cb4a98c`, PR #168,
AU-437, merged 2026-08-02) đã thêm `"image_studio": it.image_studio` vào dict item trả về
cho **mọi** outfit suggestion (`/api/v05/recommendation/build` và `/try_another` — serializer
dùng chung).

NHƯNG commit đó chỉ sửa `blueprints/recommendation/engine_v05.py` +
`API_DOCUMENTATION.md` — **không sửa** `schemas/v05_recommendation.py::ItemDTO` (Pydantic
response model gắn vào FastAPI qua `response_model=...`). `ItemDTO` hiện chỉ khai báo
`image_url`, `image_png` — không có `image_studio`. FastAPI/Pydantic mặc định **âm thầm
loại bỏ** mọi key trong dict không được khai báo trên response model trước khi serialize
JSON trả về client.

→ Backend build đúng `image_studio`, nhưng field này bị Pydantic strip ngay trước khi ra
khỏi server. Mobile không bao giờ nhận được nó trong response suggestion.

**Verify trực tiếp trên production** (không cần code, đọc live OpenAPI schema):

```bash
curl -s https://wardrobe-backend-production-c8d9.up.railway.app/openapi.json \
  | jq '.components.schemas.ItemDTO.properties | keys'
# → ["category_family","color_code","formality_level","human_readable_id","id",
#    "image_png","image_url","is_common_item","is_exploration_item","is_new",
#    "name","source","style_tags","usage_frequency","user_id"]
# KHÔNG có "image_studio"
```

Mobile side (`src/utils/url.ts::resolveItemImage`) ưu tiên `image_studio → image_png →
image_url`. Vì suggestion response thiếu hẳn `image_studio`, nó fallback về ảnh gốc chưa
enhance — đúng y hệt triệu chứng #2 user báo cáo (đôi giày "chưa enhance" trong suggestion).

**Fix (1 dòng, additive, an toàn):** `schemas/v05_recommendation.py`, trong class `ItemDTO`,
thêm ngay dưới `image_png`:

```python
image_studio: Optional[str] = None
```

Không cần sửa gì phía mobile — `src/services/v05Api.ts::V05OutfitItem.image_studio` và
`src/screens/HomeScreen/outfit-normalize.ts::mapV05Item` đã forward field này sẵn (dự phòng
từ trước, chỉ chờ backend thực sự gửi).

## Root cause #2 — GIẢ THUYẾT (chưa confirm được ở mức value), tag "Macgie" sai

Mobile xác định badge "Macgie" qua `src/utils/tile-status.ts::isCommonItem`:

```ts
export const isCommonItem = (item) =>
  item.is_common_item === true ||
  item.user_id === null ||
  item.user_id === undefined ||
  isPerUserCatalogClone(item); // human_readable_id?.startsWith('USR_')
```

Hàm này DÙNG CHUNG cho cả wardrobe grid lẫn Home suggestion (AU-392, commit `e40cdb9`,
PR #167, merged 2026-07-30 — đã confirm CÓ trên production qua cùng lệnh `curl openapi.json`
ở trên: `is_common_item`, `user_id`, `is_new`, `usage_frequency` đều có mặt trong `ItemDTO`).
`outfit-normalize.ts::mapV05Item` cũng forward đủ 2 field `user_id`/`is_common_item` không
đổi tên, không drop.

Vì cùng 1 hàm + cùng field-set + mobile forward đúng, tag hiển thị sai ở suggestion nhưng
đúng ở wardrobe cho thấy **giá trị** `user_id`/`is_common_item` mà `_serialize_outfit` build
ra cho item này trong outfit response khác với giá trị mà `to_dict()` trả cho item đó ở
`GET /api/wardrobe/items` — dù cùng 1 row DB. Chưa lấy được request/response thật (cần
tài khoản user + log) để xác nhận field nào rỗng. Nghi vấn hàng đầu, theo thứ tự khả năng:

1. Item vào outfit qua nhánh khác `_load_user_pool` bình thường — ví dụ nhánh pinned-item
   / climate-starved common-safety-injection (`_load_common_safety_items`) — nơi object
   ORM có thể không mang đủ `user_id` (hoặc bị gán `_is_common_injected` transient sai) →
   Pydantic dùng default `user_id=None` → `isCommonItem` = true.
2. `human_readable_id` được AI (Gemini/OpenAI) tự sinh lúc tag ảnh mới upload
   (`services/ai_service.py::_build_prompt`, placeholder mơ hồ
   `"NAMESPACES_LAYERS_ITEMCODE_COLOR_FIT_INDEX"` — model không được chỉ rõ NAMESPACE là
   gì) — nếu model tự đoán ra tiền tố `USR_` giống hệt quy ước dùng riêng cho
   catalog-clone (`services/wardrobe_service.py::clone_common_item`, namespace cứng
   `"USR"`), `isPerUserCatalogClone` sẽ nhận nhầm. Nhưng field này wardrobe cũng nhận y
   hệt (`to_dict()` chung), nên nếu đúng vậy thì wardrobe cũng phải sai — mâu thuẫn với
   report. Khả năng thấp hơn giả thuyết 1, giữ lại vì đáng loại trừ.

**Cách xác nhận nhanh:** thêm log tạm ở `_serialize_outfit` in ra
`it.id, it.user_id, it.is_common_item, it.human_readable_id` mỗi item, gọi
`/api/v05/recommendation/build` bằng đúng account/item bị báo lỗi, so với response
`GET /api/wardrobe/items` cùng item.

## Việc cần làm

- [ ] `auxi-backend`: thêm `image_studio: Optional[str] = None` vào `ItemDTO`
      (`schemas/v05_recommendation.py`) — fix xác nhận, rủi ro thấp, deploy được ngay.
- [ ] `auxi-backend`: điều tra giá trị thực tế `user_id`/`is_common_item` mà
      `_serialize_outfit` trả cho item lỗi (cần log/case thật) để xác nhận root cause #2.
- [ ] Regenerate `tests/snapshots/v05_item_dto_schema.json` /
      `v05_outfit_dto_schema.json` sau khi sửa schema (đã có snapshot test theo AU-392, PR
      #167 — thêm field mới cũng cần update snapshot).

## Unresolved questions

- Root cause #2 cần 1 request/response thật (hoặc log) mới chốt được — chưa có quyền
  truy cập DB/log production trong session này.
- Chưa biết đây có phải deploy-lag hay không (production ĐÃ có AU-392 nhưng CHƯA đúng
  cho AU-437 vì bug schema #1, không phải vì thiếu deploy — commit `d16ff93` là HEAD của
  `main`, prod xác nhận đã chạy tới ít nhất `e40cdb9`).
