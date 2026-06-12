# Onboarding V2 + Replay smoke — BLOCKED on stale native binary

**Date**: 2026-05-26 15:56
**Agent**: qa-mobile
**Branch**: `feat/onboarding-v2-redesign` (auxi HEAD `d0a1b3d0`)
**Device**: iOS Simulator — iPhone 16, iOS 18.2 (`6371F8E8-893E-4D7C-8683-8A128B7996F8`)
**Result**: BLOCKED — none of A/B/C verified. App red-boxes on launch before any screen renders.

---

## TL;DR

The installed `com.auxi` debug build is a **stale native binary**. The branch
added the `react-native-localize` native module (RNLocalize 3.7.0), but the
`.app` on the sim was compiled before that module was linked. On launch the
JS bundle (current, from Metro) calls `getLocales()` during i18n bootstrap,
`TurboModuleRegistry.getEnforcing('RNLocalize')` throws, and the app dies on a
redbox **before the navigator mounts**. Onboarding never renders, so the V2
flow + replay row cannot be exercised on this binary.

Per project memory (don't churn build/sim cycles), I did NOT trigger a native
rebuild. The fix is a one-time `pod install` + `yarn ios` — exact command below.

---

## Infra state I found (all green EXCEPT the binary)

| Check | State |
|---|---|
| MCP doctor (`./scripts/mcp-doctor.sh`) | exit 0 — sim booted, WDA :8100 up, mobile-mcp pinned 0.0.56 |
| Booted sim | iPhone 16, iOS 18.2 |
| App installed | `com.auxi` present, **debug build** (no embedded `main.jsbundle` → loads from Metro) |
| Metro | running on :8081 (`packager-status:running`) |
| Backend :5001 | HTTP 200, `environment: development` — **prod-mirror LOCAL DB, not Railway** |
| qa-test login | `POST /api/login` → 200 + tokens (account works against this backend) |
| `/api/v05/onboarding/generate` | live — empty body → 400 validating `wardrobe_direction`, `fit_preference`, `style_preferences` (the V2 payload). Endpoint is ready. |
| Flags in code | `ONBOARDING_V2_ENABLED = __DEV__`, `ONBOARDING_REPLAY_ENABLED = __DEV__` (`src/config/featureFlags.ts:62,81`) — would be ON in this debug build |
| testIDs in code | `home-menu-button` (`HomeScreen.tsx:1086`), `settings-replay-onboarding-row` (`SettingsScreen.tsx:552`) both present |

So: backend, account, endpoint, Metro, flags, and testIDs are ALL ready. The
**only** blocker is the native binary lacking RNLocalize.

## The crash (the block)

```
Uncaught Error
TurboModuleRegistry.getEnforcing(...): 'RNLocalize' could not be found.
Verify that a module by this name is registered in the native binary.

Call Stack:
  getEnforcing      TurboModuleRegistry.js:41:12
  <global>          NativeRNLocalize.js:4:48
  <global>          module.native.js:0
  detectDeviceLanguage  init.ts:0:27   ← src/i18n/init.ts
  <anonymous>       init.ts:109:22
```

- Repro: **2/2 launches** (clean terminate + relaunch both red-box identically).
- Fires during i18n bootstrap, before the navigator/onboarding mounts.
- Screenshots:
  - `auxi/docs/qa-findings/screenshots/2026-05-26/qa-mobile-rnlocalize-redbox.png`
  - `auxi/docs/qa-findings/screenshots/2026-05-26/qa-mobile-rnlocalize-redbox-relaunch.png`

## Root cause (confirmed, not a code bug)

- `package.json:33` → `"react-native-localize": "^3.7.0"` (declared).
- `ios/Podfile.lock` → `RNLocalize (3.7.0)` resolved with pod hash `1aedbc2c…` (pod spec present in repo).
- `src/i18n/init.ts:36` → `import { getLocales } from 'react-native-localize'`; `detectDeviceLanguage()` (line 59) calls it; invoked at line 109 during init.
- The dep landed with the `au-242` i18n bootstrap (commit `517e62f8`), bundled into this branch alongside Mixpanel / Sign-In SDKs (`413bb436`, `5e61e544`) — all native-module additions.

The repo is consistent; the **simulator binary is behind the branch's native deps**. This is the exact "rebuild native if binary stale vs branch deps" situation in memory `v05_sim_verify_method`.

## What was verified vs not

- A (Replay mode): **NOT verified** — app never reaches Home/Settings.
- B (V2 happy path): **NOT verified** — onboarding never renders.
- C (Deferred completion): **NOT verified** — same.
- Backend V2 contract: **partially verified** — `/api/v05/onboarding/generate` is up and enforces the V2 schema (good sign the happy path's `/generate` call will resolve once the app runs).

I did NOT fabricate a pass on any of A/B/C.

## Exact setup to unblock (user owns this — one native rebuild)

The native module just needs to be linked into a fresh debug build. From a shell:

```bash
cd /Users/nguyenminhduc/Desktop/wardrobe_project/auxi

# 1. Ensure pods match Podfile.lock (RNLocalize 3.7.0)
cd ios && pod install && cd ..

# 2. Rebuild + install the debug app on the booted iPhone 16, with Metro live
yarn ios --udid 6371F8E8-893E-4D7C-8683-8A128B7996F8
#   (equivalently: ./scripts/qa-boot.sh — it runs `yarn ios --udid <sim>`)
```

This is a ~1-minute native build (per `scripts/qa-boot.sh` log). Keep Metro
running (already up on :8081). Backend is already up on :5001 with the
prod-mirror DB — no DB work needed; qa-test logs in fine.

After the rebuild lands, re-dispatch me and I'll run A/B/C exploratorily (or
run `maestro/flows/onboarding/onboarding-v2.yaml` with
`-e QA_EMAIL=qa-test@auxi.app -e QA_PASSWORD='QaTest!2026'`).

## Notes

- Did NOT run Jest (task is sim e2e; not requested and blocked upstream anyway).
- Did NOT touch `auxi/src/**`, did NOT author/edit Maestro YAML, did NOT
  rebuild — stayed within qa-mobile boundaries + the no-churn memory rule.
- The 2 stale bundle IDs (`com.auxi2026.app`, `org.reactjs.native.example.auxi`)
  have no container — ignore them; `com.auxi` is the live debug install.

## Unresolved questions

1. Is a fresh `yarn ios` build acceptable to the user right now, or is the sim
   intentionally pinned to an older binary for another reason? (Stopping rather
   than assuming.)
2. qa-test `is_first_login` server state was not asserted (no `/api/me`-style
   route found at the paths I probed). Not blocking: replay mode forces
   onboarding client-side via AuthContext regardless of server flag.
