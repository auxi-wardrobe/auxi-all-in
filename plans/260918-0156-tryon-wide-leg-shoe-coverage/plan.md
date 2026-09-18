# See on me — wide-leg hem phải che tối thiểu 1/2 giày

**CEO ask:** quần wide-leg render ra phải che **tối thiểu 1/2 giày**, không lộ trọn giày.
**Repo:** `auxi-wardrobe/auxi-backend` (verified tại `ac9bd56`, clone `/home/user/auxi-backend`).

## 0. Ground truth — phần lớn hạ tầng ĐÃ CÓ

Không phải bài toán "chưa làm gì". Đã ship và đọc được tại code:

- `blueprints/tryon/garment_fit.py` — directive per fit/length, spec đo được + phủ định + đặt
  CUỐI prompt. `WIDE` đã có ("hem ≈ hip width, never tapered").
- `utils/garment_fit_derivation.py` — single source of truth fit/length, share với backfill.
  Có keyword tiếng Việt (`ống rộng`, `dài phủ giày`).
- `openai_service.py:467` COMPOSITION — đã cấm đánh đổi hem lấy shoe visibility
  ("never trade garment length for shoe visibility").
- `scripts/eval-tryon-fit-fidelity.py` — eval A/B, judge phân loại mù (không leak đáp án).
- `scripts/backfill-normalized-fit.py`.

**⇒ Việc còn lại nhỏ. Đừng viết lại gì.**

## 1. Ba gap thật (đều verify tại code)

| # | Gap | Vị trí | Vì sao |
|---|---|---|---|
| G1 | `LONG` không có sàn đo được — "**partially** covering the foot" | `garment_fit.py:_LENGTH_DIRECTIVES["LONG"]` | Đúng loại tính từ mà docstring của chính module nói là thua prior. Không có "1/2". |
| G2 | **Compact template mới là path production** — `LONG` = "breaks over the top of the shoe", yếu hơn nữa | `garment_fit.py:_COMPACT_LENGTH`, dùng ở `openai_service.py:712` | `config.py:77` `TRYON_RENDER_PROVIDER` default = `kling_image` → compact. Sửa mỗi full template = sửa path không chạy. |
| G3 | `WIDE` + length unknown → **không emit dòng length nào** | `garment_fit_derivation.py:resolve_item_length` trả `None` | Tagger chưa chạm + tên item không có keyword → model tự chọn hem → lộ trọn giày. |

Phụ: judge của eval chỉ có `shoes_visible` (bool). **Bool không đo được "≥1/2"** → không nghiệm thu được bar mới.

## 2. Spec chốt

Với bottom `fit = WIDE` và `length ∈ {LONG, MAXI}` (hoặc length unknown → xem G3):

- **Prompt nhắm:** full break, chỉ còn mũi giày (bậc 3).
- **Bar nghiệm thu:** gấu quần **ngang hoặc thấp hơn top line của giày** — xấp xỉ che ≥1/2 (bậc ≥2).
- Nhắm cao hơn bar vì generator luôn undershoot về prior.
- `CROPPED` **miễn trừ** — cropped đúng chuẩn là lộ mắt cá; không gate nhầm.

Thang ordinal cho judge (**không dùng %** — vision model chấm % nhiễu, không rõ trục nào):

| Bậc | Mô tả | Verdict |
|---|---|---|
| 0 | Gấu trên mắt cá, thấy trọn giày | FAIL |
| 1 | Gấu ngang mắt cá, thấy gần hết giày | FAIL |
| 2 | Gấu chạm/thấp hơn top line giày | **PASS** |
| 3 | Gấu phủ tới mũi giày, full break | PASS (lý tưởng) |

## 3. Phases

- **P1 — data check (1 SQL, quyết định G3 có cần không).** Đếm bottom `normalized_fit='WIDE'`
  có `length_type` NULL/không hợp lệ. Cao → G3 là gap chính, không phải chữ nghĩa.
- **P2 — sửa directive (G1+G2).** Thêm sàn đo được vào `LONG` ở **cả hai** bảng.
- **P3 — default có điều kiện (G3).** WIDE + length unknown → coi như LONG. Chỉ ở lớp render,
  **không** ghi vào DB.
- **P4 — đo.** Thêm `shoe_coverage` ordinal 0-3 vào judge của `eval-tryon-fit-fidelity.py`,
  chạy `--arm both` trên fixture WIDE. Không có số thì không kết luận.

## 4. Open questions

1. P1 chưa chạy — chưa biết G3 chiếm bao nhiêu. Có thể nó là gap lớn nhất, không phải G1/G2.
2. `kling_image` có tuân thủ directive tốt bằng `gpt-image-1` không? Chưa ai đo per-provider.
3. Có nên đổi `TRYON_RENDER_PROVIDER` sang `openai` (full template, 8800 chars) không — quyết định
   riêng, cần số từ P4 trước.
