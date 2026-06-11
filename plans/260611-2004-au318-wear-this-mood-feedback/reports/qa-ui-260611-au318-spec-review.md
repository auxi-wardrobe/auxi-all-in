# qa-ui — AU-318 Mood Feedback: Static Spec Review + Maestro Flow

- Date: 2026-06-11 · Agent: qa-ui · Mode: Maestro authoring + static spec review (no sim, no Figma — none exists for this feature; reviewed against ticket spec per plan decision)
- Spec: `plans/260611-2004-au318-wear-this-mood-feedback/linear-au318-ticket.md` + `phase-03` + `phase-04`
- Code under review (branch `feat/au318-mood-feedback`, uncommitted):
  - `auxi/src/components/features/MoodFeedbackSheet.tsx` (new)
  - `auxi/src/components/features/MoodChipGrid.tsx` (new)
  - `auxi/src/components/features/mood-chips.ts` (new)
  - `auxi/src/hooks/use-mood-feedback.ts` (new)
  - `auxi/src/services/moodPolicyService.ts` (new)
  - `auxi/src/services/favouriteService.ts` (modified)
  - `auxi/src/screens/HomeScreen.tsx` (modified, AU-318 portions)
  - `auxi/src/translations/{en-EN,vi-VN,fr-FR}.json` (modified)

## Deliverable 1 — Maestro flow

Authored: `auxi/maestro/flows/home/mood-feedback.yaml` (NOT executed — qa-mobile runs it).
README inventory updated: `auxi/maestro/README.md`.

- Happy path: ensure-home → wait `home-outfit-sheet-0-0` → tap `home-this-works-0-0` →
  `mood-feedback-sheet` visible → `mood-feedback-done` asserted `enabled: false` → tap
  `mood-chip-confident` → done `enabled: true` → tap done → `mood-feedback-banner` visible →
  sheet notVisible → CTA asserted `enabled: false` (saved-state flip, no copy assertion).
- Dismiss path: swipe LEFT to outfit 0-1 (same set, no LLM call) → reopen → done `enabled: false`
  (fresh-selections re-open scenario) → tap `mood-feedback-backdrop` → sheet notVisible → no banner →
  `home-this-works-0-1` still `enabled: true` (not saved).
- 100% `id:` selectors, no coordinates, no text matching, no screenshots. Generous
  `extendedWaitUntil` budgets reuse house timing constants (E-7/E-9).
- **Execution risk flagged in header — E-10**: `MoodFeedbackSheet` uses RN `<Modal>` (separate iOS
  UIWindow). As of the last ContextChipsModal run, modal-contents testIDs were unreachable to
  Maestro. Flow authored per spec anyway (house convention, see `refine-modal-happy-path.yaml`);
  if qa-mobile sees the sheet visually open but `mood-feedback-sheet` unreachable, the failure is
  blocked-on-E-10, not a product bug.

## Deliverable 2 — Static spec review (code vs ticket)

| # | Check | Verdict | Evidence |
|---|---|---|---|
| a | Copy verbatim vs ticket | **PASS** | en-EN `mood.*`: title "How did this outfit feel?", subtitle "This helps us understand your style and mood better.", done "Done", savedBanner "This look is now saved to your favorites.", moodUpdatedBanner "Mood updated for this saved look.", errorGeneric "Unable to save your feedback. Please try again.", errorTimeout "Connection timed out. Please try again." — all byte-identical to ticket. vi/fr complete with same key set. |
| b | Chip sets ≤8, `not_quite_me` last | **PASS** | `mood-chips.ts`: 4 context sets + default, each exactly 8, `not_quite_me` last in all; `__DEV__` assert enforces both invariants. Note: DEFAULT set drops `elevated` to fit `not_quite_me` within 8 — exactly per phase-03 architecture (ticket chip list was "Examples"). |
| c | CTA disabled-until-selection | **PASS** | `MoodFeedbackSheet.tsx:189` `disabled={selectedIds.size === 0 || isSubmitting}`; `PillButton` also hard-disables on `disabled \|\| loading` (FigmaPrimitives:111). |
| d | Both dismiss paths wired | **PASS** | Backdrop: `mood-feedback-backdrop` Pressable → `onDismiss` (blocked while submitting). Swipe-down: PanResponder, 90px distance / 0.8 velocity → `onDismiss`, snap-back otherwise. Hook `onDismiss`: no save, lock released, `mood_feedback_skipped` tracked, `recommendation_state → idle`; selections reset on next open (rising-edge effect on `visible`). |
| e | Theme tokens only in new code | **PASS** | All referenced tokens exist in `theme.ts` (figmaOverlayScrim/Surface/Divider/CardTag/ChipBg/Red/TextPrimary/TextSecondary/Action/white). `./scripts/auxi-lint-tokens.sh`: zero hits in any new AU-318 file; the two HomeScreen FONT hits (2437, 2614) are pre-existing baseline — `git diff HEAD` adds no font/hex literal. |
| f | testIDs per phase spec | **PASS** | `mood-feedback-sheet`, `mood-chip-<id>`, `mood-feedback-done`, `mood-feedback-backdrop` all present, plus `mood-feedback-banner` (HomeScreen:1736) and bonus `mood-feedback-error`. a11y labels separate from testIDs (chips use translated label + `accessibilityState`; banner `accessibilityRole="alert"`). |
| g | Chip ids == server vocab | **PASS** | 16/16 ids in `MOOD_CHIPS` byte-identical to `wardrobe-backend/blueprints/mood/mood_vocab.py` `MOOD_VOCAB`. Backend also serves both `/api/favorites` + `/api/favourites` aliases and accepts `mood_tags` / returns `updated` (routers/favorites.py:73-74,216) — client `/favourites` path safe. Policy endpoint exists (`routers/mood_feedback_policy.py:52`). |
| h | All ticket states reachable | **PASS** | Hook implements `closed → selecting → submitting → success\|error`. Error keeps sheet open, selections intact (`visible` never falls so no reset), Done re-enables; timeout vs generic mapped via `ECONNABORTED/ETIMEDOUT` — made deterministic by new 15s per-request timeout in `favouriteService` (which rethrows, so the catch path actually fires). Rapid-tap lock (`lockRef`), in-flight POST guard, policy silent-fallback `{should_prompt:true}`, post-submit policy refetch. All 9 analytics events present. |
| i | Layout overflow risk (small screens) | **PASS w/ LOW flag** | Sheet has no `maxHeight` and no ScrollView. At default font scale the stack (~handle+title+subtitle+8 wrapped chips+CTA ≈ 380–430pt) fits SE-class heights. With large Dynamic Type (chips wrap to more rows, Playfair title scales) the sheet could exceed screen height with no scroll fallback. Suggest follow-up: `maxHeight` + scroll guard. Not blocking. |

## Observations / concerns (routed, not failing)

1. **MEDIUM — in-session "mood update" scenario unreachable.** Ticket scenario "Outfit already
   exists in Favorites → submits mood feedback again → 'Mood updated for this saved look.'" can
   only trigger **cross-session**: after a successful save the CTA disables
   (`disabled={saveState === 'saved'}`, HomeScreen:2199), so the sheet can't reopen for that
   outfit in the same session even though the hook explicitly supports the dedup case (and
   phase-04 step 3 implies it should open). Cross-session it works (saveStateByHash is in-memory;
   backend upsert returns `updated:true`). Route to pm/mobile-dev: confirm intended, or make the
   saved CTA re-tappable for mood updates.
2. **LOW — contextual chip sets dormant.** HomeScreen threads the recommendation MODE
   (`safe`/`power`/`creative`) as `occasion` (HomeScreen:1063, documented in-code); none match
   `CONTEXT_CHIP_SETS` keys, so DEFAULT_CHIP_SET always renders. Ticket's "Contextual Mood
   Intelligence" is latent until real occasions flow. pm awareness.
3. **LOW — E-10 Maestro execution risk** for the new flow (see Deliverable 1).
4. **LOW — file size.** `MoodFeedbackSheet.tsx` is 252 lines (guidance ≤200); chip grid already
   extracted. Acceptable, note only.
5. **Follow-up (pre-existing, out of AU-318 scope):** `home/swipe.yaml` and
   `refine-modal-happy-path.yaml` use stale single-index testIDs (`home-outfit-sheet-0`,
   `home-this-works-1`) vs the current AU-303 cellKey format (`0-0`). Those flows need a
   maintenance pass; the new flow uses current ids.

## Verdict

**Overall: PASS** — all 9 checks pass; concerns above are routed, none block Phase 5.
Next: qa-mobile executes `auxi/maestro/flows/home/mood-feedback.yaml` (watch for E-10) + smoke
verify; pm to rule on observation #1.
