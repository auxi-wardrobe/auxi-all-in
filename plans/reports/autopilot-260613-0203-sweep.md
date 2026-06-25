# Linear Sweep — 2026-06-13 ~02:20 (Phase 1)

Team Auxi, cycle 13. In Review + In Progress reconciled vs live git/PR state. Result: **near-idempotent** — every ticket was already swept ~24–43h ago (within anti-spam windows) and nothing material changed, so no new sweep comments posted. Real value tonight is in Phase 2/3 execution (turning stalled/red work into PRs).

## In Review (7) — verdicts

| ID | Verdict | Why / blocker | Action |
|----|---------|---------------|--------|
| AU-318 | R2 (hold) | PRs merged (#91/#62/#65). Only blocker: prod migration `au318a1b2c3d` not confirmed applied. #93 merged "merge alembic heads" (code), not a prod `alembic upgrade head`. | Needs **devops** to apply+confirm on prod, then closes. Did NOT probe prod DB (gated). |
| AU-314 | R3 / needs-human | FE done, no PR linked. Blocked on backend security decision: `/api/auth/email-precheck` returns "password" for anon callers (account-enumeration guard) so "email not found" branch never fires. | Product/security call — leave for human. |
| AU-298 | actionable | Stalled 16d, no PR. Root cause CONFIRMED this session: not a mobile wording bug — backend `/wardrobe/filter` maps `one_piece`→ literal `['dress','jumpsuit']` instead of canonical `category_family='FULL_BODY'` (AU-299 rule) → matches nothing. | **Queued for backend autopilot** (overlaps AU-324/256). |
| AU-80 | R3 | Core shipped, polish gaps: crop 3:4 + file-size limit not implemented. No merged PR linked. | Small follow-up; queue if time. |
| AU-289 | R3 | No PR, but CEO fully clarified scope in-thread (Material multi-select, new Energy 7-tag set, Style multi-select + new Dress Code field, hide Edit/Delete on system items, Favourite/Less-used UI, drop Purchase Date). | Now buildable — overlaps AU-330/AU-87 item-detail cluster. Feature-sized. |
| AU-288 | R3 | No PR, assigned Hiệp. Needs CEO's transparent PNG assets (Google Drive folder) to replace non-transparent common-item images. | Asset-dependent; leave for assignee. |
| AU-286 | needs-QA | Reported fixed (infra cause) 05-27. Needs qa-mobile sim re-verify to close. | Sim verify when available. |

## In Progress (5) — staleness (R4 >3d / R5 >5d)
AU-261, AU-253 (updated 06-12), AU-259, AU-254, AU-285 (updated 06-11 ~43h). None past R4 threshold yet. No pings needed. All are large UAC specs owned by team members — not autopilot-eligible (feature-sized, assigned).

## Needs attention (escalations / human-only)
- **AU-318** → devops: apply + confirm prod migration `au318a1b2c3d`. Until then mood submit/policy 500 (client degrades gracefully by design).
- **AU-314** → tech-lead: decide whether to expose "email not found" to anon callers (account-enumeration tradeoff).
- **`.env` = shared PROD Postgres** (from prior session memory) — local migrations are prod changes. Did not touch.

## Writes this run: 0 sweep comments (all within anti-spam window; state unchanged).
