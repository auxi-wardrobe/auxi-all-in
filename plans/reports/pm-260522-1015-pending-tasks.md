---
title: "PM Sweep — Pending / In-Flight Tickets"
date: 2026-05-22
timezone: Asia/Saigon
author: pm (subagent)
linear_workspace: duncan-1 (intended)
data_source: LOCAL ONLY — Linear MCP not callable this session
---

# PM Sweep — anh có gì đang dang dở?

## ⚠️ Linear access — chưa pull được

**Status: Linear MCP không gọi được trong session này.**

Hai connector Linear cùng có trong `claude mcp list`:

| Connector | State | Vấn đề |
|---|---|---|
| `claude.ai Linear` | ✓ Connected | Đang đăng nhập workspace **`Advergame`**, không phải `duncan-1` nơi chứa AU-* tickets. `get_issue AU-xxx` sẽ trả "Entity not found". |
| `plugin:linear:linear` | ! Needs authentication | OAuth không persist giữa session — phải authorize + paste callback URL hàng session, lần này chưa làm. |

Tool harness của subagent này **không expose `mcp__claude_ai_Linear__*` functions** trực tiếp, và `gemini` CLI fallback bị block do `GEMINI_API_KEY` chưa set.

**Báo cáo dưới đây dựng từ nguồn local** (PM inbox sync files, plan dirs, git worktrees, commit log, QA findings, roadmap doc). Status, priority, assignee, last-update là **suy luận từ code activity**, không phải state Linear thật.

### Cách fix bền vững (chọn 1, anh đã từng review 2026-05-21)

- **A. Đổi workspace claude.ai Linear connector** → claude.ai → Settings → Connectors → Linear → Disconnect → Connect lại, chọn `duncan-1`. Sau đó `claude.ai Linear` đi thẳng workspace đúng.
- **B. Linear PAT qua env var** → tạo personal token tại https://linear.app/duncan-1/settings/api → `export LINEAR_API_KEY=lin_api_xxx` trong shell rc → em query qua `curl https://api.linear.app/graphql`.
- **C. (tạm thời)** complete OAuth flow của `plugin:linear:linear` mỗi session đầu tiên trước khi chạy PM sweep.

Em đề xuất **B** cho headless agent work (không cần OAuth callback paste).

---

## Bảng status (suy luận từ local artifacts)

Sort: status → priority (P0→P3) → last activity desc.

| ID | Title (suy luận) | Status | Owner | Pri | Last activity | Source / note |
|---|---|---|---|---|---|---|
| **AU-242** | UAC v2 — Auth & Account Access flow (13 screens, 9 BE endpoints) | **In Progress** | mobile-dev + backend-dev | P1 | 2026-05-22 (hôm nay) | Backend phase 02 done (`feat/au-242-phase-02-backend-endpoints` HEAD `d38f088`, 39/39 pytest green). Mobile phase 01+03+04 đã có code trong 7 worktree (`auxi-au242-phase-*`). Phase 03 (API doc + service sync) đang chạy. Phase 04 đang split batch B/C/D. Phase 05 (OAuth) chưa start. Phase 06 (email service) đã DEFER. |
| **AU-243** | Onboarding redesign + Recommend Engine MVP (parent + 6 phases) | **In Progress / partial** | backend-dev + mobile-dev | P1 | 2026-05-22 (V05 LLM-1/LLM-2 shipped recent) | 7 sync files trong `docs/pm/inbox/WAR-AU243-*`. Backend đã ship phase 0+1 (V05 foundation + LLM-1 diversifier) — commits `1ce8749`, `8ac4eca`. Phase 2 LLM-2 style feedback merged (PR #57, `864767c`). Phase 3 affinity/mood chưa start. Mobile entry-point swap (legacy → PreferenceSeed/FitPreference) **vẫn chưa làm** — note trong `auxi/CLAUDE.md`. |
| **AU-252** | "Try Another" batch refresh (Remix replacement) | **In Progress / Review** | mobile-dev + backend-dev | P1 | gần đây | Backend contract đã ship (`docs/v05-try-another-mobile-contract.md`). Mobile wire-up: `b94ed364 feat(home): wire V05 buildRecommendation as the home-load endpoint` — đã merge vào main. Roadmap ghi "Modal UX refinement complete (AU-252) 🚧 In progress, due 2026-05-20" → có thể đã miss deadline 2 ngày, cần xác nhận trên Linear. |
| **AU-287** | Common items not allowed to delete permanently (bug) | **DONE (chờ verify)** | mobile-dev (duc2820) | P2 | gần đây | **BE merged**: PR #61, `53dd7ea fix(wardrobe): block delete of USR_* catalog clones`. **FE merged**: PR #22, `da121825 fix(item-detail): hide delete for catalog items + explainer`. Worktree còn tồn tại nhưng commits đã land main. Cần qa-mobile verify on TestFlight build 5/6 rồi close. |
| **AU-289** | Item Detail / metadata editing (8 modals) | **Todo / Spec ready** | mobile-dev (chưa pick) | P1 | 2026-05-22 (audit hôm nay) | Audit UI + UX đã xong: `auxi/docs/qa-findings/2026-05-22-ui-au-289-item-detail.md` (9 P0 / 9 P1 / 6 P2) + `2026-05-22-ux-au-289-item-detail.md`. **9 P0 merge-gate** — phần lớn là missing feature (8 modals chưa build). Branch `duc2820/au-289-uac-item-detail-metadata-editing` không tồn tại locally hoặc trên origin → chưa start implement. |
| **AU-272** | Item Detail accent color token confirm | **Blocked (designer pending)** | mobile-dev | P3 | từ phase AU-242 | TODO comment trong ItemDetailScreen: `// TODO AU-272: pending designer confirm — keep '#1d1f23' until token approved`. Chờ designer (anh CEO) confirm token. Không block ai khác. |
| **AU-251** | Remix `/next` PoolExhausted follow-up | **CANCEL candidate** | backend-dev | — | 2026-05-08 (Wave 5 resolved) + 2026-05-11 PM dropped Remix entirely | `docs/pm/inbox/WAR-AU251-followup-pool-exhaustion.md` ghi "Resolved by Wave 5 (2026-05-08)". Memory note 2026-05-11: "Remix killed, Try Another wins. AU-251 BE 4-axis code dead". Nếu Linear vẫn open → **propose Cancel** với comment trỏ về AU-252. |
| **AU-220 → AU-226** | UI audit follow-ups (home modes, pin, swipes, mood-check, auto-removeBG, love, dual-onboarding) | **Backlog / spec only** | mobile-dev | P2 | từ tháng trước | 11 spec files trong `docs/pm/inbox/WAR-AUDIT-*.md`. Không thấy commit nào tham chiếu AU-220–226 trong 30 ngày qua. **Đang rotting** — cần review xem có còn relevant không. |
| **AU-233** | (chưa rõ — chỉ thấy ID trong audit doc) | **Unknown** | — | — | — | Cần pull Linear để xác minh. |
| **AU-259** | V05 eval rubric (official Viet rubric) | **DONE? — chờ Linear xác nhận** | tech-lead / em | P2 | gần đây | Commit `ccc05ed feat(skill): replace v05-eval rubric with official Viet rubric (AU-259)`. Có vẻ done — cần Linear check. |
| **AU-260** | M catalog seed (V05 LLM pivot dependency) | **In Progress (anh Viet own)** | anh Viet | P1 | từ tuần này | Tham chiếu trong `docs/v05-llm-pivot-design-spec.md`: "M catalog seed (parallel work, anh Viet pending)". Em không own, không có visibility. |
| **AU-262** | V05 skipped reason granularity | **DONE? — em đã ship** | backend-dev | P2 | từ tuần này | Spec ghi "em đã ship". Cần Linear verify để close. |
| **AU-222** | (audit follow-up) | **Backlog** | — | P2 | — | Cùng nhóm với AU-220–226. |

---

## Highlight: stalled / cần attention

| Ticket | Triệu chứng | Khuyến nghị |
|---|---|---|
| **AU-251** | Code đã đào sâu, follow-up resolved 2026-05-08, **product decision 2026-05-11 đã kill Remix**. Nếu Linear vẫn open → đang chiếm slot, gây nhầm. | **Cancel** với comment: "Remix feature dropped 2026-05-11. Superseded by AU-252 Try Another. Closing as won't-do." |
| **AU-220 → AU-226 / AU-233** | 11 audit spec files đã sit yên trong `docs/pm/inbox/` từ trước AU-242. Không có commit reference trong git log của 2 submodules trong 30 ngày qua. | **Triage**: anh cho em review từng cái, decide nào còn relevant sau dual-Home migration. Cái không còn relevant → cancel. |
| **AU-252** | Roadmap ghi deadline "Modal UX refinement complete 2026-05-20" → trễ 2 ngày. BE + FE đã wire (`b94ed364`), nhưng "modal UX refinement" có thể là việc sau wire-up. | Xác nhận trên Linear: AU-252 còn open hay đã close? Nếu open → comment latest progress + dời deadline. |
| **AU-289** | Audit hôm nay tìm thấy **9 P0 merge-gate** (missing-feature, không phải drift). Branch chưa tạo. Đây là ticket nặng (~7-10 ngày implement) nhưng đang block khả năng anh ship metadata editing. | Decide priority sequencing: ship AU-242 xong rồi mới start AU-289, hay parallel? Em đề xuất sequential (AU-242 đang dùng nhiều file overlap với ItemDetail). |
| **AU-272** | Token nhỏ, designer chưa confirm sau ~tuần. Low priority nhưng cần ping. | Ping designer 1 lần cho dứt; nếu vẫn quiet, em chốt giá trị tạm và move on. |

---

## Đếm theo bucket

| Bucket | Count | Tickets |
|---|---|---|
| In Progress | 4 | AU-242, AU-243, AU-252, AU-260 |
| In Review / chờ verify close | 3 | AU-287, AU-259, AU-262 |
| Blocked | 1 | AU-272 (designer) |
| Todo (spec ready, chưa pick) | 1 | AU-289 |
| Backlog (đang rotting) | ~8 | AU-220, AU-221, AU-222, AU-223, AU-224, AU-225, AU-226, AU-233 |
| Cancel candidate | 1 | AU-251 |

---

## 3 recommended next actions (priority order)

1. **Mở Linear, đổi workspace của connector `claude.ai Linear` sang `duncan-1`** (option A trong block đầu) — hoặc set `LINEAR_API_KEY` env var. Cho đến lúc đó, mọi PM sweep từ headless agent đều phải dùng local fallback như báo cáo này, dễ miss state Linear thật. **Cost: 2 phút. ROI: cao.**

2. **Cancel AU-251 trên Linear** với comment trỏ về AU-252 + memory note 2026-05-11. Nếu vẫn open thì nó đang gây nhiễu khi sweep và đếm "đang dang dở" sai. Không tự đóng — chờ anh confirm vì em không có Linear access lúc này.

3. **Decide sequencing AU-242 vs AU-289**. AU-242 đang chạy 6 worktree, sắp hết phase 04. AU-289 audit vừa xong với 9 P0 merge-gate, không nên start parallel vì cùng động vào `ItemDetailScreen.tsx`. Đề xuất: ship AU-242 phase 04+05+07 (Maestro QA) xong → close → kick off AU-289 với 1 worktree riêng. Timeline: AU-242 còn ~10 ngày, AU-289 ~7-10 ngày → end-of-June có cả 2.

---

## Open questions

- Linear thật của các ticket trên có khớp suy luận này không? Cần verify sau khi unblock Linear MCP.
- AU-233 reference trong audit doc — đây là cái gì? Em không có local trace.
- AU-243 phase 3 (affinity/mood/novelty) có owner Linear chưa, hay vẫn "queued"?
- AU-252 còn task gì sau "Modal UX refinement" để justify open status, hay close được rồi?
- AU-260 (M catalog seed của anh Viet) có ETA không? Nó block phần nào của V05 LLM pivot?
