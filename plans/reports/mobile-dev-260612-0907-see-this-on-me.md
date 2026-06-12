# mobile-dev — Workstream 5: "See this on me" try-on flow

- **Branch / worktree**: `feat/au226-favourite-and-see-this-on-me` @
  `/Users/nguyenminhduc/dev/auxi-favourite-wt`
- **Figma**: file `0nXXMAR4Arf1ZfjtQvtBh0`, section `2852:22266`
- **Extraction note**: `plans/260611-2348-favourite-see-this-on-me/figma-extraction-see-this-on-me.md`
- **Date**: 2026-06-12

## Files created

- `src/screens/see-this-on-me/SeeThisOnMeScreen.tsx` — container + step state
  machine (`selfie → fullBody → bodyShape → generating → preview`).
- `src/screens/see-this-on-me/StepSelfie.tsx` — Step 1/3 (required).
- `src/screens/see-this-on-me/StepFullBody.tsx` — Step 2/3 (optional + skip).
- `src/screens/see-this-on-me/StepBodyShape.tsx` — Step 3/3 inline tiles → carousel.
- `src/screens/see-this-on-me/BodyShapeCarousel.tsx` — expanded full-screen picker
  modal (paging carousel + dots + Retake / Use this photo).
- `src/screens/see-this-on-me/OutfitPreview.tsx` — preview image + opt-in + back-home.
- `src/screens/see-this-on-me/GeneratingView.tsx` — loader + error/retry state.
- `src/screens/see-this-on-me/components.tsx` — shared `StomHeader`, `PromptBubble`,
  `PhotoThumb`, `PrivacyFooter`.
- `src/screens/see-this-on-me/body-shapes.ts` — labeled shape vocabulary (asset gap).
- `src/hooks/use-image-picker.ts` — reusable single-photo picker extracted from
  `BodyScreen.handleImageSelection`.

## Files modified

- `src/types/navigation.ts` — added `SeeThisOnMe: { outfit: TryOnOutfitContext }`.
- `src/navigation/AppNavigator.tsx` — registered `<Stack.Screen name="SeeThisOnMe">`
  (gestureEnabled:false, like other multi-step flows).
- `src/screens/FavouriteScreen.tsx` — replaced the "Self visualization" no-op stub
  with `navigation.navigate('SeeThisOnMe', { outfit })`, building the
  `TryOnOutfitContext` from the favourite (outfit_hash / item ids / image urls /
  reasoning_human).
- `src/screens/_HomeScreen.tsx` — repointed `handleOpenTryOn` from
  `navigate('Body', { mode:'tryOn' })` to `navigate('SeeThisOnMe', { outfit })`.
  (See CAVEAT below — this is the legacy Home file but it's the ONLY Home try-on
  entry; current `HomeScreen.tsx` has none.)
- `src/translations/{en-EN,vi-VN,fr-FR}.json` — added `seeThisOnMe.*` namespace
  (all step copy, privacy footer, preview, opt-in, back-to-home, shapes). Verified
  key parity across all three locales.

## Figma child node-ids extracted

| Node | Screen |
|---|---|
| `3395:8480` | Step 1/3 selfie |
| `3395:9006` | Step 2/3 full body |
| `3395:9248` | Step 3/3 body shape (collapsed) |
| `3398:17745` (+ `noti` `3398:17798`) | Body-shape picker expanded (carousel modal) |
| `3398:17581` | Outfit preview / success |
| `3395:8500` | shared header instance |

Key design insight: steps 1–3 are a **cumulative chat transcript** (left prompt
bubbles + right photo thumbnails), not discrete page swaps. Implemented as one
scrolling transcript driven by the step state.

## Reuse vs new

- **Reused**: `PillButton`, `TopIconButton`, `Icons.*`, theme tokens, `track()`,
  `bodyService.uploadBody/getBodies`, `tryOnService.generateTryOn`, FavouriteScreen
  header pattern, i18n.
- **New**: all `see-this-on-me/*` components + `use-image-picker` hook.
- **DIVERGENCE (Open Q1)**: task said reuse `OnboardingStepHeader` for a 1/3·2/3·3/3
  progress bar. The Figma header on these frames is a centered-title header with NO
  progress bar; the step indicator is the "1/3 -" / "2/3 -" / "3/3 -" textual prefix
  inside each chat bubble. Followed Figma (CEO is designer) → built `StomHeader`
  (centered title) and kept the step count in the bubble copy. Flagged for sign-off.

## Exact generate call wired

```ts
const body = await bodyService.uploadBody(fullBody ?? selfie);   // → body.id
const res = await tryOnService.generateTryOn({
  body_id: body.id,
  wardrobe_item_ids: outfit.itemIds,
  gemini_opt_in: true,                                  // BE rejects non-true (400)
  prompt_params: shape ? { body_shape: shape } : undefined,
});
const url = res.composite_url
  ?? (res.composite_png ? `data:image/png;base64,${res.composite_png}` : null);
```
Body photo = full-body if captured, else selfie. ~10–20s loader; failure →
error+retry. No new BE endpoint/field (body_shape rides the existing free-form
`prompt_params`).

## Analytics + testIDs

- Events: `try_on_started` {outfit_hash,item_count}, `try_on_step_completed`
  {step, skipped?}, `try_on_completed` {outfit_hash, provider}, `try_on_failed`
  {outfit_hash, error_kind}.
- testIDs: `stom-step-1/2/3`, `stom-take-photo`, `stom-skip`,
  `stom-shape-option-<shape>`, `stom-shape-use`, `stom-shape-retake`,
  `stom-generate` path via the carousel, `stom-retry`, `stom-preview-image`,
  `stom-optin`, `stom-back-home`, `stom-back`.

## Gate results

- `npx tsc --noEmit`: **19 total errors = baseline** (15 `_HomeScreen.tsx` +
  4 `reactotron.config.ts`, all pre-existing). **Zero errors in my files**; verified
  the `_HomeScreen` error set is identical to the main-submodule baseline (only
  line numbers shift by 1 from my repoint edit).
- `eslint` (my files): **exit 0, clean**. Full-suite baseline (7 errors, 6 warnings)
  is identical to the main submodule and lives entirely in pre-existing files — my
  work adds none. (Note: CLAUDE.md's "4 errors + 3 warnings" figure is stale; actual
  current baseline on both checkouts is 7+6.)
- Token-lint: no hex literals, no `fontFamily` literals in any of my screen files
  (grepped with the `auxi-lint-tokens.sh` patterns; the umbrella script itself scans
  the submodule, not this worktree).
- i18n: all referenced keys present in en-EN; fr-FR + vi-VN key parity OK.
- node_modules symlink created for gates, **removed at end** (gone, verified).

## CAVEATS / Concerns

1. **`_HomeScreen.tsx` edit vs CLAUDE.md**: CLAUDE.md says don't edit the legacy
   `_HomeScreen.tsx`. The task explicitly required repointing the Home try-on entry,
   which exists ONLY there (current `HomeScreen.tsx` has no try-on CTA). Made it a
   1-line repoint, no refactor. When `_HomeScreen` is deleted, the new
   `HomeScreen.tsx` will need the same `navigate('SeeThisOnMe', { outfit })` wiring.
2. **Body-shape asset gap**: Figma renders silhouettes as full-body PHOTOS, not
   reusable SVGs — nothing to export. Per task instruction, shipped a labeled shape
   set (pear/hourglass/rectangle/triangle/oval) in `body-shapes.ts`. Prompt-bubble
   icons (`hugeicons:face-id`, `ion:body-outline`) also missing → fell back to
   `Icons.User` / `Icons.Body`. Needs `figma-icons-sync` for full fidelity.
3. **Opt-in persistence**: "Use this photo for future outfit previews" is local
   state only (no BE preference endpoint). Left a `// TODO(see-this-on-me)` in the
   container. Confirm a pref endpoint is out of scope.
4. **`prompt_params.body_shape`**: sent to `/tryon/highres` inside the free-form
   `prompt_params`. Needs backend confirmation it isn't rejected (Open Q5 in note).
5. **Container size**: `SeeThisOnMeScreen.tsx` is 247 lines (over the ~200 target).
   It's the orchestrator (state machine + 3 render branches); extracted GeneratingView
   already. Further splitting would fragment the state logic. Judged acceptable.
6. **qa-ui review-extraction gate**: per the Figma workflow, the extraction artifact
   should be audited by qa-ui (review-extraction mode) BEFORE code. As a subagent I
   can't dispatch qa-ui — I proceeded with code since the artifact is complete and
   open questions resolved via task instructions (fallbacks). **Parent should still
   dispatch qa-ui review-extraction + qa-ui Compare (post-code) + qa-mobile smoke.**

## Visual verification

NOT run — per task instructions ("Do NOT run the simulator"). **Code complete,
visual/simulator verification pending.** Side-by-side Figma compare + sim screenshot
must be done by qa-ui (Compare mode) / qa-mobile before merge.

---
**Status:** DONE_WITH_CONCERNS
**Summary:** Built the 3-step "See this on me" try-on flow (chat-transcript layout
per Figma), wired both entry points (Favourite link + Home CTA), added the
`SeeThisOnMe` route + `use-image-picker` hook + `seeThisOnMe.*` i18n in 3 locales.
tsc/eslint/token-lint clean for all authored files; baselines unchanged.
**Concerns:** header-vs-OnboardingStepHeader divergence (followed Figma), body-shape
+ prompt-icon asset gaps (fallbacks shipped), opt-in is local-only, `_HomeScreen`
edit despite legacy status (only Home try-on entry), qa-ui review-extraction +
sim verification still pending.

---

## Follow-up — 2026-06-12 · STOM photo capture: add "Choose from library"

**Problem:** Step 1 (selfie) + Step 2 (full-body) CTAs called camera only
(`pickImage('camera')`), blocking the iOS Simulator (no camera) and stopping
real users from picking an existing photo.

**Change:** Both step CTAs now open a bottom action sheet with **Take photo**
(camera) + **Choose from library** (gallery), matching BodyScreen's add-photo
UX. Generate/upload logic untouched — `bodyService.uploadBody` already handles
either asset.

**Files changed:**
- `src/screens/see-this-on-me/components.tsx` — added `PhotoSourceSheet`
  (bottom `Modal`: title + Take photo / Choose from library / Cancel) + styles.
- `src/screens/see-this-on-me/SeeThisOnMeScreen.tsx` — `capture` now opens the
  sheet (stashing the per-step done-handler in a `useRef`); new
  `handleSelectSource` launches camera/library and delivers the asset; new
  `closeSourceSheet`; renders `<PhotoSourceSheet>`.
- `src/translations/{en-EN,vi-VN,fr-FR}.json` — added `seeThisOnMe`
  `chooseFromLibrary`, `choosePhotoSource` (sheet title), `cancel`.
  (`takePhoto` already existed; reused for the camera option.)

**Hook status:** `use-image-picker.ts` **already supported** `'camera' |
'gallery'` (extracted from BodyScreen with `launchImageLibrary` +
didCancel/errorCode handling). **No hook change needed.**

**Action-sheet reused:** No shared action-sheet primitive exists in
`src/components/` — BodyScreen's is inlined. Rather than duplicate across both
step files, added one co-located `PhotoSourceSheet` to the STOM
`components.tsx` barrel (same pattern as BodyScreen) and the container owns its
visibility. testIDs: `stom-photo-source-sheet`, `-camera`, `-gallery`,
`-cancel` (text actions also carry `accessibilityLabel`).

**Tokens:** No hex/font literals. Scrim `figmaOverlayScrim`, surfaces/dividers/
text via existing `figma*` + `spacing`/`borderRadius` tokens, type
`interMediumSm`/`interBodySm`.

**Gates:**
- `npx tsc --noEmit`: touched files clean; only pre-existing baseline errors
  (`reactotron.config.ts`, `_HomeScreen.tsx`) remain. No
  see-this-on-me/translations/use-image-picker errors.
- 3 translation JSONs parse OK.
- `auxi-lint-tokens.sh`: **zero** see-this-on-me violations (45 reported are all
  pre-existing in unrelated files); targeted grep on the 2 changed code files
  shows no hex / no fontFamily literals.

Did NOT commit. Did NOT touch Metro. Worktree left as-is.

**Status:** DONE — code complete; sim visual verify not run by mobile-dev
(no mobile-mcp). Hand to qa-mobile/qa-ui for sim verify.
</content>
