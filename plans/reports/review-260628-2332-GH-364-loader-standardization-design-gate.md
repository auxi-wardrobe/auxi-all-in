# Design Review — Loader & mascot standardization (PR #173 + #175)

> Preserved copy of the step-6.5 designer-gate artifact (originally written to
> `auxi/docs/design-reviews/2026-06-28-loader-standardization.md` inside a
> throwaway resolve-worktree). Both PRs are now MERGED to auxi `main`.
> Mirror into `auxi/docs/design-reviews/` on a future auxi PR if a checked-in
> record is wanted.

**Date**: 2026-06-28
**Gate**: step 6.5 designer (HARD GATE) · code-level review
**Reviewer**: designer agent
**Scope**: PR #173 (ActivityIndicator → DotsLoader app-wide) · PR #175 (MacgieLoader → MacgieNod on auth Welcome)

## VERDICT
- **PR #173 (DotsLoader standardization): PASS** — only MINOR follow-ups.
- **PR #175 (MacgieNod on Welcome): PASS** — only MINOR follow-ups.

No BLOCKER, no MAJOR. Both on-system; both improve cross-screen coherence.
DotsLoader is on-system (theme/ds tokens, `motion.ts` timings, native driver,
reduce-motion fallback). MacgieNod matches the splash exactly (size 96, 24/16
spacing rhythm). The two coexist on Welcome (mascot vs social-CTA spinner).

## MINOR follow-ups (non-blocking; routed)
- **MINOR-1 → mobile-dev**: add a `motion.scale.pulse` token so DotsLoader's
  decorative pulse `[0.7,1]` (DotsLoader.tsx:112-115) is fully tokenized.
- **MINOR-2 → qa-ux**: DotsLoader is `accessibilityRole="progressbar"` with no
  label at standalone sites (OutfitCanvas picker, Wardrobe add). No regression
  vs ActivityIndicator, but add `accessibilityLabel="Loading"`.
- **MINOR-3 → mobile-dev**: awareness only — Home "Wear this" CTA carries two
  loader mechanisms (save overlay + generating trailing); states are mutually
  exclusive (disabled-while-generating), so no collision.
- **MINOR-4 → qa-ux**: forced `\n` in en/fr/vi subtitle may orphan a line at
  large Dynamic Type.

## Tech-lead sign-off (parallel review)
- PR #173: **APPROVE-WITH-NITS** — WardrobeScreen conflict resolution valid
  (union-of-imports minus dead `PillButton`); zero net-new tsc errors.
- PR #175: **APPROVE** — type-safe; archive green.
- Red-main (pre-existing, NOT introduced here, separate cleanup ticket):
  `DatabaseScreen.tsx:258 openSidebar`, `HomeScreen/index.tsx:101
  AI_NOTICE_DISMISSED_KEY`, `HomeScreen refineToast{Wrap,,Text}`. Babel masks
  these (archive build passes); they do not block these two PRs.

## Conflict resolutions applied
- **#173** `src/screens/WardrobeScreen.tsx` (import block): kept `MActionSheet`
  (main GH-364) + `MBottomSheet`/`MButton` + `DotsLoader` (#173); dropped dead
  `PillButton` (zero body usages after main's MActionSheet refactor).
- **#175** `src/screens/auth/WelcomeScreen.tsx` (import block): kept `MacgieNod`
  (#175) + `DotsLoader` (#173); dropped dead `MacgieLoader`.

## Unresolved / follow-ups
1. Red-main cleanup ticket (5 pre-existing tsc errors) — needs an owner (PM).
2. Umbrella submodule pin for `auxi` is now behind merged `main` — bump when ready.
3. Mirror this gate record into `auxi/docs/design-reviews/` on a future auxi PR.
