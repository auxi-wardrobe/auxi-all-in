# mobile-dev report — AU-442 ghost-snapshot fix, SeeThisOnMeScreen scoped pass

Branch: `nguyenthaihiep94/au-442-paywall` (based on `7d00825`)
File: `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx`

## What was fixed

Same fix class as `7d00825` (SettingsAboutScreen QA debug row): a screen
rendering its main content + `<UsageLimitSheet>` (via the `usageLimitSheet`
element) as Fragment (`<>...</>`) siblings, instead of nested inside one
root host view, was diverging structurally from the actual working
trigger sites (`EnhanceImageScreen`, `WardrobeScreen`). This screen has
**two separate `return` branches** — both were Fragment-wrapped and both
needed the fix.

### Branch 1 — `stepScreen` shell (line ~750, non-stepped states)

Covers profile-loading / generatingShapes / generating / preview /
limit-reached — i.e. any state where `renderStomStepScreen()` returns a
non-null element (`StepShell`/`SafeAreaView` or `StomLoadingScreen`, both
already `flex:1` single roots).

Before:
```tsx
if (stepScreen) {
  return (
    <>
      {stepScreen}
      {aiLimitSheet}
      {usageLimitSheet}
      <DiscardGenerationDialog ... />
    </>
  );
}
```
After: wrapped in `<View style={styles.root}>` (`root: { flex: 1 }`),
matching `7d00825`'s pattern exactly.

### Branch 2 — active capture step (line ~861, selfie/fullBody/bodyShape)

Renders `<StomStepLayout>` (a `SafeAreaView` with `flex:1` at its own
root — confirmed by reading `StomStepLayout.tsx:49,79-82`) plus
`PhotoSourceSheet`, `AiConsentDialog`, `aiLimitSheet`, `usageLimitSheet`
as Fragment siblings. Same wrap applied.

Single shared `StyleSheet.create({ root: { flex: 1 } })` added at the
bottom of the file (only one `styles` object — both branches reference
the same `styles.root`, no duplication).

### Why safe (layout-preservation check)

Both wrapped subtrees already had exactly one flex:1 child at the very
top (`StepShell`/`SafeAreaView` in `StomStepScreen.tsx:84`,
`StomStepLayout`'s own `SafeAreaView` at `StomStepLayout.tsx:49`), so
adding an outer `<View style={{flex:1}}>` is transparent to layout — no
absolute-positioning or sibling-height dependency existed on the Fragment
shape. Confirmed by reading `StomStepScreen.tsx` and
`StomStepLayout.tsx` fully before editing (not just the screen file).

## What was explicitly NOT touched

- No change to conditional logic, step ordering, safe-area handling, or
  any handler.
- No change to `renderStomStepScreen` / `StomStepLayout` internals — only
  the two outer Fragment→View wraps in `SeeThisOnMeScreen.tsx`.

## Verification

- `npx tsc --noEmit` — 3 pre-existing errors remain (`components.tsx`,
  `StomStepLayout.tsx` — missing `poppinsTimeLg`/`poppinsBodySm`
  typography aliases), confirmed present BEFORE this change via
  `git stash` + re-run. None in the file I edited. Baseline unaffected.
- `yarn lint` — `npx eslint src/screens/see-this-on-me/SeeThisOnMeScreen.tsx`
  standalone → clean, 0 output. Full `yarn lint` shows the pre-existing
  baseline (web/ stub errors + inline-style warnings), none in this file.
- `./scripts/auxi-lint-tokens.sh` — 13 pre-existing violations elsewhere
  (`BodyPhotoGrid.tsx`, `BodyTryOnView.tsx`, `ItemPickerPanel.styles.ts`,
  `LanguageSettingsScreen.tsx`, `HomeScreen/styles.ts`,
  `ContextChipsModal.tsx`, `PinGenerationError.tsx`) — none in
  `SeeThisOnMeScreen.tsx`. Clean re: this change.
- No existing test file targets `SeeThisOnMeScreen.tsx` (only
  `__tests__/SeeThisOnMeConfirmScreen.test.tsx` exists, a different
  screen — nothing to re-run).
- No sim/tap tools this session — **code-complete only, visual
  verification pending qa-mobile.**

## Fastest real-flow trigger path for qa-mobile

The sheet only fires after `try_on_completed` when
`maybeShowUsageLimit('see_on_me', user)` resolves truthy (usage count
reaches the free-tier limit — check `auxi/src/services/usageLimit.ts` for
the exact threshold, referenced in the task as `used >= 2`). Two options,
fastest first:

1. **Debug reachability aid (already shipped, `__DEV__`-gated)** —
   `SettingsAboutScreen.tsx` has a QA debug row (from `625c895`/`7d00825`)
   that opens `UsageLimitSheet` directly with `usageLimitPreview` props,
   without needing to run the real generation flow twice. This is the
   FASTEST path to see the sheet itself and its ghost-snapshot behavior
   in isolation, but it does not exercise the real
   `SeeThisOnMeScreen` → `NotifyMeScreen` transition this fix targets.
2. **Real trigger, 2x See-on-me completions** — run the See-on-me flow to
   a successful `try_on_completed` twice against the real backend (same
   outfit or different, whichever `maybeShowUsageLimit` keys off — check
   `usageLimit.ts` for whether it's per-outfit or per-user-global). On
   the 2nd completion the sheet should appear over the `preview` step
   screen (Branch 1 above). This is the path that actually proves the
   fix for THIS screen, since it's the one with the two-return-branch
   structure the debug row doesn't reach.
3. If there's a test account with a pre-seeded `see_on_me` usage counter
   at the limit, or a debug backend override to force
   `limit_reached: true` for a given user, that would be fastest for
   *this* screen specifically — I don't have visibility into whether such
   an override exists server-side; flag to backend-dev/qa-mobile if
   speeding this up matters.

## Unresolved questions

- Whether `maybeShowUsageLimit` counts per-outfit or account-wide (affects
  whether qa-mobile needs 2 different outfits or can reuse one) — not
  verified this pass, out of scope for the structural fix; check
  `auxi/src/services/usageLimit.ts` directly.
- Whether a backend/test-account override exists to force
  `limit_reached: true` without spending 2 real AI generations — flagging
  for qa-mobile/backend-dev, not something I can answer from `auxi/`.

**Status:** DONE
