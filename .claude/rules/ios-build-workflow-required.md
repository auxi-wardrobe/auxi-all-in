# iOS Build & Dev Workflow — Required For This Project

> **Rule (CEO directive 2026-06-22):** ALL auxi mobile dev / build / run on the
> iOS simulator MUST go through the standardized workflow below. No ad-hoc
> rebuilds. No killing the shared Metro / Simulator / watchman without
> coordination. A code change is expected to **hot-reload**, never to trigger a
> native rebuild.

## Why this exists

Sim build flakiness on this project was never random — it came from an unpinned,
bleeding-edge toolchain (Node version drift, missing watchman → stale JS bundle,
many parallel dev servers/worktrees). The CEO runs **many Claude Code sessions
concurrently** (one doing qa-ui, one changing code, one building), so an
uncoordinated rebuild in one session wrecks every other. This workflow makes
builds reproducible and concurrency-safe.

## The rule

1. **Node is pinned to 20** via `auxi/.nvmrc` (RN 0.83 needs ≥20; **never** a
   non-LTS like 23). Run `nvm use` in auxi, or use the standardized scripts
   which force it.
2. **watchman must be installed and watching.** It is the file-watcher Metro
   relies on; its absence is the #1 cause of "I changed code but the sim shows
   the old bundle." Verify with `yarn ios:doctor`.
3. **Code change → Fast Refresh.** Editing JS/TS hot-reloads into the running
   app. Do **not** rebuild native for a JS change.
4. **"Code không hiện trên sim" escalation ladder — cheapest first, never skip
   to rebuild:** reload (`Cmd+R`) → `yarn start:reset` → `yarn ios:clean`.
5. **`yarn ios:doctor`** (read-only preflight) before suspecting anything deeper
   — it reports Node / Xcode / pods / watchman / Metro state.
6. **Concurrency — the hard part.** Metro `:8081`, the Simulator, and watchman
   are **ONE shared machine singleton**, not per-session. Destructive / GLOBAL
   ops — kill Metro, `watchman watch-del-all`, `pod install`, `yarn ios:clean`,
   any native rebuild — disrupt **every** other Claude Code session. **NEVER run
   them automatically or unilaterally.** Confirm with the user that no other
   session is mid-qa/build first. `auxi/scripts/ios-clean-rebuild.sh` enforces
   this: it refuses to run non-interactively (an agent in another session)
   unless `--yes` is passed, and prompts `y/N` on a TTY.
7. **Switch branch with native deps changed → `yarn pods`** before building.
8. **One Metro, one worktree** per build session. Don't confuse the web preview
   (`vite`, `:4173`) with the iOS app.

## One-time setup (new machine)

```bash
brew install watchman
nvm install 20 && nvm use      # reads auxi/.nvmrc
cd auxi && yarn install && yarn pods
```

## When this applies

- Any auxi RN dev/build/run on the iOS simulator, in any session or agent
  (mobile-dev, qa-ui, qa-mobile, designer).

## When this does NOT apply

- Backend (`wardrobe-backend`) work — no RN/sim surface.
- `wardrobe-admin` SPA — separate web build.
- Pure web preview work (`yarn web:*`) that never touches the simulator.

## Tooling — source of truth

- `auxi/.nvmrc` — Node 20 pin
- `auxi/scripts/ios-clean-rebuild.sh` — `--check` doctor + deterministic clean
  rebuild + concurrency guard
- `auxi/package.json` — `start:reset`, `pods`, `ios:clean`, `ios:doctor`
- `auxi/docs/ios-build-troubleshooting.md` — 5 root-cause map + escalation ladder
- `auxi/CLAUDE.md` — Verification section pointers

## Related

- `auxi/docs/ios-build-troubleshooting.md` — full troubleshooting doc
- Memory: `concurrent-cc-sessions-build-safety`, `auxi-sim-build-toolchain-blocker`,
  `auxi-node-version-trap`
