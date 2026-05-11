# Phase 3 — Wave 6: Mixpanel Events + Jest Tests + First-Time Tooltip

## Context Links

- Parent plan: `plan.md`
- Telemetry spec: `docs/pm/remix-feature-plan.md` §5 (event table)
- Tooltip copy: `docs/pm/remix-feature-plan.md` §4.4
- Phase 2 prereq TELEMETRY-SVC: `mixpanel-react-native` SDK + `analytics.ts` hook (must land before this wave)
- Existing console.info sites in HomeScreen: `:437, :475, :479, :495, :506, :535` (six TODO(analytics) markers from Phase A/B/C)
- Jest config: `auxi/jest.config.js` (preset `react-native` only — no testing-library installed)

## Overview

**Priority**: P1 (core Mixpanel events) / P2 (first-time tooltip — descope candidate #2)
**Status**: pending
**Description**: Wire 9 Mixpanel events at the call sites scaffolded in Waves 3-5. Add Jest tests verifying event emission. Add first-time tooltip with AsyncStorage-backed "shown once" flag.

## Requirements

- REMIX-TEL-01 (event names + properties match spec)
- REMIX-TEL-02 (Jest tests verify emission)
- REMIX-TEL-03 (event sample-rate sensible: 100% for v0.5)
- REMIX-ME-08 (first-time tooltip — descope candidate)

## Architecture

```
analytics.ts (Phase 2 TELEMETRY-SVC, expected shape)
   │
   ├─► track(eventName: string, props: Record<string, unknown>): void
   └─► identify(userId: string): void   // existing user binding handled elsewhere

useRemix hook
   ├─► onMutate:   track('remix_tapped', {session_id, current_outfit_hash, force_axis})
   ├─► onSuccess:  track('remix_completed', {session_id, variation_axis, latency_ms})
   └─► onError:    track('remix_failed', {session_id, error_code})

useTodayOutfit hook
   └─► onSuccess of /build:  track('v05_recommendation_shown', {session_id, outfit_hash})

useDailyReset hook
   └─► onReset:    track('daily_reset_triggered', {session_id_old, session_id_new})

HomeScreen
   ├─► RefreshControl onRefresh:  track('pull_to_refresh_remix', {session_id})
   ├─► RemixButton mount effect:  track('remix_button_shown', {session_id, outfit_hash})  [debounced]
   ├─► ForcedAxisSheet open:      track('remix_axis_picker_opened', {session_id})
   └─► ForcedAxisSheet select:    track('remix_axis_picker_selected', {session_id, axis})
```

**Wiring discipline**: track calls live AT THE CALL SITE in HomeScreen / hooks, NOT inside `RemixButton.tsx` or `AxisChip.tsx` (presentational components stay pure for Jest test simplicity).

## Related Code Files

**Modify**:
- `auxi/src/hooks/useRemix.ts` — add 3 track calls
- `auxi/src/hooks/useTodayOutfit.ts` — add 1 track call
- `auxi/src/hooks/useDailyReset.ts` — caller (HomeScreen) tracks; hook itself stays pure
- `auxi/src/screens/HomeScreen.tsx` — add 4 track calls + tooltip mount

**Create**:
- `auxi/src/components/features/RemixFirstTimeTooltip.tsx` (≤80 lines, optional)
- `auxi/src/hooks/__tests__/useRemix.test.ts`
- `auxi/src/hooks/__tests__/useDailyReset.test.ts`

**Pre-flight check**:
- Confirm `auxi/src/services/analytics.ts` (or equivalent path Phase 2 settled on) exists with `track()` exported.
- Confirm `mixpanel-react-native` in `package.json` deps.
- If either missing → STOP, escalate to Phase 2 owner. Do NOT scaffold a stub here unless explicitly approved.

---

## Implementation Steps

### Task 6.1 — Wire telemetry in hooks (useRemix, useTodayOutfit)

**Wave**: 6 · **Estimated**: 30 min · **Parallel-eligible**: Yes (with 6.2)
**Files touched**:
- EDIT: `auxi/src/hooks/useRemix.ts`
- EDIT: `auxi/src/hooks/useTodayOutfit.ts`

**Steps for `useRemix.ts`**:
1. Import `track` from `../services/analytics` (Phase 2 path).
2. Capture `mutationStartMs` ref before mutation:
   ```ts
   const startMsRef = useRef<number>(0);
   ```
3. In `onMutate`:
   ```ts
   onMutate: async (vars) => {
     startMsRef.current = Date.now();
     const memory = await recommendationMemory.loadSession();
     track('remix_tapped', {
       session_id: memory?.session_id ?? null,
       current_outfit_hash: memory?.last_outfit_hash ?? null,
       force_axis: vars?.force ?? null,
     });
   }
   ```
4. In `onSuccess`:
   ```ts
   onSuccess: async (data) => {
     const latency_ms = Date.now() - startMsRef.current;
     track('remix_completed', {
       session_id: data.session_id,
       variation_axis: data.trace.variation_axis,
       latency_ms,
     });
     // ... existing memory save logic
   }
   ```
5. In `onError`:
   ```ts
   onError: (err) => {
     const status = (err as any)?.response?.status;
     const memory = recommendationMemory.loadSession(); // sync read OK if memoized
     track('remix_failed', {
       session_id: memory?.session_id ?? null,
       error_code: status ? `HTTP_${status}` : 'NETWORK_ERROR',
     });
   }
   ```

**Steps for `useTodayOutfit.ts`**:
1. Import `track`.
2. After successful `/build` (in `onSuccess` or post-fetch effect):
   ```ts
   track('v05_recommendation_shown', {
     session_id: data.session_id,
     outfit_hash: data.outfits[0]?.outfit_hash ?? null,
   });
   ```
3. Fire ONCE per /build response (not per re-render). Use `useEffect` keyed on response identity or move into the mutation/query callback.

**Acceptance**:
- All 4 events emit with correct properties.
- `latency_ms` is a sane integer (typically 100-300ms).
- No emission on cached cold-start (only fresh `/build` response triggers `v05_recommendation_shown`).

**Verify**:
- Manual iOS sim with Mixpanel staging enabled — events visible in dashboard within ~30 seconds.

---

### Task 6.2 — Wire telemetry in HomeScreen

**Wave**: 6 · **Estimated**: 35 min · **Parallel-eligible**: Yes (with 6.1)
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Import `track` from `../services/analytics`.
2. **Replace 6 existing `console.info(...)` analytics stubs** (per ENV-CONFIG / TELEMETRY-SVC reqs):
   - `:437` `home.swipe.favorite` → `track('home_swipe_favorite', {outfit_hash: hash})` (existing event, not Remix-related but cleanup opportunity per FOUND-02)
   - `:475`, `:479` `home.pin.set` / `home.pin.clear` → `track('home_pin_set'|'home_pin_clear', {item_id})`
   - `:495` `home.mode.change` → `track('home_mode_change', {from, to})`
   - `:506` `home.pin.clear` → same as :479
   - `:535` `home.swipe.miss` → `track('home_swipe_miss', {fromIndex, toIndex, source})`
   - **Remove all `// TODO(analytics): replace console.info with the real telemetry hook.` comments** after replacement.
3. **Add new Remix-specific track calls**:
   ```ts
   // RemixButton mount (debounce: only fire when outfit_hash changes, not on re-render)
   useEffect(() => {
     if (currentOutfitHash) {
       track('remix_button_shown', {
         session_id: currentSessionId,
         outfit_hash: currentOutfitHash,
       });
     }
   }, [currentOutfitHash]);

   // Pull-to-refresh
   const handlePullToRefresh = useCallback(async () => {
     track('pull_to_refresh_remix', { session_id: currentSessionId });
     // ... existing refresh logic
   }, [currentSessionId]);

   // ForcedAxisSheet open (Wave 4 left a TODO marker here)
   onLongPress={() => {
     track('remix_axis_picker_opened', { session_id: currentSessionId });
     setAxisPickerOpen(true);
   }}

   // ForcedAxisSheet select
   onSelect={(axis) => {
     track('remix_axis_picker_selected', { session_id: currentSessionId, axis });
     setAxisPickerOpen(false);
     remix({ force: axis });
   }}

   // useDailyReset onReset callback
   useDailyReset({
     onReset: (oldSessionId) => {
       setDidReset(true);
       refetchToday();
       // After refetch resolves, the new session_id is available via memory.
       // Fire telemetry inside refetchToday's onSuccess OR via a useEffect watching for a new session_id following oldSessionId capture.
       track('daily_reset_triggered', { session_id_old: oldSessionId, session_id_new: null });
       // session_id_new is null at trigger time; if dashboards need both, wire a follow-up event.
     },
   });
   ```
4. Acceptance: `grep -c "console.info" auxi/src/screens/HomeScreen.tsx` returns 0.

**Acceptance**:
- 0 `console.info` calls remaining in HomeScreen.tsx.
- 4 Remix-specific track calls + 5 cleanup track calls in place.
- All track calls include `session_id` property where the spec requires it.

**Verify**:
```bash
cd auxi && grep -c "console.info" src/screens/HomeScreen.tsx
# 0 expected
cd auxi && grep -c "track(" src/screens/HomeScreen.tsx
# ≥9 expected
```

---

### Task 6.3 — Jest tests for event emission

**Wave**: 6 · **Estimated**: 50 min · **Parallel-eligible**: Yes
**Files touched**:
- CREATE: `auxi/src/hooks/__tests__/useRemix.test.ts`
- CREATE: `auxi/src/hooks/__tests__/useDailyReset.test.ts`
- POSSIBLY EDIT: `auxi/jest.config.js` (add setupFiles for AsyncStorage mock)
- POSSIBLY EDIT: `auxi/package.json` (add `@testing-library/react-native` if not present — see Risk #1)

**Pre-flight**:
```bash
cd auxi && grep -i "testing-library" package.json
# If empty: yarn add -D @testing-library/react-native @testing-library/react-hooks
```

**Steps**:
1. Mock `analytics.ts`:
   ```ts
   // setup
   jest.mock('../../services/analytics', () => ({
     track: jest.fn(),
   }));
   import { track } from '../../services/analytics';
   ```
2. Mock `v05Api.ts` and `recommendationMemory.ts`:
   ```ts
   jest.mock('../../services/v05Api');
   jest.mock('../../utils/recommendationMemory');
   ```
3. Mock `@react-native-async-storage/async-storage` via the official mock:
   ```ts
   jest.mock('@react-native-async-storage/async-storage', () =>
     require('@react-native-async-storage/async-storage/jest/async-storage-mock')
   );
   ```
4. Test cases for `useRemix`:
   - `emits remix_tapped on mutate` — call hook's `remix()`, assert `track` called with event name + props (session_id, current_outfit_hash, force_axis=null).
   - `emits remix_completed on success` — mock `v05Api.remixOutfit` to resolve, assert event with variation_axis + latency_ms.
   - `emits remix_failed on error` — mock to reject with 500, assert event with error_code.
   - `passes force axis through` — call `remix({ force: 'COLOR' })`, assert track payload has force_axis: 'COLOR'.
5. Test cases for `useDailyReset`:
   - `does not call onReset on same-day foreground` — mock memory load returns today's date, assert `onReset` not called.
   - `calls onReset on cross-midnight foreground` — mock memory date as yesterday, assert `onReset` called once with old session_id.
   - `removes listener on unmount` — assert AppState.removeEventListener pattern (or returned subscription's `.remove()`).
6. Use `@testing-library/react-hooks` `renderHook` if installed; else fall back to a thin React tree using `react-test-renderer` (already in deps).

**Acceptance**:
- `cd auxi && yarn test` exits green.
- All 4 useRemix tests pass.
- All 3 useDailyReset tests pass.
- Coverage report (optional): hooks/ ≥ 80%.

**Verify**:
```bash
cd auxi && yarn test --testPathPattern="hooks/__tests__"
# 0 failures
```

---

### Task 6.4 — First-time tooltip (DESCOPE CANDIDATE #2)

**Wave**: 6 · **Estimated**: 30 min · **Parallel-eligible**: Yes · **DESCOPE CANDIDATE**
**Files touched**:
- CREATE: `auxi/src/components/features/RemixFirstTimeTooltip.tsx`
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Create `RemixFirstTimeTooltip.tsx`:
   - Props: `{ visible: boolean, onDismiss: () => void, anchorRef?: ... }`
   - Renders speech-bubble pointing at RemixButton with copy from spec §4.4: "Tap Remix to swap part of your outfit. Long-press to choose what to change."
   - Dismiss button + tap-anywhere-to-dismiss.
   - Uses theme tokens.
   - testID: `home-remix-tooltip`.
2. AsyncStorage flag: `remix.tooltip.shown.v1`.
3. In HomeScreen:
   ```ts
   const [tooltipVisible, setTooltipVisible] = useState(false);
   useEffect(() => {
     AsyncStorage.getItem('remix.tooltip.shown.v1').then((v) => {
       if (!v) setTooltipVisible(true);
     });
   }, []);
   const dismissTooltip = useCallback(() => {
     setTooltipVisible(false);
     AsyncStorage.setItem('remix.tooltip.shown.v1', '1');
   }, []);
   ```
4. Mount tooltip near RemixButton. Visibility flag survives app reinstall? No — AsyncStorage clears on reinstall. Acceptable.
5. Telemetry: optional `track('remix_tooltip_shown', {})` and `track('remix_tooltip_dismissed', {})` — not in spec but useful for v0.6 measurement.

**Acceptance**:
- First app open after Phase 3 ships → tooltip visible.
- Dismiss → never shows again on same install.
- Visible for ≤ 5 seconds OR until first interaction.

**Verify**:
- Manual: clear AsyncStorage in iOS sim (`xcrun simctl uninstall booted com.auxi.app && yarn ios:sim`).

---

## Todo List

- [ ] 6.1 Wire telemetry in `useRemix` + `useTodayOutfit` (30m)
- [ ] 6.2 Wire telemetry in HomeScreen (replace 6 console.info + add 4 Remix events) (35m)
- [ ] 6.3 Jest tests for event emission (50m)
- [ ] 6.4 First-time tooltip (30m, descope candidate)
- [ ] Wave 6 verify: `yarn test` green + manual iOS smoke + Mixpanel staging dashboard event check

## Success Criteria

- ✅ Success criterion #5 (Mixpanel events fire with correct properties; Jest tests verify) — VERIFIED
- 0 `console.info` calls in HomeScreen.tsx (FOUND-02 partial closure).
- 9 distinct Mixpanel events from spec §5 wired at correct call sites.
- `yarn test` exits green with new test files.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `@testing-library/react-native` not installed; existing tests use bare `react-test-renderer` | H | M | Pre-flight check. If missing, install in Task 6.3 first step. Cost: ~3 min npm install. Alternative: drop to react-test-renderer-only style (verbose, but no dep change). |
| `mixpanel-react-native` SDK not yet shipped by Phase 2 | H | H | Pre-flight check. If missing, BLOCK Wave 6 entirely; escalate to Phase 2 owner. Do NOT stub a fake SDK — risk of shipping with no telemetry and not noticing. |
| `track('daily_reset_triggered')` missing `session_id_new` property because reset fires BEFORE refetch resolves | M | M | Two-event approach OR delay event emission to refetch onSuccess. Recommended: file a Mixpanel-side note, accept null for v0.5, fix in v0.6. |
| Jest test for `useDailyReset` flaky due to AppState mock | M | M | Use the official React Native AppState mock pattern from `react-native/jest/setup.js`. If still flaky, switch to direct unit test of the date-comparison function (not the AppState wiring). |
| First-time tooltip overlaps with iOS keyboard / context modals | L | L | Z-index: tooltip above ScrollView, below modals. Manual smoke verifies. |
| Latency event includes network roundtrip — could be misleading on cellular | L | L | Document in spec: "latency_ms = end-to-end client-perceived, includes network". Dashboards interpret accordingly. |

## Security Considerations

- Mixpanel events MUST NOT include PII (email, full name, JWT). Properties limited to: session_id (UUID), outfit_hash (opaque), error_code (HTTP status), variation_axis (enum), latency_ms (int).
- Confirm `mixpanel-react-native` config (Phase 2's TELEMETRY-SVC) does NOT auto-include device IMEI / MAC / IDFA without consent flag.

## Next Steps

- Phase 3 closure: run full verification gate from `plan.md`.
- Hand off to Phase 5 (qa-mobile + qa-ui Maestro authoring + execution).
- File post-launch follow-ups for any descoped items (REMIX-ME-04 forced-axis if cut, REMIX-ME-08 tooltip if cut, mode/pin Remix-on-change from Wave 5 Risk #5).
