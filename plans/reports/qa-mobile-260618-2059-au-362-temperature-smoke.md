# QA Mobile Smoke — AU-362 Outfit Temperature (step 7 gate)

**Date:** 2026-06-18 21:06
**Verify ID:** sim 9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916 (iPhone 16 Pro, iOS 18.1) · installed build `com.auxi2026.app-1781698661573.app` (built **Jun 17 19:17 2026**)
**Source under test:** auxi @ `4dfb4082` (branch `duc2820/au-362-uac-outfit-temperature-adjustment-temperature-aware-outfit`, AU-362 committed Jun 18 20:53)
**Backend:** healthy on :5001 (`/health` → 200) — full happy path was available
**MCP pre-flight:** `./scripts/mcp-doctor.sh` → exit 0 (sim booted, WDA :8100 up, mobile-mcp 0.0.56)

## Verdict up front

**The installed simulator binary does not contain the AU-362 build and cannot be cold-launched.** Smoke could not be executed. This is an environment blocker, not a feature defect.

## What happened

1. On first `launch_app`, the app showed a **warm leftover process** from the prior qa-ui/designer session — the Outfit Temperature sheet was already open with stale state (`10 - 25°C` radio selected, header already showing a `-10 - 0°C` override indicator + active pill). This was NOT a clean run; it was a previously-rendered frame from someone else's session.
2. To get a clean baseline I terminated + relaunched. **Every cold launch redboxes** with:
   `[@RNC/AsyncStorage]: NativeModule: AsyncStorage is null.` (throws at module init, `@react-native-async-storage/.../NativeAsyncStorage` line 23, before the app mounts).
3. Metro is running and healthy (:8081 `packager-status:running`). A Metro `/reload` did NOT clear it — the throw fires during native-module init, so reloading the same binary reproduces it.
4. No native crash reports for Auxi (`list_crashes` shows only unrelated 2024/2025 entries). This is a JS redbox, app process alive but stuck on the dev error overlay.

## Root cause (binary integrity, confirmed)

- Installed `.app/auxi` binary build time: **Jun 17 19:17 2026** — predates the AU-362 commit (Jun 18 20:53).
- `nm` / `strings` on the installed binary: **no `RNCAsyncStorage` / `RCTAsyncStorage` symbols present** — the AsyncStorage native module is not linked into this binary.
- Therefore the binary on the device (a) is older than the feature commit and does not contain AU-362, and (b) is missing a native dependency the JS bundle requires, so it cannot cold-start.

The earlier "working" warm process was stale prior-session render state, not valid evidence of the AU-362 build behaving correctly.

## Smoke checklist results

| # | Step | Result | Note |
|---|------|--------|------|
| 1 | Tap lightbulb → sheet opens, no request, "Use current weather" preselected | BLOCKED-BY-ENV | Cold launch redboxes; warm leftover showed sheet but with stale `10-25°C` selected, not the default |
| 2 | Select range (0–7°C) → radio toggles, Apply enabled | BLOCKED-BY-ENV | Cannot reach clean Home |
| 3 | Apply → sheet closes, outfit refreshes, header override + label, weather hidden, pill active | BLOCKED-BY-ENV | — |
| 4 | Show another / Remix → override persists | BLOCKED-BY-ENV | — |
| 5 | Reopen sheet → previously-selected range preselected | BLOCKED-BY-ENV | — |
| 6 | "Use current weather" → Apply → weather widget returns, indicator gone, pill idle | BLOCKED-BY-ENV | — |
| 7 | Reopen, select same active option, Apply → close, no reload | BLOCKED-BY-ENV | — |
| 8 | Backend-down → inline error, sheet stays open, Apply re-enabled | BLOCKED-BY-ENV | Backend was UP; could not exercise client error path either |

## Evidence

- Redbox: `auxi/docs/qa-findings/screenshots/2026-06-18/qa-mobile-au362-redbox-asyncstorage.png`
- Stale warm-process sheet (first launch, prior-session state): observed via `list_elements_on_screen` + screenshot before termination.

## Routing / next action

This is a **build/install** issue, owned by the person who controls the simulator build:
- Reinstall the AU-362 build on the sim from source `4dfb4082` via the boot/build path (`./scripts/qa-boot.sh` or `yarn ios:sim` from auxi on Node 20). qa-mobile does not build/install per boundaries (no booting, no building, no src edits).
- The `AsyncStorage is null` redbox must be resolved in the freshly-built binary (clean `pod install` + rebuild so `RNCAsyncStorage` links). If it persists on a fresh build, that is a `mobile-dev` / native-deps task, not AU-362 feature logic.
- Once a real AU-362 build is installed and cold-launches to Home, re-dispatch this same 8-step smoke.

## Unresolved questions

- Was the sim ever running the AU-362 build, or only the Jun 17 binary the whole time (prior qa-ui/designer gates may have run against a warm process too — worth confirming their build provenance)?
- Does `AsyncStorage is null` reproduce on a clean rebuild, or is it specific to this stale install?

---

**Verdict:** FAIL (blocked) — could not smoke AU-362; installed binary predates the feature commit and cannot cold-launch.
**Status:** BLOCKED
**Summary:** Sim build is Jun-17 (pre-AU-362) and missing the AsyncStorage native module, so every cold launch redboxes — feature is not in the installed binary; needs a fresh AU-362 build/install before the step-7 smoke can run.
