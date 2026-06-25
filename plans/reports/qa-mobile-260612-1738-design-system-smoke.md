# QA-Mobile — Design System Screen Smoke (BLOCKED)

**Status:** BLOCKED
**Date:** 2026-06-12 17:4x
**Device:** iOS Simulator — iPhone 16 Pro, iOS 18.1 (9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916)
**App:** com.auxi2026.app (installed, Debug build, built Jun 12 00:19)
**Lane:** mobile-mcp exploratory verify (WDA :8100 confirmed, tap injection works)
**Target:** `__DEV__`-gated Design System reference screen (route `DesignSystem`)

## TL;DR

Could NOT reach the Design System screen. The entry point (Settings →
"Version 0.0.1" row, testID `settings-version-devmenu`) is **not present in
the JS bundle the app is running**. Root cause is an environment / worktree
mismatch, not a product bug and not a tap-targeting issue. No app crash.

## What worked (got me to the door)

1. App already logged in, landed on Wardrobe/Home grid.
2. Opened sidebar via header hamburger.
3. Tapped "Setting" → reached the Settings screen cleanly.
4. Confirmed the "Version 0.0.1" row is present at the bottom of Settings.

## The block (concrete evidence)

Tapping the "Version 0.0.1" row does nothing — no navigation, no multi-tap
counter. `list_elements_on_screen` on Settings reports the row as a plain
**`StaticText`** ("Version 0.0.1", x=27 y=571 w=348 h=24) with **no**
`settings-version-devmenu` testID and **no** TouchableOpacity wrapper. That
is the inert prod-branch `<View>`, i.e. the `__DEV__ ? <Touchable> : <View>`
gate evaluated to the non-dev branch in the loaded bundle.

Source IS correct in this checkout:
- `auxi/src/screens/SettingsScreen.tsx:596-606` — `__DEV__` TouchableOpacity,
  testID `settings-version-devmenu`, `onPress → navigation.navigate('DesignSystem')`.
- `auxi/src/navigation/AppNavigator.tsx:111-114` — `DesignSystem` route registered.
- `auxi/src/types/navigation.ts:123` — `DesignSystem: undefined` in param list.
- `auxi/src/screens/DesignSystemScreen.tsx` — present (created Jun 12 17:00).

But the **live Metro bundle does not contain this code**:
```
curl 'http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false'
  → grep -c 'settings-version-devmenu'  = 0
  → grep -c 'DesignSystemScreen'        = 0
```

### Why: Metro is serving the WRONG worktree

Running packager (PID 30271):
```
node /Users/nguyenminhduc/dev/auxi-favourite-wt/node_modules/.bin/react-native start --reset-cache
```
- Metro root = `/Users/nguyenminhduc/dev/auxi-favourite-wt`
  branch `feat/au226-favourite-and-see-this-on-me`
  → has NO `DesignSystemScreen.tsx`, 0 `settings-version-devmenu`.
- Design System work lives in `/Users/nguyenminhduc/dev/wardrobe_project/auxi`
  branch `feature/au318-mood-feedback` (DS files present, but **uncommitted**:
  `DesignSystemScreen.tsx` untracked; `SettingsScreen.tsx`, `AppNavigator.tsx`,
  `navigation.ts` modified-not-committed).

The installed Debug binary loads JS from Metro (no embedded `main.jsbundle`),
and Metro is pointed at the favourite worktree, so the app simply never has
the DS screen or its entry point in scope. `__DEV__` is true, but the dev
branch can't render code that isn't in the bundle.

## Crash check

`mobile_list_crashes` → no `auxi`/`com.auxi2026.app` entries. Only unrelated
system crashes (`searchd`, `Cursor Helper`, `IDECacheDeleteAppExtension`).
App did not crash or red-box.

## Spot-check (Settings toggles) — partial, color NOT verifiable

Confirmed toggle STATE via element tree on Settings:
- `settings-daily-toggle` value=1 (Daily reminder ON)
- `settings-analytics-consent-toggle` value=1 (ON)
- `settings-dark-mode-toggle` value=0 (OFF)

Teal-vs-green active-track color: the ON tracks render greenish-teal in the
screenshot, but mobile-mcp screenshots are not reliable for a #16a085 vs green
hex call (that's a qa-ui Figma/color lane judgement, and this build predates
the DS color work anyway). **Could not validate the DS Components-section
switch color** because the DS screen was unreachable. Defer the teal-track
confirmation to a build that includes the DS work.

## To unblock (for dev/devops — NOT actioned by me)

Pick one, then re-dispatch this smoke:
1. Point Metro at the checkout with the DS work: stop PID 30271 and run
   `react-native start --reset-cache` from
   `/Users/nguyenminhduc/dev/wardrobe_project/auxi`, then reload the app; OR
2. Commit/stash the DS changes onto the favourite worktree branch (or merge),
   so the currently-serving Metro root contains them; OR
3. Rebuild + install a Debug binary from the `feature/au318-mood-feedback`
   checkout and run its Metro.

I did NOT rebuild, re-point Metro, commit, or move files (out of QA scope).

## Screenshots

- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/qa-findings/screenshots/2026-06-12/qa-mobile-ds-smoke-blocked-settings.png`
  — Settings screen showing the inert "Version 0.0.1" row (no devmenu).

(No DS-section screenshots: Hero / Color / Typography / Space & form /
Components / Principles were all unreachable — nothing to capture.)

## Unresolved questions

- Is the favourite worktree's Metro intentional, or should the DS smoke run
  against `feature/au318-mood-feedback`? Confirm which checkout is canonical
  for this dispatch before re-running.
- DS work is uncommitted — is that expected at smoke time, or should it land
  on a branch first so Maestro/qa-ui can reference a stable build?
