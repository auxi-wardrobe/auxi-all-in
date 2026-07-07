# TestFlight Deploy — auxi-mobile main — Attempt 4

**Date:** 2026-06-29
**Repo:** auxi-wardrobe/auxi-mobile · branch `main` · HEAD `35ae72092` (PR #192, aps-environment=production)
**Outcome:** FAILED at signing — **BLOCKED on Apple Developer certificate cap** (user action required)

## Trigger
- Method: `gh workflow run auxi-testflight-beta.yml --ref main -R auxi-wardrobe/auxi-mobile` (manual workflow_dispatch)
- New run id: **28357213657**
- Run URL: https://github.com/auxi-wardrobe/auxi-mobile/actions/runs/28357213657
- gh active account: `0xduc98` (has `workflow`+`repo` scopes; dispatch only, no push)

## CI result
- Final status: **failure** (failed in ~2.5 min — fast-fail at signing, never reached upload)
- Failing step: **Build & upload to TestFlight (fastlane beta)** — failed at 08:00:24, ~24s into `xcodebuild clean archive`
- All prior steps green: checkout, setup-node, setup-ruby, Select Xcode, Cache CocoaPods, Install JS deps, Write ASC API key
- `Push release tag` skipped; no TestFlight upload; no Slack/GitHub Release

## Exact error (quoted)
```
::error file=.../ios/auxi.xcodeproj::Choose a certificate to revoke. Your account has
reached the maximum number of certificates. To create a new one, you must choose a
certificate to revoke. (in target 'auxi' from project 'auxi')

error: No profiles for 'com.auxi2026.app' were found: Xcode couldn't find any iOS App
Development provisioning profiles matching 'com.auxi2026.app'. (in target 'auxi' from
project 'auxi')

Exit status: 65
Lane beta failed: Error building the application - see the log above
```

## Root cause (confirmed via ASC API)
With automatic signing, `xcodebuild archive` signs the **archive build** with an **Apple
Development** certificate (the Distribution identity is only applied at the later `-exportArchive`
step). `-allowProvisioningUpdates` tries to mint that Development cert, but the account is at its
**Development certificate cap**, so it can't — hence both errors. The build dies here, BEFORE export.

ASC API inventory (GET /v1/certificates, key from workflow secrets):
- **DEVELOPMENT: 11** ← at cap
  - 10 × "Created via API", expiries 2027-06-24 → 2027-06-29 (one minted per recent CI attempt)
  - 1 × "Nam-Viet Tran", exp 2027-05-06 (a real developer's manual cert)
- **DISTRIBUTION: 0**

Each ephemeral CI runner's automatic signing creates a NEW Development cert and never reuses/cleans
it → they accumulated to the cap over builds 24-29. This is why attempt 3's "max certificates" error
persisted unchanged despite PR #192 — #192 fixed aps-environment for the *export* path, but the build
never gets that far.

## Is this the "distribution path" cert error from the task brief?
No. It is the **Development** cert cap (the archive build's dev signing), not the distribution path.
The brief anticipated #192 would flip the failure to the distribution path; instead the same
development-path cap from attempt 3 recurred because the cap was never cleared.

## ESCALATION — user action required (do NOT let CI fix this)
1. Go to https://developer.apple.com/account/resources/certificates/list
2. **Revoke the auto-created Apple Development certificates** — the 10 "Created via API" entries
   (exp 2027-06-24 → 2027-06-29). They are CI-generated throwaways; the next CI run mints a fresh
   one. Keep "Nam-Viet Tran" (exp 2027-05-06) if that developer still needs it locally.
   (Equivalently, revoke via Xcode → Settings → Accounts → Manage Certificates.)
3. Then re-run: `gh workflow run auxi-testflight-beta.yml --ref main -R auxi-wardrobe/auxi-mobile`

I did NOT revoke anything (per brief; cert revocation is irreversible Apple-account state).

## Caveats for the next run
- Clearing the dev-cert cap is **necessary but may not be sufficient**. The build currently dies
  before export, so PR #192's `aps-environment=production` export path and the **Push Notifications
  capability** on App ID `com.auxi2026.app` are still UNVERIFIED. The next run is the first real test
  of those. Watch for either: success, OR a NEW error of the form "doesn't support the Push
  Notifications capability" / "aps-environment not in profile" → that would then require enabling
  **Push Notifications** on the App ID in the portal (Identifiers → com.auxi2026.app → tick Push
  Notifications → Save).
- aps-environment finding: could not confirm exported IPA value — no export/IPA was produced.

## Systemic fix (recommendation — tech-lead / mobile-dev call, not done here)
The cert cap WILL recur every few builds as long as CI uses automatic signing with
`-allowProvisioningUpdates` on ephemeral runners (each mints a new dev cert). Durable fix options:
- Adopt `fastlane match` (or import a fixed cert + App Store profile) so CI reuses one stable
  signing identity instead of minting per-run, OR
- Add a cleanup step that revokes stale API-created dev certs.
This is a Fastfile/signing-architecture change (`auxi/ios/fastlane/Fastfile`, lines ~71-74 set the
`-allowProvisioningUpdates` xcargs) — flagging, not executing.

## No retry performed
Hard account-level blocker, not a transient. A retry would mint yet another dev cert and fail
identically.

---
**Status:** BLOCKED
**Summary:** Attempt 4 (run 28357213657, HEAD 35ae72092) failed at the archive signing step with
"reached the maximum number of certificates" — the Apple account is at its **Development**
certificate cap (11 dev certs, 10 CI-auto-created; 0 distribution). PR #192 is correct but the build
dies before export. User must revoke the unused "Created via API" Development certs at
developer.apple.com, then we re-run.
**Concerns/Blockers:** (1) User must revoke dev certs — I will not. (2) Push Notifications capability
+ aps-environment=production export remain unverified (build never reached export); next run may
surface a Push capability error needing a portal change. (3) Cert cap will recur without a signing
rearchitecture (match / fixed cert) — tech-lead/mobile-dev decision.
