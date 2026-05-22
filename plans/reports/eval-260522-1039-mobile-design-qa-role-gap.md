# Eval: vì sao mobile UI/UX cứ ra sai ý CEO

**Date:** 2026-05-22
**Author:** claude (orchestrator) — diagnostic only, không fix code
**Scope:** mobile-dev + qa-ui + qa-ux + qa-mobile role system trong umbrella

---

## TL;DR

Pipeline hiện tại để **mobile-dev một mình đọc Figma, một mình code, một mình tự verify**. qa-ui chỉ vào sau khi đã có code — toàn bộ là audit post-hoc, không có gate upstream. Pass 3 (sim screenshot) bị skip "kinh niên" vì lý do "no sim / no MCP". Theme tokens và font family bị drift lặp đi lặp lại trên nhiều màn hình. Hậu quả: bug fidelity không phải cá biệt — nó là **đầu ra mặc định** của pipeline này.

---

## 1. Evidence từ QA findings gần nhất (cùng ngày 2026-05-22)

6 findings files trong 1 ngày — tất cả Pass 3 SKIPPED:

| File | Pass 1 (Figma extract) | Pass 3 (sim screenshot) | Severity |
|---|---|---|---|
| `ui-au-289-item-detail.md` | ⚠️ Indirect (no MCP) | ⏭ Skipped (no sim) | 9 P0 · 9 P1 · 6 P2 |
| `item-detail-compare.md` | Partial (no MCP) | Skipped | "40% surfaced, none 100% correct" |
| `home-grid-view-compare.md` | BLOCKED (no MCP) | Skipped | NEW UI element missing |
| `ux-au-289-item-detail.md` | n/a | n/a | Heuristic — findings only |
| `wardrobe-database-compare.md` | — | — | — |
| `setting-compare.md` | — | — | — |

**Recurring failure modes** (rút từ findings):

1. **Token drift lặp lại trên mọi screen**
   - App background `#F3F5F9` (cool blue-gray) thay vì Figma `#f2efec` (warm cream)
   - Font `Archivo` / `Inter` / `Manrope` thay vì Figma `Poppins-Medium`
   - Hex literal trong screen file (`'#EEDCDD'`, `'rgba(39, 42, 50, 0.9)'`) — vi phạm "no literal hex" rule của `figma-to-rn-workflow`
   - Heart icon, badge color, divider color — tất cả hardcode

2. **Glyph text thay cho SVG icon**
   - Back button render `'<'` text fontSize 22 thay vì `IconChevronLeft` SVG
   - Selected glyph `'x'` literal trong category modal

3. **Feature thiếu hẳn (TODO marker)**
   - 6/10 metadata fields chưa làm (Name, Note, Materials, Energy, Occasion, Purchase date)
   - Pagination indicator "1/3 / 2/3 / 3/3": state có (`activeSheetIndex`) nhưng không render
   - 8 modals trong Figma → 1 generic `<Modal>` switching list

4. **Pattern mismatch — đoán sai ý Figma**
   - Multi-select Figma → single-select code
   - Bespoke chip row Figma → bottom-sheet generic list code
   - Kebab/overflow Figma → inline button code
   - Style field maps sai (Style → `formality_level` enum, mất hẳn sporty/edgy/romantic)

5. **Backend contract gaps lộ ra SAU khi mobile đã code**
   - Materials / Energy / Purchase date cần BE schema change — không sync trước

---

## 2. Gốc rễ theo role

### 2.1 mobile-dev — quá nhiều mũ, không peer check

mobile-dev hiện làm 3 việc cùng lúc:
- **Reader**: đọc Figma (skill `figma-design-extraction`)
- **Coder**: viết RN (skill `figma-to-rn-workflow`)
- **Self-verifier**: side-by-side sim screenshot

→ Không có ai check giữa Reader và Coder. Nếu Reader hiểu sai variant / overrides / multi-vs-single, Coder code đúng theo Reader's misread. qa-ui chỉ vào ở cuối → discover sau khi code đã ship.

**Skill `figma-design-extraction` rất tốt trên giấy** (33 mục checklist, đòi `get_metadata` → `get_variable_defs` → `get_design_context`). **Vấn đề: không có artifact bắt buộc lưu lại**. mobile-dev có thể nói "đã extract" mà không tạo bằng chứng → reviewer không có gì để so.

**Skill `figma-to-rn-workflow` Phase 6 "Verify on simulator" tuyên bố "non-negotiable"** — nhưng cho phép escape hatch: *"If the simulator can't run in your current session, mark the task as 'code complete · visual verification pending'"*. Trong thực tế escape hatch này trở thành trạng thái FINAL. 6/6 findings hôm nay đều Pass 3 SKIPPED.

### 2.2 qa-ui — downstream, không upstream

`auxi-figma-audit` chạy 3-pass. Nhưng:
- Triggered SAU khi đã có PR/code (per agent table: "PR has Figma URL")
- Không có pass cho "review extraction note BEFORE code"
- Khi qa-ui được dispatch trong subagent với Figma MCP không expose → Pass 1 BLOCKED → audit chạy "inferred from frame names" — đoán mò
- Khi không có sim → Pass 3 SKIPPED → kết quả chỉ là static code audit, mất pixel verification

→ qa-ui đáng lẽ là **gate** nhưng đang là **observer**.

### 2.3 qa-ux — findings-only, không fix-loop

qa-ux có rule "Findings only — never proposes fix code". Đúng nguyên tắc, nhưng **không có cơ chế chuyển finding thành ticket bắt buộc fix**. Findings nằm trong `auxi/docs/qa-findings/` rotting — không có severity gate, không có "P0 = merge blocker" enforced ở PR level.

### 2.4 qa-mobile — chỉ chạy cái có sẵn

qa-mobile vừa được mở rộng (turn này) cho phép mobile-mcp exploratory. Nhưng vẫn không phải role kiểm soát thiết kế — nó verify behavioral, không catch fidelity.

### 2.5 Role thiếu — không có "Spec Reviewer" / "Designer Proxy"

CEO = designer, nhưng CEO không trong agent loop. tech-lead có "Mode B post-implementation review" → vẫn là post-hoc. **Không ai check spec interpretation BEFORE mobile-dev viết line code đầu tiên.**

Trong khi đó memory `feedback_designer_is_ceo.md` ghi "Figma fidelity & on-simulator verification non-negotiable" — rule có, enforcement không.

---

## 3. Pipeline hiện tại — chỗ rò ý

```
CEO Figma intent
   │
   │  [LEAK 1] mobile-dev đọc một mình. Không artifact. Không peer check.
   ▼
mobile-dev interprets
   │
   │  [LEAK 2] Không gate "extraction approved" trước khi code
   ▼
mobile-dev codes
   │
   │  [LEAK 3] Theme/font lint không tồn tại. Hex literal pass-through CI.
   │  [LEAK 4] Pass 3 sim verify "pending" → final state. Escape hatch active.
   ▼
PR opened
   │
   │  [LEAK 5] qa-ui audit post-hoc. Khi MCP/sim không có → audit cũng degraded.
   ▼
Findings filed (auxi/docs/qa-findings/)
   │
   │  [LEAK 6] Không có cơ chế bắt buộc loop back. P0 không là merge gate.
   ▼
Merged (with drift)
   │
   ▼
CEO thấy → "ko phải cái tôi muốn"
```

**6 leak points → ít nhất 6 lần ý CEO bị pha loãng** trước khi ra sim.

---

## 4. Patches — xếp theo leverage cao → thấp

### P1 — Force extraction artifact + spec sign-off (HIGHEST LEVERAGE)

Thay đổi `mobile-dev.md` + `figma-design-extraction.md` để bắt buộc:

- mobile-dev MUST tạo file `plans/{plan-dir}/figma-extraction-{screen}.md` TRƯỚC khi code (theo template ở Phase 1 của `figma-to-rn-workflow`).
- File chứa: frame names, tokens used, icons enumerated, variants, **all open questions**.
- mobile-dev MUST chờ tech-lead hoặc PM sign-off file extraction này trước khi `Edit`/`Write` bất kỳ `.tsx` nào.
- qa-ui có thêm mode "review-extraction": audit file `figma-extraction-*.md` vs Figma (Pass 1 ONLY, không cần code).

→ Catches misread BEFORE code. CEO/PM có chance redirect khi cost còn thấp.

### P2 — Theme conformance lint = CI blocker

Thêm ESLint rule (hoặc codemod check) ban:
- Literal hex (`/'#[0-9a-fA-F]{3,8}'/`) trong file `src/screens/**` và `src/components/**`. Whitelist: `src/theme/theme.ts`.
- Font family string ngoài `theme.text.*` preset.

CI fail nếu vi phạm. → Loại trừ recurrence của #1 và #2 trong section 1.

### P3 — Sim verification = merge gate, hết escape hatch

Đổi rule trong `figma-to-rn-workflow` Phase 6:
- "code complete · visual verification pending" KHÔNG được merge.
- Nếu mobile-dev không chạy sim được trong session → tự dispatch qa-mobile (giờ có mobile-mcp) làm Pass 3 thay.
- PR template thêm checkbox: "Sim screenshot attached / link to qa-mobile verify ID" — required.

### P4 — Spec gap escalation rule

Thêm vào `mobile-dev.md`:
- Khi extraction note có ≥1 "open question" về intent (multi vs single, modal pattern, copy, field new) → mobile-dev MUST escalate qua tech-lead → designer trước khi code.
- Default action khi ambiguous: **stop, ask**. Default action hiện tại: **guess**.

### P5 — Backend gap detection ở extraction time

Trong extraction artifact template, bắt buộc 1 section "New fields / contract delta":
- mobile-dev liệt kê fields mới trong Figma so với `services/wardrobeService.ts` (hoặc tương đương).
- tech-lead route sang backend-dev để confirm schema. mobile-dev không code field mới đến khi BE confirm.

→ Tránh trường hợp Materials/Energy/Purchase date code xong mới phát hiện BE chưa có.

### P6 — qa-ux findings → auto-ticket → P0 merge gate

`pm` agent sweep qa-findings hằng ngày:
- Mỗi P0/blocker finding → tự tạo Linear issue (`Bug: <title>` linked PR).
- PR không merge được nếu có open P0 linked.

→ Loop close cho UX/a11y findings, không rotting trong `qa-findings/` nữa.

### P7 — qa-ui MCP/sim availability check tại dispatch time

Khi dispatch qa-ui trong subagent context, kiểm tra Figma MCP + sim availability TRƯỚC khi bắt đầu audit:
- Không đủ tool → REFUSE dispatch, escalate. Không chạy degraded.
- Hiện tại findings có dòng "Pass 1 BLOCKED — figma MCP read tools not exposed" — đó là kết quả audit vô giá trị, nhưng vẫn được file → đánh lừa rằng đã audit.

---

## 5. Đề xuất thứ tự thực hiện

Nếu chỉ làm 1 patch: **P1** (extraction artifact + sign-off). Đây là patch duy nhất chặn leak ở SOURCE (giữa CEO intent và code). Mọi patch khác chỉ giảm hậu quả.

Nếu làm 3 patches: **P1 + P2 + P3**. Catch sai intent sớm + chặn hex/font drift mechanical + bắt buộc verify trên sim. Cover 4/6 leak points.

Nếu làm full: P1 → P7 tuần tự (P5 phụ thuộc P1, P6 phụ thuộc PM workflow setup).

---

## 6. Unresolved questions

1. **CEO (designer) có sẵn sàng review extraction note pre-code không?** Patch P1 phụ thuộc người này responsive. Nếu CEO bận → tech-lead proxy được không, và proxy có quyền sign-off thay không?
2. **ESLint rule cho theme conformance — đã có ai thử setup chưa?** Cần check `auxi/.eslintrc*` xem có infrastructure custom rule.
3. **qa-ui subagent có thể access Figma MCP nếu được provision đúng không?** Hay đây là limit của subagent context architecture? Nếu là limit kiến trúc thì P7 thành "chỉ chạy qa-ui ở main session" — restrict dispatch path.
4. **PR template hiện có gì?** Cần xem để biết P3 (sim screenshot checkbox) inject vào đâu.
5. **Hiện có codemod hoặc script nào pre-commit không?** Để biết P2 hook vào layer nào (lint-staged / husky / CI only).
6. **`activeSheetIndex` không render pagination — bug hay chưa làm?** Cần PM/CEO confirm scope AU-ticket nào cover sheet pagination để biết là regression hay feature gap.
