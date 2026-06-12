# Phase 5 — Service Wiring + Persistence

**Priority:** P1 · **Status:** pending · **Effort:** ~3h · **Blocks:** Phase 6
**Owner:** mobile-dev

## Context links
- Client: `auxi/src/services/v05Api.ts:433-441` (`generateStarterWardrobe`)
- Mutation precedent: `auxi/src/screens/StylePickerScreen.tsx:136-166`
- AuthContext: `auxi/src/context/AuthContext.tsx:226-241`
- Analytics: `auxi/src/services/analytics.ts:124` (`track`)
- Contract: `API_DOCUMENTATION.md` L3373-3451

## Overview
Wire the `/generate` call into the new Step-3 screen, thread the result into the
Completed/Outro flow, defer `completeOnboarding()`, and emit the activation
analytics event. **No new service code** — `generateStarterWardrobe` already exists
and is correct. This phase is integration + persistence sequencing.

## Key insights
- `generateStarterWardrobe` (v05Api.ts:433) already POSTs `/v05/onboarding/generate`
  with `{wardrobe_direction, fit_preference, style_preferences}` — exactly the
  contract. REUSE as-is. No edit unless tech-lead D1 surfaces a change (not expected).
- The OLD StylePickerScreen calls `completeOnboarding()` inside `onSuccess`
  (line 151). The NEW flow MUST NOT — it navigates to Completed instead and defers
  the flip to Outro (Phase 2 architecture).
- Idempotency: `/generate` hard-deletes prior auto-clones (contract L3375), so a
  Retake or relaunch is safe — no dedupe logic needed.
- Analytics: keep the `onboarding_completed` event (StylePickerScreen.tsx:153-157)
  but FIRE it where completion truly happens — on Outro `completeOnboarding` success,
  not on `/generate` success (the user can still drop on Completed/Outro). Add
  `onboarding_generated` at /generate success for funnel granularity (optional).

## Data flow (final)
```
OnboardingStylesScreen
  useMutation(generateStarterWardrobe)
    mutate(ranked)  // pending → Loading view
    onSuccess(data) → navigate('OnboardingCompleted', {
        wardrobe_direction, fit_preference, fit_label, ranked_styles
      })  // NO completeOnboarding here
    onError → parseGenerateError → error block + Retake (reuse existing parser)
OnboardingOutroScreen
  onPress "See my outfit":
    track('onboarding_completed', { wardrobe_direction, fit_preference, styles_selected })
    await completeOnboarding()  // is_first_login=false → Home swap
    (on throw → toast, keep CTA tappable)
```

## Related code files
- MODIFY `OnboardingStylesScreen.tsx` (Phase 3 created it) — add the mutation,
  navigate-on-success, error block.
- MODIFY `OnboardingOutroScreen.tsx` (Phase 4 created it) — completeOnboarding +
  track on CTA.
- READ-only: `v05Api.ts`, `AuthContext.tsx`, `analytics.ts`.
- (Possibly) MODIFY `v05Api.ts` ONLY if tech-lead D1 requires (not expected).

## Implementation steps
1. Add `useMutation` to Styles screen (copy the shape from StylePickerScreen.tsx:136,
   minus the `completeOnboarding` call).
2. On success → navigate to Completed with the selection payload.
3. Reuse `parseGenerateError` (extract to a shared util if both old+new use it — DRY;
   else duplicate is acceptable since legacy is slated for deletion).
4. Outro CTA → track + completeOnboarding; error → Toast (pattern: AuthContext uses
   react-native-toast-message).
5. Real-HTTP smoke against local backend (`uvicorn ... :5001`) with a fresh
   `is_first_login=true` account (qa-test) — confirm 200 + Home swap. NOT a mock.
6. `npx tsc --noEmit` + `yarn lint`.

## Todo
- [ ] /generate mutation on Styles screen (no completeOnboarding in onSuccess)
- [ ] navigate → Completed with selection payload on success
- [ ] error block + Retake on 4xx (reuse parser)
- [ ] Outro CTA: track + completeOnboarding + error toast
- [ ] Real HTTP smoke vs local :5001 (fresh first-login account) returns 200 → Home
- [ ] tsc + lint clean

## Success criteria
- End-to-end: Welcome→…→Styles fires real `/generate`, lands Completed→Outro→Home.
- `is_first_login` stays true until Outro CTA; flips false after.
- Activation event fires exactly once, at true completion.
- No mocked backend in the verification (umbrella gate).

## Risks
| Risk | L×I | Mitigation |
|---|---|---|
| Contract drift discovered at smoke (400) | L×H | Caught here before QA; single targeted edit to v05Api.ts + ping tech-lead per umbrella rule. |
| Double completeOnboarding (Styles + Outro) | M×H | Explicit: Styles onSuccess must NOT call it. Code review checks. |
| Activation event fires on drop-out | M×L | Move event to Outro CTA, not /generate success. |
| Rate limit (5/min on /generate, contract L3379) hit on rapid Retake | L×L | Disable Retake while pending; acceptable for normal use. |

## Backwards compatibility
Legacy V05 path (flag OFF) keeps its own `completeOnboarding`-on-success behavior —
untouched. No shared mutable state between old and new flows.
