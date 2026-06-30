---
name: deploy-homepage-web
description: Deploy the Macgie homepage (landing site) to Cloudflare Pages for the designer to preview in a browser. Use whenever the user/designer asks to deploy/ship/publish/update the homepage or its sandbox — e.g. "sandbox đi", "deploy homepage", "deploy the landing page", "ship the homepage preview", "cập nhật homepage". Default path deploys the SANDBOX preview (production stays untouched). Never commits, pushes, opens a PR, or merges.
---

# Deploy Macgie Homepage (sandbox / prod)

The homepage (`homepage/` submodule → `auxi-wardrobe/homepage`) is a plain
static site — HTML + CSS + vanilla JS, **no build step**. Deploy uploads
`homepage/public/` to the Cloudflare Pages project `macgie-homepage`.

This is the homepage twin of `deploy-auxi-web` (the RN web-review surface).
Same posture: PREVIEW-FIRST, never touch git.

## Primary path — sandbox preview (designer vibe loop)
```bash
cd homepage && ./scripts/deploy.sh          # or: ./scripts/deploy.sh sandbox
```
- Live: **https://sandbox.macgie-homepage.pages.dev** (ready in ~30s; hard-refresh).
- Production is NOT touched — `macgie-homepage.pages.dev` keeps serving the last
  promoted version. Sandbox is the designer's surface to vibe on.

## Promote to production (separate, intentional step)
```bash
cd homepage && ./scripts/deploy.sh prod
```
- Live: **https://macgie-homepage.pages.dev**.
- Only run this once the sandbox looks right and the change is meant to go live.

## ⛔ Never touch git
This skill MUST NOT run git/gh (`add/commit/push`, branch, `pr create`, merge).
A deploy just uploads the current `homepage/public/` to Pages. Committing the
source to the `homepage` repo and bumping the umbrella submodule pointer are
separate, maintainer-reviewed steps — never part of a deploy.

## Requirements
- `wrangler` authenticated (OAuth via `wrangler login`, or `CLOUDFLARE_API_TOKEN`).
  `wrangler whoami` confirms; needs `pages (write)`.
- The Pages project `macgie-homepage` already exists (created with production
  branch `main`). Sandbox is the `sandbox` branch alias on the same project.

## Guardrails
- PREVIEW ONLY by default — `sandbox` unless the user explicitly says prod/production/go-live.
- Never run git/gh.
- Report the live URL + the ~30s / hard-refresh reminder.
- Smoke check: `curl -s -o /dev/null -w '%{http_code}' https://sandbox.macgie-homepage.pages.dev/` → `200`.

## Related
- Source + layout: `homepage/README.md`
- Deploy script: `homepage/scripts/deploy.sh`
- Sibling skill (RN web review): `.claude/skills/deploy-auxi-web.md`
