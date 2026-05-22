# HomeScreen.tsx deep code review — AU-242 variant grid scan

- File: `auxi/src/screens/HomeScreen.tsx` (1630 LOC)
- Auxi HEAD seen at review time: branch `fix/ios-archive-sentry-pbxproj` (working tree dirty; HomeScreen.tsx is modified).
  Note: the PR brief says `feat/home-grid-variant-layouts @ 95cb2aae`, but the umbrella's auxi submodule was on a different branch. Review uses the working-tree contents.
- Adjacent refs read: `services/v05Api.ts`, `services/recommendationService.ts`, `services/favouriteService.ts`, `types/item.ts`.

Priorities: CRITICAL > HIGH > MEDIUM > LOW > INFO. Line refs are absolute to HomeScreen.tsx.

---

## CRITICAL

### C1 — `pickLayout` returns `null` for count 0/1/2, sheet renders an EMPTY grid with no fallback
- Locations: `pickLayout` lines 993-1024; `OptionSheet.renderLayout` line 1091-1094; sheet container line 1209.
- `pickLayout` only handles 3, 4, 5+. For `count === 0`, `1`, `2` it returns `null`, and `renderLayout` short-circuits with `return null`. The sheet still renders (line 1209 `<View testID={'home-outfit-grid-{itemCount}'}>`) but with an empty body. Result: a card-less white sheet plus the bottom action cluster — looks broken to the user, no error/empty state.
- V05 hard-codes `count: 3` at line 404, so in the common path count is 3. However:
  - Server can short-return fewer items if pool insufficient (the V05 spec allows degraded sets and `wardrobe_gap`/`tier_pools_partial` flags exist in `BuildRecommendationResponse`).
  - `buildGridOutfitSheetWithPin` (line 128) splices pinned item to position 0 and slices to 3, so the pinned-rewrite path always yields exactly `min(originalCount, 3) + 1 - 1 = 3 or 4`. With a fresh-pin race the actual count can drop to 2 or fewer if upstream returned 1-2 items.
  - "5/6/7+" is the design intent, but the V05 wire never delivers > 3 because of the hard-coded `count: 3` (see C2). So today the heroStackPlusRows branch is dead code AND the layout you reach in practice is `twoRowOneLarge` (3) or `null` (<3).
- Recommendation: add explicit `count < 3` fallback (render the bare `Item[]` as a single-column or 2-up grid), or surface an empty-state with retry CTA. At minimum, log telemetry when null layout is rendered so you catch it in prod.

### C2 — V05 `count: 3` hard-coded conflicts with the new "5/6/7+" variant layouts
- Location: line 404 `count: 3`.
- The PR brief calls out 5/6/7+ layouts (`heroStackPlusRows`) but the wire request is fixed at 3 outfits per call. `count` in V05 refers to # of outfits in the response, not # of items per outfit — re-read `BuildRecommendationInput.count` at v05Api.ts:208 ("bounded 1..3 by Pydantic"). So the variant-count grid actually reflects items-per-outfit, which is determined by the V05 engine's outfit composition (TOP/BOTTOM/OUTER/FOOTWEAR/FULL_BODY/ACCESSORY).
- Confusion risk: the comment at line 1209 sets `testID='home-outfit-grid-{itemCount}'` keyed on items.length per sheet. Maestro selector `home-outfit-grid-5` will only ever fire if the V05 engine returns a 5-item outfit, which depends on accessory/outer composition. Today's V05 outfits typically return 3-4 items (TOP + BOTTOM + FOOTWEAR ± OUTER).
- This isn't a bug per se but: the heroStackPlusRows branch (lines 1146-1199) is likely dead in the current backend contract. Either confirm V05 emits ≥5-item outfits or remove the unused branch (YAGNI).

### C3 — `buildGridOutfitSheetWithPin` truncates to 4 items, defeating the variant-count grid
- Locations: lines 128-152, esp. line 146 `[pinnedItem, ...outfit.items.slice(0, 3)]`.
- When `pinnedItem` is present and the outfit doesn't already contain it, the helper splices pin into position 0 AND slices the rest to 3, capping total at 4 items.
- For an outfit that arrived with 5/6/7 items, pinning a foreign item destroys items 4..N. The Maestro test `home-outfit-grid-7` would flip to `home-outfit-grid-4` mid-session as soon as the user pins something not in the sheet.
- Also `gridItems: buildGrid(mixed)` returns `Array<Item | null>`, but `pickLayout` consumes `items: Item[]` (line 1049-1050 — `outfit.items`, not `outfit.gridItems`). The pin-splice mutates `items` so `pickLayout` sees the 4-item set. But `gridItems` is then computed and never read anywhere in `OptionSheet` (see L1).
- Recommendation: replace `.slice(0, 3)` with passing the full tail; pre-existing 2-row × 2-col assumption is the source of the truncation.

### C4 — Snap-paging math broken when sheet contents overflow on small phones
- Locations: `CARD_HEIGHT` line 92, `OPTION_SHEET_HEIGHT` line 83, `cardAspect` style line 1467-1470, inner `gridScroll` lines 1204-1210.
- `OPTION_SHEET_HEIGHT` is clamped to `AVAILABLE_VIEWPORT` to avoid clipping the action cluster on iPhone 16. `CARD_HEIGHT` is derived from the clamped sheet for the *2-row* assumption.
- New variant grids (`twoRowOneLarge` uses 2 rows, `twoByTwo` uses 2 rows, `heroStackPlusRows` uses `1 + ceil(rest/3)` rows). Crucially, the `cardAspect` style (line 1467) sets `height: undefined, aspectRatio: 3/4` — overriding `CARD_HEIGHT`. So every tile is now `width × 4/3`. For heroStackPlusRows the hero is `flex: 2` width so its height = `(2/3 × gridWidth) × 4/3 ≈ 0.89 × gridWidth`. Adding ≥1 extra row of rest items will not fit in the capped sheet height.
- The inner `gridScroll` (line 1204, `flex: 1`) makes the overflow scrollable inside the outer snap-paged ScrollView. **Nested vertical scroll inside a snap-paged outer ScrollView is the bug the C-5 fix (line 68-83) was explicitly trying to prevent.** The 2026-05-18 comment (line 86-94) says "Derive tile height from actual grid space so 2 rows always fit" — but `cardAspect` now ignores `CARD_HEIGHT` entirely. The fix has been silently undone.
- Snap interval still set to `OPTION_SHEET_HEIGHT + SHEET_GAP` (line 84), correct for outer paging, but the inner scroll will steal vertical-pan gestures on the affected sheets. Users on iPhone 16/SE will perceive sticky paging on 5/6/7+ sheets.
- Recommendation: compute tile dimensions based on grid space available per layout variant, OR allow the outer ScrollView to grow (drop the AVAILABLE_VIEWPORT cap) and surface the variable height through `getItemLayout`-style measurement. Don't ship the inner scroll.

### C5 — Counter renders STALE `activeSheetIndex` for non-active sheets
- Locations: counter render lines 1245-1251; sheet map line 915-933.
- Every `OptionSheet` receives `activeSheetIndex` as a prop and renders the counter `{activeSheetIndex + 1}/{totalSheets}`. Each sheet renders its own counter, but the user only sees the one in the currently visible sheet. So far so good — but each sheet that's already mounted and offscreen will re-render whenever `activeSheetIndex` changes. With many sheets, this is O(N) re-renders per swipe just to update an offscreen counter.
- More importantly: until React commits the new `activeSheetIndex`, the *prior* sheet's counter displays the old index. If the user swipes fast (multiple sheets in one fling), `onMomentumScrollEnd` fires once at rest with the final index — but during deceleration the visible counter on the in-flight sheet may show e.g. "2/5" when the user has already passed sheet 4. Minor visual artifact, not a correctness bug, but explains any flicker QA flags.
- Recommendation: hoist the counter out of `OptionSheet` and render once at the screen level (e.g. overlay above the action cluster) using `activeSheetIndex` from state. Eliminates the N× re-render and the deceleration flicker.

---

## HIGH

### H1 — Cold-start fetch never re-fires when mode changes; mid-swipe mode change is invisible until next prefetch
- Locations: useEffect line 472-484 (only deps `[valenGetRecommendation]`); `handleSelectMode` lines 632-641; prefetch lines 547-554.
- The comments at lines 627-631 and 540-554 explicitly say mode/pin changes "do NOT trigger an immediate refetch (would feel jarring inside the swipe loop)". This is intentional.
- BUT: after `handleSubmitContext` (line 738-781) immediately triggers a fetch, *mode/pin* changes do not. The user can tap "Power Choice" and see no effect until they've scrolled past `total - PREFETCH_LOOKAHEAD = total - 2` sheets. If they tap on sheet 1 of 3 total, they need to scroll to sheet 1 (already there) → ≥1 to trigger prefetch — actually `1 >= 3 - 2 = 1` is true, so it would fire. With 5 sheets buffered, mode change on sheet 1 does nothing until sheet 3.
- Recommendation: either (a) document this in a user-facing affordance ("New mode applies to next batch"), (b) clear `listOutfits` and refetch on mode change (matches C5's "feels jarring" warning — pick your trade-off explicitly), or (c) immediately add a single fresh sheet at the end with the new mode and bump pagination.

### H2 — Race: rapid mode changes can interleave responses out of order
- Locations: `valenGetRecommendation` mutation lines 437-470.
- TanStack `useMutation` doesn't queue or cancel in-flight calls when `mutate` is invoked again. If user submits context (line 776), then before the response arrives changes mode (line 632 — no fetch), the in-flight response still appends using its captured `mode/style_feedback` snapshot. Fine in isolation, but if `handleSubmitContext` is called twice in quick succession (e.g. they re-open the modal and confirm again), both responses land and append.
- The de-dup at lines 455-461 only drops by `outfitHash` collisions. V05 emits stable hashes per item-set; two genuinely different responses with different items will both append, doubling the buffer size.
- Worse: a stale earlier response can arrive *after* the user has triggered a cold-start replace path (line 446 `setListOutfits(incoming)`), and the later cold-start onSuccess will see `listOutfitsRef.current.length === 0` is no longer true (because the stale request beat it). The branch goes into append mode with `incoming` being the cold-start payload — fine logically, but `isFirstLoadRef.current` is now also false, so subsequent appends are correct.
- Recommendation: track an in-flight request id (incrementing counter ref); ignore onSuccess for any non-latest id. Standard "stale-while-revalidate" fix.

### H3 — `useMutation.onSuccess` reads `listOutfitsRef.current.length === 0` as proxy for "cold start" — fragile after deletions
- Location: line 443.
- Today there's no delete path, but if the user pulls-to-refresh or future code calls `setListOutfits([])`, the next onSuccess will mistake it for cold start and **reset `activeSheetIndex` to 0** (line 447), yanking scroll position. The comment at line 441-442 acknowledges this intent for cold start but the guard is symptom-based.
- Recommendation: add an explicit `isReplaceFetchRef` flag set by the caller (cold-start effect, mode-clear path) rather than inferring from list length.

### H4 — `useEffect` cleanup at line 358-362 calls `setPinnedItemId(null)` on unmount
- Location: lines 356-362.
- Setting state inside an unmount cleanup is technically allowed but a code smell — the setter is invoked when the component is already torn down, so React queues a warning-free no-op. Comment claims "session-only … cleared on unmount" but the state ALREADY gets discarded on unmount (component dies, state dies). The `setPinnedItemId(null)` call has no observable effect. Dead code masquerading as cleanup.
- Recommendation: delete the effect.

### H5 — Stale closure risk: `valenGetRecommendation` rebound only when `buildViaV05` changes (and it does, every weather update)
- Locations: `buildViaV05` line 381-435 has deps `[weather.tempC]`; passed to `useMutation` line 439; useEffect line 472-484 lists `[valenGetRecommendation]`.
- When `weather.tempC` updates (line 328 setter), `buildViaV05` is re-memoised → new `mutationFn` → TanStack creates a new mutation → `valenGetRecommendation` is a new function reference → **the cold-start useEffect (line 472-484) re-fires**.
- Result: every weather refresh (and the initial 22 → real-temp transition at line 326-329) triggers an extra full recommendation fetch, replacing `listOutfits` because `isFirstLoadRef.current` may have flipped but `listOutfitsRef.current.length === 0` could now be the deciding branch differently. Even if it appends, you're spending an extra V05 call per weather update.
- Recommendation: read `weather.tempC` via a ref inside `buildViaV05` so the function reference is stable. Add `[]` to `buildViaV05`'s deps.

### H6 — `moodMap` keyed by wrong `RecommendationMode` values (typo/desync)
- Locations: `moodMap` lines 389-395; `RecommendationMode` definition in recommendationService.ts line 35.
- `RecommendationMode = 'safe' | 'power' | 'creative'`. The `moodMap` keys are `casual | work | play | date | weekend` — none of those exist. The `as unknown as Record<RecommendationMode, string | null>` cast at line 395 swallows the type error.
- Effect: `moodMap[input.mode]` is always `undefined` → `mood = null`. The V05 intent.mood is always null regardless of the user's selected mode. **The entire mode selector is wired to the backend in name only.**
- Recommendation: rewrite moodMap with correct keys, e.g.:
  ```
  const moodMap: Record<RecommendationMode, Mood | null> = {
    safe: 'calm',
    power: 'confident',
    creative: 'playful',
  };
  ```
  Remove the unsafe cast.

### H7 — `occasion` field is set to the mode id (`safe`/`power`/`creative`), not an actual occasion
- Location: line 397 `const occasion = input.mode || DEFAULT_RECOMMENDATION_MODE;`
- V05 `user.occasion` is the social context (e.g. `work`, `weekend`, `date`). Sending `safe` / `power` / `creative` muddles the engine's occasion-based scoring. Per v05Api.ts:181, `occasion` is an optional free-form string but backend almost certainly expects standard occasion vocabulary.
- Recommendation: drop the `occasion` derivation or pass a fixed default (`'casual'` / `'general'`).

### H8 — `unfavoritedSwipeCountRef` reset paths inconsistent — counter can reach threshold from prefetched sheets the user never saw the favourite affordance on
- Locations: ref reset paths at lines 571 (any heart tap), 682 (modal opened), 764 (context submitted).
- Counter only resets when user opens or submits the modal, or favorites. It does NOT reset on mode change, pin change, or cold start. So a user who pre-faves on sheet 0, mode-changes, then swipes past 2 new prefetched sheets, would hit the threshold even though they actively engaged earlier. Likely benign but worth confirming with PM intent.

---

## MEDIUM

### M1 — `loading` flag flips back to true after first results, hiding sheets during refetch
- Location: line 492 `const loading = isStartPending && listOutfits.length === 0;`
- `isStartPending` is the mutation's general pending state, used for any in-flight `valenGetRecommendation` call. Since cold-start ALSO clears `listOutfits` via line 446's non-functional set... actually the cold-start path DOESN'T pre-clear, it just replaces on response. So `listOutfits.length` stays > 0 during prefetch, and `loading` stays false. Good.
- But if `handleSubmitContext` (line 776) fires while sheets are present, the prefetch on its onSuccess will hit the append branch (line 448-461) instead of the replace branch. The user's "I want different recommendations" intent results in appended sheets rather than replaced. UX feels wrong — submitting context should replace, not append.
- Recommendation: clear `listOutfits` before triggering context-driven fetch, OR mark that fetch as "replace" via the explicit flag from H3.

### M2 — `setListOutfits(incoming)` on cold-start (line 446) is not the functional setter — race with concurrent mutation onSuccess
- Same root cause as H2. The non-functional `setListOutfits(incoming)` on line 446 vs `setListOutfits(current => ...)` on line 455. If two onSuccess handlers fire in quick succession, the first non-functional call uses a stale closure (always `incoming`), the second functional call sees committed state. Not a hard bug today but a footgun.

### M3 — `gridItems` field on `OutfitSheetWithGrid` is built but never consumed by the new variant rendering
- Locations: `OutfitSheetWithGrid` type line 104-106; built at line 120, 150; `OptionSheet` reads `outfit.items` not `outfit.gridItems` (line 1049).
- The new `pickLayout(items)` ignores the precomputed `gridItems: Array<Item | null>`. The field is dead weight kept around for back-compat with the legacy buildGrid path.
- Recommendation: delete `gridItems` from the type and the builders, OR consume it (e.g. pass `gridItems` to `pickLayout` if null-safety matters downstream).

### M4 — `buildGridOutfitSheet` (line 118-121) and `buildGrid` (line 115-116) are dead with the new layout
- Same root as M3. `buildGrid` is invoked only inside `buildGridOutfitSheet[WithPin]`, neither product is read. Comments at lines 110-114 ("H2 fix") and 1539-1545 (`placeholderCard` style) reference the legacy "4-tile grid with one missing tile" rendering that no longer exists.
- Recommendation: delete `buildGrid`, simplify `buildGridOutfitSheetWithPin` to `(outfit, pinned) => ({ ...outfit, items: maybePinSpliced })`. Drop `placeholderCard` style.

### M5 — `'showAnother'` removal residue — `advanceToSheet` source param is now a single-literal union
- Location: line 658-659 `(nextIndex: number, source: 'swipe')`.
- The union `source: 'swipe'` is degenerate (only one possible value). Comment at line 793-795 still references "Bug 3 fix: counter mutation lives in advanceToSheet (outer function body), NOT inside a setState updater" — accurate but the helper no longer has a second call site.
- Recommendation: either (a) drop the `source` param entirely and inline the string in `console.info` at line 675, or (b) keep the union open (`'swipe' | string`) if you anticipate adding sources back.

### M6 — Module-scope `Dimensions.get('window')` evaluated once at import time
- Location: line 57.
- Doesn't react to orientation change or split-screen resize on iPad. Auxi is iPhone-portrait-only today, but the cap constants (`AVAILABLE_VIEWPORT`, `CARD_HEIGHT`) are baked at startup. If you ever support iPad or landscape, every layout math here breaks.
- Already flagged in the TODO at line 72-74 ("replace approximated chrome constants with useSafeAreaInsets()"). Same fix unlocks both.

### M7 — `setPinnedItemId(current => …)` updater reads `current` (line 615-624), which is safe — but `setSelectedMode(current => …)` (line 633) does the same with a NO-OP console.info inside the updater
- Location: line 632-641.
- The comment at line 309-311 explicitly warns that setState updaters must be pure. Yet `setSelectedMode` and `setPinnedItemId` both `console.info` inside the updater. StrictMode will double-invoke → double-log analytics events. The TODO comments on each `console.info` call (lines 580, 618, 622, 638, 649, 678) say "replace with the real telemetry hook" — if those become actual analytics calls, you'll double-track every mode change / pin change in dev StrictMode.
- Recommendation: move the logging out of the updater, or check the existing-vs-new value outside `setState`.

---

## LOW

### L1 — `pinHeaderLabel` style + clear pin TouchableOpacity (line 888-900) is missing `testID`
- Required by auxi/CLAUDE.md `testID` convention.

### L2 — `home-this-works-{n}` testID is sheet-index keyed but text flips between "Wear this" / "Saved to favourite"
- Line 1216-1225. Maestro flows asserting the static label will break when the button enters the saved state. The convention doc says "flip the suffix" for stateful elements (heart toggle does this at line 811-815). Recommendation: emit `home-this-works-{n}` vs `home-this-works-{n}-saved`.

### L3 — `WeatherWidget` initial render uses `tempC: 22` placeholder while async fetch resolves
- Line 319-322. Hanoi default coords (21.0285, 105.8542) hard-coded at line 327. PII / location-permission flow exists elsewhere — confirm with product whether falling back to Hanoi for non-Vietnam users is acceptable, or render a "—°" placeholder instead.

### L4 — Inner ScrollView (line 1204-1210) lacks `nestedScrollEnabled` prop
- On Android, nested vertical ScrollViews require `nestedScrollEnabled` on the inner one or panning falls through to the outer. Even setting aside C4 (which says don't nest scrolls at all), if the inner is intentional you need this prop.

### L5 — `key={outfit.outfitHash}` (line 920) collides when fallback hash repeats
- `normalizeOutfits` generates fallback hashes `outfit-{offset+index}` (line 190). Two cold-start replaces using the same offset (0) produce identical fallback hashes — React's reconciler will treat the second-render entries as the same nodes, preserving stale state. Today not reachable because cold-start only fires once unless H5 strikes, but worth tightening.

### L6 — `RecommendationMode` import unused via the legacy path
- `recommendationService` is imported at line 41-45 but not invoked anywhere in HomeScreen (V05 migration uses `v05BuildRecommendation` directly). Only `DEFAULT_RECOMMENDATION_MODE` and the `RecommendationMode` type are used. Remove the `recommendationService` import.

### L7 — `Outfit` imported (line 42) only for the cast inside `buildViaV05` (line 431) — dead-ish indirection
- The `as unknown as Outfit[]` cast just satisfies the legacy `{ outfits: Outfit[] }` return shape that's only consumed by `normalizeOutfits` which doesn't use the `Outfit` type strictly. Could simplify by widening `buildViaV05` return to `unknown` (matching the mutation's `onSuccess` param).

### L8 — `gridItems: Array<Item | null>` is typed as nullable but `buildGrid` only inserts `null` for sparse holes that the V05 API never emits
- Line 115-116 maps items via `items[index] || null`. V05 `outfit.items` is `V05OutfitItem[]` with no holes. The `| null` branch is unreachable in practice. Either prove the falsy-coalesce protects against a real wire shape or drop it.

### L9 — Comment at line 88-94 ("2026-05-18 fix: derive tile height from actual grid space so 2 rows always fit") is now MISLEADING
- After the AU-242 cardAspect override (line 1467), CARD_HEIGHT is no longer used by the variant grid (only by the loading skeleton at line 1267 and the base `card` style at line 1456). The comment narrative is stale and obscures the snap-paging math.

### L10 — `placeholderCard` style (line 1543-1545) is unused
- Originally for the "H2 fix" 3-item legacy grid; the new variant rendering uses transparent `cardShell` spacers (lines 1114, 1188-1194). Dead.

### L11 — `primaryAction` style (line 1578-1580) is defined but never used (only `primaryActionFull` is consumed at line 1224)
- Dead.

---

## INFO

### I1 — TODO debt
- Multiple `TODO(analytics)` comments (lines 580, 618, 622, 638, 649, 677, 705) all replicate the same console.info → track() migration. Consider a single batch refactor.
- Module-scope chrome constants TODO at line 72-74.
- `localhost:5001` hardcoded API URL (called out in CLAUDE.md don'ts).
- Logout-clears-session TODO in `recommendationService.ts` line 83-84.

### I2 — Comment hygiene
- Phase A/B/C/D-prefixed comments are pedagogical but heavy. Once the features ship, consider trimming the inline rationale to a single line + a link to the AU-XXX ticket.
- Comments referencing "Show another" pill (lines 62-64 about #3 fix moving "Show another" — the button has been removed) still describe layout deltas as if the button existed. Update or delete.
- The 1539-1545 `placeholderCard` block describes a legacy fix that's no longer reachable; combine with L10 deletion.

### I3 — Type safety nit: `GridLayout` discriminated union has no exhaustiveness check on consumers
- `pickLayout` switch handles `if (count === 3) … if (count === 4) … if (count >= 5) …` — no `default`/`never` guard. Adding a fourth `kind` later will silently miss in `renderLayout` (which uses `if` not `switch`). Add a `: never` assertion at the bottom of `renderLayout` for compile-time safety.

### I4 — `tier_role`, `engine_score`, `signal_reweight_applied`, `wardrobe_gap`, `tier_pools_partial` from V05 are dropped on the floor
- See v05Api.ts:240-331 — these fields carry signal about the engine's confidence, fallback state, and tier diversification. HomeScreen ignores all of them. Worth at least logging in QA to verify engine health.

---

## Unresolved questions

1. The umbrella's auxi submodule was on `fix/ios-archive-sentry-pbxproj`, not the brief's `feat/home-grid-variant-layouts @ 95cb2aae`. Are the AU-242 changes already merged into the iOS-archive branch, or did I review a different snapshot? (Working-tree had HomeScreen.tsx modified; review reflects the dirty contents.)
2. Does the V05 engine ever return > 4 items per outfit in production? If not, `heroStackPlusRows` (lines 1146-1199) and the entire `count >= 5` branch are dead code. Confirm with backend before keeping or deleting.
3. Is the mode → mood mapping (H6) intentional or a copy-paste leftover from a different mode vocabulary? Confirm with PM/spec author.
4. Counter hoisting (C5): is the per-sheet render intentional for future per-sheet metadata, or just incidental?
5. Should `handleSubmitContext` replace `listOutfits` rather than append (M1)? Product intent unclear from the comments.
6. `_HomeScreen.tsx` still exists per CLAUDE.md "Don'ts" — is the cleanup ticket tracked? Unrelated to this review but worth confirming.

