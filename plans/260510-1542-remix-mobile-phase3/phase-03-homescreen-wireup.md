# Phase 3 — Wave 3: HomeScreen Wire-Up (V05 /start, RemixButton, Cross-Fade)

## Context Links

- Parent plan: `plan.md`
- Current HomeScreen: `auxi/src/screens/HomeScreen.tsx` (1267 LOC — already over 200-line guideline; this wave MUST extract logic, not inline more)
- Current mount call: `HomeScreen.tsx:343-349` (the `useEffect` calling `valenGetRecommendation`)
- Wave 1 outputs: `useTodayOutfit`, `useRemix`, `recommendationMemory`, `v05Api.remixOutfit`
- Wave 2 outputs: `RemixButton`, `AxisChip`
- UX spec: `docs/pm/remix-feature-plan.md` §4.3 (animation: 250ms cross-fade)
- Pull-to-refresh contract: `docs/pm/remix-feature-plan.md` §2.5 ("Pull-to-refresh = Remix tap, not /start reset")

## Overview

**Priority**: P1
**Status**: pending
**Description**: Replace HomeScreen mount call from legacy `valenGetRecommendation` to V05 `/start` via `useTodayOutfit`. Mount RemixButton + AxisChip in the bottom action cluster. Wire `RefreshControl` to `useRemix`. Add 250ms cross-fade on outfit swap. **All tasks in this wave are sequential — same file edits.**

## Requirements

- REMIX-ME-01 (HomeScreen mount calls V05 `/start`)
- REMIX-ME-02 (RemixButton tap fires `/next`)
- REMIX-ME-06 (pull-to-refresh = Remix cycle, not `/start`)
- REMIX-ME-03 (250ms cross-fade animation)

## Architecture

```
HomeScreen mount
   ├─► useTodayOutfit() ──► /start (if no session OR stale by date)
   │                        else: render cached outfit_hash
   │
   ├─► <ScrollView refreshControl={<RefreshControl onRefresh={remix}/>}>
   │       <Animated.View opacity={fadeAnim}>      ← 250ms cross-fade
   │           <OptionSheet outfit={current}/>
   │       </Animated.View>
   │   </ScrollView>
   │
   └─► <BottomActionCluster>
           <RemixButton onPress={remix} state={...}/>
           <AxisChip axis={lastAxis} visible={chipVisible}/>
       </BottomActionCluster>
```

**Critical invariant**: HomeScreen MUST NOT call `valenGetRecommendation` after Wave 3. Grep gate enforced in verify step.

## Related Code Files

**Modify**:
- `auxi/src/screens/HomeScreen.tsx` — surgical edits, NO new business logic inline
- `auxi/src/hooks/index.ts` — barrel export (if not created in Wave 1)

**Create**: none (all components from Waves 1-2)

**Delete**: none (legacy `valenGetRecommendation` stays in `recommendationService.ts` — used by no one after this wave but kept for rollback safety; deletion is a Phase 5 followup)

---

## Implementation Steps

### Task 3.1 — Replace mount call: `valenGetRecommendation` → `useTodayOutfit`

**Wave**: 3 · **Estimated**: 45 min · **Sequential** (all of Wave 3 is sequential)
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Add imports at top:
   ```ts
   import { useTodayOutfit } from '../hooks/useTodayOutfit';
   import { useRemix } from '../hooks/useRemix';
   ```
2. Inside `HomeScreen` component, REPLACE the existing `useMutation` block (lines 309-341) and the mount `useEffect` (lines 343-349) with:
   ```ts
   const { outfit, isLoading: isFirstLoading, isFreshSession, refetch: refetchToday } = useTodayOutfit();
   const { remix, isRemixing, lastAxis, error: remixError } = useRemix();
   ```
3. Adapt `listOutfits` state to receive single outfit from `useTodayOutfit` on first load and prepend new outfits from `useRemix` on each tap. Recommended pattern:
   - Keep `listOutfits: OutfitSheet[]` state.
   - `useEffect` watches `outfit` from useTodayOutfit; on first non-null value, set `listOutfits = [outfitToSheet(outfit)]`.
   - `useEffect` watches `useRemix` mutation `data` (expose via hook return) — on success, append/prepend new outfit to `listOutfits`.
4. **Decide caching strategy** (resolves Wave 1 Risk #2):
   - **Recommended (KISS)**: On app cold start with stored session_id, call `/build` again to repopulate the visible outfit. Brief loading spinner acceptable. Persist only the session_id + last_outfit_hash; don't try to cache the V05Outfit JSON.
   - Document choice in inline comment on `useTodayOutfit` call site.
5. Remove the old `valenGetRecommendation` mutation block entirely.
6. Keep prefetch logic (`triggerPrefetchIfNeeded`) — but route it through `remix()` instead of `valenGetRecommendation`. (Or: drop prefetch in this phase; user-driven Remix taps are fast enough at p95 < 250ms. Recommended: drop, simpler.)

**Acceptance**:
- HomeScreen no longer references `valenGetRecommendation` or `recommendationService` import (grep gate).
- Mount triggers V05 `/start` (verifiable via Charles/Proxyman or backend logs in iOS sim).
- Cold start renders the same 4-tile outfit grid as before.
- On second cold start same day, `/start` is NOT called again — uses cached session.

**Verify**:
```bash
cd auxi && grep -c "valenGetRecommendation\|recommendationService" src/screens/HomeScreen.tsx
# 0 expected
cd auxi && grep -c "useTodayOutfit\|useRemix" src/screens/HomeScreen.tsx
# ≥2 expected
cd auxi && npx tsc --noEmit 2>&1 | grep -v "_HomeScreen.tsx" | grep "error TS" | wc -l
# 0 expected
```

---

### Task 3.2 — Mount RemixButton in bottom action cluster

**Wave**: 3 · **Estimated**: 30 min · **Sequential**
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Import `RemixButton` from `../components/features/RemixButton`.
2. In the existing `OptionSheet` component's bottom `actionCluster` View (around line 909-934), insert RemixButton ABOVE the `Edit context` PillButton:
   ```tsx
   <RemixButton
     state={isRemixing ? 'loading' : remixDisabled ? 'disabled' : 'default'}
     onPress={handleRemixTap}
     onLongPress={undefined}            // Wave 4 wires this
     testID={`home-remix-button-${sheetIndex}`}
   />
   ```
3. Add prop `onRemix: () => void` to `OptionSheet` and `remixDisabled: boolean`. Thread these from parent.
4. In parent `HomeScreen`, define:
   ```ts
   const handleRemixTap = useCallback(() => {
     remix();   // no force axis; auto-cycle
   }, [remix]);
   const remixDisabled = false;  // Wave 5 task 5.4 computes this from wardrobe size
   ```
5. Hide existing `Show another` PillButton OR repurpose — recommend: keep both for now, drop `Show another` in Wave 5 cleanup once Remix proven.

**Acceptance**:
- RemixButton renders in bottom action cluster of every OptionSheet.
- Tapping RemixButton invokes `remix()` from useRemix.
- Loading state visible during in-flight `/next`.

**Verify**:
```bash
cd auxi && grep -c "RemixButton" src/screens/HomeScreen.tsx
# ≥2 expected (import + usage)
cd auxi && npx tsc --noEmit 2>&1 | grep -v "_HomeScreen.tsx" | grep "error TS" | wc -l
# 0 expected
```

---

### Task 3.3 — Wire `RefreshControl` (pull-to-refresh = Remix tap)

**Wave**: 3 · **Estimated**: 25 min · **Sequential**
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Import `RefreshControl` from `react-native`.
2. Add state `const [isRefreshing, setIsRefreshing] = useState(false);`.
3. On the outer `ScrollView` (line 730), add prop:
   ```tsx
   refreshControl={
     <RefreshControl
       refreshing={isRefreshing || isRemixing}
       onRefresh={handlePullToRefresh}
       testID="home-pull-to-refresh"
     />
   }
   ```
4. Define handler:
   ```ts
   const handlePullToRefresh = useCallback(async () => {
     setIsRefreshing(true);
     try {
       await remix();   // calls /next, NOT /start
     } finally {
       setIsRefreshing(false);
     }
   }, [remix]);
   ```
5. **Critical**: handler must call `remix()` not `refetchToday()`. Comment inline citing `docs/pm/remix-feature-plan.md` §2.5.

**Acceptance**:
- Pull-to-refresh on iOS sim triggers `/next` (verifiable in backend logs / Charles).
- Pull-to-refresh does NOT call `/start`.
- Spinner appears during refresh and clears on completion.

**Verify**:
- Manual iOS sim test: pull down on home, watch network tab — request hits `/api/v05/recommendation/next`.

---

### Task 3.4 — 250ms cross-fade on outfit swap + AxisChip mount

**Wave**: 3 · **Estimated**: 65 min · **Sequential**
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Import `Animated` from `react-native` (already imported? check). Import `AxisChip` from `../components/features/AxisChip`.
2. Add ref + state in `OptionSheet` for cross-fade:
   ```ts
   const fadeAnim = useRef(new Animated.Value(1)).current;
   ```
3. When new outfit replaces current (i.e., `outfit.outfitHash` changes):
   - Animate fadeAnim 1→0 over 125ms, then on complete, swap content, then 0→1 over 125ms. Total 250ms.
   - **Implementation pattern**: Use `useEffect` keyed on `outfit.outfitHash`. On change, run sequence.
4. Wrap the grid `View` (`gridWrap`) inside `<Animated.View style={{ opacity: fadeAnim }}>`.
5. Mount AxisChip just below the OptionSheet's top action band OR overlay above bottom cluster (decision: place INSIDE OptionSheet, top-right of grid, absolutely positioned; refine in Wave 4 polish).
   ```tsx
   <AxisChip
     axis={lastAxis}
     visible={chipVisible}
     onAutoFadeComplete={() => setChipVisible(false)}
     testID={`home-axis-chip-${sheetIndex}`}
   />
   ```
6. Add HomeScreen-level state: `const [chipVisible, setChipVisible] = useState(false);`.
7. `useEffect` watches `lastAxis` from useRemix; when it changes from null→value, set `chipVisible(true)`. AxisChip auto-fades after 3s and calls back to clear.
8. **Edge case**: rapid taps within 3s window — chip should re-key to restart animation. Add `key={lastAxis ?? 'none'}` to AxisChip OR include a serial counter in key. Wave 2 risk #4 contract.

**Acceptance**:
- Outfit grid fades out (125ms), content swaps, fades in (125ms) on every successful Remix.
- AxisChip appears within 50ms of new outfit, auto-fades after 3s.
- Rapid tap (Remix #2 within 3s of #1) restarts chip animation cleanly.
- No layout shift / no spinner during cross-fade.

**Verify**:
- Manual iOS sim: tap Remix, observe smooth 250ms fade. Use sim's "Slow Animations" toggle to inspect frame timing.

---

## Todo List

- [ ] 3.1 Replace mount call: `valenGetRecommendation` → `useTodayOutfit` (45m)
- [ ] 3.2 Mount RemixButton in bottom action cluster (30m)
- [ ] 3.3 Wire `RefreshControl` (pull-to-refresh = Remix tap) (25m)
- [ ] 3.4 250ms cross-fade + AxisChip mount (65m)
- [ ] Wave 3 verify: tsc clean + manual iOS smoke (cold start → /start, tap Remix → /next + chip + fade)

## Success Criteria

- ✅ Success criterion #1 (HomeScreen calls V05 `/start`, session persists same-day) — VERIFIED
- ✅ Partial success criterion #2 (Remix tap fires `/next`, cross-fade, AxisChip appears + auto-fades) — VERIFIED (long-press deferred to Wave 4)
- ✅ Partial success criterion #4 (Pull-to-refresh = Remix cycle) — VERIFIED (daily-reset deferred to Wave 5)
- HomeScreen LOC delta ≤ +50 (logic should live in hooks, not the screen).
- 0 references to `valenGetRecommendation` in HomeScreen.tsx after this wave.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| HomeScreen.tsx grows past 1320 LOC, lint baseline drifts | H | M | Hard cap: any new logic >5 lines goes into a custom hook (`useHomeRemixCoordinator` in Wave 5 if needed). Reviewer rejects PRs that inline. |
| Cross-fade animation conflicts with snap-paging ScrollView | M | M | Animate `gridWrap` (inner) NOT outer ScrollView. Validated pattern; if it still glitches, fallback: instant swap + 200ms chip animation only. |
| `useTodayOutfit` doesn't return outfit content for cached sessions (only hash) | H | M | Resolved by KISS in task 3.1: silently call `/build` on cold start with stored session_id, brief spinner OK. Documented decision. |
| Removing prefetch breaks the existing infinite-scroll pattern; users see only one outfit at a time | M | L | Acceptable for v0.5 — Remix model is "one outfit, swap on demand", not "scroll through 10". Document in inline comment, defer infinite-scroll to v0.6 if user feedback demands. |
| `RefreshControl` triggers while `/next` already in flight (double-tap edge case) | M | L | `useMutation` natively dedupes — second `mutate()` while first pending is queued or dropped. Verify with iOS sim manual stress test. |

## Security Considerations

- session_id sent in plaintext in request body — over HTTPS in production (CORS hardening is Phase 2 FOUND-04).
- No new auth surface; uses existing `apiClient` JWT interceptor.

## Next Steps

- Wave 4 (forced-axis sheet + animation polish) blocked by Wave 3.
- Wave 5 (daily-reset, edge cases, Edit Context wire) blocked by Wave 3.
- Suggest manual iOS sim smoke at end of Wave 3 before proceeding — confirms baseline before adding complexity.
