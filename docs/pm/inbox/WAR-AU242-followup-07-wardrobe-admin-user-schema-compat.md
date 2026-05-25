---
id: WAR-AU242-FU-07
parent: AU-242
type: chore
title: "[M7] Wardrobe-admin compat with new User schema"
state: Backlog
priority: P3
labels: [type:chore, area:wardrobe-admin, area:backend, role:tech-lead, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: tech-lead (coordinate) + wardrobe-admin maintainer
estimate: 1d
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

Phase 02 backend migration added 5 nullable columns to the `users`
table:

- `email_verified_at` (timestamp, nullable)
- `oauth_provider` (varchar, nullable)
- `oauth_subject` (varchar, nullable)
- `apple_private_relay` (boolean, nullable)
- `display_name` (varchar, nullable)

Plus `password_hash` is now nullable (OAuth accounts have no password).

The wardrobe-admin SPA (internal ops UI under
`wardrobe-backend/wardrobe-admin/`) is the other consumer that
touches `/admin/users/*`. Per the umbrella's two-repo contract,
admin endpoints don't go through the same drift-prevention process
as the public `/api`, so this needs an explicit hand-off rather than
silent breakage.

No immediate break — all new columns are nullable — but the admin UI
will show empty cells / odd states until adapted.

## Acceptance criteria

- [ ] Tech-lead pings wardrobe-admin maintainer with full schema diff
      (alembic revision + ORM model file).
- [ ] Admin user list adds an OAuth provider badge
      (google/apple/email).
- [ ] Admin user list shows "Not verified" warning row when
      `email_verified_at IS NULL` for email-signup accounts (OAuth
      accounts treated as verified by definition).
- [ ] Admin user detail page handles `password_hash IS NULL` without
      crashing — shows "OAuth-only account" instead of a hash
      placeholder.
- [ ] No breaking change to existing admin flows (user search, role
      edit, ban, etc.).
- [ ] Smoke test against staging post-deploy.

## Out of scope

- Admin-side "force verify" or "reset OAuth link" actions (separate
  ticket if needed).
- Public `/api` schema work — that's in Phase 02 already.

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding M7
- Schema: `wardrobe-backend/models/user.py`, `wardrobe-backend/alembic/versions/*au_242_phase_02*`
- Admin SPA: `wardrobe-backend/wardrobe-admin/src/services/users.ts`,
  `wardrobe-backend/wardrobe-admin/src/pages/users/`
- Parent: AU-242
