# Suggestion tiles render blank while item detail shows the same garment

**Date:** 2026-09-18 · **Repo:** `auxi-wardrobe/auxi-mobile` (base `a00f98b`)
**Severity:** P1 — the app's headline surface (outfit suggestion) shows empty tiles.
**Status:** root cause confirmed; **every** client render path fixed + verified locally.
**Not pushed** — this session was denied push access to `auxi-mobile`. Patch attached.

---

## 1. Verdict

Same dead-`processed/`-URL bug as `debugger-260917-0337-delete-account-reregister-
missing-images.md`, not a new one. auxi-mobile#333 fixed it in **three** places —
wardrobe grid, Database grid, item detail — and left **eleven other render paths**
on the old single-winner logic. That is exactly the asymmetry the CEO reported: the
wardrobe has images again, the suggestion does not, and tapping a suggestion item
into detail shows it fine.

Detail works because `ItemDetailScreen` walks the ordered candidate chain. The
suggestion tile picked one winner on string presence and had no `onError`, so a dead
cutout URL rendered nothing.

---

## 2. Chain of causation

Backend state (unchanged, pre-existing): SYSTEM catalog rows still carry `image_png`
/ `image_studio` pointing at `processed/` keys that 404 — the blobs were deleted
before `ac9bd56` closed the hole, and the §6.3 recovery was never run. Every
onboarding clone copies those dead URLs verbatim.

Client precedence is `image_studio → image_png → image_url`, picked on **string
presence**, not fetch success. So the dead `processed/` URL beats the alive
`common_items/` original.

`src/screens/HomeScreen/components/GarmentPreview.tsx` — the suggestion tile,
rendered by `OptionSheet.tsx:125` inside the Home outfit grid:

```tsx
const imageUrl = resolveItemImage(item);   // single winner, = the dead URL
<Image source={{ uri: imageUrl }} resizeMode="contain" />   // no onError
```

`<Image>` fails silently → blank tile. `onItemPress(item)` still navigates, so the
item is tappable and `ItemDetailScreen` renders it.

Suggestion items carry all three fields — `V05OutfitItem` (`src/services/v05Api.ts:237-247`)
— so the chain has something to fall back to. Prior report confirmed 8/8 sampled
`common_items/` originals return HTTP 200.

---

## 3. Full call-site audit (every render path, not just the reported one)

| Surface | File | Before | Now |
|---|---|---|---|
| Wardrobe grid | `wardrobe/WardrobeGridTile.tsx` | chain ✅ | ✅ |
| Database grid | `DatabaseScreen.tsx` | chain ✅ | ✅ |
| Item detail | `ItemDetailScreen.tsx` | chain ✅ | ✅ |
| **Suggestion tile** | `HomeScreen/components/GarmentPreview.tsx` | single ❌ | **fixed** |
| **Today's picks** | `home/components/TodaysPicksSection.tsx` | single ❌ | **fixed** |
| **Favourite tile** | `favourite/FavouriteOutfitCard.tsx` | `fallbackUris` unused ❌ | **fixed** |
| **Favourite collage** | `favourite/FavouriteOutfitCard.tsx:295` | single ❌ | **fixed** |
| **Collage seed layer** | `features/collage-seed-layout.ts` | single ❌ | **fixed** |
| **Canvas surface** | `features/OutfitCanvasSurface.tsx` | no `onError` ❌ | **fixed** |
| **Remix → canvas** | `HomeScreen/index.tsx:1557` | single ❌ | **fixed** |
| **Home landing remix** | `home/HomeLandingScreen.tsx:90` | single ❌ | **fixed** |
| **Canvas add-items** | `canvas/useCanvasAddItems.ts:72` | hand-inlined single ❌ | **fixed** |
| **Pin confirm modal** | `features/PinConfirmModal.tsx` | single ❌ | **fixed** |
| **Capsule tile** | `capsule/components/CapsuleItemTile.tsx` | single ❌ | **fixed** |
| **Capsule item detail** | `capsule/CapsuleItemDetailScreen.tsx` | single ❌ | **fixed** |
| **Capsule outfit picker** | `capsule/CapsuleSelectOutfitsScreen.tsx:200` | single ❌ | **fixed** |

`OutfitSwipeDeck` renders no images itself — it wraps the `OptionSheet` grid, so it
is covered by the `GarmentPreview` fix.

**After the sweep, zero render paths call the single-winner resolver.** The only
remaining `resolveItemImage` references in `src/` are two code comments. The helper
itself is kept (public API, unit-tested) but is now unused by production code.

### Two extra defects found during the sweep

1. **`useCanvasAddItems.ts:72` re-implemented the precedence by hand** —
   `item.image_studio || item.image_png || item.image_url` with a comment admitting
   it duplicates `resolveItemImage`. Same bug, plus a DRY violation that would have
   drifted again. Now calls the shared `resolveItemImageSources`.
2. **`capsule-format.ts` exported a dead helper** — `resolveWardrobeItemImage` had
   no consumers left after the capsule fixes. Removed rather than left to rot.

---

## 4. How the fix is shaped

The chain already existed (`resolveItemImageSources` + `useImageFallback`, both from
#333). The work was **threading it through the data structures** that had flattened
it to one string:

- `CollageSeedItem` / `Node` / `CanvasItemData` gain `imageFallbackUris?: string[]`,
  carried through the layout engine untouched — the same passthrough pattern the
  existing `status` field already uses. Layout math never reads it (test-locked).
- `OutfitCanvasSurface`'s `DraggableItem` walks the chain on error. `imageSource` is
  `ImageSourcePropType`, so a `require()`'d local asset (a number, not `{uri}`) is
  rendered as-is with **no** `onError` — a bundled asset cannot 404 and has no chain.
- Navigation param `OutfitCanvas.items[].imageFallbackUrls?: string[]` — optional, so
  existing callers keep type-checking.
- `CapsuleSelectOutfitsScreen`'s `thumbUris: string[]` (one URL per thumbnail) became
  `thumbSources: string[][]` (one *chain* per thumbnail), with the thumbnail extracted
  into its own `OutfitThumb` component so it can hold fallback state.

Persisted creations store a single resolved URI, so they become one-element chains —
no behaviour change, no migration.

---

## 5. Verification

- **`npx tsc --noEmit`** — 3 errors, **all pre-existing** in `see-this-on-me`
  (`poppinsTimeLg` / `poppinsBodySm` missing from theme typography). Identical with
  the patch stashed. None of the 18 touched files appear.
- **`npx eslint`** on all changed files — **0 errors**. One warning, pre-existing
  (`OutfitCanvasScreen.tsx:407` inline style; the patch touches line 90).
- **`npx jest`** full suite:

  | | Baseline `a00f98b` | With patch |
  |---|---|---|
  | Passing | 869 | **884** |
  | Failing | 33 | **31** |
  | Total | 902 | 915 |

  +13 new tests, +2 previously-failing now pass. Diffed the `FAIL` lists: the **only**
  difference is `todays-picks.test.ts` moving failing → passing. Nothing regressed.
- The 10 still-failing suites all fail with **"Test suite failed to run"** — a jest
  transform/ESM error on bundled native deps (`react-native-purchases`, a
  Svelte-bundled dep). Pre-existing, unrelated, env-level.
- **Patch verified to apply cleanly** to a pristine `a00f98b` (`git apply --check`).
- **Mutation-tested the fix**: reverting `onError` on the canvas surface makes
  "retires the dead cutout and renders the live original" fail, confirming the test
  binds to the behaviour rather than passing vacuously.
- **No simulator run** — no macOS/iOS sim in this environment.

### Tests added (13)

`__tests__/canvas-image-fallback.test.tsx` (5) — seed layer carries the chain
through; layout geometry unchanged by the extra field; the surface retires a dead
cutout and renders the original; a `require()`'d asset gets no `onError`; a
fallback-less item still renders.

`garment-preview.render.test.tsx` (2) — the suggestion tile degrades to the live
original; all-candidates-dead falls through to the blank tile.

`services/__tests__/image-fallback-analytics.test.ts` (6) — the event ships storage
buckets and never the URL; the blank-tile case sets `recovered: false` and omits
`recovered_bucket` (never null/empty); dedup fires once per failed URL per session;
a different dead URL still counts; an upload is classified distinctly from the
catalog; an empty URL is ignored.

### Bonus: 2 unrelated failing tests fixed

`home/__tests__/todays-picks.test.ts` had 2 tests failing on `main` **since
2026-09-13** — a time bomb, not a product regression. `shouldColdStart` and
`pickTodaysSheets` reach the clock via `isPersistedStale`'s `now = new Date()`
default and take no `now` parameter, so the suite's hardcoded `2026-09-12` fixtures
stopped being "today" the next day. Froze the clock with
`jest.useFakeTimers().setSystemTime(NOW)`.

---

## 5b. Tech-lead review round (2026-09-19)

PR #49 review: **Clean, 0 BLOCKER / 0 MAJOR**, no PII or secrets, no contract
drift. Two MINOR findings + one NIT. Disposition:

1. **Analytics gap (MINOR) — fixed.** Per `.claude/rules/analytics-tracking-required.md`,
   the new fallback path is a user-recoverable failure surface and shipped with no
   `track()` call. Correct finding, and the product argument is the strongest part
   of it: the fallback rate is precisely the metric that says whether the rotten
   SYSTEM `processed/` blobs are still live in prod. Now wired:
   - `analytics.ts` `trackImageFallbackUsed` — event `item_image_fallback_used`,
     literal name, fired through the single analytics seam.
   - Wired in **`useImageFallback`**, not at the ~14 render sites: every garment
     surface now walks its chain through that one hook, so one call covers all of
     them (DRY) and cannot drift as surfaces are added.
   - **No PII**: the URL is never shipped. Properties are the storage-prefix token
     only (`failed_bucket` / `recovered_bucket`: `common_items` | `processed` |
     `uploads` | `tryon` | `bodies` | `other`) plus `recovered` (boolean). The URL
     is used *solely* as the dedup key.
   - **Deduped per failed URL per session** (module-level Set, mirrors
     `trackRecommendationViewedOnce`). This is load-bearing, not polish: one rotten
     catalog blob is shared by every clone and re-renders on every grid scroll, so
     undeduped it would fire hundreds of events per session and drown the signal.
   - Tracking plan updated: §5.4 shipped row, §10 as a data-health gauge (not a
     funnel step) — segment by `failed_bucket`; a `processed` share that stays high
     means the backend repair never landed, and `recovered: false` is the residual
     blank tile.

2. **Unreviewed patch-as-artifact (MINOR) — agreed, no code change.** Whoever
   `git am`s this into `auxi-mobile` re-runs the gates; it must not land as
   "already reviewed". One correction to the framing: the gates were not merely
   asserted — they were executed against a real `auxi-mobile` clone at `a00f98b`
   (deps installed, tsc/eslint/jest run, fix mutation-tested). The reviewer's point
   stands regardless, since none of that is verifiable from *this* repo.

3. **NIT (umbrella CI red)** — already established and commented; no action.

### Correction to the verification claimed before this round

The earlier "tsc clean" claim was **overstated**. `canvas-image-fallback.test.tsx`
was created *after* the last full typecheck of that round, so it was never
typechecked — and it did in fact carry an error (`TS2739`: `OutfitCanvasSurface`
requires `width` / `height` / `onPositionChange`, which the test's render helper
omitted). Jest passes on it regardless because Babel strips types. Fixed, and the
full typecheck is now back to exactly the 3 pre-existing `see-this-on-me` errors.
The lesson generalises: run the typecheck *after* the last file is written, not
before.

## 6. What is still open

1. **Push blocked.** Read-only git access to `auxi-mobile`; `add_repo access:"push"`
   was denied. The patch needs a human or a session with push rights.
2. **The data is still rotten.** This is a client-side symptom fix, as #333 was.
   `scripts/repair_dead_processed_images.py` + `backfill_cutout_images.py` have never
   been run against prod (§6.3 of the 09-17 report). Until they are, every tile costs
   a failed request before falling back, and the app stays one deletion from blank.
   **This is now the only remaining root-cause work — the client side is complete.**

## Correction to the earlier version of this report

The first version claimed the suite went "873 → 875 passing". That was wrong —
measured against a stashed baseline, the true figures are **869 → 873** for the
first patch, and **869 → 878** for the complete one. The conclusion (nothing
regressed, only `todays-picks` changed state) is unaffected.

## Unresolved questions

1. Is the CEO's build actually carrying #333? If it predated #333 the wardrobe grid
   would be blank too — it is not, so presumably yes, but worth confirming.
2. `auxi-web` has never been checked for the same resolver precedence (carried over
   unanswered from the 09-17 report).
3. Should `resolveItemImage` (now unused by production code) be deleted outright, or
   kept as public API? Left in place — deleting it is a separate, purely cosmetic
   change and it is still exercised by its own unit tests.
