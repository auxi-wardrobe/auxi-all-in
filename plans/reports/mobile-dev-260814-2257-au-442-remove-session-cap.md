# mobile-dev — AU-442 remove per-session paywall suppression

Branch: `nguyenthaihiep94/au-442-paywall` (auxi/), on top of `7d00825`/`2b0c000`.

## Change

Reversed the locked "once per feature per app session" decision per user
confirmation — the soft-paywall sheet now shows every time a free user hits
a usage limit (`limit_reached: true`), no session-scoped suppression.

## Files changed

- `auxi/src/services/usageLimit.ts` — removed `shownThisSession` Set, its
  guard, the `.add()` call, and the `clearUsageLimitSession()` export.
  Updated module + function doc comments to drop stale session-memory
  language.
- `auxi/src/context/AuthContext.tsx` — removed the dead
  `clearUsageLimitSession()` call + import in the logout/session-expiry
  identity-effect branch (~line 370 before removal).
- `auxi/src/services/__tests__/usageLimit.test.ts` — removed
  `clearUsageLimitSession` import/`beforeEach` call; replaced the "shows
  only once per session" test with "the same feature fires again on a
  later call — no per-session suppression"; removed the
  `clearUsageLimitSession() resets...` (logout) test; reworded two stale
  "not marked shown" comments in the false-then-true and network-fail-open
  tests (behavior itself unchanged, still valid).
- `plans/260814-1232-au-442-paywall-mvp/plan.md` — "Key decisions locked"
  item 5 updated to show the reversal with a strikethrough + date note.

## Verified untouched (per task instructions)

- `SeeThisOnMeScreen.tsx` (~325-338) — `resolvedHashRef`/`key` dedup guard
  against duplicate fires for the *same* render event: untouched, still
  needed, no stale comment referencing session semantics.
- `EnhanceImageScreen.tsx`, `useAddWardrobeItem.ts` — both call
  `maybeShowUsageLimit` fire-and-forget with no session-semantics comments;
  no changes needed.
- `SettingsAboutScreen.tsx` `__DEV__` QA debug row — calls
  `useUsageLimitGate().open()` directly, never touches
  `maybeShowUsageLimit`/session state; no changes needed.

## Verification

- `npx tsc --noEmit` — 3 pre-existing errors in
  `see-this-on-me/components.tsx:259,281` and `StomStepLayout.tsx:95`
  (`poppinsTimeLg`/`poppinsBodySm` missing from theme font type), confirmed
  identical via `git stash` baseline — unrelated to this change.
- `yarn lint` — 26 problems (2 errors / 24 warnings), identical to
  `git stash` baseline. Zero issues in the 3 touched files.
- `./scripts/auxi-lint-tokens.sh` (umbrella root) — 13 pre-existing
  hex/font violations, all in unrelated files (`BodyPhotoGrid.tsx`,
  `BodyTryOnView.tsx`, `ItemPickerPanel.styles.ts`, `HomeScreen/styles.ts`,
  `ContextChipsModal.tsx`, `PinGenerationError.tsx`, `LanguageSettingsScreen.tsx`),
  confirmed identical to baseline.
- `npx jest src/services/__tests__/usageLimit.test.ts` — 9/9 pass.
- `npx jest src/context/__tests__/AuthContext.checkAuth.test.tsx` — target
  file PASSes (6/6); the paired FAIL is a stray duplicate test file under
  the untracked `.claude/worktrees/au-428-pin-refine-crash/` directory
  (Haste module-naming collision), confirmed present identically on
  `git stash` baseline — not caused by this change, out of scope to fix.
- Full `npx jest`: `24 failed, 141 passed` suites / `76 failed, 1111 passed,
  1187 total` tests vs `git stash` baseline `24 failed, 141 passed` /
  `76 failed, 1112 passed, 1188 total` — delta is exactly the 1 removed
  test (logout-clears-session test), zero new failures, zero regressions.

Sim verification not applicable — this is a pure logic/service change with
no new visual surface (the sheet's own UI, tokens, and trigger call-sites
are unchanged); no Figma delta, no design-review gate needed.

## Unresolved questions

None. All 5 numbered task items completed; item 5 (trigger-site audit)
confirmed no stale assumptions elsewhere.
