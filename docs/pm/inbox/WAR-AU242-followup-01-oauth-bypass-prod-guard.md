---
id: WAR-AU242-FU-01
parent: AU-242
type: bug
title: "[B2] OAuth test bypass env vars need prod startup guard"
state: Backlog
priority: P1
labels: [type:bug, area:backend, role:backend-dev, security, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 1h
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

`wardrobe-backend/services/oauth_service.py:58, 134` reads
`GOOGLE_OAUTH_TEST_BYPASS=1` and `APPLE_OAUTH_TEST_BYPASS=1` env vars
unconditionally — both disable JWT signature verification entirely.
If either is set in production by accident, anyone can forge an OAuth
identity token = total account-takeover vector.

This was acceptable for Phase 05 test harness (PR #27) but must be
hard-blocked before any production rollout.

## Acceptance criteria

- [ ] Add startup assertion in `wardrobe-backend/app.py` lifespan that
      raises and crashes the app on boot if either bypass env is set
      AND `settings.ENV == 'production'`.
- [ ] Assertion message lists the offending env var(s) and exits non-zero
      so deployment platform marks the deploy failed.
- [ ] Add unit test `tests/test_app_startup.py::test_oauth_bypass_blocked_in_prod`
      that monkeypatches ENV=production + bypass=1, asserts boot fails.
- [ ] Document the guard in `API_DOCUMENTATION.md` under the OAuth env
      section.

## Out of scope

- Removing the bypass mechanism entirely (still needed for staging/CI).
- Changing OAuth verify logic itself.

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding B2
- Files: `wardrobe-backend/services/oauth_service.py:58`,
  `wardrobe-backend/services/oauth_service.py:134`,
  `wardrobe-backend/app.py` (lifespan)
- Parent: AU-242
