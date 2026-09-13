# See on me — garment fit fidelity (Tầng 1–4)

**Date:** 2026-09-13
**Repo:** `auxi-wardrobe/auxi-backend` · branch `claude/inspiring-johnson-hriucq` · commit `7f09391`
**Scope:** Tầng 1–4 của phân tích. Một PR backend. Không migration, không đổi API contract, không đụng mobile.

## Triệu chứng

Quần ống rộng → render thành quần vừa. Áo rộng → vừa. Áo bó → **cũng** vừa.

Mọi silhouette bị kéo về cùng một điểm. Đây là hồi quy về trung bình, không phải lỗi ngẫu nhiên — loại trừ "ảnh món đồ xấu" (lỗi ngẫu nhiên tán loạn cả hai hướng). Nguyên nhân: prior của image model thắng reference image trên chiều hình học. Texture/màu là đặc trưng cục bộ, copy được; silhouette là hình học toàn cục, phải tái dựng dưới body+pose mới → model lấy từ prior, mà mode của prior là regular fit.

## Nguyên nhân gốc (đã xác minh trên code)

### 1. Prompt không hề nhận dữ liệu fit

`openai_service._build_prompt(garment_types, params, has_fullbody)` — `garment_types` chỉ là `item.category` (`"top"`/`"bottom"`). Thứ duy nhất liên quan hình dáng lọt vào prompt là `prompt_params.body_shape` = dáng **người**, không phải dáng **đồ**.

Trong khi đó fit đã có sẵn trong DB: `WardrobeItem.physical_attributes` (JSON) chứa `normalized_fit` (v05 tagger) hoặc `fit_code` (user upload). Engine V05 đọc nó để *chọn* outfit (`engine_v05_layers.py:130`), rồi try-on vứt đi. **Bài toán đấu nối, không phải thiếu dữ liệu.**

### 2. Xung đột chỉ thị trên đúng một token 🔴 gốc rễ thứ hai

- `GARMENT FIDELITY` liệt kê `silhouette` lọt thỏm giữa ~20 thuộc tính khác (colors, materials, logos, stitching…).
- `_build_body_line` dùng **cùng chữ "silhouette"** cho dáng **người**: *"overall height/silhouette (shoulders, torso, waist, hips, limb length, perceived height)"*.

Nghĩa body cụ thể hơn hẳn (liệt kê vai/thân/eo/hông) nên thắng. Prompt đang **chủ động** bảo model bám theo đường viền cơ thể — phá trực tiếp áo rộng/quần rộng. `PRIORITY ORDER` xếp garment > body proportions, nhưng độ cụ thể thắng thứ tự.

Trầm trọng thêm: `_BODY_TYPE_GARMENT_BEHAVIOR["slim"]` = *"cleaner drape, less fabric tension, sharper silhouette"* → ép ôm.

### 3. ❌ Giả thuyết pipeline ảnh bị stretch — SAI

Đã kiểm: `flatten_transparent_image` giữ nguyên `rgba_image.size`; `_pil_to_file` không resize. Ảnh món đồ tới OpenAI đúng tỉ lệ gốc. **Không cần sửa gì ở Tầng 4.**

## Đã làm

**Mới** — `blueprints/tryon/garment_fit.py` (299 dòng, phần lớn là bảng prompt-text)
- `resolve_item_fit(item)` — `normalized_fit` → từ khoá fit trong `name/subcategory/description` → `fit_code`.
- `build_silhouette_section()` / `build_compact_fit_clause()` — directive theo từng món.

Mỗi directive ghép 3 kỹ thuật: **spec đo được** ("hem ≈ hip width") + **phủ định chế độ lỗi** ("must NOT taper") + **cue thị giác** ("visible air between fabric and leg"). Tính từ đơn thuần quá yếu để thắng prior; phủ định đứng một mình thì không đáng tin — phải đi cặp.

**Sửa** — `openai_service.py`
- `garment_fits` optional thêm vào `generate_tryon_from_paths` / `generate_tryon_sync` / `_build_prompt` / `build_text_garment_prompt` → additive, path multipart ở `routers/tryon.py` và mọi test cũ không đổi.
- `height/silhouette` → `height/build` (gỡ va chạm token).
- `silhouette` tách khỏi danh sách 20 mục thành chỉ thị riêng + *"never normalise toward a standard or regular fit"*.
- Block `CRITICAL GARMENT SILHOUETTE` đặt **cuối**, ngay trước câu đóng.

**Sửa** — `tryon_render_service.py`: `resolve_garment_fits(items)` cho cả hai path (OpenAI multi-image + text provider flux/kling).

### Thứ tự ưu tiên: tên món đồ thắng `fit_code` (có chủ ý)

`fit_code` chỉ có 4 giá trị `SLM|REG|OVS|TLR` — **không có WIDE, không có STRAIGHT**. Một cái quần ống rộng user upload chỉ có thể bị gán `REG`. Nên tên món đồ ("Wide-leg linen trousers", "Quần ống rộng") là nơi duy nhất silhouette thật sống sót → cho nó thắng. `normalized_fit` (enum mịn) vẫn thắng cả hai.

Token lệch nhóm được **coerce**, không drop (`REG` trên bottom → `STRAIGHT`), nếu không thì phần lớn quần user upload không có directive nào.

## Prompt sinh ra (thật)

```
CRITICAL GARMENT SILHOUETTE (highest priority — read this last and apply it
over any competing instruction above):
- The top is oversized. The shoulder seam sits 5-8 cm BEYOND the natural
  shoulder point, dropping onto the upper arm; the body is roughly 25% wider
  than the torso and the fabric falls straight from chest to hem. It must NOT
  be fitted at the shoulder or waist and must NOT trace the body outline.
- The bottom is wide-leg. The legs hang straight and full from the hip in one
  continuous column; the hem is roughly as wide as the hip, with visible air
  between the fabric and the leg. It must NOT taper toward the ankle and must
  NOT follow the contour of thigh or calf.
These silhouettes are non-negotiable. Where a garment is loose, wide or
oversized, the GARMENT's silhouette takes precedence over the body outline —
the body is concealed by the fabric, not traced by it. Do NOT normalise any
garment toward a standard or regular fit.
```

Prompt đầy đủ 10057 chars (trước ~8800). Path compact vẫn trong ngân sách 2700.

## Kiểm chứng

- 24 test mới — `tests/test_garment_fit.py`, pass hết.
- Full suite: **21 failed / 1862 passed** vs baseline (stash code) **21 failed / 1838 passed**. Đúng 21 failure có sẵn, **không regression**.
- `python test_server.py` **chưa chạy**: cần DB live + key provider thật trên :5002, không có trong session này.
- `API_DOCUMENTATION.md` không cập nhật — đúng rule, không đụng `routers/*/routes.py` và không đổi payload/response.

## Chưa giải quyết

1. **`fit_code` thiếu WIDE/STRAIGHT** — gốc rễ còn lại. Hiện phải cứu bằng tên món đồ; quần ống rộng đặt tên chung chung ("Quần đen") vẫn hỏng. Sửa đúng = mở rộng enum trong prompt extraction ở `services/ai_service.py` (JSON column, **vẫn không cần migration**) + backfill. Không làm trong PR này vì `fit_code` chảy vào `_generate_human_readable_id` và scoring V05 → blast radius ngoài try-on, cần quyết định riêng.
2. **Độ phủ `normalized_fit` trên item user upload** — chưa đo. Nếu gần 0 thì gần như mọi item user chỉ dựa vào tên/`fit_code`.
3. **Chưa có eval set** (Tầng 8 trong phân tích, CEO chưa yêu cầu). Không có nó thì không đo được cải thiện thật — mọi tinh chỉnh prompt tiếp theo là mê tín. Skill `v05-eval` đã có sẵn khuôn multimodal scoring để tái dùng.
4. `garment_fit.py` 299 dòng > guideline 200. Phần vượt là bảng prompt-text (config-like, rule miễn trừ). Tách ra sẽ tạo 2 file luôn đổi cùng nhau.
5. `.gitmodules` ở umbrella còn trỏ `ducga1998/wardrobe-backend` (đã migrate sang `auxi-wardrobe/auxi-backend`) → submodule init fail.

---

# Phần 2 — Đóng gốc rễ còn lại (commit `be19811`)

**Ngày:** 2026-09-13 · cùng branch `claude/inspiring-johnson-hriucq`

## Đổi kế hoạch so với đề xuất ban đầu

Đề xuất cũ: "mở rộng enum `fit_code` trong `services/ai_service.py`". **Đã bỏ — sai hướng.** `fit_code` là:

- thành phần tên file manifest (`SYS_L2_TEE_WHT_REG_01`, `commonItems/generate_manifest.py:83`)
- required field của `commonItems/seeder.py:84`
- mirror trong `commonItems/constants.py`

Thêm code mới vào nó lan ra cả bộ tooling commonItems.

Hướng thay: ghi **`normalized_fit`** — enum mịn, group-aware, mà `commonItems/gemini_tagger_v05.py` đã sinh và engine V05 đã đọc (`engine_v05_layers.py:130`). Additive vào JSON column `physical_attributes`. `fit_code` không đụng tới.

Lợi thế phụ: `garment_fit.resolve_item_fit` vốn đã đọc `normalized_fit` **đầu tiên** → không cần sửa gì phía try-on, dữ liệu mới tự chảy vào prompt.

## Đã làm

| File | Việc |
|---|---|
| `services/ai_service.py` | `normalized_fit` vào schema extraction + khối FIT RULES (không trộn nhóm; xét *cut* chứ không xét cách bày ảnh — flat-lay phóng đại độ rộng, treo móc thì hẹp lại; shoes/accessory = `NA`) |
| `utils/garment_fit_derivation.py` (mới, 164 dòng) | Tách derivation khỏi blueprint try-on. Backfill không phải import module try-on; giá trị ghi vào DB và giá trị render vào prompt từ **cùng một hàm** → không thể lệch nhau |
| `blueprints/tryon/garment_fit.py` (172 dòng) | Còn lại đúng phần render prompt |
| `scripts/backfill-normalized-fit.py` (mới) | Backfill deterministic, theo khuôn `scripts/backfill-warmth-weather-season.py` (dry-run mặc định, `--apply`, `--limit`, `--batch-size`) |

Cả hai module giờ **dưới 200 dòng** — đóng luôn mục 4 "chưa giải quyết" ở Phần 1.

## Backfill báo provenance, không làm phẳng nó

Điểm thiết kế quan trọng nhất. Ba nguồn không cùng độ tin:

| Nguồn | Bản chất |
|---|---|
| `normalized_fit` có sẵn | dữ liệu thật |
| tên/mô tả món đồ ("Wide-leg", "Quần ống rộng") | **kiến thức khôi phục được** |
| `fit_code` REG | **phỏng đoán thô** |

Script đếm và in riêng nhóm cuối là `low-confidence`, cộng cờ `--skip-low-confidence` để ai muốn để NULL chờ re-extraction thì không bị ghi đè bằng đoán mò.

**"Quần đen" + `fit_code: REG` → `STRAIGHT`. Vẫn render sai.** Nói thẳng trong docstring thay vì che. Chỉ vision re-extraction mới cứu được nhóm này — job riêng, tốn tiền, **cố ý không làm ở đây**.

## Tác dụng phụ đã biết (cần đọc trước khi `--apply` prod)

Engine V05 đọc **cùng field** và hiện mặc định item user = `REGULAR` (`engine_v05_layers.py:130`). Backfill sẽ **đổi silhouette scoring** → đổi outfit được gợi ý. Đúng hơn về mặt correctness, nhưng là thay đổi hành vi thật. Đã ghi cảnh báo trong docstring script.

## Kiểm chứng

- 39 test (24 cũ + 15 mới), pass hết. Có test pin đúng bẫy SQLAlchemy: JSON column chỉ được track khi **gán lại** attribute, mutate dict tại chỗ sẽ âm thầm không persist.
- Full suite **21 failed / 1877 passed** vs baseline đã xác minh **21 failed / 1838 passed** → cùng 21 failure có sẵn, không regression.
- Script chạy thật: `--help` OK, guard thiếu `DATABASE_URL` báo lỗi và thoát đúng.
- Chưa chạy backfill trên DB thật — cần `DATABASE_URL` + review của devops (đúng khuôn script backfill có sẵn).

## Chưa giải quyết (cập nhật)

1. ~~`fit_code` thiếu WIDE/STRAIGHT~~ → đã vòng qua bằng `normalized_fit`. `fit_code` giữ nguyên cho HRID/manifest.
2. ~~`garment_fit.py` > 200 dòng~~ → đã tách.
3. **Item không có tín hiệu nào trong tên** vẫn chỉ nhận phỏng đoán từ `fit_code`. Cần một pass vision re-extraction để dứt điểm — chưa làm, tốn tiền, cần CEO duyệt.
4. **Độ phủ thật chưa đo.** Phải chạy dry-run trên prod-mirror để biết bao nhiêu item rơi vào `low-confidence` — đó là con số quyết định có đáng làm re-extraction không.
5. Vẫn **chưa có eval set**. Không đo được cải thiện thật của cả Phần 1 lẫn Phần 2.
6. `.gitmodules` còn trỏ `ducga1998/wardrobe-backend` (đã migrate sang `auxi-wardrobe/auxi-backend`).
