# Phase 06 — Mobile: surface the applied gender in analytics + tracking doc

**Repo:** `auxi-wardrobe/auxi-mobile` · **Owner:** mobile-dev · **Effort:** 1h
**Status:** pending · **Blocked by:** phase 02 **tech-lead sign-off**

## Context

- `src/services/discoveryService.ts` — `DiscoveryOutfitsResponse`,
  `DiscoveryOutfitCard`. Wraps the shared `apiClient` (never a new axios
  instance).
- `src/hooks/useDiscoveryFeed.ts` — owns the feed's analytics. Already fires
  `discovery_feed_viewed` on focus (filter props via refs, so it does not
  re-fire per filter tweak), `discovery_filter_applied` on chip tap,
  `discovery_load_retry_tapped` on retry.
- `src/hooks/useDiscovery.ts` — TanStack Query wrappers, 60s `staleTime`,
  `refetchOnWindowFocus: false`.
- Rule: `.claude/rules/analytics-tracking-required.md` — this change alters
  **when/why** the feed's content appears, which the rule names explicitly as a
  tracking site. `docs/analytics/mixpanel-tracking-plan.md` §5 update is
  mandatory.

## Key insights

- **No functional mobile change is needed.** The filter is entirely server-side
  and keyed off the authenticated user, so `discoveryService` sends nothing new
  and the feed "just works". This phase exists only so the CEO can *see* the
  filter working — and see it failing — in Mixpanel.
- There is **no client-side gender source**. `wardrobeDirection.ts` (referenced
  by the 2026-06-02 V05 eval as an uncommitted interim) does not exist in the
  repo; the only gender vocabulary on the client is `WARDROBE_DIRECTIONS` in
  `src/services/v05Api.ts`, used by onboarding. So the event property must come
  from the server's `applied_gender` — not from local storage. This also makes
  the event report what the backend *actually did*, not what the client guessed.
- `discovery_feed_viewed` fires on focus, **before** the query resolves, so
  `applied_gender` is not reliably available there. Hence a second, separate
  event for the empty case rather than bolting a result count onto the first.

## Requirements

### 1. `src/services/discoveryService.ts`

```ts
export type DiscoveryGender = 'M' | 'W' | 'U';
```

- `DiscoveryOutfitCard` → `gender: DiscoveryGender | null;`
- `DiscoveryOutfitsResponse` → add, with the comment that explains the whole
  design:

```ts
  /**
   * The wardrobe gender the backend applied to this feed, derived from the
   * user's persisted onboarding direction — `null` when the user has no
   * direction on file and the feed came back unfiltered. There is NO client
   * parameter for this and no way to override it; it is reported, not
   * requested. Menswear users receive only `M` outfits, Womenswear only `W`,
   * Mixed all of them (backend AU-305 rule).
   */
  applied_gender: DiscoveryGender | null;
```

No change to any request. `listOutfits` params stay exactly as they are.

### 2. `src/hooks/useDiscoveryFeed.ts`

**a.** Add `applied_gender` to `discovery_feed_viewed` when it is already known
from a warm cache (omit the key entirely when unknown — never send `null`, per
the rule's "omit a property when its value is unknown"):

```ts
  const appliedGenderRef = useRef<DiscoveryGender | null>(null);
  useEffect(() => {
    if (outfitsQuery.data) {
      appliedGenderRef.current = outfitsQuery.data.applied_gender;
    }
  }, [outfitsQuery.data]);
```

then inside the existing `useFocusEffect` track call:

```ts
        ...(appliedGenderRef.current
          ? { wardrobe_gender: appliedGenderRef.current }
          : {}),
```

**b.** New event `discovery_feed_empty` — the blackout detector. Fires **once
per empty result set**, only when the feed genuinely resolved empty with **no
filter active** (a filter returning nothing is a normal user action, not a
coverage failure):

```ts
  // Strict gender targeting means a cohort with no published outfits for its
  // gender gets a silently empty feed. This event is how that becomes visible
  // in Mixpanel instead of in a support ticket. Guarded by a ref so a
  // re-render or a background refetch can't inflate the count.
  const emptyTrackedRef = useRef(false);
  useEffect(() => {
    const settled = !!outfitsQuery.data && !outfitsQuery.isFetching;
    const isEmpty = settled && outfitsQuery.data.total === 0;
    if (!isEmpty || isFilterActive) {
      emptyTrackedRef.current = false;
      return;
    }
    if (emptyTrackedRef.current) {
      return;
    }
    emptyTrackedRef.current = true;
    track('discovery_feed_empty', {
      ...(outfitsQuery.data.applied_gender
        ? { wardrobe_gender: outfitsQuery.data.applied_gender }
        : {}),
    });
  }, [outfitsQuery.data, outfitsQuery.isFetching, isFilterActive]);
```

`isFilterActive` is already computed in this hook — reuse it, don't recompute.
Declare the effect after it.

Event name is `object_verb`, snake_case, past-tense-ish per the taxonomy
(`discovery_feed_viewed` is the sibling precedent). No template literals, no
dynamic names. No PII: `wardrobe_gender` is a one-character bucket.

### 3. `docs/analytics/mixpanel-tracking-plan.md` — MANDATORY

- §5 Discovery subsection: add `wardrobe_gender` to `discovery_feed_viewed`'s
  properties (noting it is omitted on a cold first focus), and add
  `discovery_feed_empty` as a new shipped event with its `file:line` and its
  one property.
- §10 funnels: note that `discovery_feed_empty` is a **coverage alarm**, not a
  funnel step — segment it by `wardrobe_gender` to find a blacked-out cohort.

## Related code files

- MODIFY `src/services/discoveryService.ts`
- MODIFY `src/hooks/useDiscoveryFeed.ts`
- MODIFY `docs/analytics/mixpanel-tracking-plan.md`

No change to `useDiscovery.ts`, `DiscoveryScreen.tsx`, the card components, the
filter row, navigation, or translations. **No new UI**, so no Figma extraction,
no qa-ui Compare, no designer 6.5 (plan.md §Workflow deviation). If this phase
grows a visual element, that gate chain re-applies.

## Implementation steps

1. Types in `discoveryService.ts`.
2. The two analytics additions in `useDiscoveryFeed.ts`.
3. Tracking-plan doc update.
4. `npx tsc --noEmit` — clean.
5. `yarn lint` on the changed files — clean.
6. `yarn test` — `src/services/__tests__/` must stay green (the deep-link tests
   live there and are untouched).
7. Sim check per `.claude/rules/ios-build-workflow-required.md`: this is a
   JS-only change, so **Fast Refresh, never a native rebuild**. Do not kill
   Metro, do not `pod install`, do not `yarn ios:clean` — those are shared
   machine singletons and other sessions may be mid-QA. `yarn ios:doctor` first
   if the bundle looks stale.

## Todo

- [ ] `DiscoveryGender` + `gender` on the card + `applied_gender` on the response
- [ ] `wardrobe_gender` on `discovery_feed_viewed` (omitted when unknown)
- [ ] `discovery_feed_empty` fires once, only on an unfiltered empty feed
- [ ] `mixpanel-tracking-plan.md` §5 + §10 updated
- [ ] `npx tsc --noEmit` clean · `yarn lint` clean · `yarn test` green
- [ ] No native rebuild performed

## Success criteria

- A Menswear test user's feed shows only `M`/untagged outfits with no client
  change (proves the filter is server-side).
- `discovery_feed_viewed` carries `wardrobe_gender: "M"` on a re-focus.
- With zero published `M` outfits, `discovery_feed_empty` fires exactly **once**
  with `wardrobe_gender: "M"`, and the existing `DiscoveryFeedStates` empty view
  renders (no new empty-state work needed).
- Applying a season filter that returns nothing does **not** fire
  `discovery_feed_empty`.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| `discovery_feed_empty` fires repeatedly on re-render → inflated Mixpanel counts | **H**×M | `emptyTrackedRef` guard + the `isFetching` settle check; success criteria asserts "exactly once" |
| Event fires during the initial load (data undefined) and reads as a blackout | M×M | Guarded on `!!outfitsQuery.data && !isFetching`, not on `outfits.length` |
| `null` shipped as a property value | M×L | Both properties are spread-conditional, per the no-null rule in `.claude/rules/analytics-tracking-required.md` |
| A user re-onboards to a new direction mid-session and the 60s-stale feed cache still holds the old gender's outfits | L×M | Out of scope, but worth one line in the delivery report: `invalidateQueries({ queryKey: [DISCOVERY_QUERY_KEY] })` at onboarding completion would close it |

## Pre-existing bug noticed, deliberately NOT fixed here

`useDiscoveryOutfits`'s query key is
`[DISCOVERY_QUERY_KEY, 'outfits', season, trendTag]` — it **omits `offset`**, so
every page writes to the same cache entry. Paging forward then returning to
offset 0 can serve page 2's cached body as if it were page 1, and
`useDiscoveryFeed`'s accumulator would replace the list with it. Pre-existing
from AU-457, unrelated to gender, and touching it would widen this phase.
**File it as its own ticket** — do not fold it in.

## Next steps

Phase 07 verification.
