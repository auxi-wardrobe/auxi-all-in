# Suggestion tiles render blank while item detail shows the same garment

**Date:** 2026-09-18 · **Repo:** `auxi-wardrobe/auxi-mobile` (base `a00f98b`)
**Severity:** P1 — the app's headline surface (outfit suggestion) shows empty tiles.
**Status:** root cause confirmed; fix implemented + verified locally. **Not pushed** —
this session was denied push access to `auxi-mobile`. Patch attached.

---

## 1. Verdict

This is the **same** dead-`processed/`-URL bug as
`debugger-260917-0337-delete-account-reregister-missing-images.md`, not a new one.
auxi-mobile#333 fixed it in **three** places — wardrobe grid, Database grid, item
detail — and the suggestion surfaces were **never wired up**. That is the exact
asymmetry the CEO reported: the wardrobe has images again, the suggestion does not,
and tapping a suggestion item into detail shows it fine.

Detail works because `ItemDetailScreen` walks the ordered candidate chain. The
suggestion tile picked one winner on string presence and had no `onError`, so a
dead cutout URL rendered nothing.

---

## 2. Chain of causation

Backend state (unchanged, pre-existing): SYSTEM catalog rows still carry
`image_png` / `image_studio` pointing at `processed/` keys that 404 — the blobs were
deleted before `ac9bd56` closed the hole, and the §6.3 recovery was never run. Every
onboarding clone copies those dead URLs verbatim.

Client precedence is `image_studio → image_png → image_url`, picked on **string
presence**, not fetch success. So the dead `processed/` URL beats the alive
`common_items/` original.

`src/screens/HomeScreen/components/GarmentPreview.tsx` — the suggestion tile,
rendered by `OptionSheet.tsx:125` inside the Home outfit grid:

```tsx
const imageUrl = resolveItemImage(item);   // single winner, = the dead URL
...
<Image source={{ uri: imageUrl }} resizeMode="contain" />   // no onError
```

`<Image>` fails silently → blank tile. `onItemPress(item)` still navigates, so the
item is tappable and `ItemDetailScreen` (which uses `resolveItemImageSources` +
`useImageFallback`) renders it.

The suggestion items do carry all three fields — `V05OutfitItem`
(`src/services/v05Api.ts:237-247`) exposes `image_url`, `image_png`, `image_studio` —
so the chain has something to fall back to. Confirmed in the prior report: 8/8 sampled
`common_items/` originals return HTTP 200.

## 3. Call-site audit — who got the #333 fix and who did not

| Surface | File | Before |
|---|---|---|
| Wardrobe grid | `wardrobe/WardrobeGridTile.tsx` | chain ✅ |
| Database grid | `DatabaseScreen.tsx` | chain ✅ |
| Item detail | `ItemDetailScreen.tsx` | chain ✅ |
| **Suggestion tile** | `HomeScreen/components/GarmentPreview.tsx` | **single ❌** |
| **Today's picks** | `home/components/TodaysPicksSection.tsx` | **single ❌** |
| **Favourite tile** | `favourite/FavouriteOutfitCard.tsx` | **`LoadableRemoteImage` with no `fallbackUris` ❌** |
| Outfit collage | `components/features/collage-seed-layout.ts:630` | single ❌ — **still open**, see §6 |
| Remix → OutfitCanvas | `HomeScreen/index.tsx:1557` | single ❌ — still open |
| Home landing | `home/HomeLandingScreen.tsx:90` | single ❌ — still open |
| Capsule | `capsule/capsule-format.ts:24` | single ❌ — still open |

`OutfitSwipeDeck` renders no images itself — it wraps the `OptionSheet` grid, so it
is covered by the `GarmentPreview` fix.

---

## 4. Fix (implemented, in the attached patch)

`plans/260918-1221-suggestion-blank-tiles/auxi-mobile-suggestion-image-fallback.patch`
— applies to `auxi-mobile` at `a00f98b`. 5 files, +81/-6.

1. **`GarmentPreview.tsx`** — `resolveItemImageSources` + `useImageFallback`, `onError`
   on the `<Image>`. Kept the plain `<Image>` rather than swapping to
   `LoadableRemoteImage`: `styles.cardImage` is already 100%/100% so the swap is
   layout-neutral, but `OptionSheet` owns its own `SkeletonTile` during generation
   and a second skeleton would double up. Minimal change, no visual delta.
2. **`TodaysPicksSection.tsx`** — same treatment for `PickTile`.
3. **`FavouriteOutfitCard.tsx`** — pass `fallbackUris` to the existing
   `LoadableRemoteImage` (the prop already existed and was simply unused here).
4. **`garment-preview.render.test.tsx`** — 2 regression tests: a dead cutout retires
   and degrades to the original; all-candidates-dead falls through to the blank tile.
   Both fail against the pre-fix component by construction.

### Bonus: fixed 2 unrelated failing tests

`src/screens/home/__tests__/todays-picks.test.ts` had **2 tests failing on `main`
since 2026-09-13** — a time bomb, not a product regression. `shouldColdStart` and
`pickTodaysSheets` reach the clock via `isPersistedStale`'s `now = new Date()`
default and take no `now` parameter, so the suite's hardcoded
`2026-09-12` fixtures stopped being "today" the next day. Froze the clock with
`jest.useFakeTimers().setSystemTime(NOW)`.

---

## 5. Verification (run locally against `a00f98b` + patch)

- `npx tsc --noEmit` — 3 errors, **all pre-existing** in `see-this-on-me`
  (`poppinsTimeLg` / `poppinsBodySm` missing from theme typography). Identical count
  with the patch stashed. None of the touched files appear.
- `npx eslint` on all 5 changed files — clean, exit 0.
- `npx jest` (full suite): **873 → 875 passing**, failing suites 11 → 10.
  Diffed `FAIL` lists before/after: the **only** difference is `todays-picks.test.ts`
  moving failing → passing. Nothing regressed.
- The 10 still-failing suites all fail with **"Test suite failed to run"** — a
  jest transform/ESM error on bundled native deps (`react-native-purchases` and a
  Svelte-bundled dep), not assertion failures. Pre-existing, unrelated, env-level.
- **No simulator run** — no macOS/iOS sim in this environment.

---

## 6. What is still open

1. **Push blocked.** This session has read-only git access to `auxi-mobile`;
   `add_repo access:"push"` was denied. The patch needs a human or a session with
   push rights to land it.
2. **The data is still rotten.** This is a client-side symptom fix — the same one
   #333 was. `scripts/repair_dead_processed_images.py` + `backfill_cutout_images.py`
   have still never been run against prod (§6.3 of the 09-17 report). Until they are,
   every tile in the app is one layer of fallback away from blank, and the fallback
   costs a failed request per tile per render.
3. **4 surfaces still unfixed** — collage (`collage-seed-layout.ts`), Remix →
   OutfitCanvas, Home landing, Capsule. These thread a single `imageUri: string`
   through a layout data structure, so fixing them means widening that type to
   `string[]` across `collage-seed-layout.ts`, `CollageSheetCanvas.tsx` and
   `OutfitCanvasSurface.tsx`. Deliberately out of scope here — it is a real refactor,
   not a 3-line wiring change, and none of them is the surface the CEO reported.
   File it as a follow-up.

## Unresolved questions

1. Is the CEO's build actually carrying #333? If the installed TestFlight build
   predates it, the wardrobe grid would be blank too — it is not, so presumably yes,
   but worth confirming before anyone concludes this patch is sufficient.
2. Should the collage/canvas refactor (§6.3) be one ticket with this, or separate?
3. `auxi-web` has never been checked for the same resolver precedence (carried over
   unanswered from the 09-17 report).
