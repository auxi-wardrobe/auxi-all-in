# AU-442 ghost/duplicate snapshot — round 2 root-cause investigation

**Scope**: code-reading only, no simulator access this session. Cannot verify
the fix live — handing back to qa-mobile for the same repro steps.

## What I checked (in order, per the task's diagnostic branch)

1. Re-read `SettingsAboutScreen.tsx` debug row vs the 3 real trigger sites
   (`EnhanceImageScreen.tsx`, `WardrobeScreen.tsx` via `useAddWardrobeItem.ts`,
   `SeeThisOnMeScreen.tsx`).
2. Read `MBottomSheet.tsx` (`mounted`/`useOverlayProgress.ts`) — confirmed the
   sheet's scrim `View` fully unmounts (`return null`) once its close
   animation's `Animated.timing(...).start(() => setMounted(false))` callback
   fires. No residual native view kept alive past that point at the React
   level.
3. Read `NotifyMeScreen.tsx` end to end — no self-referencing preview/thumbnail,
   no nested small-card component. Its own render is a plain
   `SafeAreaView > Header + ScrollView(hero, feature grid, CTA)`.
4. Read `AppNavigator.tsx`'s `NotifyMe` registration + surrounding
   `screenOptions` — no `freezeOnBlur`, no custom `cardStyleInterpolator`,
   `gestureEnabled` left at native-stack's default (`true`, i.e. interactive
   swipe-back is enabled, same as most pushed screens including `Upgrade`).
5. Read `MButton.tsx` / `PressScale` (`MMotion.tsx`) — single `Pressable`,
   single `onPress` wire-up, no double-fire path found.

## Finding: the debug row's structural divergence is real — confirmed, fixed

**`SettingsAboutScreen.tsx`'s old return was:**

```tsx
return (
  <>
    <SettingsScreenScaffold>...</SettingsScreenScaffold>
    {__DEV__ && <UsageLimitSheet ... />}
  </>
);
```

That's a top-level `<>` Fragment with **two sibling host views** — the
scaffold's own `SafeAreaView` and (while the sheet is open or mid-close-
animation) `MBottomSheet`'s absolute-fill `scrim` `View` — both direct
children of whatever native-stack hands this screen's `component` render
output. This is a genuine divergence from:

- **`EnhanceImageScreen.tsx`** — single root `<View style={styles.container}>`
  with `<UsageLimitSheet>` nested INSIDE it as the last child (line 552-556).
- **`WardrobeScreen.tsx`** — single root `<SafeAreaView>` with
  `<UsageLimitSheet {...usageLimitSheetProps} />` nested inside it (line 715).

**Fixed** — `SettingsAboutScreen.tsx` now wraps both the scaffold and the
`__DEV__` sheet in one root `<View style={styles.root}>` (`flex:1`), matching
the single-root-nesting shape those two real sites use. `src/screens/settings/SettingsAboutScreen.tsx:1-2,53-54,109-135`.

## Important caveat found during the audit — do not treat as fully closed

**`SeeThisOnMeScreen.tsx` (a REAL production trigger site, not debug-only)
uses the SAME Fragment-sibling pattern** the task suspected was debug-row-only:

```tsx
// see-this-on-me/SeeThisOnMeScreen.tsx:751-763 and :861+
return (
  <>
    {stepScreen}
    {aiLimitSheet}
    {usageLimitSheet}
    <DiscardGenerationDialog ... />
  </>
);
```

So the premise "the 3 real call sites mount the sheet inside their own render
tree, not as a Fragment-wrapped sibling" is only **2 of 3 true** — I verified
`EnhanceImageScreen` and `WardrobeScreen` do single-root nesting, but
`SeeThisOnMeScreen` does not. I did **not** touch `SeeThisOnMeScreen.tsx` in
this pass:

- It's a large, two-branch-return screen (line ~751 and ~861), each ending in
  a different root wrapper (`stepScreen`'s own component vs `StomStepLayout`).
  Restructuring it to single-root safely needs its own scoped pass + real
  device verification, which is out of reach this session (no simulator).
- Its usage-limit sheet is reached from a genuine free-tier 429, which is hard
  to trigger manually — exactly why the debug row exists — so if the
  Fragment-sibling shape IS contributing to the ghost snapshot, this path is
  currently un-QA'd and carries the same latent risk in production.

**I could not conclusively prove via code reading alone that the Fragment-
sibling shape is the actual native-level mechanism causing the ghost** (I
could not find MBottomSheet/react-native-screens source access — `node_modules`
is blocked in this sandbox — to confirm exactly how `react-native-screens`
4.23.0's push-transition snapshot machinery treats a screen with 2 top-level
host children vs 1). What I *can* say with certainty from code reading:

- The debug row was the ONE call site that visibly diverged from the majority
  single-root pattern AND was the only one flagged as broken so far.
- The fix removes that divergence with no behavior change (same props, same
  conditional render, same handlers) — it's a pure structural/layout fix,
  low risk, `flex:1` wrapper doesn't affect `SettingsScreenScaffold`'s own
  `flex:1` SafeAreaView.
- If qa-mobile still repros the ghost after this fix, the next most likely
  candidate (given the ghost mirrors `NotifyMeScreen`'s own content, not the
  previous screen's) is a `react-native-screens`/`UINavigationController`
  push-transition snapshot artifact independent of app code — worth testing
  whether the same repro occurs when reaching `NotifyMe` from a REAL trigger
  site (`EnhanceImageScreen`, forcing a real `enhance_photo` limit) to isolate
  whether it's debug-row-specific at all, and whether `SeeThisOnMeScreen`'s
  Fragment shape needs the same fix.

## Changes made

- `auxi/src/screens/settings/SettingsAboutScreen.tsx` — single-root `<View>`
  wrapper replaces the top-level `<>` Fragment; `UsageLimitSheet` now nests
  inside that view instead of sitting as a Fragment sibling. Doc comment
  updated to record the reasoning so it doesn't regress.

## Verification run

- `npx tsc --noEmit` — clean except 3 PRE-EXISTING errors in
  `see-this-on-me/components.tsx` and `see-this-on-me/StomStepLayout.tsx`
  (`poppinsTimeLg`/`poppinsBodySm` missing typography alias) — untouched
  files, confirmed via `git status` these are not from my edit.
- `yarn lint` — 2 pre-existing errors in `web/mocks/handlers.ts` and
  `web/stubs/toast.tsx` (unrelated web-preview stub files), 24 warnings —
  none in `SettingsAboutScreen.tsx`.
- `./scripts/auxi-lint-tokens.sh` — 13 pre-existing violations elsewhere
  (`body/`, `canvas/`, `HomeScreen/`, `ContextChipsModal.tsx`,
  `PinGenerationError.tsx`) — none in `SettingsAboutScreen.tsx`.
- Simulator verification: **NOT performed** — no mobile-mcp tools available
  to this agent. Code complete, visual verification pending qa-mobile.

## Handoff

qa-mobile: re-run the exact repro (Settings → About → "Preview usage limit
sheet (QA)" → Upgrade to Macgie+ → inspect top-left corner of NotifyMeScreen
for several seconds, same as the round-2 report). If it still reproduces,
the debug row's Fragment shape was not the (sole) cause — please also try
reaching `NotifyMe` from a real trigger site (e.g. force an `enhance_photo`
limit via `EnhanceImageScreen`) to tell us whether this is native-stack-level
(independent of app code) or specific to `SeeThisOnMeScreen`'s matching
Fragment-sibling shape.

## Unresolved questions

- Is the ghost snapshot mechanism inside `react-native-screens` 4.23.0's push
  transition (iOS 26.5 specifically) — i.e. could this be an OS/library
  compatibility issue unrelated to any app-level render shape? Not
  verifiable without simulator + native log access.
- Does `SeeThisOnMeScreen.tsx`'s identical Fragment-sibling pattern need the
  same single-root fix? Flagged, not yet fixed — needs its own scoped pass
  with real-device verification given the screen's complexity (two return
  branches, `StomStepLayout` wrapper).
