# AU-361 — "item ready" snackbar never fires — root cause + forward fix

**Date:** 2026-06-18
**Agent:** mobile-dev
**Scope:** `auxi/` only

## TL;DR

Root cause was NOT the toast plumbing and NOT the dedup seeding. It was a
**predicate mismatch**: the tile "preparing" overlay used a *truthy* check on
`is_preparing` while the ready-transition detector used a *strict* `=== true`
check. When `is_preparing` arrives as a non-boolean truthy value (string
`"true"`/`"false"` or number `1`/`0`), the overlay shows+clears correctly but
the item is **never seeded into `preparingIdsRef`**, so the preparing→ready edge
is never detected and `Toast.show({type:'successSnackbar'})` is never called.

This single mechanism explains BOTH observed facts (overlay works, toast
doesn't). Fixed by making `isPreparing()` coerce string/number forms and making
the overlay reuse the same predicate (one source of truth).

## Investigation (systematic-debugging)

### Plumbing verified end-to-end — all correct
- `<Toast config={toastConfig} />` is mounted at the **App root**
  (`auxi/App.tsx:84`), OUTSIDE the navigator/`RootDrawer`, so it does not
  unmount on the Wardrobe screen.
- `successSnackbar` IS registered in `toastConfig`
  (`auxi/src/components/feedback/toastConfig.tsx:46`) and its render returns a
  visible node with `testID="wardrobe-item-ready-snackbar"`.
- The `type` string in `WardrobeScreen` is exactly `'successSnackbar'`
  (`WardrobeScreen.tsx:147`) — matches the config key.
- SVG asset `auxi/src/assets/images/icon_check_circle.svg` exists and is valid
  (uses `currentColor`); all theme tokens used by the snackbar
  (`figmaSnackbarSuccessBg`, `figmaTextDark`, `uacTextBase`, `borderRadius.s`,
  `spacing.s/m`) resolve. No render-time throw.

Conclusion: plumbing is fine — IF `Toast.show` is reached.

### Logic verified by reproduction tests
Wrote a repro that drives the real screen + real poll (`useIsFocused:true`, fake
timers advancing `PREPARING_POLL_MS`) and spies `Toast.show`:
- Boolean `true→false` on first poll → **toast fires** ✓ (logic correct)
- Boolean stays preparing 2 polls then flips → **toast fires** ✓
So detection + dedup + poll wiring are correct **for a JSON boolean**. This
ruled out the "dedup seeding" and "prev-ref captures after flip" hypotheses.

### The discriminating evidence
Bug report fact: the per-item overlay **clears** on the same poll, but the toast
never appears ("not in the a11y tree, not in any screenshot"). Both
`setItems(data)` (drives overlay) and `reconcileReadyItems(data)` run on the
**same** `data` in `fetchItems`. The only way the overlay updates but reconcile
doesn't toast is if the item was never in `preparingIdsRef` — i.e. the two code
paths disagree on what "preparing" means.

They did:
- Overlay (old): `item.is_preparing ?` → **truthy** check (`WardrobeScreen.tsx:390`)
- Detector: `isPreparing` = `item.is_preparing === true` → **strict** (`WardrobeScreen.tsx:91`)
- Seeding into `preparingIdsRef` only happens when `isPreparing(item) === true`.

Backend signal: `is_preparing` does not exist anywhere in `wardrobe-backend/`
Python or `API_DOCUMENTATION.md` — strongly consistent with the field arriving
via a path that serialises it as a non-canonical truthy value (string/number),
not a JSON boolean.

### Confirmed
Added a repro with `is_preparing: "true" → "false"`: overlay-equivalent truthy
state holds, but `Toast.show` is NOT called with `successSnackbar` — reproduces
the live bug deterministically. (Now flipped into a passing regression test.)

## Root cause (specific)

`auxi/src/screens/WardrobeScreen.tsx:91` (pre-fix):
```ts
const isPreparing = (item) => item.is_preparing === true;
```
diverged from the overlay's truthy check at line 390. Non-boolean truthy
`is_preparing` → item never seeded into `preparingIdsRef` → preparing→ready edge
never detected → snackbar never fired.

## Fix (path:line)

`auxi/src/screens/WardrobeScreen.tsx`
- **`isPreparing()` (now ~91-108):** coerce representations — string
  `"true"`(case/space-insensitive) and number `1` count as preparing; boolean
  `true` unchanged. This makes detection match the overlay's intent.
- **Tile overlay (~408):** now renders on `isPreparing(item)` instead of the raw
  `item.is_preparing` truthy check — one shared predicate so the two paths can
  never diverge again (DRY). Added `testID="wardrobe-item-preparing-<id>"` for
  deterministic QA of the overlay state.

### Why it fires exactly once (dedup intent preserved)
Unchanged: `readyToastedIdsRef` still gates the toast — an item that flips fires
once, then is added to the toasted set and skipped on every subsequent poll. An
item already ready on first fetch never enters `preparingIdsRef`, so it never
toasts. Both covered by the new "fires once / not on already-ready" test.

## Tests

New regression suite: `auxi/src/screens/__tests__/WardrobeReadyToast.test.tsx`
(5 tests — boolean edge, string `"true"→"false"` edge, number `1→0` edge,
fire-exactly-once + no-toast-for-already-ready, multi-poll-then-flip).

```
PASS src/screens/__tests__/WardrobeScreen.test.tsx       (existing AU-351, no regression)
PASS src/screens/__tests__/WardrobeReadyToast.test.tsx    (5 new AU-361 tests)
Tests: 7 passed, 7 total
```

## Verification

- `npx tsc --noEmit` → **clean, 0 errors** (no legacy `_HomeScreen` errors today).
- `npx eslint` on touched files → **0 problems**. Full `yarn lint` shows 8
  pre-existing problems in OTHER files (`SignInScreen.tsx` etc.); none in my
  touched files (baseline in CLAUDE.md has drifted from other session work, but
  my change adds zero lint debt).
- Did NOT commit/push (per task) — left in working tree for Metro hot-reload +
  qa-mobile re-verify.

## Analytics
No new wiring needed. This is a behavior fix to an existing handler; the
`item_ready_toast_shown` event already exists and now fires correctly when the
edge is detected. No new user interaction introduced.

## What to watch on re-verify (qa-mobile / sim)
- Repro the live flow: upload an item, stay on Wardrobe, wait 2+ poll cycles
  (~20s) for backend processing to finish. Expect the teal
  `wardrobe-item-ready-snackbar` to appear once, and the per-tile
  `wardrobe-item-preparing-<id>` overlay to clear on the same cycle.
- Confirm it fires exactly once (does not re-toast on subsequent polls).
- If it STILL doesn't appear with the corrected predicate, the next suspect is
  the toast library's runtime rendering of the custom `successSnackbar` type on
  device (could not be exercised in jest — the lib ships untranspiled ESM
  outside the preset's `transformIgnorePatterns`). In that case capture the
  actual `is_preparing` value/type from the `/wardrobe/items` response so we can
  confirm the serialisation assumption.

## Open questions (escalate if relevant)
- Backend has no `is_preparing` field in Python/docs. The coercion fix is
  defensive and correct regardless, but tech-lead/backend-dev may want to
  confirm the canonical serialised type of `is_preparing` on the
  `/wardrobe/items` response and document it (contract hygiene). Not blocking
  the mobile fix.

---

**Status:** DONE
**Summary:** Root cause = predicate mismatch — overlay used truthy `is_preparing`
while ready-detection used strict `=== true`, so non-boolean (`"true"`/`1`)
serialisations broke the preparing→ready edge and the snackbar never fired.
Fixed by coercing in `isPreparing()` and reusing it for the overlay; added a
5-test regression suite. tsc clean, lint clean on touched files.
**Files changed:**
- `auxi/src/screens/WardrobeScreen.tsx` (isPreparing coercion + overlay reuses predicate + overlay testID)
- `auxi/src/screens/__tests__/WardrobeReadyToast.test.tsx` (NEW regression suite)
**Concerns/Blockers:** None blocking. Open item: backend should confirm/document
the canonical type of `is_preparing` on `/wardrobe/items` (contract hygiene —
backend-dev/tech-lead, not mobile).
