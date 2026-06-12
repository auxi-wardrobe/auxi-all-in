# QA Mobile Smoke — AU-226 Favourite + "See this on me"

**Date**: 2026-06-12 09:32–09:48
**Build under test**: worktree `/Users/nguyenminhduc/dev/auxi-favourite-wt` · branch `feat/au226-favourite-and-see-this-on-me`
**Device**: iPhone 16 Pro (iOS 18.1) · UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`
**App**: `com.auxi2026.app` (Debug, JS-only swap onto worktree Metro)
**Backend**: existing `:5001` (reused, not restarted)
**Auth**: existing logged-in session — landed straight on Home, no login required.
**Metro/JS log**: clean — bundle 1986 modules, 0 resolve errors, 0 redbox, 0 warnings.
**Crashes**: none for `com.auxi2026.app` (only stale unrelated 2024/2025 reports on device).

## Setup (JS-only swap)

1. Killed existing Metro (PID 81859) on :8081 — freed port.
2. Worktree had no `node_modules`. First attempt: directory-symlink the main
   submodule's modules → **Metro failed** `Unable to resolve module
   @babel/runtime/helpers/interopRequireDefault` (Metro resolves the symlink's
   real path, which falls outside the worktree project root).
3. Fix: in worktree `metro.config.js` added `watchFolders` +
   `resolver.nodeModulesPaths` pointing at the main submodule's `node_modules`
   (standard monorepo pattern). `node_modules` left as a real dir of per-package
   symlinks. **This is a disposable test-worktree config edit — not `auxi/src`,
   not a Maestro flow, not the main submodule.** qa-ui must keep it to re-run.
4. Restarted Metro from worktree (`--reset-cache`), relaunched app → clean
   bundle, Home rendered.

## Flow 1 — Favourite (Love Collection)

| Step | Result | Evidence |
|---|---|---|
| Sidebar → "My Favourite" navigates (was no-op) | **PASS** — opens Favourite screen (header "Favourite") | `01-favourite-after-nav.png` |
| Date-grouped list | **PASS** — "31 May / 27 May / 18 May / 6 May" headers | `02-favourite-grid-layout.png` |
| Item grids + rarity tags | **PASS** — item images + "common" tags | (elements dump) |
| Per-outfit ⊖ remove + "Self visualization" | **PASS** — testIDs `favourite-remove-<uuid>`, `favourite-self-visualization-<uuid>` | `02..` |
| Grid layout | **PASS** | `02-favourite-grid-layout.png` |
| Collage layout (toggle) | **PASS** — footer flips `home-footer-tab-grid-active` → `home-footer-tab-collage-active` | `03-`, `04-favourite-collage-toggled.png` |
| ⊖ remove → confirm dialog (danger) | **PASS** — "Remove from your favourite / Are you sure…" with Cancel + red **Yes** | `06-favourite-remove-dialog.png` |
| Confirm → outfit leaves list | **PASS** — `fa6a7e2d…` removed, next outfit promoted to top | `08-favourite-removed-confirmed.png` |

Did NOT empty the whole list — removed exactly one outfit (data preserved).
Account has ~16 favourites, so empty-state was not reachable without destroying
data; empty-state path NOT verified this run (note below).

## Flow 2 — "See this on me" (from Favourite)

| Step | Result | Evidence |
|---|---|---|
| Tap "Self visualization" → launches STOM (not old Body screen, not no-op) | **PASS** — header "Self visualization", step "1/3" | `09-stom-step1-selfie.png` |
| Step 1 selfie UI | **PASS** — "1/3 – Start with a selfie photo…", "Take photo 📷", "Your photos are always kept private" | `09-` |
| "Take photo" action fires | **PASS (action)** — opens image picker | `11-stom-takephoto-action.png` |
| Camera capture on sim | **BLOCKED by environment** — "Error / Failed to pick image" (iOS Simulator has no camera) | `11-` |
| Error dismiss (OK) | **PASS** — returns to Step 1, no crash/redbox | `12-stom-after-error-dismiss.png` |
| Step 2 full-body / Skip | **NOT REACHED** — gated behind Step 1 camera capture |
| Step 3 body-shape carousel | **NOT REACHED** |
| Generate → loading → preview | **NOT REACHED** |

The STOM flow is correctly wired and the entry + Step 1 render perfectly. Steps
2/3/generate/preview could not be exercised because **Step 1's "Take photo" uses
the camera source**, which the iOS Simulator cannot satisfy. This is an
environment limitation, not a flow defect.

## Findings

1. **[minor / qa-ui] Favourite toggle reuses Home footer testIDs.** The
   grid↔collage toggle on Favourite exposes `home-footer-tab-grid(-active)` /
   `home-footer-tab-collage(-active)`, NOT the `favourite-toggle-grid` /
   `favourite-toggle-collage` testIDs named in the dispatch. Functionally
   correct (state flips, layout changes). If qa-ui authors a Maestro flow, the
   selectors must use the `home-footer-tab-*` IDs OR mobile-dev should add
   dedicated favourite testIDs. Route: qa-ui (flow author) / mobile-dev (testID).

2. **[env-blocked / not a bug] STOM Step 1 needs camera → unverifiable on sim.**
   "Take photo" → "Failed to pick image" on the simulator. To smoke Steps 2/3 +
   generate/preview, run on a physical device OR have mobile-dev expose a
   gallery/dev source for Step 1 in Debug builds. Route: info only.

3. **[note] Drawer + dialog + STOM overlays not in mobile-mcp a11y tree.** The
   left drawer, the remove confirm dialog, and STOM Step 1's "Take photo"/back
   button do not appear via `list_elements_on_screen` (only the underlying
   screen does). Navigated via screenshot-derived coordinates. If qa-ui writes
   Maestro flows here, verify these overlays carry testIDs so selector-based
   assertions work. Route: qa-ui.

## Not verified (out of reach this run)
- Favourite empty state (green heart + "Tap 'Wear this'…" copy) — would require
  emptying the list (destructive) or a fresh account.
- STOM Steps 2 (full-body/Skip), 3 (body-shape carousel), generate/loading,
  preview ("Your outfit preview" + opt-in + Back to home) — gated by Step 1
  camera on simulator.
- `stom-step-2/3`, `stom-skip`, `stom-generate`, `stom-preview-image`,
  `stom-back-home` testIDs — never rendered.

## Screenshots
`/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/qa-screens/`
- `00-home-loaded.png`
- `01-favourite-after-nav.png`
- `02-favourite-grid-layout.png`
- `03-favourite-collage-layout.png`
- `04-favourite-collage-toggled.png`
- `06-favourite-remove-dialog.png`
- `07-favourite-after-remove.png` (dialog still up — mis-tap)
- `08-favourite-removed-confirmed.png`
- `09-stom-step1-selfie.png`
- `11-stom-takephoto-action.png` (Failed to pick image)
- `12-stom-after-error-dismiss.png`

## Left running (for qa-ui follow-up)
- Metro (worktree) PID 56501 on :8081 — `packager-status:running`.
- App `com.auxi2026.app` PID 57258 on the booted sim.
- Worktree `node_modules` + `metro.config.js` edit intact (do NOT revert).

---

## STOM completion (library path) — BLOCKED (2026-06-12 09:57)

**Goal**: re-run the "See this on me" smoke now that photo steps offer "Choose from library" (sim-friendly path), to clear the earlier camera block on Steps 2/3 + generate + preview.

**Outcome**: BLOCKED at MCP pre-flight. No STOM steps executed; no app relaunch; no library seeding performed; worktree untouched.

### Blocker — WebDriverAgent failed to start (mobile-mcp unusable)
- `./scripts/mcp-doctor.sh` → **exit 2**.
- Doctor found the sim booted (iPhone 16 Pro) but WDA not responding on `:8100`; it auto-invoked `wda-install.sh` (`xcodebuild test` of WebDriverAgentRunner), which **did not respond within the 180s poll**.
- Independent checks: `lsof -iTCP:8100 -sTCP:LISTEN` → nothing listening. `curl :8100/status` → no response.
- WDA log (`/Users/nguyenminhduc/Desktop/wardrobe_project/logs/wda.log`) tail shows only the xcodebuild destination enumeration dump (no successful "ServerURLHere"/test-bundle-started line) — the WDA runner build/launch did not complete. Doctor printed: `✗ WebDriverAgent startup failed — check Xcode signing, sim runtime`.

Per qa-mobile MCP pre-flight rule (exit ≠ 0 → STOP, don't fight cryptic mobile-mcp/WDA errors), execution halted before any `mobile-mcp` call.

### Per-step result
| Step | Result | Notes |
|---|---|---|
| Pre-flight (`mcp-doctor.sh`) | FAIL | WDA did not come up on :8100 within 180s; doctor exit 2 |
| Seed photo library | NOT RUN | gated behind working mobile-mcp / app relaunch |
| Relaunch app (hot-reload pickup) | NOT RUN | gated |
| STOM Step 1/3 selfie (PhotoSourceSheet → gallery) | NOT RUN | blocked |
| STOM Step 2/3 full-body (skip + gallery) | NOT RUN | blocked |
| STOM Step 3/3 body shape (BodyShapeCarousel) | NOT RUN | blocked |
| Generate → preview (`stom-generate` → `stom-preview-image`) | NOT RUN | blocked — no API credits spent |
| Back to home (`stom-back-home`) | NOT RUN | blocked |

### Screenshots
None (no mobile-mcp session opened).

### Crashes
Not re-checked (mobile-mcp `get_crash` unavailable); prior section already noted none for `com.auxi2026.app`.

### To unblock (user action)
WDA is the missing piece, not the app. Suggested:
1. Re-run `./scripts/qa-boot.sh` (runs the MCP doctor / WDA install as part of boot) and confirm it exits 0, OR
2. Re-run `./scripts/mcp-doctor.sh` directly and confirm `:8100/status` returns 200, then re-dispatch this STOM smoke.
3. If WDA keeps failing: check Xcode signing for WebDriverAgentRunner + that the iOS 18.1 sim runtime is fully installed (log tail at `/Users/nguyenminhduc/Desktop/wardrobe_project/logs/wda.log`).

Note: this STOM smoke did NOT touch Metro (:8081) or the worktree — both left as the parent handed them off. The `lsof` from the sandboxed shell did not surface the :8081 listener (sandbox visibility), but nothing was killed or restarted by this run.
