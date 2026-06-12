# AU-303 Two-Axis Home Swipe — Behavioral Smoke (BLOCKED)

**Date**: 2026-05-31 13:26 (dispatch) / executed 14:38
**Verbatim instruction**: "verify AU-303 two-axis swipe fix on sim"
**Severity**: blocker (test infra, not product)
**Build/Branch**: `duc2820/au-303-...` worktree, served by Metro on :8081
**Device**: iOS Simulator iPhone 16 Pro (udid `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`), iOS 18.1
**App**: `com.auxi2026.app` (installed + running per dispatch)
**Lane**: mobile-mcp exploratory verify (ticket close-out smoke)

## Status: BLOCKED — WebDriverAgent not available, cannot drive gestures

The entire AU-303 checklist is gesture-driven (tap-to-dismiss overlays,
horizontal/vertical swipes, nested-pager handoff). mobile-mcp on the iOS
Simulator routes all taps/swipes/element queries through WebDriverAgent on
`:8100`. WDA is **not running**, so no checklist item can be exercised.

Per the qa-mobile MCP pre-flight boundary (mcp-doctor exit ≠ 0 → STOP, do
not fight cryptic mobile-mcp errors), execution is halted before the first
mobile-mcp call. No build/sim churn was attempted (memory caution honored —
nothing rebuilt or reinstalled).

## Pre-flight evidence

```
./scripts/mcp-doctor.sh  → EXIT 2
  ✓ Simulator booted: iPhone 16 Pro
  ! WebDriverAgent not responding on :8100 — invoking wda-install.sh
  ▸ Polling :8100 (timeout 180s)...
  ✗ WebDriverAgent startup failed — check Xcode signing, sim runtime, logs/wda.log
  ✗ WebDriverAgent failed to start.
```

Direct port probe (definitive):
```
curl -m5 http://localhost:8100/status  → http_code=000, curl_exit=7 (connection refused)
lsof -iTCP:8100 -sTCP:LISTEN           → (nothing listening)
```

## Root cause (from logs/wda.log)

```
xcodebuild: error: Unable to find a device matching the provided destination specifier:
  The requested device could not be found because no available devices matched the request.
```

`wda-install.sh` launched WebDriverAgentRunner via `xcodebuild test` but the
destination specifier did not resolve to the booted iPhone 16 Pro. The booted
device exists in `simctl` (and appears in xcodebuild's device list as
`id:9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916, OS:18.1, name:iPhone 16 Pro`), so the
runner's destination args are likely mismatched (name-only collision across
multiple "iPhone 16 Pro" runtimes, or missing explicit `id=` / `OS=` in the
xcodebuild destination). WDA never bound :8100 → mobile-mcp inert.

## Checklist — all UNTESTED (blocked at infra)

| # | Item | testID | Result |
|---|------|--------|--------|
| 1 | Overlay 1 dismiss via "Got it" only (backdrop tap = no-op) | `home-coachmark-dismiss-horizontal` | BLOCKED |
| 2 | Horizontal swipe cycles 3 outfits in set; dots track active | `home-pagination-dot-<i>-active` | BLOCKED |
| 3 | Overlay 2 (vertical) fires after 3 outfits viewed, "Got it" only | — | BLOCKED |
| 4 | Vertical swipe up/down changes SET (starts at outfit 0) | — | BLOCKED |
| 5 | 3-swipe ContextChipsModal fires, sequenced w/ overlay 2 (no overlap) | — | BLOCKED |
| 6 | Re-launch persistence (AsyncStorage dismissal) | — | BLOCKED |
| 7 | Red-box / console warnings / nested-pager diagonal jitter | — | BLOCKED |

## Routing

- **qa-ui / infra owner** — WDA destination resolution in `wda-install.sh`.
  Likely fix: pass explicit `-destination 'platform=iOS Simulator,id=9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916'`
  (id-pinned, not name) so the multi-runtime "iPhone 16 Pro" ambiguity can't
  steal the destination. Then re-run `./scripts/mcp-doctor.sh` to confirm
  :8100 binds.
- Not routed to mobile-dev/backend-dev — no product evidence gathered; this is
  test-harness only.

## Re-dispatch criteria

Once `curl http://localhost:8100/status` returns http 200 (WDA up), re-dispatch
this exact smoke. The app + Metro are already healthy; only WDA needs to come up.
No rebuild required — terminate + relaunch the app via Metro if it looks stale.

## Unresolved questions

- Does `wda-install.sh` accept a `UDID=` override env, or is the destination
  hard-coded by name? (Determines whether qa can self-heal vs. needs a script fix.)
- Is there a stale WDA build/derived-data that's targeting an 18.2/26.5 "iPhone
  16 Pro" runtime instead of the booted 18.1 one?

---
**Status:** BLOCKED
**Summary:** WebDriverAgent failed to bind :8100 (xcodebuild destination
did not match the booted iPhone 16 Pro), so mobile-mcp cannot send any
gesture. All 7 AU-303 two-axis checklist items are untested. Halted at
pre-flight per MCP boundary; no build/sim churn. Fix is in `wda-install.sh`
destination resolution (id-pin the booted udid), then re-dispatch.
**Blockers:** WDA not running on :8100 (connection refused).
