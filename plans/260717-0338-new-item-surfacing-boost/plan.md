# New-item surfacing boost — ưu tiên item user mới upload vào suggestions

**Date:** 2026-07-17
**Branch (umbrella):** `claude/upload-item-prioritization-aiudnm`
**Scope:** `wardrobe-backend/` — V05 recommendation engine scoring only. Không đụng mobile.
**Owner routing:** backend → `backend-dev` · contract/tuning sign-off → `tech-lead` · giá trị tham số → CEO
**Status:** Planned, not started

> Code engine (`ducga1998/wardrobe-backend`) không reachable từ umbrella checkout này, nên
> đây là artifact điều phối: định nghĩa rule + plan phân phối. Implementation land trong submodule
> qua `backend-dev`. Mọi `file:line` dưới đây trích từ các report đã verify code thật
> (`plans/reports/architecture-260531-1439-*`, `tech-lead-260528-0012-*`, `v05-eval-260602-*`).

---

## 1. Vấn đề & mục tiêu

**Vấn đề:** V05 hiện **không có** cơ chế nào đảm bảo item user vừa upload được đưa vào suggestions.
Item mới chỉ được đối xử như mọi item user khác — nếu phối chưa "thắng" điểm, nó có thể nằm im
rất lâu. Không có tín hiệu recency/coverage nào trong scoring (`_score_pair_for_slot` chỉ đọc
color/silhouette/formality/length-rise — architecture report §4). Tag `New` chỉ là UI, không ảnh
hưởng engine.

**Mục tiêu:** Item user mới upload có **cơ hội xuất hiện sớm** trong suggestions để user thấy đồ
mới được style (activation + vòng feedback nhanh) — **mà không hy sinh chất lượng outfit**.

**Không phải mục tiêu:** ép item mới vào MỌI outfit; ghim cứng; đổi pool filtering.

## 2. Rule — định nghĩa chính xác

**Tên:** `NEW_ITEM_SURFACING_BOOST` — coverage-based, soft, decaying.

**Phát biểu:** Một item **user-owned** (`is_common_item == false`) **chưa được style đủ** sẽ nhận
một **hệ số thưởng nhỏ, giảm dần** khi chấm điểm — chỉ áp dụng cho candidate **đã qua mọi hard
gate**, nên không bao giờ đẩy một item không hợp thời tiết/màu/độ trang trọng lên.

### 2.1 Tín hiệu: đếm theo ĐỘ PHỦ, không theo ngày

- Định nghĩa "đã style" = item đã **xuất hiện trong một outfit đã phục vụ** `surface_count` lần.
- Nguồn đếm: tái dùng `v05_outcome_events` (đã có — `plans/260515-1530-v05-phase-0-foundation/plan.md:143-146`,
  index sẵn theo `user_id, event_type, created_at`). Đếm số lần `item_id` nằm trong outfit đã serve.
  KISS: **không** tạo bảng mới nếu log serve đã chứa item_ids; nếu chưa, thêm counter nhẹ
  `(user_id, item_id, surface_count, last_surfaced_at)`.
- **Không dùng `created_at`/cửa sổ ngày.** Lý do (đã chốt với CEO): upload dồn 50 item cùng lúc sẽ
  triệt tiêu tín hiệu, và item không hợp phối vẫn bị đẩy suốt cả tháng. Coverage tự tắt đúng khi
  mục tiêu đạt (item đã được style), bất kể nhịp upload.

### 2.2 Công thức (multiplier — đồng bộ với pattern engine)

Engine đã dùng multiplier cùng loại (`COMMON_INJECTED_PENALTY = 0.9` —
`tech-lead-260528-0012-pr71-v05-sustain-review.md:74-76`). Dùng multiplier để nhất quán:

```
boost = 1 + (NEW_ITEM_BOOST_MAX - 1) * max(0, 1 - surface_count / COVERAGE_TARGET)
```

- `surface_count = 0` → boost = `NEW_ITEM_BOOST_MAX` (đỉnh).
- `surface_count >= COVERAGE_TARGET` → boost = `1.0` (tắt hoàn toàn).
- Chỉ item user-owned đủ điều kiện. Common/Macgie item **không bao giờ** được boost (chúng còn
  đang bị `COMMON_INJECTED_PENALTY` — cùng hướng, không mâu thuẫn).

### 2.3 Hằng số (thêm vào `engine_v05_constants.py`)

| Hằng số | Giá trị đề xuất | Ghi chú |
|---|---|---|
| `NEW_ITEM_BOOST_MAX` | `1.12` | Đủ để nhích khi sát nút, không lật kèo chất lượng. CEO tune. |
| `NEW_ITEM_COVERAGE_TARGET` | `3` | Số lần xuất hiện trước khi bonus về 0. |
| `NEW_ITEM_BOOST_ENABLED` | `false` (mặc định) | Feature flag, bật qua ML config versioning (AlgorithmCockpit). |

## 3. Điểm móc & bất biến "soft"

- **Vị trí:** trong tầng chấm điểm cặp/slot (`engine_v05_layers.py`, quanh `_score_pair_for_slot`),
  áp `boost` vào điểm slot của item **sau khi** candidate đã qua hard gate, **trước khi** rank.
- **Bất biến chất lượng (cấu trúc):** Hard gate (warmth/gender/rain/formality window —
  `engine_v05_constants.py` warmth buckets, `engine_v05_layers.py` gates) **chạy trước** và độc lập
  với boost. Boost chỉ **sắp xếp lại survivor** → không thể đưa item bị gate loại quay lại. Đây là
  cách "soft boost, không phá chất lượng" được đảm bảo bằng thiết kế, không bằng tuning.
- **Không đụng pool filtering** (Layer 1) → không làm nặng thêm `PoolInsufficient`
  (v05-eval-260602 §V05-2). Boost thuần là multiplier điểm.
- **Tương tác novelty layer** (`engine_v05_signature.py`): item mới thường vốn đã "novel" nên hai
  tín hiệu cùng hướng; kiểm tra chúng compose (nhân) chứ không tự chọi.

## 4. Observability (backend eval — không phải Mixpanel)

Analytics rule (`.claude/rules/analytics-tracking-required.md`) áp cho mobile; đây là backend nên
dùng eval/log:
- Gắn debug flag `new_item_boosted: true` + `surface_count` vào item trong outfit đã serve (giống
  pattern `_is_common_injected` / `source: common_essential`).
- Metric eval (v05-eval harness): **time-to-first-surface** cho item mới upload (trước/sau), và
  **outfit-quality delta** để chứng minh không regression.

## 5. Phases (dispatch)

**Phase 0 — Đo baseline (backend-dev + v05-eval) — GATE trước khi build**
- [ ] Query prod: với item user upload, độ trễ trung vị từ upload → lần đầu vào outfit serve. Xác
      nhận lỗ hổng có thật (report V05 luôn nhấn "measure before re-tuning").

**Phase 1 — Đếm surface_count (backend-dev)**
- [ ] **GATE (chốt trước khi code):** Xác minh log serve có thực sự lưu `item_ids` của outfit. Chỉ
      khi xác nhận xong mới khóa quyết định **derive vs counter mới**. Nếu có → derive count từ
      `v05_outcome_events`. Nếu chưa → thêm counter table nhẹ + tăng ở serve time.

**Phase 2 — Scoring hook (backend-dev)**
- [ ] Thêm 3 hằng số §2.3 vào `engine_v05_constants.py`.
- [ ] Áp `boost` §2.2 trong `engine_v05_layers.py` (sau gate, trước rank), chỉ item user-owned đủ ĐK.
- [ ] Sau feature flag `NEW_ITEM_BOOST_ENABLED`.
- [ ] **Test bắt buộc (bất biến chất lượng §3):** assert hard gate chạy trước & độc lập — một item
      bị gate loại (sai warmth/gender/rain/formality) KHÔNG bao giờ được boost đưa trở lại; boost chỉ
      đổi thứ tự các survivor. Test này chặn refactor tương lai vô tình đẩy boost lên TRƯỚC gate.

**Phase 3 — Observability (backend-dev)**
- [ ] Debug flag + `surface_count` trên item serve.
- [ ] Metric time-to-first-surface + outfit-quality delta vào v05-eval.

**Phase 4 — Rollout & verify (tech-lead + CEO)**
- [ ] Ship qua config version (AlgorithmCockpit), bật flag cho cohort nhỏ.
- [ ] v05-eval: time-to-first-surface giảm, quality **không** giảm. `python test_server.py` xanh.
- [ ] CEO chốt `NEW_ITEM_BOOST_MAX` / `COVERAGE_TARGET` sau khi đọc eval.

## 6. Quyết định đã chốt
- Cơ chế: **coverage-based** (không phải cửa sổ 30 ngày). ✅ CEO 2026-07-17
- Độ mạnh: **soft boost** — không vượt hard gate. ✅ CEO 2026-07-17

## 7. Câu hỏi chưa giải quyết
- Log serve hiện đã lưu đầy đủ item_ids của outfit chưa? (quyết định Phase 1 derive vs thêm counter.)
- Giá trị `NEW_ITEM_BOOST_MAX`/`COVERAGE_TARGET` cuối — chờ eval Phase 0/4.
- Có cần cả cận trên thời gian (hybrid) không, hay coverage-only là đủ? (Mặc định: coverage-only, YAGNI.)

## 8. Traceability
- **GH PR:** `auxi-wardrobe/auxi-all-in#35` (spec này).
- **Branch:** `claude/upload-item-prioritization-aiudnm`.
- **Linear ticket:** _TBD — PM tạo & gán_ để 4 phase track được ngoài doc (Linear MCP chưa auth ở session này).
