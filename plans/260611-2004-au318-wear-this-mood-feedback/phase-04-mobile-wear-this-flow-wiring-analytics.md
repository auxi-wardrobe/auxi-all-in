---
phase: 4
title: Mobile Wear-This Flow Wiring & Analytics
status: completed
priority: P2
effort: 1.5d
dependencies:
  - 1
  - 3
---

# Phase 4: Mobile Wear-This Flow Wiring & Analytics

## Overview

Wire the full flow: "Wear this" no longer saves immediately — it opens `MoodFeedbackSheet`
(policy-gated), and Done saves outfit + mood_tags atomically via the Phase 1 contract. Implements the
ticket's state machine, dismiss/error/timeout/dedup scenarios, success banners, and all 9 analytics
events. Logic lives in a new `useMoodFeedback` hook to avoid bloating the already-large HomeScreen.

## Requirements

Functional (ticket scenarios → behavior):
- **Tap "Wear this"** (`HomeScreen.tsx:2077-2087` → `handleHeartTapForOutfit` at 966-984): track `wear_this_clicked`; if `policy.should_prompt` → open sheet (`recommendation_state: idle → awaiting_mood_feedback`), do NOT save yet; else → legacy direct save (wear-only = existing outcome events, unchanged).
- **Rapid taps**: single modal instance — lock until sheet rendered/closed (`modal_state: locked_until_rendered`); no duplicate pending saves.
- **Policy**: `GET /api/v05/mood-feedback/policy` fetched once per session (cache; staleTime ∞), refetched after each successful submit. Fetch failure → default `{should_prompt: true}` (ticket: new users prompt every save) — silent fallback, no UI error.
- **Done** → `favouriteService.saveFavourite({outfit_hash, item_ids, source:'home', mood_tags})`:
  - success + `updated:false` → close sheet, `saveStateByHash[hash]='saved'`, banner **"This look is now saved to your favorites."**
  - success + `updated:true` → banner **"Mood updated for this saved look."** (already-in-favorites dedup case)
  - track `mood_feedback_submitted`, `outfit_mood_linked` (+ `negative_mood_selected` when `not_quite_me` ∈ selection)
- **Dismiss** (swipe-down/backdrop): no save, no mood stored, selections cleared, `recommendation_state → idle`, track `mood_feedback_skipped`. Re-tap "Wear this" → fresh sheet, cleared selections, no duplicate pending state.
- **Submit error**: keep sheet open, preserve chips, re-enable CTA, error text **"Unable to save your feedback. Please try again."**, track `mood_feedback_submission_failed`. Retry safe (Phase 1 upsert = idempotent).
- **Timeout** (axios timeout): stop loading, preserve state, **"Connection timed out. Please try again."**; in-flight guard prevents duplicate save attempts.
- **Chip interaction events**: `mood_feedback_opened` (sheet open), `mood_chip_selected` / `mood_chip_deselected` (with `chip_id`).

Non-functional:
- No changes to swipe/prefetch paths (`recordBrowse`, `ensureBuffer`, AU-303 two-axis logic) — zero regression surface there.
- All analytics via existing consent-gated `track()` (`src/services/analytics.ts`) — fire-and-forget.
- Services wrap `apiClient`; never axios in screens.

## Architecture

State machine (component state in hook, mirrors ticket):
```
recommendation_state: idle → awaiting_mood_feedback → accepted
mood_feedback_state:  closed → selecting → submitting → success | error(message)
```

```
useMoodFeedback (src/hooks/use-mood-feedback.ts)
  in:  { outfit, saveDirectly(outfit) }   // saveDirectly = existing legacy save path
  out: { sheetProps (visible, occasion, isSubmitting, errorMessage, onSubmit, onDismiss),
         onWearThisPress(outfit) }
  owns: policy cache (fetch once/session via moodPolicyService; refetch post-submit),
        modal lock ref, pending outfit ref, state machine, analytics calls
HomeScreen: replaces direct handleHeartTapForOutfit call with onWearThisPress;
            mounts <MoodFeedbackSheet {...sheetProps}/> as sibling of OptionSheet;
            OptionSheet closes BEFORE mood sheet opens (sequenced, no double-modal)
Banner: reuse existing success feedback mechanism; if none exists (scout: success today = button
        label flip), add minimal inline banner in HomeScreen using theme tokens (no new dependency)
```

## Related Code Files

Create:
- `auxi/src/services/moodPolicyService.ts` — `getMoodPromptPolicy(): Promise<{should_prompt: boolean; tier: string}>` via `apiClient`
- `auxi/src/hooks/use-mood-feedback.ts` — flow hook per Architecture

Modify:
- `auxi/src/services/favouriteService.ts` — `SaveFavouritePayload` + optional `mood_tags: string[]`; response type + `updated: boolean`
- `auxi/src/screens/HomeScreen.tsx` — rewire CTA (2077-2087), mount sheet, banner display, keep `saveStateByHash` semantics (966-984)

Delete: none.

## Implementation Steps

1. **Service types.** Extend `favouriteService` payload/response per Phase 1 contract (`mood_tags?`, `updated`).
2. **Policy service.** `moodPolicyService.getMoodPromptPolicy()` → `GET /api/v05/mood-feedback/policy`; caller handles fallback default `{should_prompt: true, tier: 'every_save'}` on any error.
3. **Hook.** Implement `useMoodFeedback`:
   - `onWearThisPress(outfit)`: track `wear_this_clicked`; if locked → no-op; if `saveStateByHash[hash]==='saved'` → still open sheet (dedup case: mood update); resolve policy (cached) → `should_prompt` ? open sheet (lock, store pending outfit, track `mood_feedback_opened`) : `saveDirectly(outfit)`.
   - `onSubmit(moodIds)`: state → submitting; `saveFavourite({...pending, mood_tags: moodIds})`; success → close + banner (per `updated`), track submitted/linked/negative events, refetch policy; failure → state error with mapped message (timeout vs generic), track `mood_feedback_submission_failed`.
   - `onDismiss()`: close, clear pending + selections, track `mood_feedback_skipped`.
   - Chip select/deselect tracking via sheet callback `onChipToggle(id, selected)` — track in hook, keep sheet dumb.
4. **HomeScreen wiring.** Replace the CTA's `onConfirm` target: close OptionSheet first, then `onWearThisPress(outfit)` (sequence: await sheet close animation ~220ms or use callback). Mount `<MoodFeedbackSheet/>`. On success set `saveStateByHash[hash]='saved'` so CTA label flips to "Saved to favourite" as today.
5. **Banner.** Show success banner text (savedBanner / moodUpdatedBanner i18n keys from Phase 3) — reuse existing pattern if found, else minimal auto-dismissing inline banner (~3s) with theme tokens + testID `mood-feedback-banner`.
6. **Verify.** `cd auxi && npx tsc --noEmit && yarn lint`; manual sim run against local backend :5001 (real HTTP — no mocks per umbrella gate); dev-mode Mixpanel console shows all 9 events across the scenario walks.

## Success Criteria

- [x] Ticket primary flow: tap → sheet (no save) → select → Done → saved + banner + CTA flips "Saved to favourite".
- [x] Dismiss flow: swipe-down/backdrop → no favorite created (verify via GET /api/favorites), `mood_feedback_skipped` tracked; re-tap opens fresh sheet.
- [x] Dedup: outfit already saved → Done → no duplicate favorite, banner "Mood updated for this saved look."
- [x] Rapid taps open exactly one sheet; no duplicate POSTs (network log).
- [x] Error path: kill backend → Done → sheet stays open, chips preserved, error copy shown, CTA re-enabled; restart backend → retry succeeds.
- [ ] Policy gate: with 15+ seeded signals (tier occasional, should_prompt=false case) → "Wear this" saves directly, no sheet. — blocked: migration unapplied — shared prod DB, followup-02
- [ ] All 9 analytics events observed in dev Mixpanel flush — wired in hook, runtime flush unobservable in RN 0.83 Metro — code-level verified
- [x] `tsc`/`lint` clean; no diffs in swipe/prefetch logic.

## Risk Assessment

- **HomeScreen regression** (2k+ line component, AU-303 swipe interplay). Mitigation: all new logic isolated in hook; CTA rewire + mount are the only screen edits; zero changes to `recordBrowse`/`ensureBuffer`.
- **Double-modal conflict with OptionSheet.** Mitigation: sequenced close→open; modal lock ref.
- **Duplicate saves from retries** (ticket High). Mitigation: in-flight guard + Phase 1 upsert idempotency.
- **Policy endpoint down → feature breaks save.** Mitigation: fallback `should_prompt:true`; save path itself unchanged on direct-save branch.
- **Banner pattern doesn't exist.** Mitigation: minimal inline banner, no new deps; qa-ui reviews in Phase 5.
