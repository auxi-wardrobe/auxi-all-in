# devops — auxi-mobile TestFlight attempt 3 (push notifications)

- Date: 2026-06-29
- Run: **28356347961** — https://github.com/auxi-wardrobe/auxi-mobile/actions/runs/28356347961
- Repo/branch: auxi-wardrobe/auxi-mobile @ `main`, headSha `dec2cd496` (correct HEAD)
- Trigger: manual `gh workflow run auxi-testflight-beta.yml --ref main` (active gh account `0xduc98`, has repo+workflow scopes; dispatch only, no git push)
- Final CI status: **failure** at step `Build & upload to TestFlight (fastlane beta)`
- Build number computed: **36** (from LATEST_TESTFLIGHT 35)

## Result vs the two previously-failing points — BOTH FIXED

| fastlane action | result | meaning |
|---|---|---|
| `cocoapods` (pod install) | **success, 70s** | attempt-1 Firebase static-lib pod failure (fixed by #190) — VERIFIED clears |
| `build_app` archive compile | reached **signing** at 53s, **no `Module 'FirebaseCore' not found`** | attempt-2 module/plist-ref failure (fixed by #191) — VERIFIED clears; the Firebase compile + GoogleService-Info ref now build |
| `build_app` signing | **FAILED** | new blocker, below |

Progression proves both regressions are gone: prior builds died at pod install (attempt 1) and at the Release compile with module errors (attempt 2). This build cleared pods, compiled the archive, and only failed when Xcode tried to resolve a provisioning profile.

## The blocker — Apple-portal capability (ESCALATE, not retried)

```
ios/auxi.xcodeproj: error: No profiles for 'com.auxi2026.app' were found:
Xcode couldn't find any iOS App Development provisioning profiles matching 'com.auxi2026.app'.
(in target 'auxi' from project 'auxi')
```
Fastlane: `Lane beta failed: Error building the application` (Fastfile line 73, `build_app`).

xcargs used (correct — signing flags only on xcargs, no `export_xcargs` duplication):
`-allowProvisioningUpdates -authenticationKeyPath <p8> -authenticationKeyID *** -authenticationKeyIssuerID ***`

### Root cause
Cloud signing (`-allowProvisioningUpdates`) auto-creates/updates a provisioning profile only for capabilities that are enabled on the App ID. The built commit's entitlements (`ios/auxi/auxi.entitlements`, verified at `dec2cd496`) now declare:
- `aps-environment = development`  ← **NEW** (Push Notifications)
- `com.apple.developer.applesignin = [Default]`  ← unchanged (SIWA, already signed fine on builds 27–35)

SIWA was already on the App ID, so the only new requirement is **Push Notifications**. The App ID `com.auxi2026.app` does not have Push Notifications enabled, so ASC cannot generate a profile that satisfies the `aps-environment` entitlement → "No profiles ... were found". A blind re-run will fail identically — nothing on the Apple side changed.

### Required human action (Apple Developer portal)
Apple Developer → Certificates, Identifiers & Profiles → **Identifiers → `com.auxi2026.app`** → enable **Push Notifications** → Save. Then re-run the workflow (build number will auto-advance to 36+).

## aps-environment finding (for the worker's prod APNs)
- Source entitlement value is `development`. No IPA was produced, so the embedded/exported value is **unverified**.
- For an `app-store`/TestFlight export, Xcode normally promotes the distribution profile's `aps-environment` to `production`, but the source file saying `development` is a risk worth confirming. Once a build is produced, confirm the exported IPA carries `aps-environment=production` (the push worker sends via prod APNs). If it ships as `development`, TestFlight push delivery will fail — that would be an entitlements (app-code) change for **mobile-dev**, not ops.

## Side effects of the failure
- No IPA, no TestFlight upload. `Push release tag` skipped. No Slack message, no GitHub Release (both fire only on success).
- `Upload IPA artifact` step ran (always-on) but no real binary was produced.
- No build number 36 was consumed on TestFlight (build_app never finished), so the next successful run will take 36.

## Status
**Status:** BLOCKED
**Summary:** Attempt 3 (run 28356347961, main `dec2cd496`) cleared both prior failures — CocoaPods (70s) and the Release archive compile (no Firebase module errors, reached signing) — then died at provisioning: `-allowProvisioningUpdates` can't make a profile for `com.auxi2026.app` because the new `aps-environment` entitlement requires the Push Notifications capability, which is not enabled on the App ID.
**Concerns/Blockers:** (1) Apple-portal: enable Push Notifications on App ID `com.auxi2026.app`, then re-run — did not retry per instructions. (2) Source `aps-environment=development`; confirm exported IPA promotes to `production` for the push worker's TestFlight sends (mobile-dev if not).
