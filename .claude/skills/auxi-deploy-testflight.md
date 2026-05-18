---
name: auxi-deploy-testflight
description: Ship a new auxi iOS build to TestFlight. Use when the user says "deploy", "ship build", "upload TestFlight", "build mới lên TestFlight", "release", "ship lên test flight", or asks for a TestFlight build with a specific build number. Encodes the full Apple submission pipeline so we don't re-debug Xcode 26 / fmt / icons / signing / env each time.
---

# Auxi → TestFlight deployment

Project: `auxi/` submodule (RN 0.83 + TS 5.8). Backend: Railway prod at `https://wardrobe-backend-production-c8d9.up.railway.app`. Apple team `9Z32ZJK4A5`, bundle `com.auxi2026.app`.

**Single command does it all:** `scripts/release-testflight.sh <build-number>`. This skill is the wrapper that runs pre-flight, invokes the script, then post-flights.

## When to use

- User says: "deploy", "ship to TestFlight", "upload build", "build mới", "release build N", "ship lên Apple", "đẩy lên testflight"
- User pastes a build number + asks to ship
- User says "build tiếp" after PR merge

## When NOT to use

- User wants a local dev build (`yarn ios:sim`) — that's `mobile-dev` flow
- User wants App Store *public* release (not TestFlight) — different reviewer flow, ask first
- User wants to ship the *backend* — that's `wardrobe-backend` + Railway, different skill

## Pre-flight (mandatory, no shortcuts)

Run these checks in parallel, fail loud on any miss:

```bash
cd auxi
git branch --show-current                              # warn if not on main
git pull --ff-only                                     # latest main
git status --short                                     # clean tree

# Effective build settings via xcodebuild (authoritative, vs grep on pbxproj)
xcodebuild -project ios/auxi.xcodeproj -target auxi -showBuildSettings 2>/dev/null \
  | grep -E '^\s*(MARKETING_VERSION|CURRENT_PROJECT_VERSION) =' | head -2

test -f ~/.appstoreconnect/private_keys/AuthKey_*.p8 && echo ok-asc-key
test -n "$ASC_API_KEY_ID" && test -n "$ASC_API_ISSUER" && echo ok-env \
  || echo "Set ASC_API_KEY_ID + ASC_API_ISSUER in shell rc"
test -f src/config/env.ts && grep PROD_ROOT src/config/env.ts
test -f ios/ExportOptions.plist
grep -c "FMT_USE_CONSTEVAL" ios/Podfile                                          # must be >0
grep -c "CFBundleIconName" ios/auxi/Info.plist                                   # must be 1
test -f ios/auxi/Images.xcassets/AppIcon.appiconset/Contents.json && echo ok-icons

# Sentry creds — Bundle RN + Upload Debug Symbols phases wrap sentry-cli.
# Without auth, archive dies ~10 min in with "Node: cannot execute binary file".
{ [ -f ios/sentry.properties ] || [ -n "$SENTRY_AUTH_TOKEN" ] \
  || grep -q "SENTRY_DISABLE_AUTO_UPLOAD=true" ios/auxi.xcodeproj/project.pbxproj; } \
  && echo ok-sentry || echo "Set SENTRY_AUTH_TOKEN, create ios/sentry.properties, or disable upload in pbxproj"
```

If any check fails → STOP, route to fix:
- Missing fmt patch / sandboxing / icons / plist → branch is older than the TestFlight infra merge → `git pull origin main` and re-check
- Missing `env.ts` → branch is older than the env-switch merge → same fix
- Missing ASC env vars → user must add to `~/.zshrc` (values come from App Store Connect → Users and Access → Keys):
  ```bash
  export ASC_API_KEY_ID=<your-key-id>       # e.g. 10-char alphanumeric
  export ASC_API_ISSUER=<your-issuer-uuid>  # UUID at top of the Keys page
  ```
- Missing `AuthKey_*.p8` → user must download from App Store Connect → Users and Access → Keys (same place) and place at `~/.appstoreconnect/private_keys/`

## Decide build number

```bash
# Latest build number on Apple side (source of truth)
xcrun altool --list-apps --apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_API_ISSUER" --output-format json 2>/dev/null
# OR check the local pbxproj — if user said "build 5", pass 5
```

Apple rejects re-uploads of the same `MARKETING_VERSION + CURRENT_PROJECT_VERSION` pair. Always bump. Ask user if unsure.

## Ship

```bash
scripts/release-testflight.sh <next-build-number>
```

The script:
1. Bumps `CURRENT_PROJECT_VERSION` in pbxproj
2. `pod install --silent` (reapplies fmt + base.h patches)
3. `xcodebuild archive` against iOS 26 SDK → `/tmp/auxi-archive/auxi.xcarchive`
4. `xcodebuild -exportArchive` → `auxi.ipa`
5. `xcrun altool --validate-app` — fail-fast on icon/plist/signing issues
6. Prompts `y/N` → `xcrun altool --upload-app`
7. Creates annotated git tag `v<MARKETING_VERSION>-build<N>` locally

**If validate fails:** read the error code (`ITMS-XXXXX`), route via failure table below. Do NOT re-run with same build number after a partial run — Apple may have started ingesting. Bump and retry.

## Post-flight

```bash
# Push the commit (build number bump) + tag
git push                                         # branch
git push origin v<x.y.z>-build<N>                # tag

# Optional: comment on Linear AU-249 (or related ticket) with delivery UUID
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
| `iOS 26.x is not installed` | Xcode 26 platform missing | Open Xcode → Settings → Platforms → install iOS 26 |
| `Bundle React Native exit 1` + `Node: Node: cannot execute binary file` | pbxproj build phase used backticks instead of escaped quotes — `` `$WITH_ENVIRONMENT` `` ran with-environment.sh, captured stdout, corrupted the `/bin/sh` command. | Fix the shellScript in `ios/auxi.xcodeproj/project.pbxproj` "Bundle React Native code and images" phase: `/bin/sh -c "\"$WITH_ENVIRONMENT\" \"$SENTRY_XCODE\" \"$REACT_NATIVE_XCODE\""` (escaped quotes, no backticks) |
| `An organization ID or slug is required` from sentry-cli during archive | Sentry build phase tries to upload sourcemap but creds missing | (a) set `SENTRY_AUTH_TOKEN` env, (b) create `ios/sentry.properties` with `defaults.org`/`defaults.project`/`auth.token`, or (c) ship without sourcemap: add `export SENTRY_DISABLE_AUTO_UPLOAD=true` to the build phase shellScript |
| `fmt/format-inl.h:59 consteval error` | Pods got reset, patch lost | `cd ios && pod install` — Podfile post_install reapplies the patch |
| `ITMS-90713 CFBundleIconName missing` | Info.plist key removed | Check `<key>CFBundleIconName</key><string>AppIcon</string>` present |
| `ITMS-90022 Missing 120×120 icon` | Asset catalog broken | 9 PNGs + Contents.json with `filename` keys in `AppIcon.appiconset/` |
| `Your team has no devices` | Apple Dev portal | Register at least one device UDID under team 9Z32ZJK4A5 |
| Upload returns 401 in app | Wrong env URL | `src/config/env.ts` → check PROD_ROOT matches deployed Railway URL |
| API calls return 404 in app | Backend path drift | Compare `src/services/*.ts` paths vs `/api/openapi.json` on Railway |
| Apple emailed "ITMS-90809 deprecated API" | RN/iOS SDK incompatibility | Likely need RN update or specific RN package patch — investigate per ITMS code |

## Idempotence & safety

- Script is rerunnable — bump build number each run, archive dir is wiped clean
- Tag operation is `if-not-exists` — won't clobber existing tags
- Upload requires explicit `y` from user — won't burn build numbers on accidents
- Pre-flight checks fail loud before any destructive action

## Related artifacts (always reference, never duplicate)

- `auxi/scripts/release-testflight.sh` — the executable
- `auxi/docs/release-checklist.md` — full setup + gotchas (long-form)
- `auxi/docs/journals/2026-05-10-first-testflight-upload.md` — post-mortem of the gnarly first ship
- `auxi/ios/Podfile` post_install — fmt patch lives here, do NOT edit fmt source directly
- `~/.appstoreconnect/private_keys/AuthKey_*.p8` — gitignored, never commit
- `.claude/skills/auxi-launch-notify.md` — downstream skill auto-invoked on success

## Auto-chain to launch-notify (zero-touch announcement)

After `release-testflight.sh` exits 0 with upload success, the script writes `$ARCHIVE_DIR/release-metadata.env` containing:

```
BUILD_NUMBER=3
MARKETING_VERSION=1.0
TAG=v1.0-build3
DELIVERY_UUID=e5df3f7f-...
COMMIT_SHA=08142d2
BRANCH=chore/...
```

Immediately invoke the `auxi-launch-notify` skill so it can post 3 announcement artifacts (GitHub Release, Linear comment, CHANGELOG.md). Pass the metadata file path:

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

If `$META_FILE` is missing or empty (e.g., script crashed before writing it), DO NOT auto-chain — surface the issue to the user instead.

## Trigger workflow summary

1. User says one of the trigger phrases
2. Run pre-flight checks (parallel where possible) — fail loud
3. Confirm/ask build number
4. Run script, capture logs to `/tmp/auxi-archive/`
5. If validate passes, prompt user `y/N` (the script does this)
6. After upload success, push branch + tag
7. **Source `$META_FILE` and invoke `auxi-launch-notify`** (creates GH Release + Linear comment + CHANGELOG entry)
8. Tell user: Apple processing 5–30 min, check email, answer Export Compliance if first build of this version

## Anti-patterns (don't)

- Don't archive from feature branches without merging to main first (gotchas may be missing)
- Don't skip `pod install` to "save time" — fmt patch reapplies from Podfile
- Don't `--no-verify` past validate errors — fix them, the script's pre-flight catches most
- Don't manually edit `Pods/fmt/include/fmt/base.h` — the patch lives in Podfile's post_install
- Don't commit `.p8`, `AuthKey_*`, or anything in `~/.appstoreconnect/` — gitignore covers `*.p8`
- Don't re-upload the same build number after a partial run — bump and retry
- Don't trust local `pbxproj` build number as canonical — Apple's TestFlight history is source of truth for "next build number"
