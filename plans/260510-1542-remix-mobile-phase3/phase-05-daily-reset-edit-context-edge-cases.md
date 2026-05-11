# Phase 3 — Wave 5: Daily Reset + Edit Context Wire + Edge Cases

## Context Links

- Parent plan: `plan.md`
- Edge cases spec: `docs/pm/remix-feature-plan.md` §2.5
- Daily reset spec: `docs/pm/remix-feature-plan.md` §2.4 (device local time, NOT UTC)
- Edit Context current state: `auxi/src/screens/HomeScreen.tsx:617-621` (handleSubmitContext currently no-op except modal close)
- Wave 1 outputs: `recommendationMemory.isStaleByDate`, `recommendationMemory.clearSession`
- Wave 3 outputs: `useTodayOutfit.refetch()`, `useRemix.remix()`

## Overview

**Priority**: P1 (daily reset + core edge cases) / P2 (Edit Context wire — descope candidate)
**Status**: pending
**Description**: Wire AppState foreground listener for daily reset. Thread `style_feedback` from Edit Context modal into `remix()`. Cover the 6 edge cases from spec §2.5: network fail, wardrobe < 5, exhausted axis, expired session, no rate limit, daily reset.

## Requirements

- REMIX-ME-09 (daily reset on midnight crossover, device local time)
- REMIX-ME-08 partial (Edit Context wires `style_feedback` — descope candidate)
- Coverage of edge cases §2.5 (1-7)

## Architecture

```
AppState ──► 'active' event ──► useTodayOutfit recheck:
                                  if isStaleByDate → clearSession() → refetch()
                                                       │
                                                       └─► Mixpanel daily_reset_triggered (Wave 6)

HomeScreen mount ──► useTodayOutfit() ──► /start (catches initial cold-start case too)

Network fail in useRemix mutation
   └─► onError → toast "Couldn't remix — try again" + keep current outfit

Wardrobe < 5 items per layer (read from /start trace)
   └─► useTodayOutfit exposes `wardrobeTooSmall: boolean` → RemixButton state="disabled"

Edit Context modal submit
   └─► handleSubmitContext({ style_feedback: customContextText })
       └─► remix({ feedback: '...' })  // Wave 1 useRemix already accepts feedback
```

## Related Code Files

**Modify**:
- `auxi/src/screens/HomeScreen.tsx` — AppState listener, Edit Context wire, error toast
- `auxi/src/hooks/useTodayOutfit.ts` — expose `wardrobeTooSmall` flag (read from `/build` trace)
- `auxi/src/hooks/useRemix.ts` — error surface (already returns `error`; add typed handling for 422 / 500)

**Create**:
- `auxi/src/hooks/useDailyReset.ts` (≤80 lines) — encapsulates AppState listener + reset logic. Keeps HomeScreen lean.

**Delete**: none

---

## Implementation Steps

### Task 5.1 — Create `useDailyReset.ts`

**Wave**: 5 · **Estimated**: 35 min · **Parallel-eligible**: Yes (with 5.4)
**Files touched**:
- CREATE: `auxi/src/hooks/useDailyReset.ts`

**Steps**:
1. Hook signature: `useDailyReset(opts: { onReset: (oldSessionId: string | null) => void }): void`.
2. Subscribe to `AppState.addEventListener('change', handler)` from `react-native`.
3. On state change to `'active'`:
   - Call `recommendationMemory.loadSession()`.
   - If null → no-op.
   - If `isStaleByDate(memory)` true:
     - Capture `oldSessionId = memory.session_id`.
     - Call `recommendationMemory.clearSession()`.
     - Call `opts.onReset(oldSessionId)` — caller (HomeScreen) handles refetch + telemetry.
4. Cleanup: remove listener on unmount.
5. Edge case: handle `null` AppState event gracefully (some Android versions emit null on first mount).

**Acceptance**:
- Hook is silent on same-day foreground.
- Hook calls `onReset` exactly once on cross-midnight foreground.
- No memory leak (listener removed on unmount).

**Verify**:
```bash
cd auxi && npx tsc --noEmit 2>&1 | grep "useDailyReset" | grep "error"
# 0 errors
```

---

### Task 5.2 — Wire `useDailyReset` in HomeScreen + show "Today's outfit" header

**Wave**: 5 · **Estimated**: 25 min · **Sequential** (HomeScreen edit, after 5.1)
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Import `useDailyReset`.
2. Inside HomeScreen component:
   ```ts
   const [didReset, setDidReset] = useState(false);
   useDailyReset({
     onReset: (oldSessionId) => {
       setDidReset(true);
       refetchToday();   // forces /start
       // Wave 6 wires Mixpanel daily_reset_triggered here
     },
   });
   ```
3. Header text logic: replace static `"Auxi"` (line 646) with conditional:
   ```tsx
   <Text style={styles.headerTitle}>{didReset ? "Today's outfit" : "Auxi"}</Text>
   ```
4. Reset `didReset` flag back to `false` after first user interaction (Remix tap or scroll). Add to `handleRemixTap`:
   ```ts
   const handleRemixTap = useCallback(() => {
     setDidReset(false);
     remix();
   }, [remix]);
   ```
   This way "Today's outfit" shows briefly on cross-midnight cold-start, returns to "Auxi" on next interaction. Per UX spec §2.4.
5. **Decision flag**: if PM wants "Today's outfit" sticky for the whole session post-reset, change to a single setter in init only. Default per spec is brief.

**Acceptance**:
- Manual test: change device clock to next day, background app, foreground → header shows "Today's outfit".
- Tap Remix → header reverts to "Auxi".
- Same-day foreground → header stays "Auxi".

**Verify**:
- Manual iOS sim with clock manipulation (Settings → General → Date & Time).

---

### Task 5.3 — Network fail + error toast for Remix

**Wave**: 5 · **Estimated**: 25 min · **Parallel-eligible**: Yes (with 5.4, 5.1)
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`
- EDIT: `auxi/src/hooks/useRemix.ts` (expose error code)

**Steps**:
1. In `useRemix`, expand error handling:
   ```ts
   onError: (err) => {
     const status = (err as any)?.response?.status;
     // Don't clear session on 5xx — server hiccup, retry safe.
     // On 404 (session expired): silently call /start to re-establish, then no-op (user re-taps).
     if (status === 404) {
       // Silent re-/start path
       v05Api.buildRecommendation({...lastBuildArgs}).then((r) => {
         recommendationMemory.saveSession({ session_id: r.suggested_default ? ... });
       }).catch(() => {});
     }
   }
   ```
   (Refine signature in implementation; the exact recovery path may simplify to just clearing memory + letting user retry.)
2. In HomeScreen, wire toast:
   ```ts
   import Toast from 'react-native-toast-message';   // already a dep
   useEffect(() => {
     if (remixError) {
       Toast.show({ type: 'error', text1: "Couldn't remix — try again" });
     }
   }, [remixError]);
   ```
3. Verify `react-native-toast-message` Provider is mounted at App.tsx root. If not, mount it (small App.tsx edit, document in inline note).
4. **Critical**: keep current outfit visible on error. Don't clear `listOutfits` state on failed Remix (spec §2.5 row 1).

**Acceptance**:
- Disable simulator wifi → tap Remix → toast appears, current outfit unchanged.
- 404 from backend → silent recovery (next tap works).
- 422 outfit_hash drift → toast + log warning (rare; investigate post-launch if seen).

**Verify**:
- Manual iOS sim: disable network, tap Remix.

---

### Task 5.4 — Wardrobe-too-small disabled state

**Wave**: 5 · **Estimated**: 25 min · **Parallel-eligible**: Yes
**Files touched**:
- EDIT: `auxi/src/hooks/useTodayOutfit.ts`
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. In `useTodayOutfit`, after `/build` response, inspect `trace.pool_sizes_after_L1`:
   ```ts
   const wardrobeTooSmall = useMemo(() => {
     if (!buildResponse) return false;
     const pools = buildResponse.trace.pool_sizes_after_L1 || {};
     // Heuristic: if any L1 pool < 5, Remix likely can't cycle 4 axes.
     return Object.values(pools).some((n) => (n as number) < 5);
   }, [buildResponse]);
   return { ..., wardrobeTooSmall };
   ```
2. In HomeScreen:
   ```ts
   const remixDisabled = wardrobeTooSmall;
   ```
3. RemixButton state computation:
   ```ts
   state={isRemixing ? 'loading' : remixDisabled ? 'disabled' : 'default'}
   ```
4. When disabled, render an empty-state hint near the button:
   ```tsx
   {remixDisabled && (
     <Text style={styles.emptyStateHint} testID="home-remix-empty-state">
       Add more items to enable Remix
     </Text>
   )}
   ```
5. Tooltip text from spec §4.1 row 4. Use `manropeCaption` typography token.

**Acceptance**:
- User with < 5 items in any L1 layer → RemixButton greyed out, hint visible.
- Once user adds items and re-mounts Home → button re-enables.

**Verify**:
- Manual: seed test account with 4 BT items, observe disabled state.

---

### Task 5.5 — Edit Context wire (`style_feedback` thread-through)

**Wave**: 5 · **Estimated**: 30 min · **Parallel-eligible**: Yes · **DESCOPE CANDIDATE #3**
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Replace existing `handleSubmitContext` (line 617-621):
   ```ts
   const handleSubmitContext = () => {
     const feedback = trimmedCustomContextText || selectedContextChipId || '';
     closeContextModal();
     if (feedback) {
       remix({ feedback });
     }
   };
   ```
2. The `useRemix` hook from Wave 1 already accepts `feedback` arg — no hook change needed.
3. Empty feedback → just close modal (no-op), don't tap Remix.
4. Mode change handler (line 490-499) — should it auto-Remix? Per spec §2.6 risk row 6 "Mode/pin change → force `/start` not `/next` (reset session)":
   - Replace `handleSelectMode` to call `recommendationMemory.clearSession()` then `refetchToday()`.
   - This is a session reset, not a Remix tap. Document in inline comment.
5. Pin change handler (line 469-483): similarly. Per spec, pin/mode change resets session. **Decision**: defer to v0.6 if mode/pin Remix is too disruptive — for v0.5 launch, accept that pin/mode changes only affect the NEXT cold start. Document decision in inline comment.

**Acceptance**:
- Edit Context modal → typed feedback "warmer top" → submit → Remix fires with `style_feedback: 'warmer top'`.
- Backend log shows `style_feedback` field present.
- Empty feedback submit closes modal silently.

**Verify**:
- Manual: open Edit Context, type, submit, watch network for `/next` body.

---

## Todo List

- [ ] 5.1 Create `useDailyReset.ts` (35m)
- [ ] 5.2 Wire `useDailyReset` + "Today's outfit" header (25m)
- [ ] 5.3 Network fail + error toast (25m)
- [ ] 5.4 Wardrobe-too-small disabled state (25m)
- [ ] 5.5 Edit Context wire (30m, descope candidate)
- [ ] Wave 5 verify: tsc clean + manual iOS smoke (clock test, network test, Edit Context)

## Success Criteria

- ✅ Success criterion #4 (foregrounding after midnight discards session, "Today's outfit" header) — VERIFIED
- Edge cases §2.5 rows 1, 2, 3, 4, 5, 7 covered (rows 6 "no rate limit" requires no mobile work).
- HomeScreen LOC delta from Wave 5 ≤ +60 (logic in `useDailyReset` hook, Edit Context wire is small).

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| AppState 'change' event semantics differ iOS vs Android | M | M | Test both. Common pitfall: Android emits `'background'` then `'active'` on lock-unlock without time passage; `isStaleByDate` check guards against false-resets. |
| User has device-clock manipulation enabled (frequent traveler crossing TZs) | L | L | Use `Date.now()` consumed via `toLocaleDateString`. If user spoofs date forward, they get an unexpected reset — acceptable trade-off vs server UTC complexity. Document in spec §7 risk row "Daily reset surprises user mid-day if device timezone wrong". |
| Edit Context wire might double-fire `/next` if user submits while previous Remix in flight | L | M | `useMutation` dedupes. Verify with stress test. |
| `react-native-toast-message` Toast component not yet mounted at App root | M | L | Pre-flight check. If not mounted, add `<Toast />` to App.tsx as small one-line edit (1-2 min). |
| Mode/pin change auto-Remix decision (Task 5.5 step 4-5) blocks PM sign-off | M | M | Defer behavior, ship spec-deviation note. Recommended call: v0.5 keeps current behavior (pin/mode are advisory, picked up next cold start), v0.6 wires reset. PM ping at end of Wave 5. |

## Security Considerations

- AppState listener is OS-managed, no privilege escalation.
- Network errors logged via `console.warn` only — no stack traces sent to telemetry without scrubbing (Wave 6).

## Next Steps

- Wave 6 blocked by Wave 5 (telemetry needs all event sites in place).
- After Wave 5: PM ping for mode/pin Remix-on-change decision (Risk row 5).
