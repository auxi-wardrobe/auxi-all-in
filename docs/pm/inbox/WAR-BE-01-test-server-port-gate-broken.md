---
id: WAR-BE-01
parent: none
type: bug
title: "[backend] test_server.py e2e gate broken — app.py hardcodes port 5001, harness probes 5002"
state: Backlog
priority: P2
labels: [type:bug, area:backend, role:backend-dev, ci, testing]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 0.25d
linear_sync_status: pending
created: 2026-06-11
---

## Context

Found during the V05 diversity pivot (260611): the repo-wide pre-commit gate
`python test_server.py` cannot pass on ANY branch — `app.py:320` hardcodes
`port=5001` and ignores the `PORT` env var that `test_server.py` sets before
probing `:5002`. The probe always gets connection-refused.

Two independent backend-dev agents confirmed it on clean `origin/main`.
Workaround used: boot via `python3 -m uvicorn app:app --port 5002` and probe
`/health` manually.

## Acceptance criteria

- [ ] `app.py` honors `PORT` (env) with 5001 default.
- [ ] `python test_server.py` passes on a clean main checkout.
- [ ] CLAUDE.md pre-commit instructions verified accurate afterward.
