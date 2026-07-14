# mobile-dev delivery — See-on-me redesign (chat-transcript → stepped flow)

Plan: `plans/260714-0516-see-on-me-redesign/spec.md`
Branch (auxi submodule): `claude/see-on-me-redesign-ygds3d` (committed, NOT pushed)

## Commits (auxi submodule)

| SHA | Summary |
|---|---|
| `18e194debad91de95fc390a0ea8249f2757da94d` | infra: staggered-reveal hook, feedback service/hook, thumb icons, shared StepProgressHeader |
| `c7c82ec985c2ee9e1977e83ad339ee8f59092e90` | flow: chat transcript → full-screen stepped flow (B1/B2/B3) |
| `dadf161d2a4d3d410392563617b87a6070589d44` | i18n keys (en/fr/vi) + analytics tracking-plan update |

## What changed, per file

### New
- `src/hooks/useStaggeredReveal.ts` — B1 hook `useStaggeredReveal(rowCount, {stepMs:2000,minCtaMs:7000}) → {visibleCount, ctaEnabled}`. Row-by-row reveal, CTA gated to 7s; reduce-motion reveals all rows at once but still gates the CTA.
- `src/hooks/useTryOnFeedback.ts` — B3 optimistic single-choice (up XOR down) vote; fires analytics on positive selection only; fire-and-forget write.
- `src/services/tryOnFeedbackService.ts` — `POST /api/tryon/feedback {job_id,result_url,vote}` via `apiClient`; swallows all errors (endpoint is a backend follow-up).
- `src/assets/images/icon_thumb_up.svg`, `icon_thumb_down.svg` — currentColor, viewBox 0 0 24 24; registered as `Icons.ThumbUp`/`Icons.ThumbDown`.
- `src/components/layout/StepProgressHeader.tsx` — shared "Step n/3" + 3-segment bar (lifted from OnboardingStepHeader).
- `src/screens/see-this-on-me/StomStepLayout.tsx` — full-screen step shell (StomHeader + progress + scroll body + sticky footer + privacy caption).
- `src/screens/see-this-on-me/StomLoadingScreen.tsx` — B1 loading (mascot + staggered green-check rows + footer + 7s-gated leave CTA); `shapes` (3 rows) / `result` (4 rows) variants.
- Tests: `hooks/__tests__/useStaggeredReveal.test.tsx`, `hooks/__tests__/useTryOnFeedback.test.tsx`, `services/__tests__/tryOnFeedbackService.test.ts`, `see-this-on-me/__tests__/NextGating.test.tsx`.

### Reshaped
- `SeeThisOnMeScreen.tsx` — removed the transcript branch; every step now routes through `StomStepScreen`. Added capture-step CTA handlers (moved out of the deleted controls file), B2 local-pick vs Next-confirm split (`onPickShape`/`onConfirmShape`), and the `try_on_step_viewed` effect. **Async store, background-notify, completion-notice, AI-consent gate, AI-limit gate, reuse/rehydrate/cached-result logic all untouched** — only wired into the new shells.
- `StomStepScreen.tsx` — was a null-returning render function; now a component that routes EVERY step to a full-screen shell (profile-loading, capture steps, staggered loading, error retry, preview, reuse-confirm).
- `StepSelfie.tsx` / `StepFullBody.tsx` — controls-only → full-screen stepped cards (StomStepLayout + progress header + hero CaptureCard + footer CTA + privacy).
- `OutfitPreview.tsx` — added the B3 thumbs feedback overlay (two 32×32 white rounded-8 buttons, 4px gap, headerIcon shadow, bottom-center on the image); optional `outfitHash`/`jobId` props.
- `components.tsx` — added `CaptureCard` (hero 3:4 card w/ glyph or preview).
- `OnboardingStepHeader.tsx` — now composes `StepProgressHeader` (behavior identical).
- i18n `en-EN/fr-FR/vi-VN.json` — `stepLabel`, `next`, `privacyShort`, `loadingShapes`/`loadingResult` (title + rows arrays), `loading.footer`, `feedback.like/dislike`.
- `docs/analytics/mixpanel-tracking-plan.md` — §5.5 `try_on_step_viewed` + `try_on_result_liked/disliked`; §6.4 feedback-endpoint dependency; §10 result-satisfaction funnel tail.

### Deleted
- `StomStepControls.tsx` — obsolete transcript controls (logic moved into the orchestrator).

### Reused (built on, not recreated)
- `StepBodyShape.tsx` + `BodyShapeCarousel.tsx` — **unchanged**; B2 achieved purely by rewiring the orchestrator (sheet "Use this photo" → `onSelectShape` = local pick; new footer Next → render). Selected-tile border already keyed on `selectedShape`.
- `GeneratingView.tsx` — kept for the error/retry state.
- `MacgieLoader`, `PillButton`, `TopIconButton`, `Header.BackTitle`, `LoadableRemoteImage`, `PrivacyFooter`, `StepReuseConfirm`, async store + hooks — reused as-is.

## Behaviors
- **B1** staggered reveal + 7s CTA gate — `useStaggeredReveal`, both loading screens; reduce-motion honored (all rows at once, CTA still gated).
- **B2** Next-gating — `stom-next` disabled until `selectedShape`; sheet "Use this photo" selects locally, Next fires the existing select+render.
- **B3** thumbs feedback — optimistic toggle, `stom-feedback-like`/`-dislike` (flip `-selected` suffix), a11yLabels "Like/Dislike result"; write swallowed on failure.

## Verification (this headless env — no iOS sim)
- `npx tsc --noEmit` → **0 errors** (legacy `_HomeScreen` also clean here).
- `yarn eslint` on all touched files (incl. tests) → **0 problems**.
- `./scripts/auxi-lint-tokens.sh` → **no violations in any touched file** (the 14 reported are pre-existing in body/, canvas/, HomeScreen/, ContextChipsModal, PinGenerationError — untouched).
- `yarn jest` new suites → **12/12 pass** (useStaggeredReveal 3, useTryOnFeedback 4, tryOnFeedbackService 2, NextGating 3).
- `yarn.lock` unchanged (installed with `--frozen-lockfile`).

### Pre-existing test failures (NOT regressions — verified against pristine HEAD)
- `see-this-on-me/__tests__/ImageSkeletons.test.tsx` — 2 of 5 fail identically on HEAD (test env never fires `onLayout`, so the fitted-dependent skeleton + aspectRatio assertions fail). My OutfitPreview edits don't touch the layout logic.
- `onboarding/v2/__tests__/*` — fail identically on HEAD (`useFocusEffect is not a function`: the suites' `@react-navigation/native` mock lacks it). Unrelated to the `OnboardingStepHeader` refactor.

## Constraints / follow-ups
- **Figma MCP unreachable in this cloud session** (no gemini CLI bridge, MCP tools not exposed). Extraction transcribed from the spec (authored from a live Figma read) into `plans/260714-0516-see-on-me-redesign/figma-extraction-see-on-me.md`. Visual verification (qa-ui Compare, designer gate, qa-mobile) is **PENDING** — could not run headless.
- **Thumb glyphs hand-authored** (standard up/down, currentColor) because the Figma export was unreachable. Re-export exact paths from Figma 4814:13244 / 4814:13239 in an interactive session.
- **Capture-step card geometry** (steps 1/2) implemented as a clean on-token onboarding-style card from existing copy + outline glyph — confirm against Figma 4814:11695 / 4814:11710.
- Header title left as existing `seeThisOnMe.title` ("Self visualization"); Figma section labels it "See on me" — copy rename left out of scope (confirm with CEO).
- Backend `POST /api/tryon/feedback` is a follow-up (repo not reachable); mobile ships against the contract, errors swallowed.
</content>
