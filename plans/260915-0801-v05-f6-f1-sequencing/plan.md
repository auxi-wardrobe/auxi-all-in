# F6 → F1 — thứ tự thi hành (coordination artifact)

**Date:** 2026-09-15 · **Scope:** điều phối 2 plan đã có, KHÔNG phải plan thứ 3
**Owner routing:** thực thi → `backend-dev` · thứ tự + rollback → `tech-lead` · ngưỡng → CEO

| Plan | Vai trò | Dispatch |
|---|---|---|
| **F6** `plans/260822-0958-v05-coherence-floor/` | Sàn chất lượng ở **cửa ra** | `dispatch-backend-dev.md` ✅ |
| **F1** `plans/260822-0951-v05-occasion-contract-fix/` | Formality gate ở **đầu vào** | `dispatch-backend-dev.md` ✅ |

**Luật cứng: F6 xanh hoàn toàn (đo xong, flag ON ổn định) TRƯỚC khi lật flag F1.** Không chạy song song.

---

## 1. Vì sao không được song song

Hai lý do độc lập, mỗi cái đủ để cấm.

**(a) Va chạm file.** Cả hai sửa cùng chỗ:

| File | F6 | F1 |
|---|---|---|
| `blueprints/recommendation/engine_v05_constants.py` | thêm `V05_MIN_COHERENCE`, `V05_COHERENCE_ENABLED` | sửa `OCCASION_FORMALITY` (~272-289) |
| `engine_v05.py:~306` (trace object) | `coherence_score`, `formality_spread` | `occasion_resolved`, `formality_window` |
| ML config versioning (AlgorithmCockpit) | flag riêng | flag riêng |
| `API_DOCUMENTATION.md` | — | bắt buộc (contract đổi) |

Merge conflict ở constants + trace là chắc chắn nếu hai nhánh chạy cùng lúc.

**(b) Không quy được nhân quả — cái này mới nghiêm trọng.**
F1 **thu hẹp pool**; F6 **không thu pool**. Cả hai cùng đo trên một metric: `v05_pool_insufficient_rate`.
Bật cả hai một lượt rồi thấy rate tăng → **không biết do đâu**, phải tắt cả hai và làm lại từ đầu.
Rủi ro này đã có tiền lệ: `plans/260601-2142-au306-cold-weather-fix/phase-02` §"Compounding starvation"
ghi rõ hai fix cùng thu hẹp một tập OUTER → phải đo **kết hợp**, không đo riêng được.

---

## 2. Vì sao F6 trước (không phải F1)

Từ `260822-0958/plan.md` §2.4:

| | F1 (thu formality window) | **F6 (coherence floor)** |
|---|---|---|
| Sửa ở đâu | Đầu vào — lọc pool | Đầu ra — trước khi serve |
| Trị được ca CEO báo? | Một phần | ✅ Trực tiếp |
| Rủi ro cạn pool | ⚠️ **Có** | ✅ Không |
| Phụ thuộc occasion đúng? | ✅ Có | ❌ Không — chặn mọi nguyên nhân |

F6 là backstop ở cửa ra: thượng nguồn sai kiểu gì, bộ ngớ ngẩn vẫn không lọt.
F6 xong có thể khiến F1 **không còn cần thiết** — đó là kết quả tốt, không phải lãng phí.

---

## 3. Ma trận flag — mỗi bước đúng MỘT biến đổi

| Bước | `V05_COHERENCE_ENABLED` | flag F1 | Đo cái gì |
|---|---|---|---|
| 0 | OFF | OFF | **Baseline** — `v05-eval --hybrid`, lưu lại số |
| 1 | **ON** (cohort nhỏ) | OFF | F6 làm tăng/giảm `pool_insufficient` bao nhiêu? coherence P2 tăng? |
| 2 | ON (toàn bộ) | OFF | F6 ổn định. **Đây có thể là điểm dừng** — xem §5 |
| 3 | ON | **ON** (cohort nhỏ) | Delta thuần của F1, trên nền F6 đã biết |
| 4 | ON | ON (toàn bộ) | Xong |

Không bao giờ lật hai flag trong cùng một lần đo. Giữa mỗi bước: chờ đủ volume để so sánh có nghĩa
(baseline `--days 7` là mặc định của skill `v05-eval`).

---

## 4. Merge & pin

1. F6 merge vào `auxi-backend` → deploy → bước 1-2 ở §3.
2. F1 **rebase lên `main` đã có F6** (không phải lên nhánh F6). Conflict constants + trace giải bằng
   giữ cả hai khối, không ghi đè.
3. F1 merge → deploy → bước 3-4.
4. Mobile Phase 3 của F1 (bỏ `occasion: mode` ở `HomeScreen.tsx`) **sau cùng**, chỉ khi bước 4 xanh.
5. Bump submodule pin ở umbrella sau khi cả hai repo merge.

---

## 5. Điểm dừng hợp lệ sau bước 2

Sau khi F6 ON toàn bộ, chạy lại eval. **Nếu bộ "sơ mi linen + quần track + giày lười" không còn
compose được và `pool_insufficient_rate` không tăng → cân nhắc DỪNG, không làm F1.**

Lý do: F1 mang rủi ro cạn pool có thật, trên một pool đã thiếu sẵn (27% item `warmth_level=0`,
57% user có 0 TOP sống sót ở HOT). Task 1.1 của V05 Phase 0 đã từng phải **nới** formality vì
49 TOP rớt còn 8. Trả giá đó chỉ đáng khi F6 chứng minh là chưa đủ.

Quyết định dừng hay đi tiếp: `tech-lead` đọc số eval bước 2, CEO chốt.

---

## 6. Rollback

- Mỗi flag rollback độc lập, tắt qua AlgorithmCockpit, không cần deploy.
- Gate rollback duy nhất: `v05_pool_insufficient_rate` **tăng** so với baseline bước 0.
- Tắt flag → hành vi phải giống hệt trước đó (cả hai dispatch đều yêu cầu test "flag OFF = hành vi cũ y nguyên").
- Tắt flag F1 KHÔNG được ảnh hưởng F6 và ngược lại — hai flag độc lập hoàn toàn. Nếu phát hiện
  chúng coupling nhau ở code, đó là bug, báo lại trước khi đo tiếp.

---

## 7. Câu hỏi chưa giải quyết

1. Cohort nhỏ = bao nhiêu %? Chưa có cơ chế cohort trong AlgorithmCockpit — cần verify nó hỗ trợ
   rollout theo % hay chỉ ON/OFF toàn cục. Nếu chỉ ON/OFF, bước 1 và 3 phải làm trên staging.
2. Cần bao nhiêu ngày volume giữa mỗi bước để so sánh có ý nghĩa thống kê? Chưa ai tính.
3. Nếu F6 làm `pool_insufficient` **giảm** (có thể — TIER 2 phục vụ bộ ít tệ nhất thay vì fail),
   baseline cho F1 phải lấy lại ở bước 2, không dùng lại số bước 0.
