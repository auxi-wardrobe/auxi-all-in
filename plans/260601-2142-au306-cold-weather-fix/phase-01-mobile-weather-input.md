---
phase: 1
title: Mobile Weather Input
status: completed
priority: P1
effort: 0.5-1d
dependencies: []
---

# Phase 1: Mobile Weather Input (auxi)

## Overview
Fix the **dominant** cause: the app fetches weather for hardcoded Hanoi coords and never uses device location, so any user outside Hanoi is dressed for warm weather. Wire real geolocation and stop masking failures as a warm 22C. Repo: `auxi/` only (`mobile-dev`).

## Context
- Research: `plans/reports/research-260601-2135-au306-cold-weather-rootcause.md` (causes #1, #6).
- `auxi/src/utils/location.ts` already exposes `getCurrentLocation()` (real `Geolocation.getCurrentPosition`) — **zero callers** today.
- Current auxi HEAD `d76d98b2` already added a `weatherLoaded` gate (HomeScreen.tsx:474, 771-783) — keep it; it now also covers location resolution.
- Units are already consistent (°C end-to-end) — do NOT introduce any conversion.

## Requirements
- Functional: Home weather reflects the user's **real location**; recommendation `temp_c` matches the displayed widget temp; weather-fetch failures are observable and fall back to last-known (not a silent warm constant).
- Non-functional: no regression to the `weatherLoaded` first-build gate; graceful permission-denied handling; no added latency beyond one location lookup.

## Related Code Files
- Modify: `auxi/src/screens/HomeScreen.tsx` (weather-fetch effect ~:476-483; build body ~:582)
- Modify: `auxi/src/services/weatherService.ts` (silent fallback ~:9-25)
- Read/use: `auxi/src/utils/location.ts` (`getCurrentLocation`)
- Possibly add: last-known-weather cache via existing AsyncStorage pattern (`auxi/src/services/tokenStorage.ts` for reference)
- Tests: `auxi/src/services/__tests__/weatherService.test.ts`

## Implementation Steps
1. **#1 Wire geolocation.** In HomeScreen's weather effect, replace the literal `getWeather(21.0285, 105.8542)` with: resolve coords via `getCurrentLocation()` first, then `getWeather(lat, lon)`. Keep it inside the `weatherLoaded`-gated flow (set `weatherLoaded` in `.finally`).
2. **Fallback chain (no silent Hanoi) — concrete order.** On `getCurrentLocation()` denial/error, resolve in this order: (a) last-known coords from AsyncStorage; (b) device-locale/region-derived coarse coords (e.g. map the system region to an approximate city — NOT hardcoded Hanoi); (c) last resort — surface a "weather unavailable" state and do **not** bias the recommendation temp warm (prefer skipping/holding the build over sending a warm default). Every fallback step logs a warning + Sentry breadcrumb identifying which tier was used.
3. **Persist last-known.** On a successful location+weather fetch, cache `{lat, lon, temp_c, condition, fetchedAt}` to AsyncStorage for the fallback above.
4. **#6 Instrument weatherService failure.** In `weatherService.getWeather` catch block (`:22-23`): log the error (console.warn + Sentry), and return last-known cached weather if available instead of the hardcoded `temp_c:22`. Only fall back to a neutral constant as last resort, flagged (e.g. `isFallback: true`) and logged. Do not swallow silently.
5. **(Optional / stretch) #is_rainy.** At HomeScreen build body (`:582`), derive `is_rainy` from `weatherService` `condition` (Rain/Snow/Drizzle/Thunderstorm → true) instead of hardcoding `false`. Mark clearly; skip if it expands the diff.
6. `npx tsc --noEmit && yarn lint` clean.

## Success Criteria
- [ ] Home requests weather for device coords (verified: `getCurrentLocation()` is called on mount; repo search shows it now has a caller).
- [ ] On a simulated cold location, the `temp_c` in the `POST /v05/recommendation/build` body equals the displayed widget temp and reflects the cold location (not Hanoi).
- [ ] Weather-fetch failure logs an error and uses last-known (not a silent 22C); regression test asserts this.
- [ ] Permission-denied path handled without crash; falls back with a logged warning.
- [ ] `weatherLoaded` first-build gate still works (spinner until weather settles).
- [ ] tsc + lint clean.

## Risk Assessment
- **Permission denied / no last-known:** the fallback order is fixed in Step 2 (last-known → locale-coarse → "weather unavailable", never silently warm/Hanoi). Surface a non-blocking "using approximate location" hint if desired.
- **iOS sim location:** simulate a cold city via Xcode sim location for verification (Phase 3).
- **Scope creep:** keep is_rainy optional; the geolocation + fallback are the must-haves.
