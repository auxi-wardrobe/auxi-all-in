---
id: WAR-PR-001
type: chore
title: "[Task] One-shot QA boot script for backend + mobile + iOS sim"
state: Done
priority: P2
labels: [type:chore, area:both, role:tech-lead, source:pr]
source_pr: https://github.com/ducga1998/auxi-all-in/pull/1
source_repo: wardrobe_project (umbrella)
author: ducga1998
merged_at: 2026-05-05T06:11:52Z
created: 2026-05-05
---

## Context

Bringing up the full local stack used to be a multi-step ritual: start
backend venv, free ports, boot iOS sim, start Metro, run yarn ios, verify
both healthy. Drift between developer machines made QA setup unreliable.

This PR introduces `scripts/qa-boot.sh` and `scripts/qa-stop.sh` so QA
sessions begin with one command and end clean — backend on :5001, RN on
the iOS simulator, healthchecks confirmed, QA test account credentials
printed in the hand-off.

## What shipped

- `scripts/qa-boot.sh` — preflight, free ports, boot backend (.venv +
  uvicorn + `/docs` healthcheck), start iOS sim, Metro, `yarn ios`,
  bundle-id verify, prints QA hand-off block with test creds.
- `scripts/qa-stop.sh` — reads `logs/pids.txt`, kills backend + Metro,
  frees ports, leaves the iOS sim running so QA state survives between
  runs.
- Pre-registered QA test account on local backend
  (`qa-test@auxi.app` / `QaTest!2026`) printed in hand-off.
- Umbrella `README.md` updated with the entry point.

## Acceptance criteria

- [x] Fresh boot ends with green block + both apps reachable (backend
      `/docs` 200 OK, app on sim).
- [x] Idempotent re-run — re-running `qa-boot.sh` while stack is up kills
      existing :5001 + :8081 listeners and re-boots cleanly.
- [x] `qa-stop.sh` returns `lsof -ti :5001 :8081` to empty.
- [x] Failure paths print diagnostics — backend startup failure shows last
      20 lines of `backend.log` and exits 1.
- [x] `logs/backend.log` and `logs/metro.log` populated for bug reports.

## Out of scope

- CI orchestration, cloud device farms, or remote QA — local-only.
- Android sim boot path.

## Verification

- Author confirmed full boot ~1m 39s wall time on warm system.
- `./scripts/qa-boot.sh` followed by `./scripts/qa-stop.sh` round-trip
  verified.

## Notes

Built via subagent-driven-development: 7 tasks, fresh implementer + spec
reviewer + code quality reviewer per task, all APPROVED. Spec at
`docs/superpowers/specs/2026-05-05-qa-boot-script-design.md`.
