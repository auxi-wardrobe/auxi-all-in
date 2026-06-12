# QA-Mobile — Sim Verify 3× (AU-319/313/315/314/311)

**Date:** 2026-06-10
**Role:** mobile QA
**Target sim:** iPhone 16 Pro · UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916` · iOS 18.1 · BOOTED
**Outcome:** BLOCKED — RELEASE build could not run; source tree is unreadable (macOS TCC). No code change verified.

---

## TL;DR

The build step is impossible from this environment. The brief stated the
macOS TCC blocker was "NOW RESOLVED / folder readable in-place." That is
**not true for the Bash host** running here: every content read under
`/Users/nguyenminhduc/Desktop/wardrobe_project/auxi/` returns
`Operation not permitted`. React Native CLI / `xcodebuild` cannot even read
`package.json`, so `run-ios --configuration Release` cannot start. I did NOT
churn build attempts (per the one-serious-attempt rule); instead I proved the
prerequisite (source read) fails and stopped.

mobile-mcp + `xcrun simctl` work fine (they talk to the simulator under
`~/Library`, not `~/Desktop`), but there is nothing new to verify because no
new binary could be produced. The app already installed on the sim is an
**old build** (display name still `auxi`, pre-AU-319).

---

## Build outcome

| Step | Result |
|---|---|
| Read `auxi/package.json` (node `fs.readFileSync`) | **EPERM — operation not permitted** |
| `git -C auxi rev-parse HEAD` | `fatal: Unable to read current working directory: Operation not permitted` |
| `ls auxi/` | `Operation not permitted` (consistent across 5 retries) |
| `cat auxi/package.json` | `Operation not permitted` (5/5 retries DENIED) |
| `npx react-native run-ios --configuration Release ...` | **Not run** — would EPERM on first source read; no point churning |
| `stat auxi` (metadata only) | OK → `drwxr-xr-x nguyenminhduc:staff` (perms are normal) |

### Root cause: macOS TCC, not Unix perms, not the sandbox

- Directory perms are normal owner-rwx (`drwxr-xr-x nguyenminhduc:staff`) — `stat`
  reads metadata fine, but **content** access (`ls`/`cat`/`node read`/`git`) is
  denied. That signature = TCC denying the host process access to `~/Desktop`,
  exactly the documented `env_tcc_blocks_desktop_builds` blocker.
- `dangerouslyDisableSandbox: true` was set on every Bash call, and
  `SANDBOX`/`APP_SANDBOX_CONTAINER_ID` are unset — so this is **not** the CC
  sandbox wrapper. It is the OS.
- Access is **intermittent**: a one-off `touch`/`cat`/`cp` inside
  `plans/reports/` succeeded once (TCC consent-cache flicker) then lapsed back
  to DENIED. Reads of `auxi/package.json` and umbrella `CLAUDE.md` were DENIED
  on every retry. Intermittency like this is the TCC fingerprint (the kernel
  can't surface a consent dialog to a headless host, so it mostly denies).

### Fix (host/user action — cannot be done from inside the shell)

Grant **Full Disk Access** to the terminal/host process that spawns these Bash
commands (System Settings → Privacy & Security → Full Disk Access), then
restart that process. Per project memory `env_tcc_blocks_desktop_builds`, that
is the resolution. Until then, no build of `auxi` is possible from this rig.

---

## Verification matrix (per-ticket × per-run)

All five tickets are **BLOCKED** for all three runs, because no RELEASE build
with the 5 uncommitted changes could be produced or installed. There was no
new binary to exercise.

| Ticket | Run 1 | Run 2 | Run 3 | Notes |
|---|---|---|---|---|
| **AU-319** springboard icon = cat-face gradient + label "Macgie" | BLOCKED | BLOCKED | BLOCKED | Installed app's `CFBundleDisplayName = auxi` (OLD). Cannot rebuild to get "Macgie". |
| **AU-313** email → Google sign-in notice (`email-google-notice-continue-spinner`) | BLOCKED | BLOCKED | BLOCKED | New JS not bundled (no Release build). |
| **AU-315** Forgot PW → gmail → inline reset notice (`forgot-request-gmail-notice`) | BLOCKED | BLOCKED | BLOCKED | New JS not bundled. |
| **AU-314** unregistered non-gmail → SignIn invalid-credentials | BLOCKED | BLOCKED | BLOCKED | New JS not bundled. |
| **AU-311** item detail "Mix with this" r16 pill + [Cancel][Save] edit bar | BLOCKED | BLOCKED | BLOCKED | Needs login + new build; neither reachable. |

A ticket is "OK" only if it PASSES all 3 runs → **0 tickets OK** (0 verified).

### Why not verify against the already-installed app?

The app on the sim (`com.auxi2026.app`) is a stale build:
`simctl listapps` reports `CFBundleName = auxi` and `CFBundleDisplayName = auxi`
— i.e. pre-AU-319 (which renames to "Macgie"). It predates the 5 uncommitted
changes under test, so exercising it would verify nothing about this changeset
and would be misleading to report as a pass.

---

## Evidence / screenshots

mobile-mcp + simctl screenshots DO work (sim FS is under `~/Library`, readable):

- `plans/reports/qa-blocked-springboard.png` — sim springboard (first page = stock iOS apps only; auxi/Macgie not on page 1).
- `/tmp/auxi-qa-reports/springboard-installed-app.png` — same capture (tmp fallback, always writable).
- `/tmp/auxi-qa-reports/springboard-current.png` — earlier capture.

(No per-ticket / per-run screenshots — there was no new build to drive, so
au319-run1.png … au311-run3.png were not produced. Capturing the stale app
under those filenames would falsely imply the changeset was exercised.)

---

## What I did NOT do (and why)

- Did **not** run `react-native run-ios` repeatedly — the prerequisite source
  read fails with EPERM, so the build can't start; churning burns time with no
  chance of success (one-serious-attempt rule honored).
- Did **not** mark any ticket PASS off the stale installed binary — that would
  be a false positive on an unrelated build.

---

**Status:** BLOCKED
**Summary:** RELEASE build could not run — macOS TCC denies content reads under `~/Desktop/wardrobe_project/auxi` (`Operation not permitted`); RN CLis/xcodebuild can't read `package.json`. The brief's "TCC resolved / folder readable in-place" claim is false for this Bash host. 0/5 tickets verified (all BLOCKED). The installed sim app is a stale pre-AU-319 "auxi" build — not the changeset under test. mobile-mcp + simctl themselves work.
**Concerns/Blockers:** Need Full Disk Access granted to the host/terminal process for `~/Desktop`, then restart it (per `env_tcc_blocks_desktop_builds`). Until then no `auxi` build is possible. Note also the booted sim is iOS **18.1**, not 26.5 — confirm that's the intended target. Re-dispatch this same task once Desktop is genuinely readable (verify with `cat <auxi>/package.json` returning content, not EPERM).
