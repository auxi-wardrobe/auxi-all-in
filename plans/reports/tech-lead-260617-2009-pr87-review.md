# Tech-Lead Review — PR #87 (auxi-mobile)

**PR:** auxi-wardrobe/auxi-mobile#87 — "fix: 6 mobile bugs from Viet's 2-day Linear batch (AU-354/356/358/359/360/361)"
**Branch:** fix/viet-bugs-mobile-260617 (7 commits, 22 files in diff) · base: main
**Reviewer:** tech-lead · **Date:** 2026-06-17

## VERDICT: APPROVED + MERGED

- **Merge commit (squash):** `1b97f7def897901b14aff985e48760d070fc8e35` on `main`
- **Merged at:** 2026-06-17T13:14:35Z · branch deleted ✔
- **Formal GH approval blocked** (bot identity authored the PR — "Can not approve your own pull request"). Verdict recorded as a review COMMENT on the PR; merged per user pre-authorization.

## tsc / lint
- `npx tsc --noEmit` (Node 20.12.2): **clean, exit 0.**
- `yarn lint`: 8 problems (1 error, 7 warnings). **Identical on `main` and the PR branch** — this PR introduces **0 new lint issues**. The HomeScreen.tsx error + DatabaseScreen/usePinReducer/SignInScreen warnings are pre-existing baseline (those files are NOT in this PR). The 3 OutfitCanvasScreen inline-style warnings (lines 179/194/551) pre-date the moveLayer hunk (408-456) and exist on main too. Baseline preserved.
- NOTE: auxi/CLAUDE.md still claims baseline "4 errors in _HomeScreen.tsx + 3 warnings" — that doc line is STALE (predates home-grid/Mixpanel work). Actual current baseline = 1 error + 7 warnings. Follow-up: refresh CLAUDE.md §Verification. Non-blocking.

## Per-area findings

### Contract integrity — PASS
- Zero edits under `src/services/`. Pure mobile fixes; wardrobe-backend HTTP boundary untouched. API_DOCUMENTATION.md update N/A. No cross-repo coordination needed.

### Architecture / conventions — PASS
- **AU-358 background store** (`try-on-generation-store.ts`): module-level singleton subscribed via React 19 `useSyncExternalStore` (`use-try-on-generation.ts`). This is a built-in React primitive, NOT a new state library — Redux/Zustand/MobX prohibition respected. Clean 4-module split: store / React binding / notify-binding (idempotent) / notice. `runToken` supersession + `resolvedHashRef` dedup prevent double-fired analytics; `generation.outfit` hash-match guard prevents stale cross-outfit result leakage. Mount rehydrate path (rehydratedRef) correctly blocks the AU-346 reuse auto-fire from double-generating. Uses existing Toast + navigationRef infra (both work outside React tree). KISS/YAGNI honored; push-notification gap explicitly deferred (doc §6.7).
- Primitives-first: StepReuseConfirm uses PillButton/PromptBubble/PhotoThumb, theme tokens, testIDs on every interactive element + accessibilityLabel where icon/text.
- New theme token `figmaSnackbarSuccessBg` (#4cf4d3) lives in theme.ts (allowed — rule forbids hex in SCREENS, not in the token file). Glyph/text reuse existing tokens.
- SeeThisOnMe route already registered (types/navigation.ts:134, AppNavigator.tsx:136). New icon via svg w/ currentColor + registered in icons/index.ts.

### PillButton prop addition — PASS (additive/backward-compatible)
- `accessibilityLabel?: string` optional, threaded to AnimatedTouchable. No breaking change to existing callers.

### Fix correctness — PASS
- **AU-356:** routes on `mode` not the enumeration-safe precheck provider (anonymous callers always get 'password'); genuine dupe caught server-side at register (409 EMAIL_ALREADY_EXISTS). Correct + well-documented. Maestro regression flow added.
- **AU-360:** z-index SWAP with adjacent neighbour replaces the ±1 nudge that produced ties (invisible move). Fires event only on real move (no front/back-edge event). Correct.
- **AU-359:** overflow:hidden + figmaSurface bg scoped to ACTIVE card only (peek card stays unclipped). Correct.
- **AU-361:** preparing→ready transition detection w/ per-session dedup (readyToastedIdsRef) + light 4s poll only while focused AND items preparing (silent refetch, no skeleton flash). Sound.
- **AU-354 pt.3:** reuse-confirm gate before render; confirm/retake split. `try_on_outcome_retaken` now gated on `resultUrl` so the pre-render reuse-retake doesn't false-fire the preview-retake event. Correct.

### Analytics rule — PASS
- New events all snake_case past-tense: item_ready_toast_shown, canvas_item_layer_reordered, body_photo_reuse_confirmed, body_photo_retake_selected, body_shape_generation_backgrounded, body_shape_generation_completed_notified.
- Documented in tracking-plan §5.5 / §5.11 (new Outfit Canvas section) / §6.6 (gap) / §10 (funnels). Properties are ids/enums only (outfit_hash, direction, result, item_category?) — no PII, no raw email/url/free-text. Omit-when-unknown pattern used (item_category? conditional).

### Security / hygiene — PASS
- No secrets/PII in diff (scan clean). Commit messages conventional (fix:/feat:/chore:), no AI references.

## Blocking issues: NONE

## Merge gate
- CI `archive` check = FAILURE, but **the job never ran** — GitHub Actions BILLING failure ("recent account payments have failed or your spending limit needs to be increased"; failed in 2s). Infra, not code.
- No branch-protection required checks on this repo (private, no Pro). mergeStateStatus UNSTABLE (non-blocking, not BLOCKED); mergeable=MERGEABLE. Squash-merge succeeded WITHOUT --admin.

## Follow-ups (non-blocking)
1. **devops:** GitHub Actions billing failure is blocking the iOS archive smoke workflow account-wide. Resolve billing / spending limit so archive CI runs again. (This will affect ALL future PRs, not just #87.)
2. **mobile-dev:** testID backfill — canvas indexed item testIDs (canvas-item-0…) + selected-state suffix + canvas-surface-root; WardrobeScreen root testID. Documented as deferred in maestro/README + au360 flow. Unblocks the deferred select→reorder→assert-swap Maestro assertion.
3. **tech-lead/docs:** refresh stale lint baseline note in auxi/CLAUDE.md §Verification (now 1 error + 7 warnings, not "4 errors in _HomeScreen.tsx").
4. Umbrella submodule pin bump for auxi → 1b97f7d when ready to ship (per submodule discipline: standalone mobile fixes, no backend dependency, so order is unconstrained).
