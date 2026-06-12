# QA Mobile Sim Verify — 2026-06-10 17:55

**Dispatch:** Build + install + run auxi on iOS sim, verify 5 uncommitted changes (AU-319, AU-313, AU-315, AU-314, AU-311) via mobile-mcp.
**Target sim:** iPhone 16 Pro `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916` (booted, iOS 18.1) — confirmed booted.
**Work context:** /Users/nguyenminhduc/Desktop/wardrobe_project/auxi

## Build outcome: FAILED TO START — macOS TCC blocker NOT resolved

The build never started. Metro failed to launch and node cannot operate under the
project tree. This is the same macOS TCC `uv_cwd` blocker documented in memory
(`env_tcc_blocks_desktop_builds.md`) — it is **still active**, despite the dispatch
stating "Warp granted Full Disk Access + restarted, TCC fixed."

### Evidence (verbatim)

Metro launch (`yarn start`) crashed immediately:
```
Error: EPERM: operation not permitted, uv_cwd
    at process.wrappedCwd [as cwd] (node:internal/bootstrap/switches/does_own_process_state:142:28)
    at /usr/local/lib/node_modules/yarn/lib/cli.js:88715:65
    ... at start (.../yarn/lib/cli.js:88759:18)
```

Direct probes (run from /tmp, absolute paths):
```
node process.cwd() in /tmp                         -> OK  (/private/tmp)
node process.cwd() in $HOME                         -> OK  (/Users/nguyenminhduc)
node process.cwd() in ~/Desktop                     -> OK  (/Users/nguyenminhduc/Desktop)
node process.cwd() in .../wardrobe_project/auxi      -> FAIL: EPERM uv_cwd
node fs.readFileSync(.../auxi/package.json)          -> FAIL: EPERM open
node process.cwd() via /tmp symlink -> real path     -> FAIL: EPERM uv_cwd (TCC resolves realpath)
xattr .../wardrobe_project                           -> FAIL: Operation not permitted
```

POSIX perms are clean and owned by the current user — so this is NOT a file-permission
problem, it's TCC sandboxing:
```
stat wardrobe_project: drwxr-xr-x nguyenminhduc:staff flags=- (no ACL, no restrictive flags)
stat Desktop (control): drwx------ nguyenminhduc:staff  (TCC-protected, but node CAN getcwd here)
```

### Root cause

Host process chain for this session:
```
my shell -> claude (pid 1977) -> -zsh -> Warp.app (pid 98213)
```
Warp is the host. `~/Desktop` itself is accessible to node, but the specific subtree
`~/Desktop/wardrobe_project/` and below denies `getcwd`/`open`/`xattr` with
`Operation not permitted` while POSIX says full access. That mismatch (owner has rwx,
syscall still EPERM) is the TCC signature. The running Warp process is operating under a
**stale/cached TCC token** — the FDA grant was added but the live process did not pick it
up. Symlink and realpath tricks do not bypass it (TCC evaluates the resolved real path).

Per dispatch constraints I did **not** loop or attempt to "fix" Xcode/pods/TCC. No build
retry was warranted — the failure is environmental, not transient (Metro was confirmed
not-up before launch; the crash is `uv_cwd`, not a Metro race).

### Fix to unblock (hand back to user)

1. Fully **Quit Warp** (Cmd-Q — not just close the window/tab; the process must exit).
2. System Settings -> Privacy & Security -> **Full Disk Access** -> confirm Warp toggle is
   ON. If already on, toggle it OFF then ON to force a fresh TCC token.
3. Relaunch Warp, start a fresh Claude session, re-dispatch.
4. Sanity gate before rebuild:
   `cd /Users/nguyenminhduc/Desktop/wardrobe_project/auxi && node -e "console.log(process.cwd())"`
   must print the path with no `EPERM uv_cwd`. Only then run Metro + `run-ios`.

## Per-ticket verdicts

| Ticket | What was to be verified | Verdict |
|---|---|---|
| AU-319 | Springboard icon = cat-face gradient + label "Macgie" | BLOCKED — no build, app not (re)installed with change |
| AU-313 | Gmail on email-entry -> Google sign-in notice (`email-google-notice-continue-spinner`) | BLOCKED — no build |
| AU-315 | Forgot Password + gmail -> inline "reset in Gmail" (`forgot-request-gmail-notice`) | BLOCKED — no build |
| AU-314 | Unregistered non-gmail -> SignIn invalid-credentials fall-through (expected) | BLOCKED — no build |
| AU-311 | Item detail redesign: rounded-rect "Mix with this" pill (r16), Trash/Less used/Change row, edit mode [Cancel][Save] | BLOCKED — no build |

All five require the new binary on the sim. Since the bundle could not even be built/served
(Metro down, node EPERM), zero tickets could be exercised. No screenshots captured — the new
code is not running on the sim, so any screenshot would show stale (already-installed) state
and would be misleading, not evidence.

## Notes
- Sim is genuinely booted and healthy — not the blocker.
- node_modules / ios/Pods / Podfile.lock all present — incremental build would have been fast
  IF TCC allowed it.
- No source code edited. No commits/pushes. The stray Metro launch attempt crashed on start
  (never bound :8081); no lingering process.

**Status:** BLOCKED
**Summary:** Build never started — macOS TCC `uv_cwd` blocker is still active under
`~/Desktop/wardrobe_project/` (Warp running on a stale TCC token despite the FDA grant).
node/yarn/xcodebuild all EPERM on `getcwd`/`open` in the project tree; Metro crashed on
launch. All 5 tickets (AU-319/313/315/314/311) BLOCKED — no new binary on sim, no
screenshots (capturing stale install would be misleading).
**Concerns/Blockers:** Fully quit Warp (Cmd-Q), re-confirm/toggle Full Disk Access for Warp,
relaunch, and gate on `node -e "process.cwd()"` succeeding under `auxi/` before re-dispatch.
The earlier "TCC fixed" assumption was not validated against a child process — the grant did
not take effect for the live Warp process.
