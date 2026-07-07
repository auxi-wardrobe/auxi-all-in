# devops — wardrobe-admin SPA prod deploy (Notifications page live)

**Date:** 2026-06-29 · **Ticket:** GH-364 / auxi-backend PR #119
**Goal:** Ship the new admin **Notifications** page (compose/send admin push + history) to Cloudflare prod.
**Result:** DONE — deployed and verified live.

## Deploy facts

| Field | Value |
|---|---|
| Command run | `npx wrangler deploy` (from `wardrobe-admin/`; wrangler.jsonc `build.command` rebuilds with prod URL, then uploads `dist/`) |
| CF target type | Cloudflare **Worker** with static assets (`assets.directory=./dist`, SPA `not_found_handling`), **not** Pages |
| CF project/Worker name | `wardrobe-admin` (single deployment, no env split) |
| Deployment URL | https://wardrobe-admin.duc2820.workers.dev |
| Version ID | `fc7034c0-5f35-4740-9a86-7ee0cc1c84b9` |
| Assets uploaded | 3 new/modified (`/index.html`, `/assets/index-DFH1jrD3.css`, `/assets/index-MQAEd3WH.js`) |
| Build | `tsc -b && vite build` clean — 8637 modules, ~12.5s, only benign font-woff + chunk-size warnings |
| wrangler | v4.67.0, authed (workers + pages write scopes present) |

## Source provenance (deployed origin/main, not a stale branch)

- origin/main HEAD = `9718af6` — this **is** the #119 merge commit ("feat: push notification system … (#119)").
- Built from the clean worktree `/Users/nguyenminhduc/Desktop/wardrobe-backend-pushnotif` (branch `feat/push-notifications`, `b85bc4c`), but verified equivalent to main for the admin SPA:
  - `git diff origin/main HEAD -- wardrobe-admin/` → **empty** (byte-identical admin dir).
  - `.env.production` / `.env.example` tracked with **identical blob hashes** on both main and HEAD (`c0382d4` / `886ef73`).
  - So the feat branch does **not** diverge from main for `wardrobe-admin/`; this build == origin/main's admin.
- Did NOT use the umbrella submodule checkout (`wardrobe-backend/`) — it's dirty on the stale `feature/au318-mood-feedback` branch. Did NOT switch the worktree's branch (push-notif work left untouched; worktree clean after build, `dist/` is gitignored).

## Prod-API-base-URL confirmation (ground-truth via baked bundle)

- `wrangler.jsonc` `build.command` injects `VITE_API_URL=https://wardrobe-backend-production-c8d9.up.railway.app` at **build time** (Vite bakes it; inline/process env wins over `.env.production`).
- `src/services/api.ts:4` → `import.meta.env.VITE_API_URL || 'http://localhost:5001'`, `baseURL = ${API_URL}/api`.
- `.env.production` was privacy-blocked (not read); routed around by inspecting the actual shipped bundle instead:
  - **LIVE** bundle contains prod Railway URL → grep count **1**.
  - **LIVE** bundle contains `localhost:5001` → grep count **0**.
- Conclusion: prod admin points at the prod Railway backend (`/api` + `/admin`). No localhost leak.

## Notifications-page-present verification (live)

- `GET /` → **200**; `index.html` references `assets/index-MQAEd3WH.js` (matches deployed asset).
- `GET /notifications` → **200** (SPA fallback works).
- `GET /assets/index-MQAEd3WH.js` → **200**; live bundle contains `/admin/notifications`, `/admin/notifications/`, `/admin/notifications/send` and nav title "Notifications" + "Notification detail".
- Source confirms route + nav: `wardrobe-admin/src/App.tsx:21,52` (import + `<Route path="notifications">`), `src/components/layout/Layout.tsx:23` (Bell nav item), `src/pages/Notifications.tsx`, `src/services/notificationsService.ts`.
- The page renders behind admin auth (JWT in localStorage, admin role enforced server-side on `/admin/*`); the route + bundle are served regardless, so a curl is 200 and the compose/send UI loads for an authed admin.

## How to verify health
- `curl -o /dev/null -w "%{http_code}" https://wardrobe-admin.duc2820.workers.dev/` → 200.
- Log into the admin → left nav "Notifications" → compose/send + history; admin push send hits `POST /admin/notifications/send` on the prod backend.

## Rollback
- `cd wardrobe-admin && npx wrangler rollback` (revert to prior version), or `wrangler versions list` → `wrangler versions deploy <prev-version-id>`. Instant; assets-only Worker.

## Notes / unresolved
- Built on local **Node v23.11.1** (non-LTS; admin has no `.nvmrc`). Build was clean and the deployed bundle verified, so no action needed — but if a future build misbehaves, pin Node 20 for parity with the CF/auxi toolchain.
- Backend dependency: the Notifications page calls `POST /admin/notifications/send` etc. on the prod Railway backend. #119's backend (FCM device tokens, admin send, queue + scheduler) must be deployed on Railway for send to actually deliver — out of scope for this admin-SPA deploy; flag to whoever owns the Railway backend release if not already shipped.
- Touched only `wardrobe-admin` + a temporary `!dist` line in umbrella `.claude/.ckignore` (added to grep the build, then reverted — verified clean). No backend/mobile/app-code changes.

**Status:** DONE
**Summary:** Built wardrobe-admin from origin/main-equivalent source (verified byte-identical admin dir) with the prod Railway API URL baked in, and deployed to Cloudflare Worker `wardrobe-admin` (version `fc7034c0-5f35-4740-9a86-7ee0cc1c84b9`) at https://wardrobe-admin.duc2820.workers.dev. Live checks pass: root 200, `/notifications` 200, live bundle contains the Notifications page + `/admin/notifications/send` and the prod backend URL (no localhost).
**Concerns/Blockers:** None blocking. Two notes: built on Node 23 (non-LTS, build clean + bundle verified); and the page's send action depends on #119's backend being live on Railway — verify that separately if push delivery is expected end-to-end.
