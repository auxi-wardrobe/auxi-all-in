# mobile-dev — Remove Unleash feature-flags integration (auxi)

**Date:** 2026-06-19
**Branch:** `chore/remove-unleash` (from origin/main @ 5134df00) — not committed, not switched
**Scope:** `auxi/` mobile app only. Railway Unleash server left untouched (separate infra decision).

## Files deleted (5)
- `src/services/feature-flags.ts` — Unleash singleton client + identify/reset/updateContext helpers
- `src/config/unleash.ts` — URL / client key / app name / refresh interval config
- `src/hooks/useFeatureFlag.ts` — typed wrapper over SDK `useFlag`
- `src/hooks/useUnleashForegroundRefresh.ts` — foreground re-fetch hook
- `docs/unleash-feature-flags-setup.md` — setup guide

No Unleash-only test files existed (checked all `src/**/__tests__` + `*.test.*` / `*.spec.*`; zero references).

## Files edited (3 consumers)
- `App.tsx` — removed `FlagProvider` import (`@unleash/unleash-react-native-sdk`) and `unleashClient` import (`./src/services/feature-flags`); unwrapped the `<FlagProvider unleashClient={unleashClient}>…</FlagProvider>`, keeping children intact (SidebarProvider → RootDrawer → AppNavigator now nest directly under AuthProvider).
- `src/navigation/AppNavigator.tsx` — removed `useUnleashForegroundRefresh` import (~L32) and its call (~L39) plus the stale "Mounted once… under FlagProvider" comment.
- `src/context/AuthContext.tsx` — removed `import { identifyFlagUser, resetFlagUser } from '../services/feature-flags'` (~L14); removed both call sites `identifyFlagUser(user)` (~L226) and `resetFlagUser()` (~L245) and the stale Unleash comments around them. Analytics identify/reset paths untouched.

## Dependencies + native
- `yarn remove @unleash/unleash-react-native-sdk` — removed from `package.json`.
- `yarn remove unleash-proxy-client` — **also removed** (scope decision below). Lockfile regenerated.
- `package.json` and `yarn.lock` both grep-clean for `unleash`.
- `cd ios && pod install` — completed clean (93 Podfile deps / 101 total pods). No Unleash pod existed in `Podfile.lock` (the RN SDK is JS-only, no native autolinked module), so nothing was dropped; ran for consistency. Deprecation notice in output is pre-existing/informational.

### Scope note — `unleash-proxy-client`
`package.json` carried a second direct dep `unleash-proxy-client@^3.8.0` that wasn't in the original edit list. Confirmed: (a) no source imports anywhere in `src`/`App.tsx`, (b) not a transitive dep of any other package in `yarn.lock` (only its own top-level entry). It's a pure Unleash leftover, so I removed it under "remove the integration ENTIRELY." Flag if this should have been left.

## Verification
- **Grep clean:** `grep -rniE "unleash|FlagProvider|useFeatureFlag|feature-flags|identifyFlagUser|resetFlagUser" src App.tsx package.json` → **no matches** (EMPTY). yarn.lock also clean.
- **tsc:** `npx tsc --noEmit` → exit 0, clean.
- **lint:** `yarn lint` → 1 error + 7 warnings. **Zero new issues from this change** — all findings are in files I did not touch (`HomeScreen.tsx`, `usePinReducer.ts`, `DatabaseScreen.tsx`, `OutfitCanvasScreen.tsx`, `auth/SignInScreen.tsx`). My edited files (App.tsx, AppNavigator.tsx, AuthContext.tsx) are clean. (Note: this branch's lint baseline differs from the `_HomeScreen.tsx`-centric baseline in CLAUDE.md, but the removal neither added nor removed any finding.)

## Not done (out of scope, intentional)
- Did NOT touch the Railway Unleash server / backend infra.
- Did NOT commit or open a PR (orchestrator commits after verify).
- Node was 20.12.2 (only 20.x ≤ 20.12.2 installed; lts/iron 20.19.6 not present). The `@react-native/new-app-screen` engine constraint `>=20.19.4` is a pre-existing repo issue unrelated to this change; used `--ignore-engines` on the first `yarn remove` (engine check only — does not alter resolution). The follow-up `yarn remove unleash-proxy-client` regenerated the lockfile successfully.

**Status:** DONE — Unleash integration fully removed from auxi (5 files deleted, 3 consumers cleaned, both npm deps + lockfile clean, pod install clean, grep-clean confirmed, tsc clean, no new lint).
