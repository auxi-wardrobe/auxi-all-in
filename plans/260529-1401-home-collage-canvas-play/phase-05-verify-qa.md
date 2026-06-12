# Phase 05 — Verify + QA

**Priority:** P0 (gate). **Depends:** P01–P04. **Status:** pending.

## Static checks
- [ ] `cd auxi && npx tsc --noEmit` → PASS (chỉ lỗi `_HomeScreen.tsx` legacy được phép).
- [ ] `cd auxi && yarn lint` → không vượt baseline (4 errors legacy + 3 warnings).
- [ ] `./scripts/auxi-lint-tokens.sh` → sạch (không hex literal / font drift mới).

## Maestro (qa-ui author → qa-mobile execute)
Create `auxi/maestro/flows/home/collage-toggle.yaml`:
- [ ] Launch app → tới Home (đăng nhập qa-test nếu cần, xem memory qa_test_account).
- [ ] Assert `home-footer-tab-grid-active` hiển thị, grid `home-outfit-grid-*` hiển thị.
- [ ] Tap `home-footer-tab-collage` → assert `home-collage-surface` (hoặc `home-collage-0`) hiển thị + có `home-collage-item-*`.
- [ ] Drag 1 item (`home-collage-item-...`) → flow không crash.
- [ ] Tap `home-footer-tab-grid` → grid trở lại.
- [ ] Run: `maestro test maestro/flows/home/collage-toggle.yaml` (cần `JAVA_HOME`).

## Visual fidelity (qa-ui Compare mode)
- [ ] Pass 2/3: so sánh seed layout collage 3/4/5/6 vs Figma section `2850:13589` (screenshot sim vs Figma).
- [ ] Xác nhận bleed/clip mép giống Figma; header/caption/action row/CTA/footer khớp grid view (đã ship).

## Smoke (qa-mobile)
- [ ] Boot stack `./scripts/qa-boot.sh`; chạy Home thật trên sim (backend :5001, không mock).
- [ ] Toggle grid↔collage nhiều lần; Show another khi đang collage → re-seed theo outfit mới; Remix → editor item thật.

## Success criteria (definition of done)
- Toggle hoạt động 2 chiều, không crash; collage seed đúng theo count; kéo-thả mượt; Remix editor regression sạch.
- Tất cả static check + Maestro flow PASS; qa-ui Compare PASS; qa-mobile smoke PASS.

## Unresolved questions (chốt khi impl)
1. Animation đổi view (cross-fade vs cứng) — mặc định cứng nếu không yêu cầu thêm.
2. Giữ vị trí đã kéo khi Show another? — mặc định re-seed (không giữ).
3. Count 0 item: giữ grid hay hiện surface trống — mặc định giữ grid.
