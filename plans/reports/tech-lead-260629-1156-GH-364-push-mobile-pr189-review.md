# Tech-Lead Review — Mobile Push Notifications PR #189

- **PR:** auxi-wardrobe/auxi-mobile #189 — `feat/push-notifications-mobile`
- **Mobile worktree:** /Users/nguyenminhduc/Desktop/auxi-pushnotif
- **Backend cross-check:** /Users/nguyenminhduc/Desktop/wardrobe-backend-pushnotif (auxi-backend #119, MERGED + DEPLOYED to prod)
- **Date:** 2026-06-29
- **Verdict:** APPROVE-WITH-NITS (safe to auto-merge to TestFlight)

## True PR scope (NOT the scattered 65-file three-dot diff)
Branch is 43 commits ahead of merge-base; 35 are already-merged PRs (#173/#175/#182/#183/#184/#185/#187/#188) picked up from main drift. The real PR = the 8 `*(push)`/`docs(analytics)` commits.
`git diff origin/main..HEAD` (two-dot, true net) = **26 files / +1297 −25**, all push-related. No scope creep.

## 1. Contract correctness — PASS (exact match, 3 artifacts agree)
POST `/api/notifications/device-token`:
- Client `notificationService.ts:68-73` sends `{ token, platform, timezone, app_version }`
- Backend `schemas/notification.py:12-18` `DeviceTokenRegisterRequest` requires `token/platform/timezone` (≤512/≤64), `app_version` optional (≤32)
- `API_DOCUMENTATION.md:3030-3038` documents the same shape
DELETE `/api/notifications/device-token`:
- Client `notificationService.ts:129` `apiClient.delete(path, { data: { token } })` → axios body `{token}`
- Backend `DeviceTokenDeleteRequest{token}` (schema:38-49) — match
Path: client `/notifications/device-token` + `BASE_URL=${ROOT_URL}/api` (config/env.ts:8) → `/api/notifications/device-token` = backend prefix. PASS.
Platform: client sends `Platform.OS` (only `ios`/`android` on native) = backend `DEVICE_PLATFORMS` allowlist. PASS.
Curated deep-link screens: client `CURATED_PUSH_SCREENS` (deepLinkHandler.ts:237) == backend `CURATED_SCREENS` (schema:61) == [Home,Schedule,Favourite,Creations,Settings]. `Creations`→RN route `MyCreations` mapped correctly (deepLinkHandler.ts:246-252); all 5 routes exist in navigation.ts. PASS.

## 2. Architecture — SOUND
- Single Firebase seam: `notificationService.ts` is the only `@react-native-firebase/messaging` importer. `.web.ts` stub has identical public surface (5 exports) — RNW sandbox builds.
- Tap routing via shared `navigationRef` (AppNavigator.tsx:57) — same pattern as deep-links / try-on notice.
- Register-on-login (AuthContext.tsx:270 `registerDeviceForPush()` fire-and-forget) / unregister-on-logout (AuthContext.tsx:332 `await unregisterDevice()` BEFORE clearing tokens — correct, DELETE is Bearer-authed).
- Listener lifecycle: `registerPushTapHandlers` + `registerTokenRefreshListener` mounted once in AppNavigator `useEffect([])` with cleanup returning all unsubs (lines 57-63). No double-registration, no leak.
- Background handler at index.js top-level (outside React tree) — correct FCM requirement.
- All paths crash-safe (try/catch → console.warn, never throw). Foreground `onMessage` counts only, no auto-nav. Unknown data → fallback Home.

## 3. Build safety (TestFlight) — PASS
- `yarn.lock` carries `@react-native-firebase/app` + `/messaging` (resolved 21.14.0). `yarn install --frozen-lockfile --ignore-engines` → "Resolving packages... Done" (lockfile↔package.json in sync). [The plain frozen-lockfile failure in review shell = Node 23 vs eslint-plugin-jest engine ^20/^22/>=24; CI runs Node 20 per .nvmrc — unaffected.]
- `GoogleService-Info.plist` committed (ios/auxi/) + referenced in pbxproj (PBXBuildFile + Resources phase + group). BUNDLE_ID `com.auxi2026.app` == PRODUCT_BUNDLE_IDENTIFIER. PASS.
- iOS native: Podfile `$RNFirebaseAsStaticFramework=true` (static, no app-wide use_frameworks!); AppDelegate `FirebaseApp.configure()`; Info.plist `UIBackgroundModes=[remote-notification]`; entitlements `aps-environment=development` (see nit).
- tsc: 5 errors, ALL pre-existing red-main baseline (DatabaseScreen openSidebar, HomeScreen AI_NOTICE_DISMISSED_KEY + refineToast* — confirmed: origin/main HomeScreen refs refineToast x11 but origin/main styles.ts defines it 0). Push surface (notificationService/deepLinkHandler/AuthContext/AppNavigator/SettingsScreen/analytics) is tsc-CLEAN. auxi CI gates on `archive` only — consistent.
- Tests: notificationService.test.ts (granted/denied/Settings/unregister paths assert exact `/notifications/device-token` payload) + deepLinkHandler.test.ts.

## 4. Known gap (Android) — CONFIRMED, does NOT block iOS
`android/app/google-services.json` is ABSENT (not on origin/main, not in worktree). Gradle plugin `com.google.gms.google-services` (build.gradle), classpath 4.4.2, manifest POST_NOTIFICATIONS perm ARE wired → an Android compile WILL fail at the google-services plugin until the file is added (package `com.auxi`). iOS-only TestFlight lane is unaffected. Follow-up below.

## 5. TestFlight signing flag to WATCH (not block)
App ID `com.auxi2026.app` needs Push Notifications capability on the Apple portal. entitlements ship `aps-environment=development`. Cloud-signing (`-allowProvisioningUpdates`) may add the cap automatically only if enabled. Watch the CI signing step. Note: `development` aps-environment means pushes route through the APNs sandbox; prod sends from the notification-worker may not deliver to a TestFlight (production-APNs) build until this flips to `production` — devops to confirm provisioning profile handles this on export.

## Nits (non-blocking, mobile-dev's call)
- `notificationService.ts:122` comment says "DELETE is user-scoped server-side (404 hides ownership)" — backend actually returns 200 idempotently (never 404). Stale comment, no behavioral impact.
- `APP_VERSION='0.0.1'` hand-maintained literal (notificationService.ts:34) — drifts from real build string; backend treats it as diagnostics-only. Fine for now.

## Follow-ups to file
1. (Android, medium) Add `android/app/google-services.json` (pkg `com.auxi`) before any Android release — Android build red until then.
2. (iOS, devops) Confirm Push Notifications cap + production aps-environment on the export profile for prod-APNs delivery to TestFlight.
3. (minor) Fix the 404-vs-200 stale comment.

## Open questions
- None blocking. Prod-APNs delivery (aps-environment) is a devops watch item, not a merge blocker for the build.
