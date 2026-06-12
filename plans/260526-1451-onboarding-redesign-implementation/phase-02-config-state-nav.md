# Phase 2 — Config + State + Navigation Scaffold

**Priority:** P1 · **Status:** pending · **Effort:** ~4h · **Blocks:** Phase 3,4,5
**Owner:** mobile-dev

## Context links
- Nav types: `auxi/src/types/navigation.ts:71-110` (AppStackParamList + V05OnboardingSelection)
- Navigator: `auxi/src/navigation/AppNavigator.tsx:53-88`
- Feature flag precedent: `auxi/src/config/featureFlags.ts:29`, `auxi/src/navigation/AuthNavigator.tsx:44-95`
- AuthContext: `auxi/src/context/AuthContext.tsx:226-241` (`completeOnboarding`)

## Overview
Create the missing `src/onboarding/config.ts`, the navigation routes for the 3 new
terminal screens (Loading/Completed/Outro), the `ONBOARDING_V2_ENABLED` flag, and
the flag-gated branch in AppNavigator. **Solves the stack-swap timing problem.**

## Critical architecture (the load-bearing decision)
Today `StylePickerScreen.tsx:147-165` calls `completeOnboarding()` on `/generate`
success → `AuthContext` sets `is_first_login=false` → `AppNavigator.tsx:54`
re-evaluates and **swaps to the Home stack, unmounting onboarding**. The redesign
needs Loading/Completed/Outro to show AFTER generation. Resolution (KISS):

> **Defer `completeOnboarding()` until the Outro "See my outfit" tap.**
> Step-3 fires `/generate`; on success it `navigate('OnboardingCompleted', {…})`
> carrying the generation result. Outro's CTA calls `completeOnboarding()` →
> stack swaps to Home. `is_first_login` stays `true` through Loading/Completed/
> Outro, so a mid-flow kill relaunches into onboarding (acceptable — `/generate`
> is idempotent per contract L3375).

This matches the existing safety note in `StylePreferenceScreen.tsx:11-15`
("preserves is_first_login=true until wardrobe materialised").

## Data flow
```
config.ts (copy/labels/art)  ──► screens render
Step1 → params{wardrobe_direction}
Step2 → params{wardrobe_direction, fit_preference(wire)}
Step3 → params{...} + ranked StyleTag[]  ──► POST /generate
   on success → navigate Loading? No: Loading IS the in-flight call (D10).
   StylePicker(new) holds the mutation; Loading view renders while pending,
   then navigate('OnboardingCompleted', {selectionSummary}).
Completed → "is ready" + CTA → navigate('OnboardingOutro')
Outro → "See my outfit" → completeOnboarding() → Home stack swap
```
(Alternative if D10 = separate Loading route: add `OnboardingLoading` route too.
Plan baseline folds Loading into the Step-3 pending state per the existing
StylePicker pattern + the maestro note that Loading is <500ms post-perf-fix.)

## State decision (no new lib — per auxi "no Zustand" rule)
Onboarding selections thread through **route params** (already typed as
`V05OnboardingSelection`, navigation.ts:60). No store. The ranked style order
lives in Step-3 local `useState` (as today, StylePickerScreen.tsx:134).

## Related code files
- CREATE `auxi/src/onboarding/config.ts` — all copy/labels/art/chip-text/quote.
- CREATE route entries in `auxi/src/types/navigation.ts` for the new screens
  (`OnboardingWardrobe`, `OnboardingFit`, `OnboardingStyles`, `OnboardingCompleted`,
  `OnboardingOutro`; optionally `OnboardingLoading` per D10). Use NEW names so the
  legacy `GenderPreference`/`StylePreference`/`StylePicker` routes stay intact
  for fallback.
- MODIFY `auxi/src/config/featureFlags.ts` — add `ONBOARDING_V2_ENABLED`.
- MODIFY `auxi/src/navigation/AppNavigator.tsx` — flag-gated branch (V2 routes vs
  legacy V05 routes) inside the `is_first_login` block.

## config.ts shape (KISS — typed constants, copy sourced here)
```
WARDROBE_OPTIONS: { value: WardrobeDirection; label; art }[]
FIT_OPTIONS:      { wireValue: FitPreference; label; art }[]   // display label per D2
STYLE_OPTIONS:    { value: StyleTag; label; art }[]            // labels per D4 (fix "Minmal")
STEP_COPY:        per-step {stepLabel, title, subtitle} keyed by wardrobe branch (D8)
LOADING_COPY:     {headline (D3), helper (D4), rows: string[], footer}
COMPLETED_COPY:   {headline, footer}
OUTRO_COPY:       {quote, ctaLabel}
MAX_STYLE_PICKS = 2  (D7)
```
All strings here → trivially liftable to i18n later (auxi convention).

## Implementation steps
1. Add `ONBOARDING_V2_ENABLED: boolean = __DEV__;` to featureFlags.ts (mirror
   UAC default-then-dev-override comment style).
2. Add new route names + param types to navigation.ts (reuse `WardrobeDirection`/
   `FitPreference`/`StyleTag` from v05Api).
3. Create `src/onboarding/config.ts` with the constants above (placeholder art
   `require()`s reuse existing `*_fit.png`; style-tile art TBD — see Phase 3 risk).
4. Wire flag branch in AppNavigator: when `ONBOARDING_V2_ENABLED`, register the new
   screens; else the legacy three. Welcome + LocationPermission shared by both.
5. `npx tsc --noEmit`.

## Todo
- [ ] `ONBOARDING_V2_ENABLED` flag
- [ ] New route names + param shapes in navigation.ts
- [ ] `src/onboarding/config.ts` created with all copy/labels
- [ ] AppNavigator flag-gated branch
- [ ] Deferred-completeOnboarding wiring point identified (consumed in Phase 4/5)
- [ ] tsc clean

## Success criteria
- Flag OFF → identical legacy V05 flow (regression-safe).
- Flag ON → new routes registered, navigable (even with placeholder bodies).
- No inline onboarding strings anywhere (all in config.ts).
- `npx tsc --noEmit` passes.

## Risks
| Risk | L×I | Mitigation |
|---|---|---|
| Stack swap fires mid-flow (Loading/Completed unmount) | M×H | Deferred `completeOnboarding` (above) — verify with sim in Phase 6; assert Completed/Outro reachable BEFORE Home. |
| Route-name collision with legacy | L×H | NEW names (`Onboarding*`), legacy untouched; both behind flag. |
| Forgetting to register a screen → cold-start crash | M×H | auxi rule: every screen in BOTH navigation.ts AND AppNavigator. tsc + sim smoke catches. |
| config.ts art assets missing for style tiles | M×M | Phase 3 risk; placeholder bg until CEO supplies (D4/D6). |

## Rollback
Flip `ONBOARDING_V2_ENABLED=false` → instant revert to legacy V05. New routes are
additive; deleting them + the flag fully reverts with no legacy edits.
