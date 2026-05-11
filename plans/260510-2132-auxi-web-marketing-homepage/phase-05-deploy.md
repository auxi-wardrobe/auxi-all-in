---
phase: 5
title: "Deploy"
status: pending
priority: P2
effort: "1.5h"
dependencies: [4]
---

# Phase 5: Deploy

## Overview
Ship the static build to Cloudflare Pages, behind a `*.pages.dev` preview
URL only (no custom domain until designer/CEO signs off). Document the
deploy flow in the README so the next contributor doesn't have to ask.

## Requirements
- **Functional:** one command from clean checkout to deployed preview URL.
- **Non-functional:** no secrets committed; Wrangler config matches the
  pattern used by `wardrobe-backend/wardrobe-admin/`.

## Architecture

**Deploy target:** Cloudflare Pages (matches umbrella's `wardrobe-admin`
which already deploys via Wrangler).

**Two paths, document both:**
1. **Direct CLI deploy** (initial + ad-hoc previews):
   `pnpm build && pnpm dlx wrangler pages deploy dist --project-name auxi-web`
2. **GitHub-connected** (when repo has a remote): connect Cloudflare
   Pages → GitHub repo → auto-deploy on push to main, preview on PR.

**Preview gating:** until designer signs off, only the random
`<hash>.auxi-web.pages.dev` URL exists. Custom domain (e.g., `auxi.app`,
`getauxi.com`) wired in a follow-up after sign-off.

## Related Code Files
- Create: `wrangler.toml` (or `wrangler.jsonc` to match wardrobe-admin's choice — verify and copy convention)
- Modify: `package.json` — add `deploy` script: `"deploy": "astro build && wrangler pages deploy dist --project-name auxi-web"`
- Modify: `README.md` — full deploy section: prerequisites, login, first deploy, subsequent deploys, rollback
- Create: `.github/workflows/deploy.yml` — only if repo gets a remote in this phase; otherwise stub and leave for later

## Implementation Steps
1. Read `/Users/nguyenminhduc/Desktop/wardrobe_project/wardrobe-backend/wardrobe-admin/wrangler.*` to copy the project's wrangler conventions (toml vs jsonc, account_id placement, build dir).
2. Write `auxi-web/wrangler.toml` (or jsonc) — `name = "auxi-web"`, `pages_build_output_dir = "dist"`, leave `account_id` empty for env injection.
3. Add `deploy` script in `package.json`.
4. Local sanity: `pnpm build && pnpm dlx wrangler pages dev dist` — preview locally without deploying.
5. First deploy: `pnpm deploy` (interactive Wrangler prompts for Cloudflare login + project creation). Capture the preview URL.
6. Verify preview URL: hero loads, fonts load, FAQ works, badges link (even to placeholder targets), Lighthouse scores survive Cloudflare's edge.
7. Update README with: prereqs (Node 20+, pnpm, Cloudflare account), `wrangler login`, `pnpm deploy`, where preview URLs land, how to roll back via Cloudflare dashboard.
8. Commit final state with message `chore: configure cloudflare pages deploy`.
9. Output preview URL for designer/CEO review.

## Success Criteria
- [ ] `pnpm deploy` from clean checkout produces a working preview URL.
- [ ] Preview URL renders identically to local `pnpm preview` (fonts, OG, accordion).
- [ ] README has a "Deploying" section a fresh contributor can follow without help.
- [ ] No Cloudflare account ID, API token, or other secret is committed to the repo.
- [ ] Lighthouse on the deployed preview matches phase 4 scores (within 2 points).

## Risk Assessment
- **Wrangler version drift:** Cloudflare changes Wrangler frequently.
  Mitigation: pin via `pnpm add -D wrangler@latest` and document the
  pinned version in README.
- **Custom domain temptation:** wiring `auxi.app` before sign-off creates
  brand exposure for an unapproved design. Mitigation: explicit "DO NOT
  add custom domain" note in README until designer approves.
- **First-deploy 404 on assets:** if `pages_build_output_dir` is wrong,
  styles 404 silently. Mitigation: `pnpm dlx wrangler pages dev dist`
  locally before hitting the network.

## Follow-ups (out of this plan)
- Designer/CEO review of preview URL.
- Custom domain wiring + DNS.
- Optional: GitHub Actions CI (build on PR, deploy on merge).
- Optional: Plausible / Umami analytics snippet.
- Optional: Cloudflare Worker for email-waitlist capture if product adds one.
