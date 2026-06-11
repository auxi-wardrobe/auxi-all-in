# Loop Engineering (@0xCodez thread) → Wardrobe Linear Autopilot

Source: https://x.com/0xCodez/status/2064374643729773029 (14-step "loop engineering" roadmap, 2026-06-09)
Goal: Linear làm chuẩn — ticket tự chạy code → QA → check → Done → release → notify.

## Thread core ideas (đáng giá nhất)

1. **Loop engineering = replace yourself as the prompter** — hệ thống tự tìm việc, giao agent, check kết quả, ghi tiến độ, quyết bước tiếp.
2. **4-condition test** trước khi build loop: task lặp ≥ weekly · verification tự động · chịu được token waste · agent có tool của senior (logs, repro env).
3. **5 building blocks**: Automations (heartbeat) · Worktrees (parallel isolation) · Skills (project memory) · Connectors/MCP (GitHub, Linear, Slack, Sentry) · Sub-agents (maker ≠ checker).
4. **State**: "agent forgets, the repo does not" — Linear board chính là state file production-grade.
5. **Minimum viable loop**: 1 automation + 1 skill + 1 state + 1 gate. Build order: manual chạy ổn → skill hoá → wrap loop → schedule.
6. **Failure modes**: Ralph Wiggum loop (exit khi nửa chừng — fix bằng gate khách quan, không phải agent tự nhận "done") · goal drift · self-grading bias · comprehension debt (vẫn phải đọc diff) · security tax (SAST, secret scan, audit permission 30 ngày).
7. **Guardrail quan trọng**: human review trước hành động irreversible (merge, deploy, dep change). Review capacity là trần của parallelism.

## Gap analysis — project đã có gì / thiếu gì

| Building block | Trạng thái | Chi tiết |
|---|---|---|
| Skills | ✅ mạnh | linear-pm-workflow, figma-*, auxi-qa-*, auxi-launch-notify, CLAUDE.md per-repo |
| Sub-agents maker/checker | ✅ | mobile-dev/backend-dev (maker) vs qa-mobile/qa-ui/qa-ux + tech-lead (checker) |
| Connectors | ✅ | Linear MCP, gh CLI, Railway/Sentry/Figma/Slack MCP |
| Objective gates | ✅ | tsc, lint, jest / pytest unit+integration, test_server.py, auxi-lint-tokens.sh |
| Worktrees | ✅ | worktree skill + isolation:worktree |
| Release notify | ✅ | auxi-deploy-testflight → auxi-launch-notify (GH release + Linear comment + CHANGELOG, idempotent) |
| **Automations (heartbeat)** | ❌ **gap #1** | Không có gì chạy theo lịch. PM sweep chỉ chạy "when the user asks". Mọi chain đều cần user gõ prompt |
| **Auto hand-off giữa agents** | ❌ **gap #2** | pm.md: "You don't dispatch other agents directly — produce a hand-off the user routes". User đang là cái loop |
| **Auto Done on verified** | ❌ **gap #3** | Verification gate có trong skill nhưng không ai tự chạy + tự flip ticket |
| Hard stops / budget | ❌ | Chưa định nghĩa retry limit, token cap, iteration cap ở đâu |
| Metric (cost per accepted change) | ❌ | Chưa track |

Kết luận: project đã có 4/5 building blocks — chỉ thiếu đúng **heartbeat + orchestrator loop**. Đây là điểm áp dụng giá trị nhất của bài.

## 4-condition test cho project này

1. Repeat weekly? ✅ ticket Linear ra liên tục.
2. Verification automated? Backend ✅ hoàn toàn (pytest, test_server.py). Mobile ⚠️ một nửa (tsc/lint/jest máy check được; sim screenshot cần qa agent → vẫn automatable qua mobile-mcp nhưng chậm + flaky hơn).
3. Token budget? ✅ (Max plan).
4. Senior tools? ✅ sim, Railway logs, Sentry, psql.

→ Pass. Backend tickets là ứng viên loop tốt nhất (gate 100% máy check). Mobile sau.

## Đề xuất: "Wardrobe Autopilot" — 3 phase

**Nguyên tắc giữ lại từ thread:** Linear = state machine duy nhất · maker ≠ checker · PR merge là hành động irreversible duy nhất giữ cho human · mọi exit condition là gate khách quan, không phải agent tự nhận done.

### Phase 0 — config 1 lần, không tốn token (làm ngay)
- Bật **Linear GitHub integration** (native): branch `*/au-xxx-*` hoặc "Fixes AU-XXX" trong PR → ticket tự sang In Review khi PR mở, tự sang **Done khi PR merge**. Đây chính là "kéo Done" rẻ nhất, zero agent.
- Chuẩn hoá branch naming + commit footer `Refs: AU-XXX` (auxi-launch-notify đã parse pattern này sẵn).

### Phase 1 — Sweep loop (read-mostly, an toàn nhất, build trước)
Scheduled routine (cron / `/schedule`) chạy 1-2 lần/ngày, dùng pm agent:
1. Quét board: ticket In Review có PR merged + evidence đủ (commit SHA, test output, qa sign-off comment) → flip **Done** + closing comment theo template linear-pm-workflow.
2. Ticket stale >3d → ping comment; Blocked >5d → escalate (Slack/notification cho user).
3. Output: 1 bảng sweep + log vào Linear comment (state persistence).
Hard stop: read + comment + state transition only — không đụng code.

### Phase 2 — Ticket→PR loop (backend trước, mobile sau)
Skill mới `linear-autopilot.md` + orchestrator chạy khi user trigger (hoặc schedule):
1. Pick ticket `Todo` + `role:backend-dev`, priority cao nhất, có AC đủ chuẩn template. Move In Progress + comment.
2. Worktree branch `feat/au-xxx-slug` → dispatch backend-dev với AC làm spec.
3. Gate: pytest unit+integration + test_server.py + secret scan. Fail → retry tối đa 2; vẫn fail → Blocked + comment lý do.
4. Checker riêng (tech-lead review / code-reviewer agent) — không cho maker tự chấm.
5. Mở PR "Fixes AU-XXX" + comment evidence lên ticket → In Review. **Dừng. Human merge.**
6. Merge xong → Phase 0 integration tự flip Done, Phase 1 sweep xác nhận evidence.
Mobile variant: thêm qa-mobile smoke + qa-ui compare (nếu có Figma) trước khi mở PR.
Hard stops: 1 ticket/run · 2 retries/gate · skip ticket đụng auth/payments/migration (label `needs-human`).

### Phase 3 — Release + notify chain
- Sau khi user quyết release (tech-lead decides, devops executes): `auxi-deploy-testflight` → `auxi-launch-notify` (đã có) → **thêm surface 4: Slack message** (Slack MCP đã connect) — "build N live, changes: …, Linear: …".
- Backend: Railway deploy success → comment lên ticket liên quan + Slack. Sentry alert mới sau deploy → auto file ticket Linear (connector ROI #4 trong thread).

### Metric
Track "cost per accepted change": ticket autopilot mở PR → merged không cần rework = accepted. <50% acceptance → loop đang lỗ, dừng tune lại (đúng Step 11).

## Những gì KHÔNG nên làm (theo chính bài này)
- Không auto-merge PR, không auto-deploy prod — review capacity là trần, human giữ nút merge.
- Không cho loop làm architecture work / vague product work — chỉ ticket có AC máy-check được.
- Không tin "agent nói done" — exit condition = PR URL tồn tại + gates green + evidence comment tồn tại.
- Vẫn đọc diff — comprehension debt là nợ thật.

## Unresolved questions
1. Linear GitHub integration đã bật cho repo auxi-mobile/wardrobe-backend chưa? (cần check Linear settings — quyết Phase 0)
2. Heartbeat chạy ở đâu: `/schedule` cloud routine (không cần máy bật) vs cron local (cần Mac chạy, nhưng có sim cho qa-mobile)? Mobile QA cần sim → Phase 2 mobile bắt buộc local.
3. Slack channel nào nhận notify?
