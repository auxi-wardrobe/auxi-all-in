# Phase 4 — Loading + Completed + Outro Screens

**Priority:** P1 · **Status:** pending · **Effort:** ~4h · **Blocks:** Phase 5
**Owner:** mobile-dev (figma-to-rn-workflow skill)

## Context links
- Extraction §3.5 (Loading), §3.6 (Completed), §3.7 (Outro)
- Primitives: `FigmaPrimitives.tsx` (`PillButton`, `BottomSheetSurface`),
  new `icon_loading.svg` / `icon_see_outfit.svg` (Phase 1)
- Architecture: deferred `completeOnboarding` (Phase 2)

## Overview
The 3 terminal screens. Loading + Completed share a layout (selected chips + headline
+ footer); Completed = Loading minus the loading-rows + enabled CTA. Outro = quote +
bottom sheet with the "See my outfit" CTA that finally calls `completeOnboarding()`.

## Key insights
- bg for all three = `#eee6df` = `figmaCaptionPillBg` (theme.ts:21). REUSE.
- Selected chips: bg `figmaChipBg` (#5b5550, new Phase 1), radius `chip:6` (new),
  label `interCaptionXxs`? No — chip label is Inter 12/16 = `uacBodyXsRegular`.
  Caption-pill labels (on tiles) use `interCaptionXxs` 10/12.
- Loading rows: text `poppinsBody` color `uacTextSubtle200` (#7a7f89) + 24×24
  `icon_loading.svg` rotating (RN `Animated.loop` + `rotate` interpolation).
- "MACGIE" headline = config (D3). If dynamic, interpolate "Your wardrobe".
- Outro CTA is a **text button** (`PillButton variant="text"`) with leading
  `icon_see_outfit.svg`, inside `BottomSheetSurface` (radius 16 top corners).

## Loading mechanics (D10 baseline = real wait)
Per the existing maestro note (`maestro/flows/onboarding/v05.yaml:33-40`), post-perf-fix
`/generate` returns in 3-4s and the loading view is <500ms before the swap. Baseline:
- Step-3's `/generate` mutation `isPending` drives a **Loading view** (rendered
  by the Styles screen OR a dedicated `OnboardingLoading` route per D10).
- On success → `navigate('OnboardingCompleted', { selection, profileSummary })`.
  Completed reads chips from the SELECTION (not the API response) so it renders
  instantly. (The `profile_classification` from the response is optional flavor.)
- On error (422 pool_insufficient / 400 / 401) → stay on Styles, show error block +
  "Retake"/"Try again" (reuse `StylePickerScreen.tsx:87-125` parseGenerateError).

## Data flow
```
Step3 selections ─► POST /generate (pending → Loading view)
   success ─► navigate Completed { wardrobe_direction, fit(wire+label), styles[] }
Completed "next" CTA ─► navigate Outro
Outro "See my outfit" ─► completeOnboarding() ─► AppNavigator swaps to Home
```

## Related code files
- CREATE `OnboardingCompletedScreen.tsx` (chips + "is ready" + CTA).
- CREATE `OnboardingOutroScreen.tsx` (quote + bottom sheet + completeOnboarding CTA).
- CREATE `OnboardingLoadingView.tsx` (shared loading body) OR inline in Styles
  screen (per D10). If dedicated route → also CREATE `OnboardingLoadingScreen.tsx`
  + register (Phase 2 already reserved the route name).
- CREATE/REUSE a `SelectedChips` component (chips row) — shared Loading+Completed.
- READ-only: `config.ts`, `AuthContext.tsx` (`completeOnboarding`).

## Implementation steps
1. Build `SelectedChips` (wrap, gap 8, chip bg/radius/label tokens).
2. Build `OnboardingLoadingView` (chips + headline + footer + animated rows).
3. Build Completed screen (same minus rows, enabled CTA → Outro).
4. Build Outro (quote + `BottomSheetSurface` + text CTA). CTA `onPress`:
   `await completeOnboarding()` (handle the loading/error from AuthContext:229-238).
5. Wire chips from route-param selection (display labels per D2/D4).
6. testIDs: `onboarding-completed-cta`, `onboarding-outro-see-outfit`,
   `onboarding-loading-view`. a11y on icon CTAs.
7. `auxi-lint-tokens.sh` + tsc + lint clean.

## Todo
- [ ] SelectedChips component (token-correct)
- [ ] Loading view (animated spinner rows, headline, footer)
- [ ] Completed screen + CTA → Outro
- [ ] Outro screen + bottom sheet + completeOnboarding CTA
- [ ] Chips populated from selection params
- [ ] testIDs + a11y
- [ ] lint-tokens + tsc + lint clean

## Success criteria
- Completed renders instantly from selection (no extra fetch).
- Outro CTA triggers `completeOnboarding()` → Home (verified Phase 6).
- Loading spinner animates; rows match config copy.
- Tokens clean; tsc passes.

## Risks
| Risk | L×I | Mitigation |
|---|---|---|
| `completeOnboarding` fails on Outro → user stranded | M×H | AuthContext already throws (AuthContext.tsx:233); show retry toast + keep CTA tappable. `/generate` already ran so wardrobe exists. |
| Spinner animation jank | L×L | `useNativeDriver:true` on rotate. |
| Loading too fast to see (<500ms) | M×L | Acceptable per maestro note; do NOT add artificial delay (anti-pattern). qa-mobile waits on post-state, not loading. |
| Completed needs API `profile_classification` but it's optional | L×M | Render from local selection; API block is flavor only. |

## Rollback
Screens are additive behind `ONBOARDING_V2_ENABLED`. Flag OFF → legacy
StylePicker's inline loading + immediate Home swap (no Completed/Outro).
