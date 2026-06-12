# V05 try_another session-lifecycle bug — analysis

**Date:** 2026-05-27
**Author:** mobile-dev (read-only analysis, no code edits)
**Scope:** auxi/ only. Backend analysis running in parallel.
**Repro reported:** Swiping (build → try_another) → switch to another tab (Wardrobe/Body/Settings)
→ come back, build again → OLD session still active → `recompose_pool_insufficient`
(pool already exhausted by the previous session).

---

## TL;DR (root cause)

The V05 session_id lives in **module scope** in `v05Api.ts` (one session per JS runtime,
not per screen mount), and **"switching tabs" does not unmount HomeScreen** because the
app uses a **native-stack navigator, not a tab navigator**. So:

- `navigation.navigate('Wardrobe')` *pushes* Wardrobe on top of the still-mounted Home.
- `navigation.navigate('Home')` *pops back* to the **same** Home instance — its cold-start
  `useEffect` does **not** re-run, component refs (`poolDepletedRef`, `fetchGenerationRef`,
  list state) are intact, and module-scope `v05SessionId` was never cleared.
- "Build again" therefore reuses the **stale, exhausted session** via `/try_another`, which
  returns `outfit: null` + pool-insufficient. The app marks `poolDepletedRef = true` and
  **dead-ends** — there is no auto-rebuild, no reset on focus, no visible error.

There is **no `resetV05Session()` on screen blur/focus, on navigation, or on app foreground**.
Reset only happens on three in-screen triggers: refine submit, mode change, and the
410/422 auto-fallback inside the façade.

---

## 1. session_id lifecycle (build → try_another)

State is module-scoped, not component-scoped:

- `auxi/src/services/v05Api.ts:532-533` — `let v05SessionId` / `let v05LastOutfitHash` at
  module scope. One session for the whole JS runtime; survives every screen mount/unmount.
- `auxi/src/services/v05Api.ts:536-539` — `resetV05Session()` nulls both.
- **Where session_id is obtained:** from the `/build` response.
  `buildAndStore()` at `v05Api.ts:584-597` calls `buildRecommendation(...)` then sets
  `v05SessionId = data.session_id ?? null` (`:593`) and caches the suggested-default outfit
  hash (`:594-595`).
- **Where it's used:** the façade `recommendV05()` (`v05Api.ts:616-676`):
  - `:620-622` — cold start / post-reset (no `v05SessionId`) → `/build`.
  - `:624-631` — otherwise build a `TryAnotherInput` with `session_id: v05SessionId` and
    `current_outfit_hash: params.current_outfit_hash ?? v05LastOutfitHash ?? ''`, then call
    `/try_another` (`:635`).
  - On success it updates `v05LastOutfitHash = data.outfit.outfit_hash` (`:638-640`).

**ONE session_id reused, not per-build.** The first call seeds it via `/build`; every
subsequent call serves a variation off the same session via `/try_another`. It only flips
back to `/build` when `v05SessionId` is null (cold start or after `resetV05Session()`), or
when the façade auto-resets on `410 session_expired` / `422 stale_hash` (`:648-654`).

HomeScreen never reads/writes `v05SessionId` directly — it goes through the façade
(`HomeScreen.tsx:504` `recommendV05(...)` inside `buildViaV05`). It only calls
`resetV05Session()` (imported at `HomeScreen.tsx:47`).

---

## 2. The bug — stale flow persists across tab-switch + rebuild

**(a) Navigator is a stack, not tabs.** `auxi/src/navigation/AppNavigator.tsx:55` uses
`createNativeStackNavigator`. Home/Wardrobe/Body/Settings are sibling `Stack.Screen`s
(`:95-100`). The sidebar navigates with `navigation.navigate('Wardrobe' | 'Settings' | 'Home')`
(`auxi/src/components/layout/Sidebar.tsx:87,107,130`). In native-stack, `navigate` to a
sibling **pushes** it on top; the screen underneath (Home) is **kept mounted**, not unmounted.
Returning to Home pops back to that same instance.

**(b) HomeScreen has no focus/blur lifecycle hook.** There is **no** `useFocusEffect`,
`useIsFocused`, or `navigation.addListener('focus'|'blur')` in `HomeScreen.tsx` (grep: none).
The only fetch entry point is the mount-once cold-start effect
(`HomeScreen.tsx:657-669`, deps `[requestRecommendation]`) — it runs once per mount and
**does not re-fire when the screen regains focus**.

**(c) Session + screen state are never reset on navigation.** `resetV05Session()` is called
in exactly three places, all in-screen user actions:
- refine/context submit — `HomeScreen.tsx:1014`
- mode change — `HomeScreen.tsx:864`
- (and inside the façade on 410/422 — `v05Api.ts:652`)

There is **no** reset tied to leaving/returning to Home. So after a tab round-trip:
`v05SessionId` is the OLD (possibly exhausted) session, `poolDepletedRef.current` may still
be `true` (`HomeScreen.tsx:381,620`), and `listOutfits` still holds the old cards. "Vẫn còn
flow đó" = exactly this — the same session + same buffered list are still live.

**(d) "Build again" is actually try_another against the dead session.** When the user
triggers another fetch after returning (swipe to tail, "Show another", or a prefetch),
`ensureBuffer()` (`HomeScreen.tsx:721-765`) threads `current_outfit_hash` (`:761`) and the
façade sees a non-null `v05SessionId` → it calls `/try_another` on the **old exhausted
session**, which returns `outfit: null` + `fallback`/pool-insufficient. There is no fresh
`/build` because nothing nulled the session.

Note one guard that *masks* the spam but not the bug: once a try_another comes back empty,
`poolDepletedRef.current = true` (`HomeScreen.tsx:619-622`) and `ensureBuffer` early-returns
(`:733-735`). So instead of hammering the dead session, the app silently stops producing
new outfits — the user sees a frozen/stuck recommendation list with no error and no recovery
path (the error UI at `:1201` only shows when `startError` is set, i.e. a *thrown* error;
pool-insufficient on try_another is a 200 with `outfit:null`, so `startError` is never set).

**TanStack cache is NOT the culprit here.** Recommendations use `useMutation`
(`HomeScreen.tsx:551-636`), not `useQuery` — there is no query cache keeping an outfit alive
across focus. The "stale flow" persistence is from (i) module-scope `v05SessionId` and
(ii) the still-mounted HomeScreen's refs/state, not from React Query caching.

---

## 3. Tab-switch behavior summary

- Navigating away (`navigate('Wardrobe')`) → Wardrobe pushed on top; Home stays mounted.
- Navigating back (`navigate('Home')`) → pops to the existing Home; **no remount**, cold-start
  effect does **not** re-run, no new `/build`.
- `try_another` is **not** debounced/queued in a timer sense, but it is gated:
  - single in-flight guard via `inFlightCountRef` counter (`HomeScreen.tsx:646-655,727-729`) —
    caps concurrency at 1 (2 only when a refine `force:true` overlaps a draining prefetch).
  - `poolDepletedRef` stops re-probing an empty pool (`:733-735`).
  - generation guard (`fetchGenerationRef`) drops results from a superseded session
    (`:572-575`).
- Swipe handler: `handleMomentumScrollEnd` → `advanceToSheet` → `ensureBuffer()`
  (`HomeScreen.tsx:1069-1078, 894-936`). It fires at most one prefetch per swipe, against
  whatever session is currently cached — which after a tab round-trip is the stale one.

So: build does **not** start fresh on return; it **resumes** the old session. That is the
defect.

---

## 4. Interaction with backend pool exhaustion

When a session's pool is exhausted, `/try_another` returns `outfit: null` (+ `fallback: true`
/ pool-insufficient; backend's `recompose_pool_insufficient`). Façade behavior
(`v05Api.ts:636-641`): `fallback`/`wardrobe_gap`/null → returns an **empty batch** `{outfits: []}`
(no card, no throw). HomeScreen `onSuccess` sees `addedCount === 0` → sets
`poolDepletedRef.current = true` and **stops** (`HomeScreen.tsx:619-622`).

**The app keeps the dead session and does nothing further** — it does **not** start a new
`/build`. The pool only "recovers" if the user happens to trigger one of the three reset
paths (refine submit / mode change / a 410/422 from the backend). Tab-switching is not one
of them, so the reported flow stays stuck.

---

## Recommended fixes (frontend-fixable)

Ordered by value/effort. All are in-scope for auxi.

### Fix A (primary) — reset the V05 session when Home regains focus
Add a `useFocusEffect` to HomeScreen that, on focus *after the first mount*, resets the
session and re-primes a fresh build:

- call `resetV05Session()`, bump `fetchGenerationRef`, clear `poolDepletedRef`, set
  `isFirstLoadRef = true`, then `requestRecommendation({...}, {force:true})`.
- guard against the very first focus (which coincides with the existing cold-start effect)
  so we don't double-fetch on initial mount — e.g. a `hasMountedRef`.

**Tradeoff:** every return to Home costs one `/build` (heavy: engine + LLM-1, re-seeds Redis
pool). That's the intended "fresh dressing session on re-entry" semantic and matches the
CEO's mental model ("new build = new flow"), but it discards the user's current scroll
position / buffered cards. If preserving position matters, gate the reset on "session looks
stale" (see Fix C) rather than always.

### Fix B (cheap safety net) — auto-rebuild on pool exhaustion instead of dead-ending
In the façade or in HomeScreen's `addedCount === 0` branch, when `/try_another` returns a
pool-insufficient empty (not a wardrobe_gap), treat it like 410/422: `resetV05Session()` +
fresh `/build` once, instead of setting `poolDepletedRef` and freezing.

**Tradeoff:** risk of a rebuild→exhaust→rebuild loop if the wardrobe genuinely can't fill
the pool. Mitigate with a one-shot flag (allow exactly one auto-rebuild per exhaustion, then
fall back to the current depleted behavior + a visible "no more options, refine to see more"
CTA). Distinguish `wardrobe_gap` (real gap → show gap CTA, don't rebuild) from transient
pool exhaustion (`fallback` with no gap → rebuild once).

### Fix C (lighter alternative to A) — reset on blur, lazy rebuild on next fetch
On Home blur, call `resetV05Session()` only (don't refetch). Next in-screen fetch (cold-start
guard sees null session) naturally rebuilds. Cheaper than A (no eager build on every return),
but the user still sees the old buffered list until they swipe/act, so the stale *cards*
persist visually even though the *session* is fresh. Combine with clearing `listOutfits`
on blur if we want a clean slate.

### Fix D (correctness, independent of A–C) — surface the dead-end to the user
Today a pool-insufficient try_another produces no error UI (the `startError` branch at
`HomeScreen.tsx:1201` only triggers on thrown errors). At minimum, when `poolDepletedRef`
trips with a non-empty list, show a "That's all for now — refine or change mode for more"
affordance so the user isn't staring at a frozen list. (Pairs naturally with the
wardrobe-gap CTA that's already flagged as a follow-up in `v05Api.ts:636-637`.)

**Recommended combination:** Fix A (focus reset, guarded against first mount) + Fix B
(one-shot auto-rebuild on transient exhaustion) + Fix D (visible dead-end CTA). A handles the
reported tab-switch repro directly; B/D harden the exhaustion path that A doesn't cover
(exhaustion *within* one session, no tab switch).

---

## Frontend vs backend split

**Frontend-fixable (auxi, this report's recommendations):**
- All of A–D. The session lifecycle, the missing focus reset, and the dead-end-on-exhaustion
  are entirely client-side decisions. No new endpoints needed — `/build`, `/try_another`,
  and the existing `session_id` / `fallback` / `wardrobe_gap` fields are sufficient.

**Needs backend awareness (parallel analysis):**
- Whether the backend can/should expire or recycle a session's pool so a reused session can
  replenish without a full `/build` (would make Fix C viable without losing cheapness).
- Confirm the exact response shape for transient pool exhaustion vs `wardrobe_gap` so the
  client can reliably distinguish "rebuild once" (Fix B) from "show gap CTA" (Fix D). The
  contract lists both `fallback` and `wardrobe_gap` on `TryAnotherResponse`
  (`v05Api.ts:380-391`); the backend analysis should confirm which fires on
  `recompose_pool_insufficient`.
- Whether `recompose_pool_insufficient` is ever returned as a non-200 (would route through
  the façade's throw path and surface `startError`) vs the current 200+null assumption.

---

## Open questions

1. Is the desired UX "new build on every Home re-entry" (Fix A, always) or "preserve session
   unless stale/exhausted" (Fix C)? Product/CEO call — affects whether returning users lose
   their current scroll position.
2. Should a `wardrobe_gap` on `/try_another` ever auto-rebuild, or always show the gap CTA?
   (Fix B must exclude gaps.)
3. Logout still doesn't clear `v05SessionId` (`v05Api.ts:529-531` TODO) — out of scope for
   this bug but the same module-scope-survives-everything root cause; worth a follow-up.
