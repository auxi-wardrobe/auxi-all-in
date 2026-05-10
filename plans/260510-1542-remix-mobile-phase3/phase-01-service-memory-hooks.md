# Phase 3 — Wave 1: Service + Memory + Hooks Scaffold

## Context Links

- Parent plan: `plan.md`
- Contract: `wardrobe-backend/API_DOCUMENTATION.md` §V05 Recommendation `/next` (added by Phase 1 BE)
- BE plan: `.planning/phases/01-remix-backend/01-01-PLAN.md` Tasks 1.1, 4.1
- Mobile arch: `docs/pm/remix-feature-plan.md` §3.2
- Existing service: `auxi/src/services/v05Api.ts` (extend, do NOT clone)
- Existing legacy: `auxi/src/services/recommendationService.ts:85-86` (module-scope sessionId — to be replaced by recommendationMemory in Wave 3, NOT here)

## Overview

**Priority**: P1 (blocks Wave 3)
**Status**: pending
**Description**: Scaffold the non-UI plumbing — V05 `/next` service function, AsyncStorage-backed session memory, and two TanStack Query hooks. No UI changes yet. All three tasks parallel-eligible.

## Requirements

- REMIX-ME-01 (foundation): session_id persistence
- REMIX-ME-02 (foundation): Remix mutation
- REMIX-ME-09 (foundation): date-aware refetch hook

## Architecture

```
HomeScreen (Wave 3)
   │
   ├─► useTodayOutfit() ───► v05Api.buildRecommendation() ───► POST /api/v05/recommendation/build
   │       │
   │       └─► reads recommendationMemory.getSession()
   │
   └─► useRemix()       ───► v05Api.remixOutfit()         ───► POST /api/v05/recommendation/next
           │
           └─► writes recommendationMemory.setOutfit()
                   │
                   └─► AsyncStorage key: 'v05.remix.session.v1'
                           Shape: { session_id, last_outfit_hash, last_signature_ring[5], date_iso_local }
```

**Single Source of Truth**: `recommendationMemory` is the ONLY place session_id lives in mobile after Wave 3. The legacy module-scope `let sessionId` in `recommendationService.ts:85` stays for non-Remix callers (none exist post-cutover, but we don't delete legacy in this phase — see scope note).

## Related Code Files

**Create**:
- `auxi/src/utils/recommendationMemory.ts` (≤120 lines)
- `auxi/src/hooks/useRemix.ts` (≤80 lines)
- `auxi/src/hooks/useTodayOutfit.ts` (≤80 lines)
- `auxi/src/hooks/` (new directory)

**Modify**:
- `auxi/src/services/v05Api.ts` — add `remixOutfit()` function + request/response types
- `auxi/package.json` — add `@react-native-async-storage/async-storage` if not present (Phase 2 may have done it; check first)

**Delete**: none

---

## Implementation Steps

### Task 1.1 — Extend `v05Api.ts` with `remixOutfit()` + types

**Wave**: 1 · **Estimated**: 30 min · **Parallel-eligible**: Yes
**Files touched**:
- EDIT: `auxi/src/services/v05Api.ts`

**Steps**:
1. Add type alias `VariationAxis = 'SILHOUETTE' | 'LAYERING' | 'COLOR' | 'NEW_ANCHOR'` near top, after `STYLE_TAGS` block.
2. Add interface `RemixOutfitInput`:
   ```ts
   interface RemixOutfitInput {
     session_id: string;
     current_outfit_hash: string;
     rejected_items?: string[];
     preferred_colors?: string[];
     style_feedback?: string;
     force_variation_axis?: VariationAxis;
   }
   ```
3. Add interface `RemixTrace extends BuildTrace { variation_axis: VariationAxis }`.
4. Add interface `RemixOutfitResponse`:
   ```ts
   interface RemixOutfitResponse {
     outfit: V05Outfit;          // single outfit, not array
     session_id: string;
     trace: RemixTrace;
   }
   ```
5. Add export `remixOutfit(input: RemixOutfitInput): Promise<RemixOutfitResponse>` calling `apiClient.post('/v05/recommendation/next', input)`.
6. Document error mapping in JSDoc: 404 = session expired, 422 = outfit_hash drift, 500 = invariant violation.

**Acceptance**:
- `remixOutfit` exported, typed, no `any`.
- Reuses `V05Outfit`, `BuildTrace` shapes — no parallel definitions.
- VariationAxis enum exported (Wave 2 AxisChip imports it).

**Verify**:
```bash
cd auxi && npx tsc --noEmit 2>&1 | grep -v "_HomeScreen.tsx" | grep "error TS"
# 0 errors expected
```

---

### Task 1.2 — Create `recommendationMemory.ts`

**Wave**: 1 · **Estimated**: 50 min · **Parallel-eligible**: Yes
**Files touched**:
- CREATE: `auxi/src/utils/recommendationMemory.ts`
- POSSIBLY EDIT: `auxi/package.json` (add `@react-native-async-storage/async-storage` if Phase 2 didn't)

**Pre-flight**:
```bash
cd auxi && grep "async-storage" package.json
# If empty: yarn add @react-native-async-storage/async-storage && cd ios && pod install
```

**Steps**:
1. Define exported type:
   ```ts
   export interface RemixSessionMemory {
     session_id: string;
     last_outfit_hash: string | null;
     signature_ring: string[];      // last 5 outfit hashes for de-dup, FIFO
     date_iso_local: string;        // YYYY-MM-DD in DEVICE local time, NOT UTC
   }
   ```
2. Define constant `STORAGE_KEY = 'v05.remix.session.v1'` (versioned for future schema changes).
3. Define `getLocalDateIso(): string` — uses `new Date()` then `toLocaleDateString('en-CA')` to get `YYYY-MM-DD` in device local TZ. (Wave 5 daily-reset depends on this.)
4. Export functions:
   - `loadSession(): Promise<RemixSessionMemory | null>` — reads AsyncStorage; returns null on miss/parse-fail.
   - `saveSession(memory: RemixSessionMemory): Promise<void>` — writes JSON.
   - `clearSession(): Promise<void>` — removes key.
   - `appendSignature(hash: string): Promise<void>` — loads, FIFO push to ring (max 5), saves.
   - `isStaleByDate(memory: RemixSessionMemory): boolean` — compares stored `date_iso_local` to `getLocalDateIso()`.
5. Wrap each AsyncStorage call in try/catch; on error, log via `console.warn` and return null/no-op. Storage failure must NOT crash the app.

**Acceptance**:
- File ≤ 120 lines.
- All exports typed; no `any`.
- `isStaleByDate` returns true when stored date != today's local date.
- Signature ring caps at 5 (oldest dropped on push).

**Verify**:
```bash
cd auxi && npx tsc --noEmit 2>&1 | grep -v "_HomeScreen.tsx" | grep "error TS"
# 0 errors
```

---

### Task 1.3 — Create `useRemix.ts` and `useTodayOutfit.ts`

**Wave**: 1 · **Estimated**: 30 min · **Parallel-eligible**: Yes
**Files touched**:
- CREATE: `auxi/src/hooks/useRemix.ts`
- CREATE: `auxi/src/hooks/useTodayOutfit.ts`

**Steps for `useRemix.ts`**:
1. Export `useRemix()` hook returning `{ remix, isRemixing, lastAxis, error }`.
2. Internally use `useMutation` from `@tanstack/react-query`:
   - `mutationFn`: takes `{ force_variation_axis?: VariationAxis, style_feedback?: string }`, reads `session_id` + `last_outfit_hash` from `recommendationMemory.loadSession()`, calls `v05Api.remixOutfit(...)`. Throws if no session.
   - `onSuccess`: calls `recommendationMemory.saveSession(...)` with new `outfit_hash`, calls `appendSignature(outfit_hash)`. Stores `data.trace.variation_axis` in local `useState` (`lastAxis`). Records `latency_ms` via `Date.now()` diff captured at mutation start.
3. Expose `remix(args?: { force?: VariationAxis, feedback?: string })` as the imperative trigger.
4. **No telemetry calls in this hook** — Wave 6 wires those at HomeScreen call sites (keeps hook pure, easier to test).

**Steps for `useTodayOutfit.ts`**:
1. Export `useTodayOutfit()` hook returning `{ outfit, isLoading, refetch, isFreshSession }`.
2. On mount: load `recommendationMemory.loadSession()`. If null OR `isStaleByDate(memory)` true → call `v05Api.buildRecommendation(...)` (the existing function), persist new session_id. Set `isFreshSession = true`.
3. If memory present and fresh → return cached outfit_hash for HomeScreen to display, mark `isFreshSession = false`. (Note: actual outfit content not cached locally; Wave 3 may need a follow-up to also cache the last outfit object — see Risk #2.)
4. Expose `refetch()` that forces a `/start` call (used by Wave 5 daily-reset path).
5. Use `useQuery` with `queryKey: ['v05', 'today-outfit', date_iso_local]` so the date-key-change auto-refetches.

**Acceptance**:
- Both hooks ≤ 80 lines each.
- No direct `axios`/`apiClient` import — go through `v05Api.ts`.
- Hooks expose imperative API (`remix()`, `refetch()`); no React state escapes the hook signature.

**Verify**:
```bash
cd auxi && npx tsc --noEmit 2>&1 | grep -v "_HomeScreen.tsx" | grep "error TS"
# 0 errors
```

---

## Todo List

- [ ] 1.1 Extend `v05Api.ts` with `remixOutfit()` + types (30m)
- [ ] 1.2 Create `recommendationMemory.ts` (+ AsyncStorage dep if missing) (50m)
- [ ] 1.3 Create `useRemix.ts` + `useTodayOutfit.ts` (30m)
- [ ] Wave 1 verify: `npx tsc --noEmit` returns 0 new errors

## Success Criteria

- All 4 new/modified files compile.
- `v05Api.remixOutfit({...})` callable from a smoke script (no axios errors at typecheck level).
- `recommendationMemory.saveSession({...})` round-trips through AsyncStorage in iOS sim manual smoke (Wave 3 covers this end-to-end).
- `useRemix()` + `useTodayOutfit()` exported from `src/hooks/index.ts` (create barrel if it doesn't exist — single line `export * from './useRemix'; export * from './useTodayOutfit';`).

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| AsyncStorage native module not linked → runtime crash on iOS | M | M | Pre-flight check (`grep package.json`). If adding here, run `cd ios && pod install` and rebuild. Document in task 1.2. |
| `useTodayOutfit` doesn't cache the actual outfit object — only the hash. After app background+foreground, hash known but tiles can't render without re-fetching items. | H | M | Wave 3 task 3.1 must decide: (a) extend memory to cache full outfit JSON, (b) accept brief reload spinner on foreground, or (c) re-call `/build` silently. Plan recommends (b) for KISS — flag for tech-lead review. |
| Legacy `recommendationService.sessionId` module-scope state lingers post-Wave 3 cutover, drifts | L | M | Wave 5 task 5.5 includes a one-line `recommendationService.resetSession()` call when V05 path activates, killing the stale legacy state. |
| TanStack Query default cache time vs daily-reset semantics conflict | L | L | `queryKey` includes `date_iso_local`, so a midnight key change naturally invalidates. No `cacheTime` override needed. |

## Security Considerations

- AsyncStorage stores session_id (UUID, not a credential). Acceptable per legacy `Keychain` reservation for JWT only.
- No PII written to memory store (no email, no user_id).
- Storage key versioned (`v1`) so future schema changes can migrate cleanly.

## Next Steps

- Wave 2 (RemixButton + AxisChip) is parallel-eligible — can start concurrently.
- Wave 3 blocked by both Wave 1 and Wave 2 completion.
- After Wave 1: ping `tech-lead` if outfit-cache decision (Risk #2) needs sign-off before Wave 3 starts.
