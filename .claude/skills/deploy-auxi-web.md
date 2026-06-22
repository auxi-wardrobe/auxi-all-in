---
name: deploy-auxi-web
description: Deploy the auxi web review surface (react-native-web build) to Cloudflare Pages so the designer can view it in a browser. Use this whenever the user or designer asks to deploy/ship/publish/update the web preview — e.g. "deploy đi", "deploy", "deploy web", "ship the web preview", "cập nhật web review", "đẩy web lên". Builds the current working tree and pushes it to the auxi-web-review Pages project, then returns the live URL.
---

# Deploy auxi Web Review Surface

One command for the designer: build the react-native-web bundle from the current
working tree and publish it to Cloudflare Pages, then hand back the live link.

## What this deploys
- Project: `auxi` (the dir containing `vite.config.ts` + `functions/`).
- Target: Cloudflare Pages project **`auxi-web-review`** → https://auxi-web-review.pages.dev
- Auth is handled server-side by the Pages Function proxy (`functions/api/[[path]].js`)
  using CF secrets `REVIEW_EMAIL` / `REVIEW_PASSWORD` — **no credentials are in the
  bundle**, nothing extra to configure at deploy time.

## Steps

1. Make sure you are in the auxi repo root (the folder with `vite.config.ts`).
   If the session's working dir is the umbrella repo, `cd auxi` first.

2. Build + deploy in one shot:
   ```bash
   yarn web:deploy
   ```
   (= `vite build` → `wrangler pages deploy dist-web --project-name auxi-web-review --branch main --commit-dirty=true`)

3. From wrangler's output, report BOTH links to the user:
   - **Production:** https://auxi-web-review.pages.dev
   - **This deploy:** the unique `https://<hash>.auxi-web-review.pages.dev` line wrangler prints.

4. Remind the user to **hard-refresh (Cmd+Shift+R)** — Cloudflare Pages caches `index.html`.

## Guardrails
- If `vite build` fails, STOP and show the error. Never deploy a broken build.
- If wrangler reports an auth error, tell the user to run `npx wrangler login`
  (Cloudflare account: duc2820@gmail.com) — it's interactive, so they run it via
  the `!` prefix in the prompt.
- This deploys the CURRENT working tree as-is. No git commit/push is required or
  performed. (If the user also wants the source committed, do that separately.)
- Optional smoke check after deploy: `curl -s https://auxi-web-review.pages.dev/api/me`
  should return JSON for the review account (confirms the proxy is live).
