# Firebase CocoaPods static-lib install fix

**Date:** 2026-06-29
**Branch:** `fix/firebase-pods-modular-headers` (off `origin/main` @ 715bb750b)
**Commit:** 5a03c85f4 — pushed, no PR opened (handoff to requester)
**CI failure addressed:** runs 28353741041 / 28349751800, step "Install Pods"

## Root cause
PR #189 added `@react-native-firebase/app` + `/messaging` (21.x) to
`package.json`, which pull `firebase-ios-sdk` 11.x. Those bring **Swift pods**
(`FirebaseCoreInternal`, etc.) that depend on `GoogleUtilities`, which does NOT
define modules. CI runs `pod install` WITHOUT `USE_FRAMEWORKS`, so
`use_frameworks!` never activates and pods build as plain static libs. A Swift
pod can only be integrated as a static lib if its deps expose module maps →
`[!] The following Swift pods cannot yet be integrated as static libraries`.

The committed `Podfile.lock` on main did NOT contain any Firebase/RNFB pods —
PR #189 added the JS deps but never regenerated the lock, so the failure only
surfaced when CI re-resolved from `package.json`.

## Fix (TARGETED, not global)
Added one line inside `target 'auxi'` in `ios/Podfile`:

```ruby
pod 'GoogleUtilities', :modular_headers => true
```

(with a comment block explaining why). Chose **targeted modular headers on the
single flagged dependency** over `use_modular_headers!` global — KISS + minimal
blast radius. Did NOT enable `use_frameworks!` app-wide (would risk
Hermes/other-pod breakage on RN 0.83).

I first verified a broader 7-pod modular-headers block worked (102 deps), then
minimized to GoogleUtilities-only and re-verified it still passes — GoogleUtilities
was the sole blocker, so the one-liner is sufficient.

## Verification (replicated the CI static-lib path)
`cd ios && unset USE_FRAMEWORKS && pod install` — ran clean, Node 20 (nvm):

```
Pod install took 17 [s] to run
Integrating client project
Pod installation complete! There are 96 dependencies from the Podfile and 111 total pods installed.
```

- NO "cannot yet be integrated as static libraries" error (grep confirmed only
  the informational "Framework build type is static library" appears).
- Firebase chain now integrated: FirebaseCore 11.11.0, FirebaseMessaging,
  FirebaseCoreInternal, FirebaseInstallations, GoogleDataTransport,
  RNFBApp 21.14.0, RNFBMessaging 21.14.0.

## fmt post_install patch — PRESERVED
- `ios/Pods/fmt/include/fmt/base.h` has the `#ifndef FMT_USE_CONSTEVAL` guard
  (1 match). The patch line only prints on first apply (idempotent guard).
- `FMT_USE_CONSTEVAL=0` present in Pods build settings (2 matches: debug+release).

## Podfile.lock changed? YES
`ios/Podfile.lock` +101/-2 — records RNFBApp/RNFBMessaging + full Firebase chain.
COCOAPODS pinned 1.16.2 (unchanged).

## Global vs targeted
**Targeted** — `pod 'GoogleUtilities', :modular_headers => true`.

## NOT committed (deliberate, scope) — needs requester decision
`pod install` also touched two files I reverted to keep the commit to the two
files you asked for:

1. **`ios/auxi.xcodeproj/project.pbxproj`** — pod install adds a REQUIRED
   `[CP-User] [RNFB] Core Configuration` build phase (RNFirebase injects
   firebase.json into Info.plist). This is legitimate and the **app will need it
   to function**, but it's PR #189's concern (PR #189 never committed it either,
   same as the stale lock). **Recommend** committing it as part of #189's
   completion or folding it into this fix branch before merge — otherwise the
   next local pod install will re-dirty it and the runtime config phase is
   absent from the checked-in app.
2. **`ios/auxi/PrivacyInfo.xcprivacy`** — pure key-reorder noise from
   CocoaPods' privacy-manifest aggregation. No semantic change; left out.

## Concurrency
Only `pod install` was run (isolated worktree). No native rebuild, no Metro /
Simulator / watchman / yarn ios:clean touched.

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Fixed the Firebase static-lib pod install with a targeted
`pod 'GoogleUtilities', :modular_headers => true` in `ios/Podfile`; verified
`pod install` completes clean in CI's no-USE_FRAMEWORKS mode (111 pods, no
static-lib error); fmt patch intact; Podfile + regenerated Podfile.lock
committed to `fix/firebase-pods-modular-headers` and pushed. No PR opened.
**Concerns/Blockers:** `pod install` also generates a REQUIRED RNFB build phase
in `auxi.xcodeproj/project.pbxproj` that I left OUT to honor the "commit only
Podfile + Podfile.lock" scope. The app needs it at runtime and PR #189 never
committed it. Decide whether to add it to this branch or to #189 before merging,
or the checked-in app will lack the RNFB Info.plist config phase.
