---
id: WAR-PR-002
type: chore
title: "[Task] Surface wardrobe-admin SPA in umbrella README + CLAUDE.md"
state: Done
priority: P3
labels: [type:chore, area:docs, role:tech-lead, source:pr]
source_pr: https://github.com/ducga1998/auxi-all-in/pull/2
source_repo: wardrobe_project (umbrella)
author: ducga1998
merged_at: 2026-05-05T07:53:05Z
created: 2026-05-05
---

## Context

The internal admin dashboard at `wardrobe-backend/wardrobe-admin/` (React
19 + Vite + Ant Design SPA, deployed to Cloudflare) was invisible in the
umbrella docs. New readers had to discover it by browsing the submodule.

## What shipped

- `README.md` — new `## Admin dashboard` section with pages table
  (Dashboard, Users, CommonItems, AlgorithmCockpit, RecommendationTest /
  Evaluation, BulkAutoTag, ValenRecommendation), backend pairings
  (`routers/admin/*`), `create_admin.py` bootstrap, local dev steps,
  Cloudflare deploy.
- `CLAUDE.md` — repo-layout diagram now nests `wardrobe-admin/` inside
  the backend submodule. Two-repo contract updated to reflect two
  clients (auxi mobile + admin SPA) hitting the same FastAPI backend on
  different surfaces (`/api` vs `/admin`), with admin role enforced
  server-side.

Pure documentation — no script/code changes.

## Acceptance criteria

- [x] Markdown renders cleanly (no broken tables, no orphan headings).
- [x] Internal `[Admin dashboard](#admin-dashboard)` link resolves.
- [x] Page list matches `wardrobe-backend/wardrobe-admin/src/pages/`.
- [x] Backend router list matches `wardrobe-backend/routers/admin/*.py`.

## Out of scope

- Replacing the default Vite template at
  `wardrobe-backend/wardrobe-admin/README.md` — separate commit on the
  backend submodule.
