# QA Mobile Sim Verify — 2026-06-10 17:03

**Target:** iPhone 16 Pro (iOS 18.1) · UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`
**Scope:** verify 5 uncommitted changes (AU-319, AU-313/315, AU-314, AU-311) on sim
**Outcome:** BLOCKED — native build could not run; app never updated.

## Build outcome: FAILED (environmental, not Xcode/SDK/pod)

Single serious attempt:
`npx react-native run-ios --udid 9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`
Exit 7. Full log: `/tmp/auxi-ios-build.log`. Exact failure:

```
Error: EPERM: operation not permitted, uv_cwd
    at process.wrappedCwd (node:internal/bootstrap/switches/does_own_process_state:142:28)
    at process.cwd (.../graceful-fs/polyfills.js:10:19)
  errno: -1, code: 'EPERM', syscall: 'uv_cwd'
```

### Root cause
macOS **TCC (Privacy & Security → Files/Folders, or Full Disk Access)** denies
this Claude Code process **read + directory-enumeration** access to everything
under `~/Desktop/`. Confirmed independently of the Claude sandbox:

- `ls ~/Desktop` → `Operation not permitted` (even with sandbox disabled)
- `node -e "require('.../auxi/package.json')"` → `EPERM: operation not permitted, open`
- `cat .../auxi/package.json` → `Operation not permitted`
- `ls ~` (HOME) → works fine; only `~/Desktop` subtree is denied

This is NOT the backgrounded-shell `uv_cwd` issue noted in the brief — it
reproduces in the FOREGROUND with cwd set, because the toolchain cannot read
the project tree at all. `node`/Metro/`xcodebuild` all need to read source +
enumerate `ios/`, `node_modules/` — all TCC-denied. No retry, pod reinstall,
or SDK change can fix this; it is an OS permission grant the process lacks.

Note: targeted path *writes/stat* are permitted (e.g. `touch`, mobile-mcp
`save_screenshot` into reports/ both succeeded), but *reads/enumeration* are not
— which is exactly what a build needs.

## Per-ticket verdicts

| Ticket | Verdict | Reason |
|---|---|---|
| AU-319 (native: Macgie name + cat icon) | BLOCKED | Build failed; new binary never installed. Installed app is still old `com.auxi2026.app` (CFBundleDisplayName=`auxi`). Cannot verify rename/icon without rebuild+install. |
| AU-313 (gmail → Google sign-in notice) | BLOCKED | No updated app to launch; JS bundle never built. |
| AU-315 (Forgot Password gmail guidance) | BLOCKED | Same — app not updated. |
| AU-314 (unregistered non-gmail → SignIn error) | BLOCKED | Same — app not updated. |
| AU-311 (item-detail redesign + Cancel/Save) | BLOCKED | Same — app not updated; also needs login. |

All 5 are blocked by the SAME upstream cause: the incremental build never
executed, so the working-tree changes are not present in any installed binary.
The old `auxi` build that IS installed predates all 5 changes.

## Evidence captured
- `/tmp/auxi-ios-build.log` — full build failure log (EPERM uv_cwd)
- `/Users/nguyenminhduc/Desktop/wardrobe_project/plans/reports/qa-mobile-260610-springboard-baseline.png`
  — springboard (mobile-mcp reachable; default iOS page, no auxi/Macgie icon on page 1)

## What works vs what's blocked
- mobile-mcp bridge: WORKING (device online, list elements + save_screenshot OK).
  The mobile-mcp server is a separate process with device + targeted-write access.
- Build toolchain (node/Metro/xcodebuild): BLOCKED by TCC read-denial on ~/Desktop.

## To unblock (human action required)
Grant the terminal/agent host process Full Disk Access (or add
`~/Desktop` under Files & Folders) in System Settings → Privacy & Security,
then re-run. Once a build succeeds and installs the new binary, all 5 tickets
become verifiable. Until then verification is impossible — the bits under test
are unreadable to the build.

## Unresolved questions
1. Which process needs the TCC grant (Terminal.app / the agent host / node)?
2. Was the booted sim (iOS 18.1) the intended target? Brief implied a fresh
   install; the only installed app is the stale `auxi` build.
