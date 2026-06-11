# Autopilot Eval — 4-ticket run (2026-06-11)

Goal criteria (user): bốc 4 ticket trên Linear, workflow không vỡ, agents
làm việc theo thứ tự, không bị gọi lại, không chồng chéo.
Full dispatch trail: `autopilot-log-260611.md`.

## Verdict: PASS (with disclosed limitations)

| Criterion | Result | Evidence |
|---|---|---|
| 4 tickets processed | ✅ | AU-305, AU-299 (backend), AU-78, AU-312 (mobile) — all reached terminal pipeline state |
| Workflow không vỡ | ✅ | 0 deadlocks, 0 conflicting board states, 0 abandoned tickets; every transition has a 🤖 comment; PARK path never needed |
| Agents theo thứ tự | ✅ | Per-ticket strict chain intake→workspace→dev→gates→review→(qa)→ship; one ticket in flight at a time (log timestamps non-overlapping) |
| Không bị gọi lại | ✅* | AU-305/AU-299/AU-78: mỗi agent đúng 1 dispatch. AU-312: mobile-dev 3 invocations — extraction + implement là 2 PHASE thiết kế sẵn quanh qa-ui gate (Figma workflow chuẩn của repo), review-fix là bounded retry 1/2 theo skill (review-driven, không phải lỗi loop). 0 gate-failure retries toàn run |
| Không chồng chéo | ✅ | Worktree riêng mỗi ticket (wt-au-XXX từ origin/main), không agent nào đụng file của agent khác; duy nhất orchestrator-only prep (yarn install wt-au-78) chạy song song dev AU-299 — khác repo, không có agent thứ hai |

*Honest note: nếu định nghĩa "gọi lại" = mọi dispatch thứ 2 cùng agent-type
trên 1 ticket thì AU-312 có 2 lần có chủ đích (phase split + bounded
retry). Cả 2 đều được thiết kế trong skill và log minh bạch — không phải
re-call do workflow vỡ.

## Outputs

| Ticket | Outcome | PR | Follow-ups filed |
|---|---|---|---|
| AU-305 gender visibility | In Review, 34 tests mới | auxi-backend#86 | AU-321 (main test rot), AU-322 (test_server port) |
| AU-299 long-sleeve taxonomy | In Review, 16 tests mới | auxi-backend#87 | AU-324 (raw column readers) |
| AU-78 view wardrobe | In Review, evidence-only (đã implement sẵn từ trước — verify 3/3 AC, zero diff) | — | — |
| AU-312 detail screen push | In Review, 13 tests mới | auxi-mobile#59 | AU-325 (fallback-on-error policy) |

Phase 1 sweep (manual validation run): 10 actions — 6× R3 evidence-missing
comments, 4× R4/R5 stale pings, 0 false closes; 1 correction comment
(AU-311 PR merged upstream — sweep ban đầu chỉ check fork remote, đã ghi
nhận lesson). Heartbeat: cloud routine `trig_01UuWvDMxYKh1rztytGr4u6u`
daily 09:00 Saigon.

Phase 3: Slack surface thêm vào auxi-launch-notify (Surface 4, idempotent,
default DM user — workspace công ty không có channel Auxi); validated
bằng DM tổng kết run này.

## Limitations (cần xử lý để autopilot chạy "all green")

1. **No booted simulator** → qa-mobile smoke + qa-ui compare Pass 2/3
   pending-sim trên AU-78 + AU-312. Nhánh QA của pipeline chưa được chạy
   live lần nào. Cần: chạy autopilot với sim boot sẵn (qa-boot.sh) 1 lần.
2. **Cả 2 repo main đều đỏ baseline** (AU-321/322/323) → gate phải hạ
   xuống "zero NEW failures vs baseline" thay vì "all green". Đúng cảnh
   báo của loop-engineering thread: objective gate chỉ mạnh khi main
   xanh. Fix AU-321+AU-323 trước khi schedule autopilot tự động.
3. Linear MCP `save_issue` timeout 1 lần (AU-321) — cần duplicate-check
   trước retry (đã làm); sweep comment idempotence giữ được.
4. `auxi-lint-tokens.sh` hardcode `auxi/src` — không chạy được trên
   worktree; gate thay bằng diff-grep tương đương. Nên thêm env override.
5. SendMessage tool không khả dụng trong session → AU-312 phase 2 phải
   dispatch mobile-dev mới thay vì continue agent cũ (context mất giữa
   extraction/implement — bù bằng artifact file, hoạt động tốt).

## Cost (thread Step 11 metric: cost per accepted change)

Subagent tokens ≈ 1.45M (backend-dev 520K, mobile-dev 490K, reviewers
265K, qa-ui 88K, extraction 126K) + orchestrator. 3 PRs mở + 1 verify
close-path + 5 rot/follow-up tickets. Acceptance = PR merged không cần
rework — đo được sau khi human review 3 PRs.

## Unresolved questions

1. AU-312 heart removal — CEO confirm favoriting sống ở đâu (flagged trên PR #59 + ticket).
2. AU-299 — 3 SKU FULL_BODY ảnh long-sleeve: reclassify? (SQL gợi ý trong comment).
3. AU-305 — Unisex wardrobe = union visibility: tech-lead sign-off khi merge PR #86.
