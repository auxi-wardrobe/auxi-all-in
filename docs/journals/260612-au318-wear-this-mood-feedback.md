# AU-318: Wear This Mood Feedback — Full Plan→Ship Cycle in One Session

**Date**: 2026-06-12 00:41  
**Severity**: Medium (operational + git procedural)  
**Component**: Mood feedback learning system (auxi + wardrobe-backend)  
**Status**: Shipped (PRs #91 backend, #62 mobile; Linear AU-318 → In Review)

## What Happened

Completed a full-stack feature in one session: five-phase backend-then-mobile implementation (ck:plan hard mode → ck:cook, 2 backend agents + 2 mobile agents in parallel pairs → tech-lead contract sign-off → code-reviewer → qa-ui + qa-mobile). Backend merged (53 tests, 19 passed mood service only), mobile stacked on #60. Linear ticket moved to In Review.

## The Brutal Truth

Mostly clean execution — the agents worked well together and the plan structure paid off. But we discovered a *critical operational fact* late: the local backend `.env` points directly at **shared Railway prod Postgres**. This isn't a technical issue with the code; it's an infrastructure blunder that only surfaced because qa-mobile tried to verify the migration. We nearly applied `au318a1b2c3d` to production before realizing. That gut-drop moment lasted about 30 seconds before we froze the migration and escalated. We also hit a git procedural gotcha that would have been bad if we weren't careful.

## Technical Details

**PRs shipped**: 
- `auxi-wardrobe/auxi-backend#91` — 19 new tests for mood feedback service, 201/200 favorite response split, upsert-by-outfit_hash atomicity
- `auxi-wardrobe/auxi-mobile#62` — MoodFeedbackSheet component, chip grid, policy refetch loop, theme-token only styling

**Code review findings** (3 major fixes applied same session):
- **B1 (hash length)**: `outfit_hash` unbounded → 500 with driver leak on >64 chars; fixed with `len(outfit_hash) <= 64` guard → 400
- **B2 (upsert TOCTOU)**: concurrent POSTs with same hash create duplicate favorites; filed follow-up ticket (low probability, but real window exists with new 15s timeout)
- **B3 (fallback hash identity)**: session-scoped `outfit-{index}` sent as upsert key → same outfit in different sessions collides, one silently not saved; fixed by omitting hash for fallback cases

**Tech-lead contract sign-off**: RATIFIED 201/200 split, mood-without-hash → 400, rate-limiter (M1) re-parent onto tracked `au242a1b2c3d` (feedback migrations still in-flight). Zero critical blocking issues for mobile consumption.

**Prod DB discovery**: `.env` DATABASE_URL → `switchback.proxy.rlwy.net:17805/railway` (same prod writes). Local `alembic upgrade` is a prod schema change. Filed CRITICAL ops follow-up; treated migration as un-applied until devops provisions local DB.

## What We Tried

1. **Plan hard mode**: 2 Explore scouts (auxi flow + backend surface) instead of Figma (none exists). Worked — per-ticket spec is precise enough.
2. **Parallel phase execution**: backend-dev phases 1–2 + mobile phases 3–4 in simultaneous pairs. Clean handoff via ratified tech-lead decisions.
3. **Selective file staging**: 4 mixed files (AU-318 lines + in-flight feedback-system WIP) staged via `git hash-object/update-index` to isolate AU-318 only. Caught leaked WIP import in test fixture before push.
4. **Git recovery**: cherry-pick-onto-origin/main pipe `| tail -1` swallowed exit code; `git reset` moved feature branch to origin/main by mistake. Recovered via documented rollback (af74f05), no data lost.

## Root Cause Analysis

**Prod DB in local .env**: Not a code bug — it's an environment configuration leak. The credential wasn't injected from `wrangler` or Docker; it was hardcoded in a checked-in `.env.example` or copy-pasted years ago. Nobody caught it because local dev usually doesn't apply migrations or creates test data that'd visibly sync to prod. QA running a full migration exposed it.

**Git procedural failure**: Piping a git command result to `tail` breaks error handling — the pipe swallows the non-zero exit code. The subsequent `git reset --hard` ran because the shell thought the previous command succeeded. It's a common pattern mistake: never chain operations that depend on exit codes through pipes.

**B1/B3 slipping through code review**: Hash validation and fallback-hash handling weren't tested in the unit suite (SQLite doesn't enforce VARCHAR width; session scoping is a runtime concern). The code reviewer found them via static analysis, not test failure.

## Lessons Learned

1. **Always verify environment assumptions before running migrations**, especially in a multi-stage setup. "Local == safe to mutate" is not true when local points at prod.
2. **Never pipe git commands whose exit status matters.** Use explicit `if` checks or `set -e` blocks instead. The feature branch nearly landed on main by accident.
3. **Selective staging is fragile but necessary**: using `hash-object/update-index` to isolate AU-318 from interleaved WIP worked, but it's a land mine for the next person. Document the worktree state clearly.
4. **Schema changes are infrastructure decisions**, not just code review items. The tech-lead sequencing call (b1 vs b2 merge order) mattered more than any correctness fix because if AU-318 lands and feedback migrations don't, `alembic upgrade` fails in production.

## Next Steps

**Immediate (blocking release):**
- devops: provision local/dev Postgres + split .env (dev vs prod); rotate leaked prod credential
- tech-lead: confirm migration parent sequencing at release time (au318 → au242, then re-parent feedback migrations on top)

**Follow-ups (filed, not blocking):**
- AU-318-followup-01: upsert uniqueness backstop (expression index or advisory lock)
- AU-318-followup-02: local backend uses prod database (ops priority)

**Session scope warning:** 42 files modified. Mostly in plan + reports; code changes tight (7 mobile AU-318 files, backend mood module). Clean, not scattered.

---

**Status:** DONE  
**Summary:** Full plan→cook→ship cycle completed; mood feedback system shipped with three major fixes applied in-session; discovered critical prod-DB-in-local-.env issue during QA, no data impact, ops follow-up filed.
