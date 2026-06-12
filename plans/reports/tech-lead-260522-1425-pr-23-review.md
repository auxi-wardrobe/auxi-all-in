# PR #23 Review — Home Grid variant layouts + reliability

**Date**: 2026-05-22 14:25
**Reviewer**: tech-lead (read-only, no edits)
**PR**: https://github.com/auxi-wardrobe/auxi-mobile/pull/23
**Branch**: `feat/home-grid-variant-layouts` -> `main`
**HEAD**: `c739ce6b` (6 commits, +1021 / -151)
**Umbrella pin**: `94d444e` already bumped to `c739ce6b`

---

## Verdict

**APPROVE WITH SUGGESTIONS** — ship as-is. No critical findings. Four minor cleanups are advisory and can land as follow-ups.

---

## Files inspected (read-only, from `origin/feat/home-grid-variant-layouts`)

- `auxi/src/screens/HomeScreen.tsx` — full (1769 LOC)
- `auxi/src/components/features/WeatherWidget.tsx` — full (85 LOC)
- `auxi/src/services/v05Api.ts` — unchanged in PR; cross-referenced for contract
- `auxi/plans/260522-0049-home-collage-view-spec/{00-index,01-spec}.md` — Collage spec
- `auxi/docs/qa-findings/2026-05-22-home-grid-view-compare.md` — driving audit
- `wardrobe-backend/blueprints/recommendation/engine_v05.py` — L4 mood handling, lines 138, 285, 560, 597, 644-687
- `wardrobe-backend/blueprints/recommendation/engine_v05_constants.py:348` — `VALID_MOODS`
- `wardrobe-backend/schemas/v05_recommendation.py:60-70` — `IntentDTO.mood` validator
- `wardrobe-backend/API_DOCUMENTATION.md` — checked for mood vocabulary

---

## Per-concern sign-off

### 1) Architecture — HomeScreen at ~1700 LOC

**Net direction: better, not worse.** PR adds 559 lines but every added section is locally cohesive (grid layout selector, OptionSheet memoization, error fallback). File is over the 200-LOC rule in `.claude/rules/development-rules.md`, but that rule was already broken pre-PR. Splitting is owed but not this PR's job.

**Discriminated-union GridLayout + pickLayout + renderLayout switch** — `HomeScreen.tsx:1016-1071, 1170-1280`
- Pattern fit: yes — three-shape union is small and finite; switching in renderLayout keeps type narrowing local and exhaustiveness obvious. Right pattern for a closed enum of layout shapes in RN.
- pickLayout normalizes sparse arrays via `filter((it): it is Item => !!it)` before counting — defends the C1 invariant.
- Minor: pickLayout returns null only when count === 0; renderLayout returns null again — fine, but if outfit lands with 0 items the sheet becomes an empty white card. Today only possible if BE returns empty items, which would fail L1. Acceptable defense.

**React.memo(OptionSheet) + per-sheet isActiveSheet boolean** — `HomeScreen.tsx:952-965, 1086-1099, 1327-1333`
- Pattern fit: yes — switching from passed-in activeSheetIndex (changes on every swipe, invalidates every sheet) to a per-instance boolean is textbook React.memo. O(N) -> O(2) re-render claim is correct.
- Prop-stability audit:
  - onItemPress, onTogglePin, onConfirm, onEditContext — `onItemPress={item => setSelectedItem(item)}` `:960` is a NEW lambda on every parent render. Same for `onConfirm={() => handleHeartTapForOutfit(outfit)}` `:962`. This defeats memo on the active+arriving pair. Inactive sheets still skip because parent doesn't re-render on a pure swipe (activeSheetIndex no longer flows into children via isActiveSheet), BUT any HomeScreen state change — heart tap, mode pill, error state — re-renders ALL OptionSheets. Net win on swipe is still real because swipe is the hot path. Future: useCallback the four handlers.
  - outfit — stable per hash via useMemo([listOutfits, pinnedItem]) `:530-536`. OK.
  - saveState — primitive, stable per sheet. OK.
  - pinnedItemId — shared primitive. Pin changes invalidate all sheets — acceptable, all tile borders depend on it.
  - totalSheets, isActiveSheet, sheetIndex — primitives. OK.
- Severity: minor. Memo is partially effective and clearly better than before; full memo wants useCallback. Advisory.

**HomeErrorState co-located in same file** — `HomeScreen.tsx:1344-1361`
- Recommend extracting HomeErrorState, HomeLoadingState `:1363-1385`, LoadingMoreIndicator `:1387-1392`, GarmentPreview `:1394-1413` into `src/components/features/`. All are pure presentational, no closure over HomeScreen state. Cuts ~70 LOC from HomeScreen.
- Severity: minor. Co-location is fine for first pass.

---

### 2) Backend contract change (H6) — `intent.mood` now ships real values

**Cross-checked**:
- Mobile mapping `HomeScreen.tsx:396-401`: safe->calm, power->confident, creative->playful
- Backend `engine_v05_constants.py:348`: `VALID_MOODS = ("calm", "confident", "playful", "low_energy", "grounded")` — full superset of mobile values
- Validator `schemas/v05_recommendation.py:60-70`: rejects out-of-vocab, accepts None
- L4 layer `engine_v05.py:644-687`: if mood is not None, applies multiplier; drops candidates with score 0 (hard filter); raises PoolInsufficientError(reason="no_outfits_after_L4_mood_filter") if all filter out

**Breaking-change risk: not breaking.** Old behavior was always-null -> L4 skipped via the `if inp.mood is not None` guard. New behavior is calm/confident/playful -> L4 applied. Engine has supported all 5 moods since V05 shipped.

**Hard-filter exposure: not reachable.** Only documented hard-filter is "low_energy + non-SAFE pair" per `:649`. Mobile never sends low_energy.

**Pool-thinning risk: intentional.** PR body flags "recommendations may shift visibly per mode" — this is the point of the mode pill. Worst case is Safe/Power/Creative now actually do something. Sanity-check in staging is valuable but NOT a merge blocker.

**Backend smoke**: Run `python test_server.py` on wardrobe-backend HEAD `e645c6f`. If the V05 fixture exercises intent.mood across calm/confident/playful, that's enough. Otherwise file a follow-up `v05-eval` ticket. Not a merge blocker — contract is valid.

**API_DOCUMENTATION.md**: V05 endpoint is documented in `docs/v05-try-another-mobile-contract.md` and the client doc `auxi/src/services/v05Api.ts:51-61` per CLAUDE.md ("the API doc is the contract"). Mood vocab is captured in v05Api.ts MOODS constant and matches backend VALID_MOODS. No doc drift.

**Minor code smell** — `HomeScreen.tsx:407`: `intent: { mood: mood as never }`. The `as never` cast is unnecessary because BuildIntent.mood is `Mood | null | undefined`. Cast was added to mute drift (commit msg notes it replaced an `as unknown as`). Cleanup: type moodMap as `Record<RecommendationMode, Mood | null>` and drop the cast. Severity: minor.

---

### 3) Latent bugs flagged but not fixed

**C3 — buildGridOutfitSheetWithPin.slice(0, 3) truncates 5+ item outfits** `HomeScreen.tsx:146`
- Today BE caps outfits at 3-4 items in production. `.slice(0, 3)` only fires when pin is foreign and outfit has 4 items — drops the last item.
- The new heroStackPlusRows layout is dead in the pin-foreign + 5+ items path because slice truncates to 4 before pickLayout runs.
- Agreed: defer. File "C3: extend buildGridOutfitSheetWithPin to preserve all items when pin foreign" ticket.

**C2 — BE hard-cap of count: 3 makes heroStackPlusRows dead in production**
- count is OUTFIT count (1..3 per response), not items per outfit — `schemas/v05_recommendation.py:84`. Hero-stack fires on >=5 ITEMS per outfit.
- V05 today produces 3-4 items per outfit (TOP + BOTTOM + SHOES +/- OUTER +/- ACCESSORY). Hero-stack is dead until recommender adds slots.
- Agreed: defer. Layout code is correct (verified via PR-body's temp-multiplex E2E). File "C2: expand V05 outfit item-count beyond 4" ticket.

---

### 4) Test plan coverage

PR-body post-merge plan is complete for happy-path. Two additions:

- **Mode-pill engine effect** — most important new test because H6 is the contract-shifting change. Maestro flow:
  1. Login as qa-test@auxi.app
  2. Tap Safe -> capture `home-tile-0-0` item ID
  3. Tap Creative -> assert at least one tile changed
  4. Repeat after pin-set to confirm pin holds across mode changes
- **C5 swipe smoothness** — visual / framerate only. Sim-eye sufficient.

**Maestro pre-merge vs post-merge**: PR body says post-merge — acceptable per CLAUDE.md verification gate (`npx tsc --noEmit` + lint baseline is the hard gate). Mode-pill flow above is a P1 follow-up owned by qa-ui (authoring) + qa-mobile (execution).

**testIDs added**: `home-sheet-counter`, `home-outfit-grid-{count}`, `home-error-state`, `home-error-retry` — follows `auxi/CLAUDE.md` naming. OK.

---

### 5) Release coordination — submodule bump granularity

5 umbrella bumps for 6 PR commits (per `git log --oneline -- auxi`):
- cb57b37 <- 95cb2aa
- 70e003e <- 7a2216e
- 662ed26 <- ca1fe0b
- 5df2475 <- 20542ef
- 94d444e <- c739ce6b
- Plus e0b7d78 orthogonal AU-242 merge bump

**Verdict: too granular for unmerged-PR commits.** Per `.claude/agents/tech-lead.md`:

> Submodule HEAD bumps in this umbrella repo are deliberate. Don't pin a submodule to an unmerged commit unless the owner explicitly asks.

Umbrella main is now pinned to an UNMERGED auxi commit (c739ce6b is on feat branch). Fresh `git submodule update` gives a detached HEAD on a feature branch.

**Recommended fix**:
1. Merge PR #23 -> auxi main
2. Re-bump umbrella to post-merge auxi main HEAD (single bump)
3. Leave the four intermediate bumps if already public; otherwise rewind

Severity: minor. Only confuses fresh clones; existing devs unaffected. Fix at next umbrella commit.

---

## Severity tally

| Severity | Count | Items |
|---|---|---|
| critical | 0 | — |
| major | 0 | — |
| minor | 4 | (a) partial React.memo due to inline lambdas; (b) extract HomeErrorState/HomeLoadingState/GarmentPreview/LoadingMoreIndicator; (c) `mood as never` cast; (d) submodule bump granularity |

Zero blockers. Sign-off green per the tech-lead.md rubric ("Sign off if zero critical findings AND every major finding is either fixed or has a documented decision").

---

## Top-3 follow-up actions

1. **mobile-dev** — File Linear tickets for C2, C3, and a small refactor PR that (i) useCallback's the four OptionSheet handlers, (ii) extracts the four presentational components out of HomeScreen, (iii) drops the `mood as never` cast by typing moodMap as `Record<RecommendationMode, Mood | null>`.
2. **qa-ui** — Author `maestro/flows/home/mode-pill-engine-effect.yaml` proving the H6 fix produces visibly different recommendations across Safe/Power/Creative. Only behavior-change verification missing from PR plan.
3. **tech-lead / PR author** — After PR #23 merges, do ONE corrective umbrella submodule bump to post-merge auxi main HEAD. Note granularity convention in the umbrella chore commit message for future reference.

---

## Unresolved questions

1. Does `python test_server.py` exercise intent.mood across calm/confident/playful with a non-trivial wardrobe? If not, low-priority v05-eval run is owed. Not a merge blocker.
2. Should the four intermediate umbrella bumps be rewound or left? Depends on whether anyone has pulled umbrella between them. Defer to PR author / user.

---

**Status**: DONE
**Summary**: APPROVE WITH SUGGESTIONS. PR #23 is contract-clean, architecturally sound, and the C1/C4/C5/H6 fixes match stated intent. Zero critical / zero major findings. Four minor follow-ups documented. Only release-process nit is intermediate umbrella bumps on an unmerged auxi branch — fixable post-merge.
