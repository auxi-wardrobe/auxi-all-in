# mobile-dev — AU-362 Outfit Temperature Adjustment (delivery)

Branch: `duc2820/au-362-...` (unchanged, not committed). Plan: `plans/260618-1957-au-362-temperature-adjustment/`.

## Extraction artifact
`plans/260618-1957-au-362-temperature-adjustment/figma-extraction-temperature-sheet.md`
— 3 frames (Home-weather / sheet / override), tokens, icons, variants, D1/D4 resolved, no new BE fields. Note: Figma `Frame 2014` inner node names are stale mislabels ("Type/Color/Fit/Style"); rendered screenshot is source of truth for the radio list.

## Files created
- `auxi/src/config/temperature-buckets.ts` — bucket config (key/labelI18nKey/repTempC) + `repTempCFor`, `bucketLabel`, `isOverrideBucket`, `isTemperatureBucketKey`. Single source of truth (D1 midpoints: 33/18/4/-5; `weather`→null).
- `auxi/src/hooks/useTemperatureOverride.ts` — `activeBucketKey` state + `activeBucketKeyRef`/`overrideTempCRef` mirrors, `apply`/`clear`, AsyncStorage `@auxi/temp_override` `{bucketKey,dateISO}` w/ same-day expiry (D3). Returns `{activeBucketKey, overrideTempC, overrideTempCRef, isOverrideActive, apply, clear}`.
- `auxi/src/components/features/TemperatureOverrideSheet.tsx` — Modal sheet cloned from ContextChipsModal/MoodFeedbackSheet. Radios from config, pre-selects active key on open, local pending selection, Apply (PillButton, loading spinner/disabled), Cancel, inline error banner, reduce-motion fallback + open/close duration asymmetry, tokens-only, testIDs on each radio + Apply + Cancel + backdrop.
- `auxi/src/components/features/TemperatureOverrideIndicator.tsx` — header override pill (person icon + selected bucket label + chevron; tap re-opens sheet). Keeps HomeScreen thin.

## Files modified
- `auxi/src/screens/HomeScreen.tsx` — hook wired; sheet mounted; lightbulb trigger (the existing insight pill in OutfitCardCaption, threaded via OptionSheet `onPressInsight`/`insightActive`); header conditional swap (`isOverrideActive ? indicator : WeatherWidget`); `applyTemperature` handler (same-option no-op, requestId guard, reset+force build, error→errorKey); override temp threaded into all 3 request sites (build `:737`-equiv now reads `overrideTempCRef.current ?? weather.tempC`, pin-gen, prefetch inherits via build chokepoint); onSuccess/onError resolve the LATEST apply only (stale guard); 6 analytics events fired at transitions.
- `auxi/src/components/features/OutfitCardCaption.tsx` — insight (lightbulb) pill becomes pressable when `onPressInsight` given; `insightActive` → darker pill (`figmaChipBg`) + white glyph (Figma `degree selected`). Non-pressable fallback preserved for Favourites.
- `auxi/src/services/analytics.ts` — 6 typed wrappers; `recommendation_generated_by_temperature` deduped per outfit_hash via module Set (mirrors `trackRecommendationViewedOnce`).
- `auxi/src/translations/{en-EN,fr-FR,vi-VN}.json` — 14 `home.temp_*` / `home.a11y_temp_*` keys, 3-locale parity (incl. `{{temp}}` interp on `temp_use_current`).
- `auxi/docs/analytics/mixpanel-tracking-plan.md` — §5.13 (6 events w/ file:line + PII note) + §10 temperature funnel.

## Ticket scenarios — how handled
- **Open**: lightbulb → `openTempSheet`, no request, sheet pre-selects `activeBucketKey`. Fires `temperature_modal_opened {override_active}`.
- **Select**: radio updates local `pendingKey`; fires `temperature_option_selected {option}`.
- **Apply override**: close + `isApplying` spinner; `applyTemperatureBucket(key)` sets override (ref live) → reset session + bump generation + force cold-start `/build` w/ rep temp; onSuccess closes sheet, header swaps weather→indicator+label, lightbulb→active, cards replace. Fires `temperature_apply_clicked`, then on success `temperature_override_active {bucket,rep_temp_c}` + `recommendation_generated_by_temperature {bucket,outfit_count}`.
- **Apply weather**: clears override (removes AsyncStorage), refetch live temp, header restores WeatherWidget, lightbulb idle; on success fires `temperature_override_removed {previous_bucket}`.
- **Reopen**: sheet pre-selects previous active bucket (`useEffect` on `visible`).
- **Edge same-option**: `key===activeBucketKey` → close, NO request, no analytics beyond apply_clicked.
- **Edge same-outfit**: backend may return same outfit under COOL collapse (D2) — outfit kept, no error (success path).
- **Error**: onError (latest apply) → `isApplying=false`, `errorKey` set; sheet STAYS open w/ inline banner, Apply re-enabled, selection retained.
- **Offline**: error code `ERR_NETWORK`/`ECONNABORTED`/`ERR_CANCELED` → `errorKey='offline'` (offline copy).
- **Loading**: Apply disabled + spinner, radios disabled (`isApplying` passed to sheet).
- **High-risk header/recommendation mismatch**: header + request both read the single hook (`isOverrideActive` / `overrideTempCRef`) — cannot diverge. **Stale Apply**: `tempApplyIdRef` bumped per Apply; onSuccess/onError act only when `__tempApplyId === tempApplyIdRef.current`, so an older Apply's response can't clear the spinner or overwrite newer state. **Override cleared correctly**: `apply('weather')` removes AsyncStorage + resets state.

## D4 — override-indicator icon decision
Reuse existing `Icons.User` (`src/assets/images/icon_user.svg`, `currentColor`, head+shoulders) — visually identical to the Figma override silhouette. NO new SVG exported (DRY; figma-icons-sync not needed). Header label = SELECTED bucket label via `bucketLabel(t, key, liveTempC)`, NOT Figma's inconsistent "10 - 35°C" mock.

## Verification (Node 20)
- `npx tsc --noEmit` → **clean** (exit 0, no errors).
- `yarn lint` → **8 problems (1 error, 7 warnings)** — IDENTICAL to baseline with my src edits stashed (verified by stash-compare). Zero new. The 1 error (`HomeScreen.tsx:734 setPinnedItemId` exhaustive-deps) is pre-existing (commit 55637ee6, AU-253). I fixed the one I'd introduced (`overrideTempCRef` dep).
- `./scripts/auxi-lint-tokens.sh` → **34 violations** — IDENTICAL to baseline (stash-compare). **Zero in my files**; all 34 are pre-existing in other screens/components. New files use only `theme.*`/`ds.*` tokens.

## Visual verification
Not run — mobile-dev does not drive the simulator (per role; hands off to qa-mobile/qa-ui). **Code complete, visual verification pending.** Recommend: qa-ui Compare mode (Pass 2+3) vs Figma 3906-8765 (sheet radio spacing, override-header alignment, lightbulb-active tone), then designer gate (6.5), then qa-mobile smoke.

## Deviations / open questions
- `temperature_apply_clicked` is present-tense (borderline vs `object_verb` past-tense convention) — kept verbatim per ticket for funnel continuity; flag to CEO if `temperature_applied` preferred.
- D1 `mild_10_25`→18°C (backend WARM) is lossy (range spans COOL→WARM). Provisional per plan; escalate only if finer control wanted (Phase 07).
- D2 accepted: `cold_0_7`/`freezing_-10_0` both → backend COOL (<15) ⇒ may return same outfit; treated as ticket's "same outfit" edge (no error).
- Indicator chevron uses `Icons.ChevronRight` rotated 90° (no dedicated down-chevron in icon set) — qa-ui to confirm acceptable vs Figma.

**Status:** DONE
**Summary:** AU-362 mobile-only temperature override fully implemented — config + hook (single source of truth) + sheet + header indicator + lightbulb trigger + 3 request sites threaded + 6 analytics events + 3-locale i18n + tracking-plan doc. tsc/lint/token-lint all at baseline (zero new violations). No backend/API change.
**Concerns:** Visual fidelity unverified (sim not run by this role) — needs qa-ui Compare + designer gate before PR. Two present-tense/lossy-mapping flags are CEO judgment calls, defaults shipped per plan.
