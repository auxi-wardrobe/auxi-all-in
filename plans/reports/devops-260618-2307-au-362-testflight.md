# devops — AU-362 TestFlight beta (2026-06-18 23:07)

**Goal:** Build + ship a TestFlight beta of Auxi iOS from `main` @ `dc3324b0`
(AU-362 outfit temperature override). Gated by the Xcode 26.5 ↔ RN 0.83.1
linker-bug safeguard (verify binary linkage before any upload).

## Status: BLOCKED — Apple Program License Agreement (PLA) not accepted; export/upload cannot proceed. Build itself is HEALTHY.

Nothing reached Apple's servers or GitHub. No upload, no tag, no GitHub
Release, no Slack notify. Local build-number bump reverted. `main` clean.

---

## What ran (commands)

1. Synced to clean main:
   `git -C auxi fetch origin && git checkout main && git pull origin main`
   → HEAD `dc3324b0` (AU-362). stash@{0} left untouched.
2. `gh auth switch --user ducga1998` (active account was `0xduc98` — switched
   per guardrail so any GitHub Release would be created under the right account).
3. Node 20 (`nvm use 20`) in every fastlane shell.
4. **Verification build (no upload):** `bundle exec fastlane ios build_only`
   — compiled + `** ARCHIVE SUCCEEDED **`, then export failed (expected: lane
   has no ASC-auth export flags / no local Distribution cert). Archive used for
   binary verification below.
5. **Release attempt:** `bundle exec fastlane ios beta` with
   `ASC_API_KEY_ID=U2JN4H9WCR`, `ASC_API_ISSUER=f7c47bd9-…`, key at
   `~/.appstoreconnect/private_keys/AuthKey_U2JN4H9WCR.p8`.
   — ASC API-key auth OK, build-number resolved from Apple, archive succeeded,
   **export FAILED on PLA** (see blocker). Lane errored before upload.
6. Reverted the build-number bump (`git checkout -- ios/auxi.xcodeproj/project.pbxproj ios/auxi/Info.plist`).

## Build number

- Apple TestFlight latest for v1.0 = **build 22** (fastlane
  `latest_testflight_build_number`; matches latest git tag `v1.0-build22`).
- Lane bumped to **build 23** (`agvtool new-version -all 23`) — pbxproj
  `CURRENT_PROJECT_VERSION` 21→23, Info.plist `CFBundleVersion` 21→23.
- **Reverted** (upload failed → per instructions only commit on healthy upload).
  pbxproj/Info.plist back to 21. NOT committed, NOT pushed, no `v1.0-build23` tag.

## Safeguard — binary linkage verification: PASS

Verified the `build_only` Release archive
`~/Library/Developer/Xcode/Archives/2026-06-18/auxi 2026-06-18 23.12.33.xcarchive/Products/Applications/auxi.app/auxi`:

| Check | Broken case (DEBUG sim) | This archive (Release) |
|---|---|---|
| Executable size | ~58,272 bytes (stub) | **15,088,704 bytes** (~15 MB) ✅ |
| `nm -c RNCAsyncStorage` | 0 | 0 — *false negative, Release strips symbol table* |
| `otool -ov` ObjC classes total | ~none | **4647 classes** ✅ |
| AsyncStorage ObjC class linked | absent | `RNCAsyncStorage`, `NativeAsyncStorageSpec`, `PodsDummy_AsyncStorage`, `_TtC12AsyncStorage9RNStorage` present ✅ |
| Other native modules (strings) | — | RNSentry 73, RNGoogleSignin 19, MixpanelReactNative 6, RNKeychainManager 1, RNCAsyncStorage 2 ✅ |
| Embedded Frameworks | only hermesvm | only hermesvm — *normal*: pods are static-linked into `auxi`, Hermes is the lone dyn framework ✅ |

**Conclusion:** the Xcode 26.5 ↔ RN 0.83.1 linker bug does NOT affect the
Release archive. The native modules ARE statically linked into the 15 MB
executable. The `nm | grep -c = 0` is purely Release symbol-table stripping
(`stripSwiftSymbols` + Release default); the authoritative check is the ObjC
class metadata (`otool -ov`), which is present. The earlier-confirmed beta
archive (`23.20.18.xcarchive`) is the same Release config → same healthy link.
A crashing beta was NOT the cause of the halt — the cause is Apple-side signing.

## Blocker (exact errors) — Apple PLA / distribution signing

`beta` lane, export step (xcodebuild `-exportArchive … -allowProvisioningUpdates
-authenticationKeyPath …AuthKey_U2JN4H9WCR.p8 -authenticationKeyID U2JN4H9WCR …`):

```
** ARCHIVE SUCCEEDED **
error: exportArchive Unable to process request - PLA Update available
error: exportArchive No signing certificate "iOS Distribution" found
** EXPORT FAILED **
Exit status: 70
Lane beta failed: Error packaging up the application
```

Root cause: **"PLA Update available"** = the Apple Developer **Program License
Agreement** has a pending update that must be accepted. Until it is, Apple
rejects the cloud-managed signing request, so `-allowProvisioningUpdates`
cannot mint an iOS Distribution cert/profile → "No signing certificate iOS
Distribution found." Distribution signing worked for build22 previously, so
this is a new account-state gate, not a code/config regression.

### What's needed to unblock (human, Apple-side — NOT a secret to guess)

1. Account Holder / Admin signs in to **developer.apple.com** (and/or App Store
   Connect) as the team's Apple ID for team **9Z32ZJK4A5** and **accepts the
   updated Program License Agreement** (Account → Membership / the banner
   prompt). Possibly also the **Paid Apps / Free Apps agreement** in App Store
   Connect → Business if flagged.
2. Re-run `cd auxi/ios && bundle exec fastlane ios beta` (env as above). It will
   re-resolve to build 23, archive (already verified-healthy config), export,
   upload, tag `v1.0-build23`, and fire the GitHub Release + Slack auto-chain.
3. On a successful healthy upload: commit the pbxproj/Info.plist build-23 bump
   to `main` (conventional commit) and `git push --follow-tags`.

Credentials present and working (ASC API key authenticated fine; the failure is
purely the license agreement). No secrets missing.

## Auto-chain (GitHub Release + Slack): did NOT fire — correct

Lane errored at export, before `upload_to_testflight` / `add_git_tag` /
`write_release_metadata` / `post_testflight_release`. Verified: 0 occurrences of
those steps in the log; no fresh `release-metadata.env` (the one present is from
09:41, an unrelated run); no `v1.0-build23` tag; no GH release; no Slack post.

## State left behind
- `auxi` on `main` @ `dc3324b0`, ios working tree clean (bump reverted).
- `gh` active account switched to `ducga1998` (left as-is — correct for this project).
- stash@{0} untouched.
- Build logs: `/tmp/auxi-build_only.log`, `/tmp/auxi-beta.log`;
  xcdistribution log dir noted in beta log line ~2361.

## Unresolved questions
- Who holds Account Holder/Admin for Apple team 9Z32ZJK4A5 to accept the PLA?
  (CEO / account owner — devops cannot accept a legal agreement.)
- Is the pending agreement the Program License Agreement only, or also a
  Paid/Free Apps agreement in ASC Business? (Visible only once signed in.)

**Status:** BLOCKED — archive is healthy and linker-safe (verified), but
TestFlight export/upload is gated by an unaccepted Apple Program License
Agreement ("PLA Update available"); needs Account Holder to accept it, then re-run.
