# AU-354 pt.3 — Persist & restore reused body photo on re-entry

**Agent:** mobile-dev · **Date:** 2026-06-17 · **Scope:** AU-354 part 3 ONLY (reuse-body-photo state). Parts 1 (AI quality) and 2 (quit-loading, AU-358) untouched.

## Gap / root cause

Persistence was already durable server-side: AU-346 saves the user's chosen body photo + shape as a reusable "active profile" (`bodyService.getActiveProfile()` → `BodyProfile` carrying `image_url`, `full_body_url`, `body_shape`). The defect was purely the **re-entry UX**:

- `SeeThisOnMeScreen.tsx` had a `useEffect` (old lines ~251-264) that, on the reuse path, **auto-fired `runGenerate` immediately** — it never showed the user which photo was being reused and gave no confirm/retake choice.
- Viet's UAC requires: on return, SHOW the previously selected photo with CONFIRM and RETAKE actions, instead of redoing capture OR silently regenerating.

So the fix is a re-entry **confirmation screen**, not new persistence — the data already round-trips through the backend.

## What changed

### New component
- `auxi/src/screens/see-this-on-me/StepReuseConfirm.tsx` (new) — presentational reuse-confirm view. Shows the persisted photo in the existing conversational transcript style (`PromptBubble` + `PhotoThumb`) + two `PillButton`s (Confirm filled / Retake text). Theme tokens only, all interactive elements carry `testID` (`stom-reuse-confirm-use`, `stom-reuse-confirm-retake`, plus `stom-reuse-confirm`, `-prompt`, `-thumb`).

### Screen wiring — `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx`
- `:45` import `StepReuseConfirm`.
- `:111-114` new `reuseConfirmed` state (false until user taps Confirm).
- `:256` `reusePhotoUri` = `full_body_url ?? image_url ?? null` (full-body preferred — it's what drives the render).
- `:262-269` `handleReuseConfirm` — guarded once-fire: sets `reuseConfirmed`, tracks `body_photo_reuse_confirmed`, then `runGenerate(profile.id, profile.body_shape)`. **Replaces the old auto-fire effect** (no more silent regeneration).
- `:280` `restartCapture` now also resets `reuseConfirmed`.
- `:293-297` `try_on_outcome_retaken` made conditional on `resultUrl` so the reuse-confirm retake (pre-render) doesn't pollute the outcome-retake funnel.
- `:305-309` `handleReuseRetake` — fires `body_photo_retake_selected` then delegates to `restartCapture`.
- `:498-516` new render branch: when `reuseMode && !reuseConfirmed && !rehydratedRef.current && reusePhotoUri && step === 'selfie'` → render `StepReuseConfirm`.

### i18n (3 locales, parity)
- `auxi/src/translations/en-EN.json`, `fr-FR.json`, `vi-VN.json` — added `seeThisOnMe.reuseConfirm.{prompt,confirm,retake}`.

### Analytics doc
- `auxi/docs/analytics/mixpanel-tracking-plan.md` §5.5 — added both events with `file:line` + `outfit_hash`. §10 — added "Reuse-on-return funnel".

## Persistence approach

No new storage introduced (KISS/DRY). The reusable profile is already persisted on the backend via AU-346 (`PATCH /api/body/{id}` with `is_primary`, `body_shape`, `full_body_url`) and read back via `GET /api/body/active` (TanStack Query key `['body','active']`). The fix consumes that existing durable state to render the confirm screen. AU-358's `try-on-generation-store` is reused as-is for the generate lifecycle (rehydrate guard `rehydratedRef` preserved so a backgrounded render isn't double-fired). No AsyncStorage added — server profile is the source of truth, matching the existing pattern.

## Regression safety (AU-358 / AU-346)
- AU-358 rehydration: reuse-confirm branch is guarded by `!rehydratedRef.current` AND `step === 'selfie'`, so returning into an in-flight/completed background render skips straight to generating/preview — unchanged.
- AU-346 capture flow + preview-screen "Retake photos" (`restartCapture`, `try_on_outcome_retaken`) preserved (outcome event now correctly fires only when a `resultUrl` exists).
- Malformed profile (id but no photo) → reuse-confirm skipped, falls through to capture. First-time user (no profile) → unchanged.

## Analytics events (new, past-tense snake_case, no PII)
- `body_photo_reuse_confirmed` — `SeeThisOnMeScreen.tsx:267` — prop `outfit_hash`. No image data/paths.
- `body_photo_retake_selected` — `SeeThisOnMeScreen.tsx:308` — prop `outfit_hash`. No image data/paths.
- Checked §5 for collisions: distinct from existing `try_on_profile_retake` / `try_on_outcome_retaken` (those are pre-render-vs-post-render different interactions; documented the distinction inline + in the doc).

## Verification
- `npx tsc --noEmit` (Node 20): **1 error, NOT mine** — `GeneratingView.tsx:51` (AU-358's uncommitted file) passes `accessibilityLabel` to `PillButton`, which the primitive doesn't accept. My touched files (SeeThisOnMeScreen, StepReuseConfirm, translations, doc) are tsc-clean.
- `scripts/auxi-lint-tokens.sh`: 34 pre-existing violations, **none in my files**. My new component uses theme tokens only.
- `eslint` on both touched source files: clean (exit 0).
- Simulator: NOT run this session (no sim launched). Code complete, visual verification pending → hand off to qa-mobile (sim smoke) / qa-ui (Maestro flow off the new `stom-reuse-confirm-*` testIDs).

## Flag for tech-lead / AU-358 owner (NOT fixed — cross-ticket ownership)
`auxi/src/screens/see-this-on-me/GeneratingView.tsx:51` currently fails `tsc` (`accessibilityLabel` not a `PillButtonProps`). This is AU-358's working-tree change and is RED on the umbrella verification gate right now. I left it untouched per scope rules. Either AU-358 drops the prop or `PillButton` gains `accessibilityLabel` support.

## Open questions
- Should the reuse-confirm screen also surface the saved body **shape** label (not just the photo) so the user confirms shape too? Current UAC reads "confirm the photo / retake the steps" — I scoped to photo + proceed-to-generate (shape rides along from the profile). Defer to CEO/tech-lead if shape should be editable here.
- No direct Figma node referenced for this re-entry state in the ticket; reuse-confirm reuses existing STOM primitives + transcript style. If a dedicated Figma frame exists, qa-ui compare-mode should validate.

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Replaced the silent reuse auto-generate with a re-entry confirm screen (`StepReuseConfirm`) that shows the persisted body photo with Confirm/Retake; persistence already durable via AU-346's server profile. Added 2 analytics events + 3-locale i18n + doc updates. tsc/lint clean for all my files.
**Files changed:** `auxi/src/screens/see-this-on-me/StepReuseConfirm.tsx` (new), `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx`, `auxi/src/translations/{en-EN,fr-FR,vi-VN}.json`, `auxi/docs/analytics/mixpanel-tracking-plan.md`
**Concerns/Blockers:** Pre-existing tsc error in AU-358's `GeneratingView.tsx:51` (`accessibilityLabel` on `PillButton`) makes the umbrella tsc gate RED — NOT mine, flagged for AU-358/tech-lead. Sim visual verification not run this session.
