# Onboarding per-wardrobe styles verify — BLOCKED by boot red-box

**Verdict:** BLOCKED — could not reach Step 3 on any wardrobe. App red-boxes
during the onboarding flow with an uncaught error on app boot path.

**Severity:** blocker
**Repro rate:** 1/1 (hit on first run; relaunch reproduces the warning toast)
**Build:** branch `feat/onboarding-v2-redesign` (auxi submodule)
**Device:** iOS Simulator iPhone 16 / iOS 18.2 (`6371F8E8-893E-4D7C-8683-8A128B7996F8`)
**App:** `com.auxi2026.app`
**Backend:** :5001 local prod-mirror, health 200
**MCP:** mcp-doctor exit 0 (sim + WDA + mobile-mcp healthy)

## What happened

The dispatch said the app was on Home (qa-test logged in). On screenshot it was
actually mid-onboarding (Step 2 / fit screen) from a prior session. I terminated
and relaunched `com.auxi2026.app` to get a clean entry point — it resumed at the
onboarding **Welcome** screen (not Home), so I drove the flow forward directly
instead of via Replay:

- Welcome → tapped CTA → advanced to **LocationPermission** OK
- LocationPermission → "Not now" → advanced to **Step 1 / wardrobe** OK
- Step 1: tapped `onboarding-wardrobe-tile-womenswear` (selection border showed) OK
- Step 1 → **Continue** did NOT advance across multiple coordinate taps

A persistent yellow RN warning toast ("Open debugger to view warnings") sat at
the bottom the entire time and was swallowing taps near the Continue button.
Tapping into it expanded the **LogBox red-box**:

```
Uncaught Error
Property 'grantAnalyticsConsent' doesn't exist

Source — App.tsx:33
  if (__DEV__) {
    grantAnalyticsConsent().catch(err =>
      console.warn('[App] analytics init failed', err),
    );
  } else {

Call Stack
  <global>        App.tsx:33:3
  eval
  invoke          EventTarget.js:382:29
  dispatch
  dispatchEvent
  <global>        RCTDeviceEventEmitter.js:14:59
  RCTDeviceEventEmitterImpl#emit
```

Screenshot: `auxi/docs/qa-findings/screenshots/2026-05-27/qa-mobile-redbox-grantAnalyticsConsent.png`

## Root cause (suspected): stale JS bundle, not a source bug

The symbol the runtime says is missing **exists on disk and is wired correctly**:

- `auxi/src/services/analytics.ts:98` — `export const grantAnalyticsConsent = async (): Promise<void> => {`
- `auxi/App.tsx:18` — `import { grantAnalyticsConsent, initAnalytics } from './src/services/analytics';`
- `auxi/App.tsx:33` — the `__DEV__` call site that throws

So this is a runtime/bundle mismatch, not a code defect in the working tree.
The app binary on the sim is running a JS bundle that predates the
`grantAnalyticsConsent` export. The dispatch noted Metro :8081 was "fresh
(reset-cache, new style assets bundled)" — but the loaded bundle the sim
booted against does NOT have this export evaluated, so either:

1. The app launched against a cached/old bundle (didn't pick up the
   reset-cache Metro), or
2. The native binary is stale vs the current branch deps and needs a rebuild
   (matches the known `v05_sim_verify_method` note: "rebuild native if binary
   stale vs branch deps").

The error is on the App.tsx module-load path (`if (__DEV__)`), so it fires on
every boot in dev and renders LogBox over the UI, which is what blocked the
Continue tap on Step 1.

## Impact on the requested verify

Could not reach Step 3 (Styles) on ANY wardrobe. **Zero of the three passes
(Womenswear / Mixed / Menswear) were executed.** No claim can be made about
whether the per-wardrobe outfit imagery is correct — the fix under test was
never reached.

I navigated cleanly through Welcome → Location → Step 1 and confirmed the Step 1
wardrobe tiles render and carry the expected testIDs
(`onboarding-wardrobe-tile-womenswear/-menswear/-mixed`), but the boot error
gates everything past Step 1 Continue.

## Routing

- **mobile-dev / dispatcher** — the running bundle is stale. Re-bundle against
  the fresh Metro and relaunch, OR rebuild the native app from the current
  `feat/onboarding-v2-redesign` HEAD, then re-dispatch this verify. The source
  tree is correct; no code change needed if it's purely a bundle/binary refresh.
- If after a clean rebuild the red-box still fires, then escalate as a real
  `App.tsx:33` / `src/services/analytics.ts` defect to **mobile-dev** — but
  current evidence points to a stale-bundle, not a source bug.

## Where I stopped (no churn)

Stopped at the red-box per the "if a screen red-boxes, capture + STOP" rule.
Did not modify any `src/**` or YAML. Did not loop coordinates further once the
red-box was identified as the obstruction. Sim left on the LogBox screen for
developer inspection.

## Unresolved questions

1. Was the sim app actually relaunched against the fresh reset-cache Metro, or
   did it attach to a cached bundle? (Needs a confirmed re-bundle + relaunch.)
2. Is the installed `com.auxi2026.app` binary built from current branch HEAD,
   or is it stale vs branch deps?
