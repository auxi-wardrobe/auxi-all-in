# devops — TestFlight unblock (attempt 5): revoke CI dev certs + push capability + ship

Date: 2026-06-29 · Repo: auxi-wardrobe/auxi-mobile · Branch: main @ `35ae72092`
Team `9Z32ZJK4A5` · Bundle id `com.auxi2026.app` (resource `6MRTS37A44`) · App id `6766749757`

## Result — UNBLOCKED. Build 36 shipped to TestFlight with aps-environment=production.

The Apple Development cert **cap** was the blocker (11 certs, no headroom for
automatic signing to mint the one the archive needs). Revoking the 10 CI
throwaways fixed it: this build minted exactly 1 new cert and signed cleanly.

---

## Task 1 — Revoke CI throwaway Development certs (AUTHORIZED, done)

Method: ASC API JWT (ES256) via PyJWT, key `AuthKey_U2JN4H9WCR.p8`, env
`ASC_API_KEY_ID` / `ASC_API_ISSUER`. `GET /v1/certificates` → 11 certs, **all
DEVELOPMENT, 0 DISTRIBUTION**. Revoked the 10 named "Created via API" via
`DELETE /v1/certificates/{id}` (all HTTP 204):

| id | name | expiry |
|---|---|---|
| 3A86ZQPDLB | Created via API | 2027-06-26 |
| 3AWV6BS95Y | Created via API | 2027-06-25 |
| 43C2YDB9C7 | Created via API | 2027-06-28 |
| 6434MRGLTZ | Created via API | 2027-06-27 |
| 79983U7L37 | Created via API | 2027-06-25 |
| 85GB6F7T7W | Created via API | 2027-06-25 |
| 96Y3JFWY49 | Created via API | 2027-06-24 |
| D46B98B4P2 | Created via API | 2027-06-28 |
| G6QRL7P992 | Created via API | 2027-06-29 |
| KK2K65ZVW2 | Created via API | 2027-06-25 |

**KEPT:** `JA32BAG6Z2` — named "Nam-Viet Tran" (DEVELOPMENT, exp 2027-05-06).
**Distribution certs touched:** none (0 existed).
**Count:** 11 → **1** immediately after revocation (verified via re-list).

## Task 2 — Push Notifications capability on the App ID

`GET /v1/bundleIds/6MRTS37A44?include=bundleIdCapabilities`:
**PUSH_NOTIFICATIONS already enabled** (cap id `6MRTS37A44_PUSH_NOTIFICATIONS`).
No action needed. Also present: `APPLE_ID_AUTH` (Sign In with Apple),
`IN_APP_PURCHASE`.
Status: **already-enabled.**
(Note: `?filter[identifier]=` + `&limit=` on the relationship endpoint misbehave —
direct `GET /v1/bundleIds` list and `?include=` on the resource are the reliable
reads.)

## Task 3 — Re-trigger + monitor TestFlight

- gh account switched to **ducga1998** (project guardrail account; both
  ducga1998 and 0xduc98 have admin on the repo).
- `gh workflow run auxi-testflight-beta.yml --ref main` →
  **Run 28358024450** — https://github.com/auxi-wardrobe/auxi-mobile/actions/runs/28358024450
  (SHA `35ae72092`, workflow_dispatch).
- **Conclusion: SUCCESS.** Job "beta" green incl. "Build & upload to TestFlight
  (fastlane beta)" (the step that failed on the cert cap in prior attempts).

Signing / upload evidence (from run log):
- xcargs `-allowProvisioningUpdates` + ASC API key, `signingStyle: automatic`.
- "Successfully exported and signed the ipa file"; "Successfully uploaded the new
  binary to App Store Connect"; **"Successfully finished processing the build
  1.0 - 36 for IOS"** (App 6766749757).
- **Build number: 36** (version 1.0).
- Cert re-list after build = **2** (kept "Nam-Viet Tran" + **1 new "Created via
  API"** exp 2027-06-29T08:05:54) — proves automatic signing minted exactly the
  one cert the archive needed, which the cap had been preventing.

Post-ship confirmations:
- **GitHub Release `TestFlight v1.0-build36`** exists (Latest, 08:34:46Z).
- **Slack: `>>> Slack notify ok=True`** (channel redacted) — sent.
- Minor: the "Push release tag" step reported `v1.0-build36` tag already existed
  → `tag push skipped` (non-fatal; the Release was created via API by the lane,
  IPA artifact uploaded fine). Harmless this run; see follow-up.

aps-environment verification (downloaded the `auxi-ipa` artifact, inspected the
shipped binary — not just config):
- **embedded.mobileprovision Entitlements → `aps-environment` = `production`**
- **binary codesign entitlements → `aps-environment` = `production`**
- Profile "iOS Team Store Provisioning Profile: com.auxi2026.app";
  `application-identifier` 9Z32ZJK4A5.com.auxi2026.app; `beta-reports-active` true;
  `com.apple.developer.applesignin` = Default (SIWA intact). IPA temp deleted after.

---

## SYSTEMIC NOTE (report-only, follow-up for tech-lead / mobile-dev)

CI automatic signing + `-allowProvisioningUpdates` **mints a new Apple
Development cert on every build**. The 2 visible now will creep back to the 11
cap over ~9 more builds, and the archive will fail again with the same cert-cap
error. The revocation is a band-aid, not a cure. Durable fix options:

1. **fastlane match** (recommended) — store ONE shared dev (+ dist) cert in a
   match repo / storage; CI imports it instead of minting. Eliminates churn.
2. **Imported fixed cert** — generate one dev cert + .p12, add as a repo secret,
   import in CI; drop `-allowProvisioningUpdates` for the dev cert.
3. **Pre-build stale-cert prune** — a CI step (reusing this ASC-API approach)
   that revokes "Created via API" dev certs beyond the kept named one before
   archiving. Cheapest to add, keeps the mint-per-build behaviour but caps it.

Also worth fixing in the lane: make the release-tag push idempotent (e.g.
`git tag -f` + `--force` with care, or skip-if-exists without erroring) so it
doesn't log a scary "rejected" each run.

## Unresolved questions
- None blocking. Build 36 is live + processed on TestFlight. The cert-churn
  follow-up is a tech-lead/mobile-dev decision (which durable fix), not an ops
  blocker right now.

---

**Status:** DONE
**Summary:** Revoked the 10 CI throwaway Apple Development certs (kept "Nam-Viet
Tran", 0 distribution touched; cap 11→1), confirmed Push Notifications already
enabled on com.auxi2026.app, re-triggered run 28358024450 which SUCCEEDED —
build 36 uploaded + processed on TestFlight, GitHub Release + Slack posted, and
the shipped IPA's profile + binary entitlements both carry aps-environment=production.
**Concerns/Blockers:** Cert churn will recur — CI mints a new dev cert every
build, so the cap returns in ~9 builds; recommended durable fix (match / imported
cert / pre-build prune) is a tech-lead/mobile-dev follow-up. Also a cosmetic
"release tag already exists → skipped" in the lane to make idempotent.
