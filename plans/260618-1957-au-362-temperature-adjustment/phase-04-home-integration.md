# Phase 04 — Home Integration (trigger, header swap, refetch, states, edge cases)

**Context:** [plan.md](plan.md) · `auxi/src/screens/HomeScreen.tsx` · depends on Phases 02 + 03

## Overview
- **Priority:** P0. **Status:** ☐.
- Wire the hook (P02) + sheet (P03) into Home: open trigger, header indicator, Apply→refetch, loading/error, concurrency guard, edge cases.

## Key Insights / seams (file:line)
- Header inline at `HomeScreen.tsx:1720–1771`; weather element `<WeatherWidget>` at `:1736`.
- Lightbulb trigger sits by the "Clean. Ready for today" status pill (per Figma) — add a `TopIconButton`/pressable near that pill; active/highlighted when override on.
- Recommendation mutation `valenGetRecommendation` / `buildViaV05` at `:767–880`; request temp at `:737`.
- "Show another" / prefetch reads refs → must read `overrideTempCRef` (P02) so buffered outfits use the override.

## Requirements (ticket scenarios)
- **Open:** tap lightbulb → sheet opens, no request, active bucket pre-selected.
- **Apply (override):** close sheet, set `isApplying`, refetch `/build` with rep temp, swap header weather→override indicator (+ label), lightbulb→active. On success: cards update; on error: keep sheet open w/ inline error, indicator unchanged.
- **Apply (weather):** clear override, refetch with live temp, restore weather icon, lightbulb→idle (ticket "Return to current weather").
- **Header (override active):** override indicator + selected range label; weather icon hidden; lightbulb available.
- **Edge — same option re-applied:** close sheet, **no new request** (compare pending vs active bucket).
- **Edge — same outfit returned:** keep outfit, keep indicator (no error).
- **Concurrency guard (high-risk):** tag each Apply with an incrementing `requestId` (ref); on response, **ignore if not the latest** id → stale Apply can't overwrite newer. (Backend already SETNX-locks per session for try_another; this guards the client build race.)

## Files to MODIFY
- `auxi/src/screens/HomeScreen.tsx` — import hook + sheet; add lightbulb pressable; conditional header element; `applyTemperature(key)` handler (requestId guard, refetch, analytics from P05); sheet visibility state.
- (new, optional) `auxi/src/components/features/TemperatureOverrideIndicator.tsx` if the header element is non-trivial — keeps HomeScreen thin.

## Implementation Steps
1. Mount sheet + visibility state; lightbulb opens it.
2. Conditional at `:1736`: `isOverrideActive ? <TemperatureOverrideIndicator label={…}/> : <WeatherWidget …/>`.
3. `applyTemperature(key)`: if `key===activeBucketKey` → just close. Else bump `requestId`, `apply/clear` (hook), refetch build with `overrideTempC ?? weather.tempC`, guard response by `requestId`, map error→`errorKey`.
4. Loading: pass `isApplying` to sheet; disable Apply/radios.
5. Wire analytics (Phase 05) at each transition.
6. `tsc --noEmit` + `yarn lint` clean.

## Todo
- [ ] Lightbulb trigger + active state
- [ ] Header conditional swap (weather ↔ override indicator + label)
- [ ] Apply→refetch with override temp; weather-select clears
- [ ] requestId concurrency guard (stale response dropped)
- [ ] Edge cases: same-option no-op, same-outfit keep
- [ ] Loading + error states wired to sheet
- [ ] tsc + lint clean

## Success Criteria
All ticket scenarios (primary, override-display, reopen, secondary, edge, error, loading, high-risk) behave; header never mismatches the active mode (high-risk "mismatch"/"state lost" avoided).

## Risks
- **Header/recommendation mismatch** & **override-not-cleared** are named high-risk → single source of truth = the hook; header + request both read it. No duplicate temp state.
- HomeScreen size — push indicator to its own component.
