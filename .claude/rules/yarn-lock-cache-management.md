# yarn.lock & Cloudflare Build Cache — Management Rule

> **Rule:** `auxi/yarn.lock` is the **cache key** for the Cloudflare Pages build
> cache on the `auxi-web-review` project (the "sandbox" web preview). Treat it as
> a build-critical, machine-generated lockfile — commit it, never hand-edit it,
> keep it in sync with `package.json`. A clean lockfile = fast cached builds; a
> drifted or corrupt one = slow or broken builds.

## Why this matters

CF Pages build cache restores `node_modules` (and the package-manager store)
**only when the `yarn.lock` hash matches** the cached one:

- lockfile **unchanged** → cache hit → `yarn install` ~skipped → fast build
- lockfile **changed** → CF auto-invalidates the deps cache → reinstalls +
  re-caches → that one build is slow, the next ones fast again

The cache is **project-scoped on Cloudflare**, shared across all deployments and
branches of `auxi-web-review`, independent of any local machine or chat session.
Changing app code (`.tsx`/`.ts`) does **not** bust the deps cache — only touching
`yarn.lock` does.

## The rules

1. **Always commit `auxi/yarn.lock`.** Never gitignore it. It is the contract
   that makes builds reproducible and cacheable.
2. **Never hand-edit the lockfile.** It changes only as a side effect of
   `yarn add` / `yarn remove` / `yarn upgrade <pkg>` / `yarn install`.
3. **Commit the lockfile in the SAME commit as the `package.json` change** that
   produced it. A dep change in `package.json` without its matching lockfile bump
   breaks `--frozen-lockfile` and silently busts the cache.
4. **Pin the toolchain.** yarn is pinned (`packageManager: yarn@1.22.22`), Node is
   pinned (`auxi/.nvmrc` = 20). Don't regenerate the lockfile on a different
   yarn/Node version — it causes churn and can cache native binaries incompatible
   with CF's Node 20.
5. **Verify sync before pushing a dep change:** `yarn install --frozen-lockfile`
   locally must pass (it fails if `package.json` and `yarn.lock` disagree).
6. **Resolve lockfile merge conflicts by regenerating, not by hand:** after a
   merge, run `yarn install` and commit the result — never resolve `yarn.lock`
   conflict markers manually.

## When do I need to clear the CF build cache + rebuild?

Normally **NO** — a lockfile change auto-invalidates the deps cache; you touch
nothing. Manually clear the cache (CF dashboard → project `auxi-web-review` →
**Settings → Build → Clear cache**, or **Retry with build cache cleared** on a
deployment) ONLY when:

- A build **fails on CF but succeeds locally**, and the error smells like stale
  deps / missing module / native-binary mismatch.
- You changed the **Node or yarn version** (cached native modules may be
  ABI-stale).
- The lockfile was edited/merged by hand and you suspect the cache is poisoned.
- Build output looks stale even though source changed (rare — the bundle is
  rebuilt every time, but clear if in doubt).

After a manual clear, the next build is a cold rebuild (slow); subsequent builds
re-cache and speed up again.

## When this does NOT apply

- `wardrobe-backend` (Python/pip) — no yarn, no CF Pages build cache here.
- `wardrobe-admin` SPA — separate build; if it gets its own CF cache, the same
  *principles* apply to its lockfile, but this rule is scoped to `auxi/`.

## Related

- `.claude/skills/deploy-auxi-web.md` — how the web preview is built/deployed
- `auxi/docs/web-review-cf-git-setup.md` — CF Pages build settings (build command,
  branch model, `dist-web` output)
- `.claude/rules/ios-build-workflow-required.md` — sibling build-hygiene rule
  (native/sim side)
