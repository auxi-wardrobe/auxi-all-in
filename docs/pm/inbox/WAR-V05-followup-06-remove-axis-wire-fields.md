---
id: WAR-V05-FU-06
parent: V05-LLM-pivot
type: chore
title: "[V05] Remove deprecated axis/variation_axis wire fields after mobile N+1"
state: Backlog
priority: P3
labels: [type:chore, area:backend, role:backend-dev, v05, try-another, api-contract]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 0.25d
linear_sync_status: pending
created: 2026-06-11
---

## Context

The diversity pivot (`plans/260611-2012-v05-diversity-try-another/`, branch
`feature/v05-diversity-try-another`) deprecated but kept the axis wire fields for
backward compat:

- `TryAnotherRequest.axis` — accepted, ignored, `deprecated:true` in OpenAPI
- `TryAnotherResponse.variation_axis` — always `null`, Optional
- `VariationAxis` enum in `schemas/v05_try_another.py`

Mobile sync (auxi branch `feature/v05-drop-axis-plumbing`) already confirmed
**zero senders and zero readers** in the app; admin tester sends `axis: null`
(tolerated until its own cleanup).

## Acceptance criteria

- [ ] Mobile release N+1 (containing `feature/v05-drop-axis-plumbing`) is live.
- [ ] Remove `axis` request field, `variation_axis` response field, and the
      `VariationAxis` enum from `schemas/v05_try_another.py` + router.
- [x] Update admin tester `tryAnotherV05AsUser` to stop sending `axis: null` —
      done early in PR #90 (`b5a8913`, deployed to wardrobe-admin 2026-06-11).
- [ ] `API_DOCUMENTATION.md` + `docs/v05-try-another-mobile-contract.md` scrubbed.
- [ ] Tech-lead sign-off (contract change, breaking for any unknown client).

## Refs

- Tech-lead sign-off note: `plans/260611-2012-v05-diversity-try-another/reports/tech-lead-260611-contract-signoff.md`
