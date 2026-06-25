# Code Review — AU-362 Outfit Temperature

Branch `duc2820/au-362-...` @ 4dfb4082 · diff `origin/main..HEAD` (11 files, ~974 ins)
Scope: correctness / concurrency / persistence / analytics hygiene. Styling NOT re-reviewed (qa-ui + designer PASSED).

## Verdict-driving finding

### [MAJOR] First build after Apply sends the STALE temperature — `overrideTempCRef` synced via effect, not synchronously
`src/hooks/useTemperatureOverride.ts:103-113` (`apply`) + `:72-75` (effect) → consumed `src/screens/HomeScreen.tsx:1820` then `:1839`.

`apply(key)` only calls `setActiveBucketKey(key)`. The ref `overrideTempCRef.current` is updated *only* in the `useEffect([activeBucketKey])` (line 72-75), which runs AFTER the React commit. But `applyTemperature` (HomeScreen:1820) calls `applyTemperatureBucket(key)` and then SYNCHRONOUSLY fires `requestRecommendation(...)` → `valenGetRecommendation` (mutate) → `buildViaV05`, which reads `overrideTempCRef.current` (HomeScreen:798) before the ref-sync effect has run.

Result: the FIRST `/build` after an Apply sends the PRE-apply temp:
- weather → bucket: sends `null ?? weather.tempC` = **live weather** (override ignored on the very request the user triggered).
- bucket A → bucket B: sends bucket A's midpoint.

Meanwhile the header indicator + sheet update correctly (state-driven, next render) showing the NEW bucket → exactly the "header shows override, request used live weather" mismatch flagged as high-risk in the brief. The override only "takes" on the NEXT request (prefetch / Show-another), by which time the effect has synced the ref.

This is the codebase's own known footgun: the refine-submit path solves it explicitly — `HomeScreen.tsx:1730-1732` `setStyleFeedback(payload); styleFeedbackRef.current = payload;` with the comment *"Update both state (for UI consumers) and ref (read by fetch sites)."* AU-362 missed the ref half.

Fix (in the hook, keeps single-source-of-truth): write the refs synchronously inside `apply` before the state set returns —
```ts
const apply = useCallback((key: TemperatureBucketKey) => {
  activeBucketKeyRef.current = key;
  overrideTempCRef.current = repTempCFor(key);   // <-- synchronous, fixes the race
  setActiveBucketKey(key);
  if (isOverrideBucket(key)) { AsyncStorage.setItem(...) } else { AsyncStorage.removeItem(...) }
}, []);
```
Keep the existing effect as a safety net (harmless). No HomeScreen change needed. Verify on sim: weather→`28-40°C` Apply → first outfit should reflect hot temp_c=33, not live weather.

## Other findings

### [MINOR] Mount-load can clobber a fast pre-load Apply (tight race)
`useTemperatureOverride.ts:78-101`. `AsyncStorage.getItem` is async; if the user taps Apply before it resolves, the load's `.then` runs `setActiveBucketKey(stored)` after the user's `apply(chosen)`, overwriting the fresh choice when `stored !== chosen`. Window is small (storage read latency on mount) and both are same-day overrides, so impact is low. Mitigation: guard the load with a "user hasn't applied yet" ref, or skip `setActiveBucketKey` in the load if the current key is already a non-default override. Acceptable to ship as-is given the tiny window; note for follow-up.

### [NIT] `temperature_apply_clicked` is present-tense vs the past-tense `object_verb` convention
`analytics.ts:191`. The tracking-plan doc (§5.13) already self-flags this and says "kept verbatim per AU-362 ticket for funnel continuity; flag to CEO if `temperature_applied` preferred." Good disclosure — no action unless CEO wants rename.

### [NIT] `activeBucketKeyRef` exposed by the hook but unused by HomeScreen
`useTemperatureOverride.ts:121` returns it; HomeScreen consumes only `overrideTempCRef`. Harmless (and the MAJOR fix above will write it), but it's dead surface today. Leave if the fix wires it; otherwise drop to keep the API honest.

## Verified-correct (no action)

- **Concurrency / stale-overwrite guard** — solid, two independent layers. `__gen` (`fetchGenerationRef`) drops stale results from touching the outfit LIST (onSuccess:853 early-return). `__tempApplyId` vs `tempApplyIdRef.current` (onSuccess:862, onError:993) gates the sheet/spinner/event resolution. Each Apply bumps BOTH, so an older Apply's late response can neither overwrite the newer list nor clear the newer spinner. Prefetch/Show-another go through `requestRecommendation` without `__tempApplyId`, so they can't masquerade as an Apply resolution.
- **All 3 request sites read the override** — build (`buildViaV05:798`), pin-gen (`:1082`), prefetch (via `requestRecommendation`→`buildViaV05`). All read `overrideTempCRef.current ?? weather.tempC` (pin-gen reads ref at effect-fire time, correct). Note: subject to the MAJOR ref-sync bug only on the synchronous Apply→build path; the others fire late enough that the effect has run.
- **Clear path** — `clear()`→`apply('weather')` clears state + removes AsyncStorage; `isOverrideBucket('weather')` is false so the `else` branch runs `removeItem`. No residual. (Once MAJOR fix lands, ref also clears synchronously.)
- **Persistence date-expiry** — `todayISO()` uses local calendar Y-M-D, compared `===` on load → resets on next calendar day, not 24h drift. Correct per D3.
- **Persistence robustness** — `getItem`→`JSON.parse` wrapped in `.then/.catch`; corrupt JSON throws → caught → no crash. `isTemperatureBucketKey` + `isOverrideBucket` type-guard the parsed value (untrusted-input validation at the storage boundary). `mounted` flag prevents post-unmount setState. AsyncStorage rejections all `.catch(()=>{})`. No unhandled rejections.
- **Same-option Apply** — `key === activeBucketKey` (state, fresh via deps) → close, no request. Correct.
- **Error keeps sheet open + re-enables Apply** — onError:993 sets `isApplyingTemp(false)` + `tempErrorKey`; sheet stays open (`isTempSheetOpen` untouched); pendingKey is sheet-local so selection retained. Loading disables radios + Apply + backdrop/onRequestClose (`isApplying ? undefined`). Correct.
- **Analytics hygiene** — 6 literal event names, no template strings. Props are bucket KEYS only (no raw temps as free text, no user input); `rep_temp_c`/`outfit_count` unquoted numbers. `recommendation_generated_by_temperature` deduped per `outfit_hash` via module Set (mirrors existing `seenRecommendations` pattern — both never cleared, bounded by distinct outfit content; consistent, not a leak). override-active/removed fire on SUCCESSFUL build per spec. No PII.
- **Cleanup / refs** — mount-load effect returns unmount cleanup; analytics refs (`activeBucketForAnalyticsRef`) read in onSuccess fire post-network so effect-sync has run (no stale-analytics issue). Pin-gen effect already has AbortController + 30s timeout cleanup (unchanged).
- **i18n** — all 14 keys present + parity across en/fr/vi. `{{temp}}`/`{{range}}` interpolation matches usage.
- **Type-safety / build** — `npx tsc --noEmit` clean (only known legacy `_HomeScreen.tsx` errors). `Icons.User`, `Icons.ChevronRight`, `PillButton.loading` all resolve.
- **Tracking-plan doc** — §5.13 + funnel §10 added with file:line + properties (analytics rule satisfied).

## Unresolved questions
- Confirm the MAJOR is reproducible on a physical device / release build (timing-dependent, but reasoning + the refine-submit precedent strongly indicate the stale read). A 1-line sim check (weather→28-40°C, inspect first outfit's warmth or the outgoing temp_c) settles it.

**Verdict:** REQUEST-CHANGES (1 major: synchronous ref-sync in `apply`; 2 nits + 1 minor non-blocking). The guard/persistence/analytics architecture is genuinely solid — this is a one-line fix in the hook, not a redesign.
**Status:** DONE — review complete; one major bug gates the merge.
