# Apply Auxi Design System (claude.ai/design) vào app — Gap Analysis

**Date:** 2026-06-24 · **Source:** claude_design MCP (DesignSync) · **Branch:** GH-364
**Question:** (1) Apply DS thì giải quyết vấn đề design + ép mobile-dev chỉ dùng DS không? (2) UI custom nhiều — ép khuôn vào DS có thiếu/vỡ/stuck gì?

> **Rev 2 (corrected):** Lần đầu soi nhầm 1 project & kết luận sai "DS không có component" + cảnh báo nhầm "vỡ font". Đã sửa: có **2 artifact**, showcase **có đủ component gallery**, và font = **Poppins-only** (CEO chốt 2026-06-24).

## Hai artifact trên claude.ai/design (đừng lẫn)

| Project | id | Type | Nội dung |
|---|---|---|---|
| **"auxi"** ← link CEO gửi | `019df3b4-ff8b-74c4-bfc6-7d7d597c90a2` | PROJECT | **Design spec đầy đủ**: `Auxi Design System Showcase.html` (component gallery) + `Auxi Design System.html` + flows (Auth/Favourite/Pin Item/Settings) + UAC specs + `auxi-ds.css`/`auxi-showcase.css` + `ds/` (Icon, tokens). **Nơi component được thiết kế.** |
| **"Auxi Design System"** | `2b147bc5-8273-42ea-b9b5-78803827970c` | DESIGN_SYSTEM | Registry: token + asset + đúng 1 component (`brand/Icon.jsx`). Token trích TỪ `theme.ts`. **Chưa chứa gallery component.** |

DS là HTML/CSS; app là RN — không có codegen, nối thủ công (theme.ts mirror). Enforce = lint + designer gate, không phải `import`.

## Showcase component inventory (`Auxi Design System Showcase.html`)

**Foundations (§01–05):** Color · Type · Space&Radius (4-pt) · Elevation (card/raised/dialog/sheet) · Icons (product sprite).

**Components (§06–18, 13 nhóm):**
- §06 Buttons — Primary/Outline/Danger/Danger-outline/Text/Icon; layout 3-btn / 2-btn dọc/ngang; states enabled→hover→pressed→disabled→loading
- §07 Divider (common divider)
- §08 Selection — Switch(teal)/Checkbox/Radio
- §09 Inputs — text field (default/focus/placeholder)
- §10 Chips/Tags/Badges — suggestion/removable/filter chips · item tags · status pills
- §11 List rows — settings row (value/chevron/danger/muted variants)
- §12 Tabs/Segments — segmented control
- §13 Cards/Tiles — item tile · outfit collage tile (+ pin badge)
- §14 Avatar — 88/44 + fallback
- §15 Navigation — top app bar · tab bar (dark) · footer bar (floating pill)
- §16 Overlays — snackbar (neutral/success) · action sheet · toast · dialog
- §17 Date Picker — time picker
- §18 Keyboard
- **Patterns:** example screens (ráp hoàn chỉnh)

~30+ specimen. Đã có **bản RN mirror** trong `auxi/src/components/design-system/*` + `DesignSystemScreen.tsx` (tự mô tả là tái dựng `Auxi Design System.html`).

## Câu 1 — giải quyết gì? Ép DS-only được không?
- **Token (màu/space/type/radius/motion/icon):** ✅ giải quyết drift NẾU enforce. Đã có nửa: `auxi-lint-tokens.sh` (hex/font) + 4 doc design-system + designer gate.
- **Component:** gallery đã thiết kế (showcase) + đã mirror trong code ⇒ ép DS-only ở mức component **KHẢ THI** — điều kiện: promote gallery vào registry chính thức + cấm bespoke mới ngoài set này. (Khác hẳn rev1.)
- **KHÔNG giải quyết:** layout/padding (double-padding — là composition, không phải token); UX-logic quality (mối lo chính CEO — orthogonal với DS).

## Câu 2 — apply vào thiếu/vỡ/stuck gì?
1. **Font — KHÔNG vỡ (đã chốt Poppins-only).** App ship Poppins-only (`theme.ts` ds.font → Poppins; chỉ bundle Poppins-*). Showcase `<head>` cũng chỉ load Poppins + JetBrains Mono. → Token DS `typography.css` ghi Roboto/Inter + 2 file `.ttf` Inter/Roboto trong registry là **drift cần sửa VỀ Poppins-only** (sửa DS, KHÔNG migrate app). Mono không bundle → fallback, chỉ overline spec, OK.
2. **Header height 107 vs 76** — `theme.ts:157 uacHeaderHeight=107`, DS lấy 107, `Header.tsx:74` render `height:76`. App tự lệch → chốt 1 giá trị. (OPEN)
3. **Legacy alias debt** — ~65 screen dùng `figma*`/`uac*`; ép DS-canonical names = migration rename hoặc alias-bridge có doc.
4. **Registry chưa có gallery** — component sống ở project "auxi" (spec) + code (mirror), CHƯA ở registry DESIGN_SYSTEM. Muốn "DS-only" enforce thật thì promote gallery vào registry trước.

## Khuyến nghị (thứ tự)
1. **Sửa token DS về Poppins-only** (typography.css + bỏ Inter/Roboto .ttf khỏi registry) cho khớp shipped. Rẻ, xoá nhầm lẫn.
2. **Enforce token ngay** — siết `auxi-lint-tokens.sh` (padding/font literal) + designer gate.
3. **Promote showcase gallery → registry DS** + đối chiếu 18 component showcase ↔ RN hiện có (implemented/lệch/thiếu) ⇒ ra danh sách "ép vào DS".
4. **Chốt header 107 vs 76.**
5. Layout/padding + UX-logic = workstream riêng (ScreenContainer/Divider primitive + qa-ux).

## Unresolved
- Header height chuẩn: 107 hay 76?
- `--info`/`--ai`/neutral-ramp/brand-grad đã có trong theme.ts chưa?
- Có promote showcase gallery (13 nhóm) lên registry DESIGN_SYSTEM làm canonical không?
