---
name: auxi-deploy-testflight
description: Ship a new auxi iOS build to TestFlight via Fastlane. Use when the user says "deploy", "ship build", "upload TestFlight", "build mới lên TestFlight", "release", "ship lên test flight", or asks for a new TestFlight build. Encodes the full Apple submission pipeline so we don't re-debug Xcode / fmt / icons / signing / env each time.
---

# Auxi → TestFlight deployment (Fastlane)

Project: `auxi/` submodule (RN 0.83 + TS 5.8). Backend: Railway prod at `https://wardrobe-backend-production-c8d9.up.railway.app`. Apple team `9Z32ZJK4A5`, bundle `com.auxi2026.app`.

**Single command does it all:** `cd ios && bundle exec fastlane beta`. This skill is the wrapper that runs pre-flight, invokes the lane, then post-flights.

The lane lives in `auxi/ios/fastlane/Fastfile`. It queries Apple for the latest build number, bumps locally, runs `pod install`, archives Release against the current iOS SDK, uploads via App Store Connect API key (no 2FA prompt), tags the commit locally, and writes a metadata file for the launch-notify auto-chain.

## When to use

- User says: "deploy", "ship to TestFlight", "upload build", "build mới", "release", "ship lên Apple", "đẩy lên testflight"
- User asks for a TestFlight build (no need to pass a build number — Fastlane picks the next one off Apple)
- User says "build tiếp" after PR merge

## When NOT to use

- User wants a local dev build (`yarn ios:sim`) — that's `mobile-dev` flow
- User wants App Store *public* release (not TestFlight) — different reviewer flow, ask first
- User wants to ship the *backend* — that's `wardrobe-backend` + Railway, different skill

## Pre-flight (mandatory, no shortcuts)

Run these checks in parallel, fail loud on any miss:

```bash
cd auxi
git branch --show-current                                                          # warn if not on main
git pull --ff-only                                                                 # latest main
git status --short                                                                 # clean tree

# Fastlane toolchain
test -f ios/Gemfile && echo ok-gemfile
test -f ios/fastlane/Fastfile && echo ok-fastfile
(cd ios && bundle exec fastlane --version 2>/dev/null | grep -q "^fastlane") && echo ok-fastlane \
  || echo "Fastlane not installed → cd ios && bundle install"

# App Store Connect API auth (preferred — no 2FA)
test -f ~/.appstoreconnect/private_keys/AuthKey_*.p8 && echo ok-asc-key
test -n "$ASC_API_KEY_ID" && test -n "$ASC_API_ISSUER" && echo ok-env \
  || echo "Set ASC_API_KEY_ID + ASC_API_ISSUER in ~/.zshrc (values from App Store Connect → Users and Access → Integrations → Keys)"

# Build-phase prerequisites (Fastlane wraps xcodebuild, so these still apply)
test -f src/config/env.ts && grep PROD_ROOT src/config/env.ts
test -f ios/ExportOptions.plist
grep -c "FMT_USE_CONSTEVAL" ios/Podfile                                            # must be >0
grep -c "CFBundleIconName" ios/auxi/Info.plist                                     # must be 1
test -f ios/auxi/Images.xcassets/AppIcon.appiconset/Contents.json && echo ok-icons

# Sentry creds — Bundle RN + Upload Debug Symbols build phases wrap sentry-cli.
# Without auth, archive dies ~10 min in with "Node: cannot execute binary file".
{ [ -f ios/sentry.properties ] || [ -n "$SENTRY_AUTH_TOKEN" ] \
  || grep -q "SENTRY_DISABLE_AUTO_UPLOAD=true" ios/auxi.xcodeproj/project.pbxproj; } \
  && echo ok-sentry || echo "Set SENTRY_AUTH_TOKEN, create ios/sentry.properties, or disable upload in pbxproj"
```

If any check fails → STOP, route to fix:
- Missing `ios/Gemfile` or `Fastfile` → branch is older than the Fastlane setup merge → `git pull origin main` and re-check
- Missing fastlane binary → `cd ios && bundle install` (one-time per machine)
- Missing fmt patch / icons / plist → branch is older than the TestFlight infra merge → `git pull origin main` and re-check
- Missing `env.ts` → branch is older than the env-switch merge → same fix
- Missing ASC env vars → user must add to `~/.zshrc`:
  ```bash
  export ASC_API_KEY_ID=<your-key-id>       # e.g. 10-char alphanumeric (U2JN4H9WCR)
  export ASC_API_ISSUER=<your-issuer-uuid>  # UUID at top of the Keys page
  ```
  Then `source ~/.zshrc`.
- Missing `AuthKey_*.p8` → user must download from App Store Connect → Users and Access → Integrations → Keys and place at `~/.appstoreconnect/private_keys/`

## Build number — Apple is the source of truth

Don't ask the user for a build number. The Fastlane lane calls `latest_testflight_build_number` against the ASC API and bumps automatically. Apple rejects re-uploads of the same `MARKETING_VERSION + CURRENT_PROJECT_VERSION` pair, so always defer to Fastlane's lookup. If the user explicitly demands a specific number, edit the Fastfile lane to pass `build_number: N` into `increment_build_number` and revert after.

## Ship

```bash
cd auxi/ios
bundle exec fastlane beta
```

The `beta` lane:
1. Loads ASC API key from `ASC_API_KEY_ID` / `ASC_API_ISSUER` env vars (+ `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`)
2. `pod install` via `cocoapods` action (reapplies fmt + base.h patches in Podfile post_install)
3. Queries Apple for latest build number on current `MARKETING_VERSION`
4. Bumps `CURRENT_PROJECT_VERSION` in pbxproj to `latest + 1`
5. `xcodebuild archive` (Release, app-store export method) using `ios/ExportOptions.plist`
6. Exports IPA → `auxi/ios/build/fastlane/auxi.ipa`
7. `upload_to_testflight` via API key (skip processing wait, skip submission to TestFlight review)
8. Creates annotated git tag `v<MARKETING_VERSION>-build<N>` locally (not pushed)
9. Writes `$TMPDIR/auxi-archive/release-metadata.env` for the auto-chain

**If any step fails:** read the error, route via failure table below. Fastlane prints a clean stack trace plus `fastlane/report.xml`. After a partial run where the build number was already bumped but upload failed, just re-run `bundle exec fastlane beta` — it'll re-query Apple and bump again.

## Post-flight

```bash
cd auxi
git push --follow-tags                                  # branch + the v<x.y.z>-build<N> tag

# Optional: comment on Linear AU-249 (or related ticket) with build info
# Use ~/.linear/api_key — see auxi/docs/release-checklist.md
```

Then in App Store Connect:
1. Wait 5–30 min for Apple processing email
2. Answer **Export Compliance** prompt once per `MARKETING_VERSION` (encryption: "No")
   - Add `<key>ITSAppUsesNonExemptEncryption</key><false/>` to `Info.plist` to skip permanently
3. Build appears under TestFlight tab → assign to Internal Testing group → testers get email

## Failure decision tree

| Error | Diagnosis | Action |
|---|---|---|
| `Could not find action 'cocoapods'` or `LoadError` | `bundle install` not run, or stale `vendor/bundle/` | `cd ios && bundle install` |
| `app_store_connect_api_key: missing ASC_API_KEY_ID` | env vars not exported in this shell | `source ~/.zshrc` then retry, or check `~/.zshrc` has the exports |
| `iOS 26.x is not installed` | Xcode 26 platform missing | Open Xcode → Settings → Platforms → install iOS 26 |
| `Bundle React Native exit 1` + `Node: Node: cannot execute binary file` | pbxproj build phase used backticks instead of escaped quotes | Fix the shellScript in `ios/auxi.xcodeproj/project.pbxproj` "Bundle React Native code and images" phase: `/bin/sh -c "\"$WITH_ENVIRONMENT\" \"$SENTRY_XCODE\" \"$REACT_NATIVE_XCODE\""` (escaped quotes, no backticks) |
| `An organization ID or slug is required` from sentry-cli during archive | Sentry build phase tries to upload sourcemap but creds missing | (a) set `SENTRY_AUTH_TOKEN` env, (b) create `ios/sentry.properties` with `defaults.org`/`defaults.project`/`auth.token`, or (c) ship without sourcemap: `export SENTRY_DISABLE_AUTO_UPLOAD=true` in the build phase shellScript |
| `fmt/format-inl.h:59 consteval error` | Pods got reset, patch lost | Fastlane's `cocoapods` step reapplies via Podfile post_install — if it still fails, `cd ios && rm -rf Pods && bundle exec fastlane beta` |
| `ITMS-90713 CFBundleIconName missing` | Info.plist key removed | Check `<key>CFBundleIconName</key><string>AppIcon</string>` present |
| `ITMS-90022 Missing 120×120 icon` | Asset catalog broken | 9 PNGs + Contents.json with `filename` keys in `AppIcon.appiconset/` |
| `Your team has no devices` | Apple Dev portal | Register at least one device UDID under team 9Z32ZJK4A5 |
| `upload_to_testflight` 401 | API key revoked or wrong issuer | Re-check ASC → Users and Access → Integrations → Keys; regenerate `.p8` if needed |
| Upload returns 401 in app | Wrong env URL | `src/config/env.ts` → check PROD_ROOT matches deployed Railway URL |
| API calls return 404 in app | Backend path drift | Compare `src/services/*.ts` paths vs `/api/openapi.json` on Railway |
| Apple emailed "ITMS-90809 deprecated API" | RN/iOS SDK incompatibility | Likely need RN update or specific RN package patch — investigate per ITMS code |

## Idempotence & safety

- Lane is rerunnable — Apple lookup bumps build number every time, archive dir is wiped clean
- Tag operation is `if-not-exists` — `add_git_tag` doesn't clobber existing tags (it'd fail loud)
- Upload uses API key (no interactive 2FA) — but won't burn build numbers on accidents because Fastlane re-queries Apple every run
- Pre-flight checks fail loud before any destructive action
- Old wrapper `scripts/release-testflight.sh` is **deprecated** — keep around as a fallback if Fastlane breaks, but the Fastlane lane is now the single source of truth

## Related artifacts (always reference, never duplicate)

- `auxi/ios/fastlane/Fastfile` — the `beta` + `build_only` lane definitions
- `auxi/ios/fastlane/Appfile` — bundle id + team id
- `auxi/ios/fastlane/.env.default` — env var template (real values live in `~/.zshrc`)
- `auxi/ios/Gemfile` — pins fastlane + cocoapods via Bundler
- `auxi/scripts/release-testflight.sh` — DEPRECATED legacy wrapper (xcodebuild + altool)
- `auxi/docs/release-checklist.md` — full setup + gotchas (long-form)
- `auxi/docs/journals/2026-05-10-first-testflight-upload.md` — post-mortem of the gnarly first ship
- `auxi/ios/Podfile` post_install — fmt patch lives here, do NOT edit fmt source directly
- `~/.appstoreconnect/private_keys/AuthKey_*.p8` — gitignored, never commit
- `.claude/skills/auxi-launch-notify.md` — downstream skill auto-invoked on success

## Auto-chain to launch-notify (zero-touch announcement)

After `bundle exec fastlane beta` exits 0, the Fastfile writes `$TMPDIR/auxi-archive/release-metadata.env` (path matches the legacy script for backward compatibility) containing:

```
BUILD_NUMBER=5
MARKETING_VERSION=1.0
TAG=v1.0-build5
COMMIT_SHA=08142d2
BRANCH=main
```

Note: `DELIVERY_UUID` is no longer written (Fastlane's `upload_to_testflight` doesn't expose it). `auxi-launch-notify` should look it up from ASC API if needed, or skip the per-delivery link.

Immediately invoke the `auxi-launch-notify` skill so it can post the announcement artifacts (GitHub Release, Linear comment, CHANGELOG.md). Pass the metadata file path:

```bash
ARCHIVE_DIR="${TMPDIR:-/tmp}/auxi-archive"
META_FILE="$ARCHIVE_DIR/release-metadata.env"
if [ -s "$META_FILE" ]; then
  set -a; source "$META_FILE"; set +a
  # Invoke auxi-launch-notify (Claude reads the skill spec and executes)
fi
```

**Fail-soft contract**: launch-notify failure does NOT undo the upload. The IPA is already on Apple's side. If a surface fails:
- User gets a summary listing which surfaces succeeded vs failed (with URLs for success, error message for failure)
- User can re-run launch-notify with `SKIP_<SURFACE>=1` for the ones that already succeeded
- Worst case: skip launch-notify entirely and announce manually

If `$META_FILE` is missing or empty (e.g., lane crashed before writing it), DO NOT auto-chain — surface the issue to the user instead.

## Trigger workflow summary

1. User says one of the trigger phrases
2. Run pre-flight checks (parallel where possible) — fail loud
3. `cd auxi/ios && bundle exec fastlane beta`
4. After upload success, `cd auxi && git push --follow-tags`
5. **Source `$META_FILE` and invoke `auxi-launch-notify`** (creates GH Release + Linear comment + CHANGELOG entry)
6. Tell user: Apple processing 5–30 min, check email, answer Export Compliance if first build of this version

## Anti-patterns (don't)

- Don't archive from feature branches without merging to main first (gotchas may be missing)
- Don't run `xcodebuild` or `xcrun altool` directly — Fastlane is the contract now; the legacy `scripts/release-testflight.sh` is a fallback only
- Don't pass a manual build number unless the user explicitly demands it — Apple's TestFlight history is the source of truth
- Don't skip `pod install` to "save time" — the `cocoapods` action runs first for a reason (fmt patch)
- Don't manually edit `Pods/fmt/include/fmt/base.h` — the patch lives in Podfile's post_install
- Don't commit `.p8`, `AuthKey_*`, or anything in `~/.appstoreconnect/` — gitignore covers `*.p8`
- Don't trust local `pbxproj` build number as canonical — the lane re-queries Apple every run
- Don't run `fastlane beta` from a dirty working tree — the local tag will reference an uncommitted state
