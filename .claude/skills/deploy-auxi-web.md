---
name: deploy-auxi-web
description: Deploy the auxi web review surface (react-native-web build) to Cloudflare Pages so the designer can PREVIEW it in a browser. Use this whenever the user or designer asks to deploy/ship/publish/update the web preview — e.g. "deploy đi", "deploy", "deploy web", "ship the web preview", "cập nhật web review", "đẩy web lên". It ONLY builds and uploads a preview to Cloudflare Pages — it never commits, pushes, branches, opens a PR, or merges. Returns the live URL.
---

# Deploy auxi Web Review Surface (PREVIEW ONLY)

One command for the designer: build the react-native-web bundle from the current
working tree and publish it to Cloudflare Pages for preview, then hand back the
live link.

## ⛔ This is PREVIEW ONLY — it MUST NOT touch git

When running this skill you may ONLY: `vite build` + `wrangler pages deploy`.
You MUST NOT run ANY git command — no `git add/commit/push`, no new branch,
no `gh pr create`, no merge. The designer's deploy is decoupled from source
control on purpose:

- "deploy đi" = publish a preview of the **current working tree** (even with
  uncommitted designer edits). Nothing is recorded in git.
- Committing code, opening PRs, and merging are the **maintainer's** job and
  happen in a separate, reviewed step — never as part of a deploy.

(Note: the `--commit-dirty=true` flag in the deploy command is a *wrangler*
flag meaning "deploy even though the git tree is dirty". It does NOT create a
git commit.)

## What this deploys
- Project: `auxi` (the dir with `vite.config.ts` + `functions/`).
- Target: Cloudflare Pages project **`auxi-web-review`** → https://auxi-web-review.pages.dev
- App auth handled server-side by the Pages Function proxy
  (`functions/api/[[path]].js`, CF secrets `REVIEW_EMAIL`/`REVIEW_PASSWORD`) —
  no app credentials are in the bundle.

## Steps

1. Be in the auxi repo root (folder with `vite.config.ts`). If the session's cwd
   is the umbrella repo, `cd auxi` first.

2. Build + deploy:
   ```bash
   yarn web:deploy
   ```
   (runs `scripts/deploy-web.sh` → `vite build` → `wrangler pages deploy dist-web
   --project-name auxi-web-review`)

3. From wrangler's output report BOTH links:
   - **Production:** https://auxi-web-review.pages.dev
   - **This deploy:** the unique `https://<hash>.auxi-web-review.pages.dev` line.

4. Remind the user to **hard-refresh (Cmd+Shift+R)** — Pages caches `index.html`.

## Cloudflare auth (one-time per machine)

`wrangler` needs Cloudflare credentials to deploy (NOT in the repo — secrets
aren't committed). `scripts/deploy-web.sh` checks for auth and, if missing,
prints setup instructions and stops. Set up ONCE, pick one:

- **(a) Browser login** — `npx wrangler login` (needs access to the Cloudflare
  account `duc2820@gmail.com`). Persists in `~/.wrangler`.
- **(b) API token (headless, recommended for the designer)** — create a
  "Cloudflare Pages — Edit" token, then `cp auxi/.env.deploy.example
  auxi/.env.deploy` and fill `CLOUDFLARE_API_TOKEN` (`.env.deploy` is gitignored).

On a machine already logged in, no setup is needed.

## Guardrails
- PREVIEW ONLY — never run git/gh commands (see the section above).
- If `vite build` fails, STOP and show the error. Never deploy a broken build.
- Optional smoke check: `curl -s https://auxi-web-review.pages.dev/api/me`
  should return JSON for the review account (confirms the proxy is live).
