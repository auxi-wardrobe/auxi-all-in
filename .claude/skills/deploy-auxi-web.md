---
name: deploy-auxi-web
description: Deploy the auxi web review surface for the designer to preview in a browser. Use whenever the user/designer asks to deploy/ship/publish/update the web preview — e.g. "deploy đi", "deploy", "deploy web", "ship the preview", "cập nhật web review". Default path triggers a SERVER-SIDE Cloudflare build (no local toolchain, no git) via a Deploy Hook. Never commits, pushes, opens a PR, or merges.
---

# Deploy auxi Web Review Surface

The build happens on Cloudflare's infra (Pages Git build of the `web-preview`
branch). "deploy đi" only triggers it — the designer needs no Node/RN/wrangler
setup, and NO git is touched.

## Primary path — trigger the server-side build (designer)
```bash
cd auxi   # if not already there
yarn web:deploy:remote
```
This POSTs the Cloudflare Deploy Hook (`scripts/deploy-hook.sh`, URL from the
gitignored `auxi/.env.deploy` → `PAGES_DEPLOY_HOOK`). Cloudflare then builds
`web-preview` and publishes it. Report:
- Live: **https://auxi-web-review.pages.dev** (ready in ~1–2 min; hard-refresh).
- Build progress is visible in the Cloudflare dashboard.

If `PAGES_DEPLOY_HOOK` is missing, the script prints where to get it — do the
one-time setup in `auxi/docs/web-review-cf-git-setup.md` (dashboard).

## ⛔ Never touch git
This skill MUST NOT run git/gh (`add/commit/push`, branch, `pr create`, merge).
A deploy only triggers a rebuild of code already on `web-preview`. Bringing new
changes into `web-preview`, and merging to `main`, are separate maintainer-
reviewed steps — never part of a deploy.

## Maintainer fallback — local build + direct upload
Only if someone has the full local toolchain + Cloudflare auth and the Git build
is unavailable:
```bash
cd auxi && yarn web:deploy   # vite build + wrangler pages deploy (versioned URL)
```

## One-time setup
- Server build + hook: `auxi/docs/web-review-cf-git-setup.md`.
- Runtime proxy secrets (`REVIEW_EMAIL`/`REVIEW_PASSWORD`) live on Cloudflare —
  never in the bundle or git.

## Guardrails
- PREVIEW ONLY — never run git/gh.
- Report the live URL + the hard-refresh reminder.
- Smoke check: `curl -s https://auxi-web-review.pages.dev/api/me` → JSON (proxy live).
