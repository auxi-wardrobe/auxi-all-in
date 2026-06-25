# Phase 02 — Override State + Bucket→temp_c Mapping + Persistence

**Context:** [plan.md](plan.md) · decisions D1/D2/D3 · skill `auxi-rn-patterns`

## Overview
- **Priority:** P0. **Status:** ☐. **Depends on:** Phase 01 PASS.
- Pure logic/state layer — no UI. Keeps `HomeScreen.tsx` (already 1700+ lines) thin by extracting a config + hook.

## Key Insights
- Recommendation request already carries temperature: `buildViaV05()` sends `weather: { temp_c: weather.tempC, is_rainy: false }` (`auxi/src/screens/HomeScreen.tsx:737`). Override = substitute `temp_c`.
- Backend `_climate_bucket(temp_c)`: `>28 HOT · ≥20 WARM · ≥15 MILD · <15 COOL`. Session cache reuses build-time temp for "Show another" → override persists across `/try_another` automatically.
- Existing session-state idiom = `useState` + mirrored `useRef` (e.g. `selectedMode`/`selectedModeRef`, `styleFeedback`), cleared on Home unmount (`HomeScreen.tsx:460–600, 681`). AsyncStorage precedent: `weatherService.ts` `LAST_WEATHER_KEY`.

## Decisions baked in (defaults — confirm w/ CEO)
- **D1 mapping (midpoint):** `28–40→33` · `10–25→18` · `0–7→4` · `-10–0→-5`; `weather`→no override (live temp). Flag `10–25` as lossy (spans COOL→WARM).
- **D2:** accept `0–7` & `-10–0` collapsing to backend COOL for MVP (ticket "same outfit" edge case). Revisit in Phase 07 if outfits must differ.
- **D3 persistence:** AsyncStorage, value `{ bucketKey, dateISO }`; load on Home mount, **expire if `dateISO` ≠ today** → fall back to weather.

## Files to CREATE
- `auxi/src/config/temperature-buckets.ts` — bucket definitions: `{ key, labelI18nKey, repTempC | null }`. `null` rep = "use current weather". Single source of truth for sheet + mapping + analytics keys.
- `auxi/src/hooks/useTemperatureOverride.ts` — owns: `activeBucketKey` state+ref, `repTempC` selector, `applyBucket(key)`, `clearOverride()`, AsyncStorage load/save w/ date expiry. Returns `{ activeBucketKey, overrideTempC, isOverrideActive, apply, clear }`.

## Files to MODIFY
- `auxi/src/screens/HomeScreen.tsx` — consume hook; at `:737` use `overrideTempC ?? weather.tempC`; thread same into pin-gen (`:957`) and prefetch `ensureBuffer` (`:1261`).

## Bucket config shape (illustrative, synthetic values)
```ts
export type TemperatureBucketKey = 'weather' | 'hot_28_40' | 'mild_10_25' | 'cold_0_7' | 'freezing_-10_0';
export const TEMPERATURE_BUCKETS = [
  { key: 'weather',        labelI18nKey: 'home.temp_use_current', repTempC: null },
  { key: 'hot_28_40',      labelI18nKey: 'home.temp_28_40',       repTempC: 33 },
  { key: 'mild_10_25',     labelI18nKey: 'home.temp_10_25',       repTempC: 18 },
  { key: 'cold_0_7',       labelI18nKey: 'home.temp_0_7',         repTempC: 4 },
  { key: 'freezing_-10_0', labelI18nKey: 'home.temp_-10_0',       repTempC: -5 },
] as const;
```

## Implementation Steps
1. Create `temperature-buckets.ts` (config + key type + `repTempCFor(key)` + `bucketLabel(t, key, liveTempC)`).
2. Create `useTemperatureOverride.ts` (state+ref, AsyncStorage `@auxi/temp_override` with date expiry, apply/clear).
3. Wire override temp into the 3 request sites in HomeScreen; keep `weather` mode = no override.
4. `npx tsc --noEmit` clean.

## Todo
- [ ] `temperature-buckets.ts` created (≤200 lines)
- [ ] `useTemperatureOverride.ts` created (state, ref, persist+expiry)
- [ ] 3 request sites use `overrideTempC ?? weather.tempC`
- [ ] tsc clean
- [ ] D1/D2/D3 confirmed or noted as provisional

## Success Criteria
With an active bucket, `/build` (and "Show another") send the bucket's rep temp; with `weather` selected, live temp is sent. Override survives reload same-day, resets next day.

## Risks
- `10–25` midpoint loses fidelity → escalate D1 if product wants finer control.
- Don't bloat HomeScreen — all new logic in the hook/config.
