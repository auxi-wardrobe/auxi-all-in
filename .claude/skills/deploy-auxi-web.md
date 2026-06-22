---
name: deploy-auxi-web
description: Deploy the auxi web review surface (react-native-web build) to Cloudflare Pages so the designer can PREVIEW it in a browser. Use whenever the user/designer asks to deploy/ship/publish/update the web preview — e.g. "deploy đi", "deploy", "deploy web", "ship the preview", "cập nhật web review". Each run publishes a VERSIONED URL (git commit hash + timestamp) plus refreshes a stable "latest" link. It ONLY builds + uploads — it never commits, pushes, branches, opens a PR, or merges. Returns the URLs.
---

# Deploy auxi Web Review Surface (PREVIEW ONLY, versioned)

`yarn web:deploy` builds the current working tree and publishes it to Cloudflare
Pages, producing:
- **This version:** `https://<shorthash>[-wip]-<yymmdd-hhmm>.auxi-web-review.pages.dev`
  (a permanent URL tied to the git commit it was built from; `-wip` = the tree had
  uncommitted edits; timestamp keeps each preview distinct).
- **Latest:** `https://auxi-web-review.pages.dev` (always the most recent deploy).

## ⛔ PREVIEW ONLY — never touch git
When running this skill you may ONLY `vite build` + `wrangler pages deploy`.
NEVER run git/gh (`add/commit/push`, branch, `pr create`, merge). Deploy = publish
a preview of the current working tree; committing/PR/merge is the maintainer's
separate, reviewed step. (`--commit-dirty=true` is a wrangler flag — it does NOT
make a git commit.)

## Steps
1. Be in the auxi repo root (folder with `vite.config.ts`); else `cd auxi`.
2. `yarn web:deploy`  (runs `scripts/deploy-web.sh`).
3. Report BOTH URLs it prints (This version + Latest).
4. Remind: hard-refresh (Cmd+Shift+R) — Pages caches `index.html`.

## One-time setup (maintainer)
1. **Cloudflare auth** for whoever deploys — `npx wrangler login`, or put a
   "Cloudflare Pages — Edit" token in `auxi/.env.deploy` (see `.env.deploy.example`).
2. **Proxy secrets in BOTH environments.** The app auth runs server-side in
   `functions/api/[[path]].js` from CF secrets `REVIEW_EMAIL`/`REVIEW_PASSWORD`.
   `wrangler pages secret put` only sets the **production** env (used by the
   "latest" URL). For the **versioned (preview) URLs** to load data, add the same
   two vars to the **Preview** environment ONCE in the dashboard:
   Cloudflare → Workers & Pages → auxi-web-review → Settings → Variables and
   Secrets → **Preview** → add `REVIEW_EMAIL` + `REVIEW_PASSWORD` (encrypt).
   Without this, versioned URLs render the UI but API calls return `proxy_auth`.

## Guardrails
- PREVIEW ONLY — never run git/gh.
- If `vite build` fails, STOP and show the error; don't deploy a broken build.
- Smoke check: `curl -s https://auxi-web-review.pages.dev/api/me` → JSON (proxy live).
