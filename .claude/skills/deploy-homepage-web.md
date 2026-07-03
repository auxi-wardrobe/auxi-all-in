---
name: deploy-homepage-web
description: Deploy the Macgie homepage (landing site) to Cloudflare Pages for the designer to preview in a browser. Use whenever the user/designer asks to deploy/ship/publish/update the homepage or asks for a preview/sandbox link — e.g. "sandbox đi", "give me sandbox", "give me a preview link", "preview link", "deploy homepage", "deploy the landing page", "ship the homepage preview", "cập nhật homepage". Default path deploys a per-build PREVIEW with a commit-hash URL (production stays untouched). Never commits, pushes, opens a PR, or merges.
---

# Deploy Macgie Homepage (sandbox / prod)

The homepage (`homepage/` submodule → `auxi-wardrobe/homepage`) is a plain
static site — HTML + CSS + vanilla JS, **no build step**. Deploy uploads
`homepage/public/` to the Cloudflare Pages project `macgie-homepage`.

This is the homepage twin of `deploy-auxi-web` (the RN web-review surface).
Same posture: PREVIEW-FIRST, never touch git.

## Primary path — preview (designer vibe loop)
```bash
cd homepage && ./scripts/deploy.sh          # or: ./scripts/deploy.sh sandbox
```
Each preview deploy returns a **commit-hash-prefixed URL** — every build is a
unique link, so the designer never sees a stale cache and never has to
hard-refresh:

- **This build:** `https://<sha>.macgie-homepage.pages.dev`
  (clean tree → `<sha>`; uncommitted edits → `<sha>-<HHMMSS>`, unique per deploy).
- **Latest bookmark:** `https://sandbox.macgie-homepage.pages.dev` — repointed to
  the newest build (one stable URL to return to).
- Production is NOT touched — `macgie-homepage.pages.dev` keeps serving the last
  promoted version. Preview is the designer's surface to vibe on.

Report BOTH URLs from the script output, plus its "Built from" line (commit +
whether it had uncommitted changes). The commit-hash link is the one to share for
this exact build.

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
- PREVIEW ONLY by default — the commit-hash preview unless the user explicitly says prod/production/go-live.
- Never run git/gh.
- Report BOTH URLs (this-build commit-hash link + latest bookmark) and the "Built from" line.
- Smoke check the returned commit-hash URL before reporting it (allow ~30s):
  `curl -s -o /dev/null -w '%{http_code}' "https://<sha>.macgie-homepage.pages.dev/"` → `200`.

## Related
- Source + layout: `homepage/README.md`
- Deploy script: `homepage/scripts/deploy.sh`
- Sibling skill (RN web review): `.claude/skills/deploy-auxi-web.md`
