# Phase 1: Mobile Push Plumbing

> **For agentic workers:** REQUIRED SUB-SKILL — implement task-by-task with `superpowers:subagent-driven-development` (or `superpowers:executing-plans`). Steps use `- [ ]` for tracking. Match the **Locked cross-phase interfaces** in [`plan.md`](./plan.md) VERBATIM. Spec: [`spec.md`](./spec.md) §8.

**Goal:** Wire the `auxi` RN app to FCM — install `@react-native-firebase/*`, register a device token (+ IANA timezone) with the backend after login, refresh/unregister on rotation/logout, route notification taps through a curated deep-link allowlist, and ship the 6 Mixpanel push events. Phase 1 is mobile-only; it consumes the Phase 0 device-token endpoint.

**Prereqs:** Phase 0 done (`POST/DELETE /api/notifications/device-token` live on the backend; `FIREBASE_CREDENTIALS_JSON` configured server-side). External (human/ops, block live verification, not code authoring): Firebase project created, `GoogleService-Info.plist` (iOS) + `google-services.json` (Android) downloaded, APNs `.p8` uploaded to Firebase, iOS Push Notifications capability + `aps-environment` entitlement enabled on the App ID, a **real iOS device** for final delivery QA.

**Repo / context:**
- Work context: `/Users/nguyenminhduc/dev/wardrobe_project/auxi` (RN 0.83, React 19, TS 5.8, TanStack Query, yarn, jest, Node 20 via `.nvmrc`).
- Reports: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/`.

**Files overview:**
- **Native config (setup):** `auxi/package.json` · `auxi/ios/Podfile` · `auxi/ios/auxi/AppDelegate.swift` · `auxi/ios/auxi/auxi.entitlements` · `auxi/ios/auxi/Info.plist` · `auxi/ios/auxi/GoogleService-Info.plist` (new, from ops) · `auxi/android/build.gradle` · `auxi/android/app/build.gradle` · `auxi/android/app/src/main/AndroidManifest.xml` · `auxi/android/app/google-services.json` (new, from ops) · `auxi/index.js`
- **New TS:** `auxi/src/services/notificationService.ts` + `auxi/src/services/notificationService.web.ts`
- **Edited TS:** `auxi/src/services/deepLinkHandler.ts` (add `resolveNotificationData` + allowlist) · `auxi/src/services/analytics.ts` (6 push helpers) · `auxi/src/context/AuthContext.tsx` (register/unregister) · `auxi/src/screens/SettingsScreen.tsx` (ensure-token on reminder enable) · `auxi/src/navigation/AppNavigator.tsx` (wire tap + refresh listeners)
- **Tests / harness:** `auxi/jest.setup.js` (firebase + `getTimeZone` mocks) · `auxi/src/services/__tests__/deepLinkHandler.test.ts` (new) · `auxi/src/services/__tests__/notificationService.test.ts` (new)
- **Docs:** `auxi/docs/analytics/mixpanel-tracking-plan.md` (§5.19 + §10 funnel note)

**Locked interfaces this phase implements (from plan.md):**
```ts
// src/services/notificationService.ts
registerDeviceForPush(): Promise<void>   // permission → FCM token → POST device-token {token,platform,timezone,app_version}
unregisterDevice(): Promise<void>        // DELETE device-token (logout)
// deep-link resolution lives in deepLinkHandler.ts:
resolveNotificationData(data) -> navigates or fallback Home
```
```
POST   /api/notifications/device-token   {token,platform,timezone,app_version?} -> 200 {ok:true}
DELETE /api/notifications/device-token   {token} -> 200 {ok:true}
```
Deep-link payload (FCM `data`, flat string map): `{kind:'route', screen:<curated>}` | `{kind:'external', url:<http(s)>}`.
Curated screens v1: `Home`, `Schedule`, `Favourite`, `Creations`, `Settings`. Unknown/missing → fallback `Home` (never crash).
Mixpanel events: `push_permission_requested` · `push_permission_granted` · `push_permission_denied` · `device_token_registered` · `push_received {type}` · `push_opened {type}`.

> ⚠ **Load-bearing mapping:** the registry's public screen name `Creations` maps to the **registered RN route `MyCreations`** (see `AppNavigator.tsx`). `Home`/`Schedule`/`Favourite`/`Settings` map 1:1. Keep this map as the single mobile mirror of spec §5.1.

---

## Task 1: Deps + native FCM config (SETUP — no TDD)

> This task changes native build inputs → it needs `pod install` + a rebuild. Per `.claude/rules/ios-build-workflow-required.md`, Metro `:8081` / Simulator / watchman are **one shared machine singleton**. **Do NOT** run `pod install` / `yarn ios:clean` / kill Metro unilaterally — confirm with the user that no other Claude Code session is mid-qa/build first. Adding a native module is NOT a hot-reload change; a rebuild is required and must be coordinated. Final push delivery needs a **real device** (sim push is unreliable per project memory).

**Files:**
- Modify: `auxi/package.json` (deps) · `auxi/ios/Podfile` · `auxi/ios/auxi/AppDelegate.swift` · `auxi/ios/auxi/auxi.entitlements` · `auxi/ios/auxi/Info.plist` · `auxi/index.js` · `auxi/android/build.gradle` · `auxi/android/app/build.gradle` · `auxi/android/app/src/main/AndroidManifest.xml`
- Create (from ops, not authored here): `auxi/ios/auxi/GoogleService-Info.plist` · `auxi/android/app/google-services.json`

**Interfaces:** Consumes — Firebase console artifacts (ops). Produces — autolinked native FCM modules; `messaging()` usable from JS in Task 2/4.

- [ ] **Add deps.** Run from `auxi/`: `yarn add @react-native-firebase/app @react-native-firebase/messaging`. Confirm both land in `package.json` `dependencies` and `yarn.lock` updates in the same change (per `.claude/rules/yarn-lock-cache-management.md`). Confirm no `firebase` web SDK is pulled.
- [ ] **iOS Podfile — static-framework flag.** RNFirebase needs firebase-ios-sdk linked as static frameworks because this project does NOT use `use_frameworks!` by default. Add this line near the top of `auxi/ios/Podfile`, immediately after `prepare_react_native_project!`:
  ```ruby
  prepare_react_native_project!

  # @react-native-firebase: pull firebase-ios-sdk as static frameworks so it
  # links without enabling use_frameworks! app-wide (RN 0.83 static build).
  $RNFirebaseAsStaticFramework = true
  ```
  Leave the existing `linkage = ENV['USE_FRAMEWORKS']` block and the `fmt` consteval post-install patch untouched.
- [ ] **iOS GoogleService-Info.plist.** Place the ops-provided `GoogleService-Info.plist` at `auxi/ios/auxi/GoogleService-Info.plist` and add it to the `auxi` target in Xcode (drag into the `auxi` group, "Copy if needed", target checked). Note in handoff: this file is from the Firebase console (external prereq) and is build-critical for `FirebaseApp.configure()`.
- [ ] **iOS AppDelegate — configure Firebase.** Edit `auxi/ios/auxi/AppDelegate.swift`: add `import FirebaseCore` to the imports, and call `FirebaseApp.configure()` as the FIRST statement inside `didFinishLaunchingWithOptions`:
  ```swift
  import UIKit
  import React
  import React_RCTAppDelegate
  import ReactAppDependencyProvider
  import FirebaseCore

  @main
  class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var reactNativeDelegate: ReactNativeDelegate?
    var reactNativeFactory: RCTReactNativeFactory?

    func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
      FirebaseApp.configure()

      let delegate = ReactNativeDelegate()
      // …rest unchanged…
  ```
  RNFirebase's AppDelegate proxy (enabled by default) handles APNs-token → FCM wiring; no manual `didRegisterForRemoteNotifications` code is needed.
- [ ] **iOS entitlements — APNs.** Edit `auxi/ios/auxi/auxi.entitlements`, add an `aps-environment` key alongside the existing Apple-Sign-In entitlement:
  ```xml
  <dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.applesignin</key>
    <array>
      <string>Default</string>
    </array>
  </dict>
  ```
  Note: the **Push Notifications capability** must also be enabled on the App ID in the Apple Developer portal + Xcode "Signing & Capabilities" (human/ops step). Archive/TestFlight builds flip `aps-environment` to `production` automatically via the capability — keep `development` in the checked-in file.
- [ ] **iOS Info.plist — background mode.** Add a `UIBackgroundModes` array with `remote-notification` to `auxi/ios/auxi/Info.plist` (enables data-message wake-ups). Insert near the other top-level keys:
  ```xml
  <key>UIBackgroundModes</key>
  <array>
    <string>remote-notification</string>
  </array>
  ```
- [ ] **index.js — background message handler (native entry).** `auxi/index.js` is the native entry (web uses `index.web.tsx`, so this import never reaches the web bundle). Register the background/quit handler at top level, BEFORE `AppRegistry.registerComponent`:
  ```js
  import { AppRegistry } from 'react-native';
  import messaging from '@react-native-firebase/messaging';
  import { initSentry, Sentry } from './src/services/sentry';
  import App from './App';
  import { name as appName } from './app.json';

  initSentry();

  // Background/quit data-message handler. MUST be registered at the top level
  // (outside the React tree) or FCM logs a missing-handler warning. The OS
  // renders any `notification` payload itself; tap routing for background/quit
  // is handled once foregrounded by onNotificationOpenedApp / getInitialNotification
  // (see notificationService.registerPushTapHandlers). No background work needed
  // in Phase 1 — keep it minimal + crash-safe.
  messaging().setBackgroundMessageHandler(async () => {});

  AppRegistry.registerComponent(appName, () => Sentry.wrap(App));
  ```
- [ ] **Android google-services.json.** Place the ops-provided `google-services.json` at `auxi/android/app/google-services.json` (external prereq from Firebase console).
- [ ] **Android project gradle.** In `auxi/android/build.gradle` add the Google Services classpath to `buildscript.dependencies`:
  ```gradle
  dependencies {
      classpath("com.android.tools.build:gradle")
      classpath("com.facebook.react:react-native-gradle-plugin")
      classpath("org.jetbrains.kotlin:kotlin-gradle-plugin")
      classpath("io.sentry:sentry-android-gradle-plugin:4.14.1")
      classpath("com.google.gms:google-services:4.4.2")
  }
  ```
- [ ] **Android app gradle.** In `auxi/android/app/build.gradle`, apply the plugin under the existing `apply plugin:` lines (top of file):
  ```gradle
  apply plugin: "com.android.application"
  apply plugin: "org.jetbrains.kotlin.android"
  apply plugin: "com.facebook.react"
  apply plugin: "com.google.gms.google-services"
  ```
- [ ] **Android manifest — POST_NOTIFICATIONS.** In `auxi/android/app/src/main/AndroidManifest.xml`, add the Android-13+ runtime permission next to the existing INTERNET permission:
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  ```
- [ ] **Verify — install + typecheck + lint (non-destructive).** From `auxi/`: `yarn install` (lockfile in sync). Then `npx tsc --noEmit` and `yarn lint` — must be at/under the known baseline (4 errors + 3 warnings, all in `_HomeScreen.tsx`). No new errors. (No `pod install`/rebuild yet — do that in the coordinated Task 6 verify.)
- [ ] **Commit:** `chore(push): add @react-native-firebase app+messaging and native FCM config`

---

## Task 2: `notificationService.ts` — token register/refresh/unregister (TDD)

**Files:**
- Create: `auxi/src/services/notificationService.ts`
- Create: `auxi/src/services/notificationService.web.ts` (no-op web stub — RNFirebase is native-only; the react-native-web sandbox must build per `.claude/rules/web-preview-on-system-required.md`)
- Modify: `auxi/jest.setup.js` (global firebase + `getTimeZone` mocks)
- Test: `auxi/src/services/__tests__/notificationService.test.ts`

**Interfaces:** Consumes — `apiClient` (axios + Bearer), `messaging()` from `@react-native-firebase/messaging`, `getTimeZone()` from `react-native-localize`, `Platform.OS`, analytics helpers (Task 3). Produces (locked) — `registerDeviceForPush(): Promise<void>`, `unregisterDevice(): Promise<void>`, plus `ensurePushPermissionAndRegister(): Promise<boolean>` (Settings path), `registerTokenRefreshListener(): () => void`, `registerPushTapHandlers(getNavRef): () => void` (Task 4 fills the tap body).

- [ ] **Add global jest mocks** so the App-render test path (`App.test.tsx` → AuthContext/AppNavigator → `notificationService.ts`) resolves the native module. Append to `auxi/jest.setup.js`:
  ```js
  // @react-native-firebase/messaging: native FCM bridge, absent in jest. Inert
  // default-export stub so the AuthContext/AppNavigator → notificationService
  // import chain (App.test.tsx render path) resolves. Per-test files re-mock
  // with spies (see services/__tests__/notificationService.test.ts).
  jest.mock('@react-native-firebase/messaging', () => {
    const messaging = () => ({
      requestPermission: jest.fn().mockResolvedValue(1),
      registerDeviceForRemoteMessages: jest.fn().mockResolvedValue(undefined),
      getToken: jest.fn().mockResolvedValue('test-fcm-token'),
      onTokenRefresh: jest.fn(() => () => {}),
      onMessage: jest.fn(() => () => {}),
      onNotificationOpenedApp: jest.fn(() => () => {}),
      getInitialNotification: jest.fn().mockResolvedValue(null),
      setBackgroundMessageHandler: jest.fn(),
    });
    messaging.AuthorizationStatus = {
      NOT_DETERMINED: -1,
      DENIED: 0,
      AUTHORIZED: 1,
      PROVISIONAL: 2,
    };
    return { __esModule: true, default: messaging };
  });
  ```
  And extend the existing `react-native-localize` mock (it currently exposes only `getLocales`) to add `getTimeZone`:
  ```js
  jest.mock('react-native-localize', () => ({
    getLocales: () => [
      { languageCode: 'en', countryCode: 'US', languageTag: 'en-US' },
    ],
    getTimeZone: () => 'Asia/Saigon',
  }));
  ```
- [ ] **RED — write the failing test** `auxi/src/services/__tests__/notificationService.test.ts` (mirrors `analytics.test.ts` / `apiClient.test.ts` style — module-scoped `mock*` spies, local `jest.mock`):
  ```ts
  /* eslint-env jest */
  // notificationService — device-token lifecycle. Mocks @react-native-firebase
  // messaging, apiClient, the analytics helpers, and react-native-localize so the
  // pure register/unregister logic is asserted without a native runtime.

  const mockRequestPermission = jest.fn();
  const mockGetToken = jest.fn();
  const mockRegisterRemote = jest.fn().mockResolvedValue(undefined);

  jest.mock('@react-native-firebase/messaging', () => {
    const messaging = () => ({
      requestPermission: mockRequestPermission,
      registerDeviceForRemoteMessages: mockRegisterRemote,
      getToken: mockGetToken,
      onTokenRefresh: jest.fn(() => () => {}),
    });
    messaging.AuthorizationStatus = {
      NOT_DETERMINED: -1,
      DENIED: 0,
      AUTHORIZED: 1,
      PROVISIONAL: 2,
    };
    return { __esModule: true, default: messaging };
  });

  const mockPost = jest.fn().mockResolvedValue({ data: { ok: true } });
  const mockDelete = jest.fn().mockResolvedValue({ data: { ok: true } });
  jest.mock('../apiClient', () => ({
    apiClient: { post: mockPost, delete: mockDelete },
  }));

  const mockTrackRequested = jest.fn();
  const mockTrackGranted = jest.fn();
  const mockTrackDenied = jest.fn();
  const mockTrackRegistered = jest.fn();
  jest.mock('../analytics', () => ({
    trackPushPermissionRequested: mockTrackRequested,
    trackPushPermissionGranted: mockTrackGranted,
    trackPushPermissionDenied: mockTrackDenied,
    trackDeviceTokenRegistered: mockTrackRegistered,
    trackPushReceived: jest.fn(),
    trackPushOpened: jest.fn(),
  }));

  jest.mock('react-native-localize', () => ({
    getTimeZone: () => 'Asia/Saigon',
    getLocales: () => [{ languageCode: 'en', countryCode: 'US', languageTag: 'en-US' }],
  }));

  import {
    registerDeviceForPush,
    unregisterDevice,
    ensurePushPermissionAndRegister,
  } from '../notificationService';

  beforeEach(() => {
    jest.clearAllMocks();
    mockGetToken.mockResolvedValue('fcm-tok-1');
  });

  describe('registerDeviceForPush — granted path', () => {
    it('requests permission, gets the token, and POSTs device context', async () => {
      mockRequestPermission.mockResolvedValueOnce(1); // AUTHORIZED
      await registerDeviceForPush();

      expect(mockTrackRequested).toHaveBeenCalledTimes(1);
      expect(mockTrackGranted).toHaveBeenCalledTimes(1);
      expect(mockTrackDenied).not.toHaveBeenCalled();
      expect(mockPost).toHaveBeenCalledWith('/notifications/device-token', {
        token: 'fcm-tok-1',
        platform: 'ios', // jest RN preset Platform.OS
        timezone: 'Asia/Saigon',
        app_version: expect.any(String),
      });
      expect(mockTrackRegistered).toHaveBeenCalledTimes(1);
    });
  });

  describe('registerDeviceForPush — denied path', () => {
    it('does NOT fetch a token or POST when permission is denied', async () => {
      mockRequestPermission.mockResolvedValueOnce(0); // DENIED
      await registerDeviceForPush();

      expect(mockTrackRequested).toHaveBeenCalledTimes(1);
      expect(mockTrackDenied).toHaveBeenCalledTimes(1);
      expect(mockTrackGranted).not.toHaveBeenCalled();
      expect(mockGetToken).not.toHaveBeenCalled();
      expect(mockPost).not.toHaveBeenCalled();
      expect(mockTrackRegistered).not.toHaveBeenCalled();
    });
  });

  describe('ensurePushPermissionAndRegister — Settings path', () => {
    it('returns true and registers when granted (provisional counts)', async () => {
      mockRequestPermission.mockResolvedValueOnce(2); // PROVISIONAL
      await expect(ensurePushPermissionAndRegister()).resolves.toBe(true);
      expect(mockPost).toHaveBeenCalledTimes(1);
    });

    it('returns false and does not register when denied', async () => {
      mockRequestPermission.mockResolvedValueOnce(0); // DENIED
      await expect(ensurePushPermissionAndRegister()).resolves.toBe(false);
      expect(mockPost).not.toHaveBeenCalled();
    });
  });

  describe('unregisterDevice', () => {
    it('DELETEs the current token (user-scoped) on logout', async () => {
      await unregisterDevice();
      expect(mockDelete).toHaveBeenCalledWith('/notifications/device-token', {
        data: { token: 'fcm-tok-1' },
      });
    });

    it('no-ops (no throw) when no token is available', async () => {
      mockGetToken.mockResolvedValueOnce('');
      await expect(unregisterDevice()).resolves.toBeUndefined();
      expect(mockDelete).not.toHaveBeenCalled();
    });
  });
  ```
- [ ] **RED — run:** `cd auxi && yarn jest src/services/__tests__/notificationService.test.ts` → expected **FAIL** (`Cannot find module '../notificationService'`).
- [ ] **GREEN — implement** `auxi/src/services/notificationService.ts` (complete):
  ```ts
  // Push device-token lifecycle (Phase 1 of the push-notification system).
  // Owns: contextual permission request → FCM token → register with the backend;
  // token-refresh re-register; unregister on logout; FCM tap/foreground handlers
  // (registerPushTapHandlers — body in Task 4). The ONLY module that talks to
  // @react-native-firebase/messaging.
  //
  // Web: a no-op stub ships as notificationService.web.ts — RNFirebase is a
  // native module with no web binding, and the react-native-web sandbox must
  // build (.claude/rules/web-preview-on-system-required.md). Keep the two files'
  // public surface identical.

  import { Platform } from 'react-native';
  import messaging, {
    FirebaseMessagingTypes,
  } from '@react-native-firebase/messaging';
  import { getTimeZone } from 'react-native-localize';
  import type { NavigationContainerRef } from '@react-navigation/native';
  import { apiClient } from './apiClient';
  import type { AppStackParamList } from '../types/navigation';
  import {
    trackPushPermissionRequested,
    trackPushPermissionGranted,
    trackPushPermissionDenied,
    trackDeviceTokenRegistered,
    trackPushReceived,
    trackPushOpened,
  } from './analytics';
  import { resolveNotificationData } from './deepLinkHandler';

  type NavRef = NavigationContainerRef<AppStackParamList>;

  // App version for diagnostics. Mirrors SettingsScreen's APP_VERSION constant;
  // react-native-device-info is not installed (see analytics.ts note), so this is
  // a hand-maintained literal rather than a runtime read.
  const APP_VERSION = '0.0.1';

  const DEVICE_TOKEN_PATH = '/notifications/device-token';

  /** Granted OR provisionally granted both count as "we may send pushes". */
  const isPermissionGranted = (
    status: FirebaseMessagingTypes.AuthorizationStatus,
  ): boolean =>
    status === messaging.AuthorizationStatus.AUTHORIZED ||
    status === messaging.AuthorizationStatus.PROVISIONAL;

  /** Request OS permission once; fires the requested/granted/denied events. */
  const requestPushPermission = async (): Promise<boolean> => {
    trackPushPermissionRequested();
    const status = await messaging().requestPermission();
    const granted = isPermissionGranted(status);
    if (granted) {
      trackPushPermissionGranted();
    } else {
      trackPushPermissionDenied();
    }
    return granted;
  };

  /** Fetch the current FCM token and upsert it on the backend (keyed by token). */
  const registerCurrentToken = async (): Promise<void> => {
    if (Platform.OS === 'ios') {
      // No-op if already registered; required before getToken on iOS.
      await messaging().registerDeviceForRemoteMessages();
    }
    const token = await messaging().getToken();
    if (!token) {
      return;
    }
    await apiClient.post(DEVICE_TOKEN_PATH, {
      token,
      platform: Platform.OS,
      timezone: getTimeZone(),
      app_version: APP_VERSION,
    });
    trackDeviceTokenRegistered();
  };

  /**
   * Request permission + register, reporting whether permission ended up
   * granted. The Settings reminder-enable path calls this so the UI can guide
   * the user to OS Settings if they declined. Never throws.
   */
  export const ensurePushPermissionAndRegister = async (): Promise<boolean> => {
    try {
      const granted = await requestPushPermission();
      if (!granted) {
        return false;
      }
      await registerCurrentToken();
      return true;
    } catch (err) {
      console.warn('[notificationService] ensurePushPermissionAndRegister', err);
      return false;
    }
  };

  /**
   * Login path: request permission → FCM token → POST device-token. Idempotent
   * (server upserts on token). Fire-and-forget — never throws.
   */
  export const registerDeviceForPush = async (): Promise<void> => {
    await ensurePushPermissionAndRegister();
  };

  /**
   * Subscribe to FCM token rotation. FCM may rotate a token at any time; re-
   * register so the backend never holds a stale token. Returns an unsubscribe.
   */
  export const registerTokenRefreshListener = (): (() => void) =>
    messaging().onTokenRefresh(() => {
      registerCurrentToken().catch(err =>
        console.warn('[notificationService] token-refresh re-register failed', err),
      );
    });

  /**
   * Logout: remove this device's token so the signed-out user stops receiving
   * pushes here. DELETE is user-scoped server-side (404 hides ownership). Never
   * throws.
   */
  export const unregisterDevice = async (): Promise<void> => {
    try {
      const token = await messaging().getToken();
      if (!token) {
        return;
      }
      await apiClient.delete(DEVICE_TOKEN_PATH, { data: { token } });
    } catch (err) {
      console.warn('[notificationService] unregisterDevice failed', err);
    }
  };

  /** notification.type rides FCM data; default 'unknown' (no PII). */
  const messageType = (
    msg: FirebaseMessagingTypes.RemoteMessage | null,
  ): string => (msg?.data?.type as string) || 'unknown';

  /**
   * Wire FCM tap + foreground handlers (mirrors registerDeepLinkListeners):
   *   - getInitialNotification → cold-start tap (app was quit)
   *   - onNotificationOpenedApp → background tap (app was backgrounded)
   *   - onMessage → foreground delivery (in-app banner; no auto-nav)
   * Caller passes a navRef factory (the nav container mounts asynchronously).
   * Returns an unsubscribe for the warm listeners.
   */
  export const registerPushTapHandlers = (
    getNavRef: () => NavRef | null,
  ): (() => void) => {
    const route = (msg: FirebaseMessagingTypes.RemoteMessage) => {
      trackPushOpened(messageType(msg));
      resolveNotificationData(
        msg.data as Record<string, string> | undefined,
        getNavRef(),
      );
    };

    // Cold start: a tap that launched the app from quit.
    messaging()
      .getInitialNotification()
      .then(msg => {
        if (msg) {
          route(msg);
        }
      })
      .catch(err =>
        console.warn('[notificationService] getInitialNotification failed', err),
      );

    // Background → foreground tap.
    const unsubOpened = messaging().onNotificationOpenedApp(msg => {
      if (msg) {
        route(msg);
      }
    });

    // Foreground delivery: count it; the in-app banner is a Phase-2 refinement
    // (see note). Do NOT auto-navigate — the user is already in the app.
    const unsubForeground = messaging().onMessage(async msg => {
      trackPushReceived(messageType(msg));
    });

    return () => {
      unsubOpened();
      unsubForeground();
    };
  };
  ```
  > Note: a richer foreground in-app banner (DS toast tappable → `resolveNotificationData`) is intentionally deferred — `onMessage` here just fires `push_received {type}`. If the CEO wants a visible foreground banner in Phase 1, surface it via `toast.show` in `onMessage` with `onPress` → `resolveNotificationData(msg.data, getNavRef())`; flag as a small follow-up.
- [ ] **GREEN — create the web stub** `auxi/src/services/notificationService.web.ts` (surface-identical no-op; resolved by metro/vite `.web.ts` precedence, same pattern as `tokenStorage.web.ts`):
  ```ts
  // Web (react-native-web sandbox) no-op stub for the push device-token service.
  // RNFirebase messaging is a native module with no web binding; the preview must
  // import a surface-compatible shim so AuthContext / Settings / AppNavigator
  // build. ensurePushPermissionAndRegister resolves true so the Settings reminder
  // toggle vibes cleanly on the sandbox (no "enable in Settings" guidance toast).
  export const registerDeviceForPush = async (): Promise<void> => {};
  export const unregisterDevice = async (): Promise<void> => {};
  export const ensurePushPermissionAndRegister = async (): Promise<boolean> => true;
  export const registerTokenRefreshListener = (): (() => void) => () => {};
  export const registerPushTapHandlers = (
    _getNavRef?: unknown,
  ): (() => void) => () => {};
  ```
- [ ] **GREEN — run:** `cd auxi && yarn jest src/services/__tests__/notificationService.test.ts` → expected **PASS** (5 tests). (Task 3 ships the analytics helpers the service imports; until then the service imports resolve against the local `jest.mock('../analytics', …)`. Run the umbrella `tsc` only after Task 3.)
- [ ] **Commit:** `feat(push): notificationService — device-token register/refresh/unregister + tap handlers`

---

## Task 3: Permission UX + Mixpanel push events (TDD where logic exists)

**Files:**
- Modify: `auxi/src/services/analytics.ts` (6 literal-name helpers)
- (Permission-denied UX is exercised in Task 5 SettingsScreen wiring + the Task 2 denied-path test already covers the service branch.)

**Interfaces:** Consumes — `track(event, props)` (existing seam, consent-gated, never throws). Produces — `trackPushPermissionRequested` / `trackPushPermissionGranted` / `trackPushPermissionDenied` / `trackDeviceTokenRegistered` / `trackPushReceived(type)` / `trackPushOpened(type)`. Event names are **literal strings** (no template literals); props are bounded — `type` only, no PII.

- [ ] **Implement the helpers** — append to `auxi/src/services/analytics.ts` after the legal-document section, matching the existing literal-name helper style (e.g. `trackTemperatureModalOpened`):
  ```ts
  // ── Push notifications (Phase 1) ───────────────────────────────────────────
  // Literal event names (no template strings). The only property is `type`
  // (notification type enum — daily_reminder | planned_outfit | admin_*) — no
  // ids, no free text, no PII. permission events carry no properties.

  /** OS notification permission prompt about to be shown / re-evaluated. */
  export const trackPushPermissionRequested = (): void => {
    track('push_permission_requested');
  };

  /** Permission granted (or provisionally granted). */
  export const trackPushPermissionGranted = (): void => {
    track('push_permission_granted');
  };

  /** Permission denied / not determined. */
  export const trackPushPermissionDenied = (): void => {
    track('push_permission_denied');
  };

  /** FCM token successfully registered with the backend. */
  export const trackDeviceTokenRegistered = (): void => {
    track('device_token_registered');
  };

  /** A push arrived while the app was in the foreground. */
  export const trackPushReceived = (type: string): void => {
    track('push_received', { type });
  };

  /** A push was tapped (cold-start or background) and routed. */
  export const trackPushOpened = (type: string): void => {
    track('push_opened', { type });
  };
  ```
- [ ] **Verify the consent gate still holds (no new test file needed — the existing `analytics.test.ts` consent-gate test protects `track`).** Optionally extend `analytics.test.ts` with one assertion that `trackPushReceived('daily_reminder')` routes `push_received` with `{type:'daily_reminder'}` to the SDK after consent — mirror the `outfit_favorited` case there. Run: `cd auxi && yarn jest src/services/__tests__/analytics.test.ts` → **PASS**.
- [ ] **Commit:** `feat(analytics): push permission + delivery event helpers (6 events)`

---

## Task 4: Deep-link tap routing — `resolveNotificationData` + curated allowlist (TDD)

**Files:**
- Modify: `auxi/src/services/deepLinkHandler.ts` (add allowlist constant, `Creations`→`MyCreations` map, `resolveNotificationData`)
- Test: `auxi/src/services/__tests__/deepLinkHandler.test.ts` (new)

**Interfaces:** Consumes — `navigationRef`/`NavRef` (`NavigationContainerRef<AppStackParamList>`), `Linking.openURL` (react-native), FCM `data` (flat `Record<string,string>`). Produces (locked) — `resolveNotificationData(data, navRef): void` (route → `navRef.navigate(<mapped>)`; external http(s) → `Linking.openURL`; unknown/missing/not-ready → fallback `Home`, never crash) + `CURATED_PUSH_SCREENS` constant.

- [ ] **RED — write the failing test** `auxi/src/services/__tests__/deepLinkHandler.test.ts`:
  ```ts
  /* eslint-env jest */
  // resolveNotificationData — FCM tap payload → navigation/open side-effect.
  // Curated route allowlist (incl. the Creations→MyCreations route mapping),
  // external-URL opening, and the unknown/missing → fallback-Home guarantee.

  import { Linking } from 'react-native';
  import { resolveNotificationData } from '../deepLinkHandler';

  const makeNavRef = (ready = true) => ({
    isReady: () => ready,
    navigate: jest.fn(),
  });

  let openUrlSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    openUrlSpy = jest
      .spyOn(Linking, 'openURL')
      .mockResolvedValue(true as never);
  });

  afterEach(() => openUrlSpy.mockRestore());

  describe('resolveNotificationData — route kind', () => {
    it('navigates to an allowlisted curated screen', () => {
      const nav = makeNavRef();
      resolveNotificationData({ kind: 'route', screen: 'Schedule' }, nav as any);
      expect(nav.navigate).toHaveBeenCalledWith('Schedule');
      expect(openUrlSpy).not.toHaveBeenCalled();
    });

    it('maps the registry name Creations → the RN route MyCreations', () => {
      const nav = makeNavRef();
      resolveNotificationData({ kind: 'route', screen: 'Creations' }, nav as any);
      expect(nav.navigate).toHaveBeenCalledWith('MyCreations');
    });

    it('falls back to Home for a screen not in the allowlist', () => {
      const nav = makeNavRef();
      resolveNotificationData({ kind: 'route', screen: 'ItemDetail' }, nav as any);
      expect(nav.navigate).toHaveBeenCalledWith('Home');
    });
  });

  describe('resolveNotificationData — external kind', () => {
    it('opens a valid https url', () => {
      const nav = makeNavRef();
      resolveNotificationData(
        { kind: 'external', url: 'https://auxi.app/promo' },
        nav as any,
      );
      expect(openUrlSpy).toHaveBeenCalledWith('https://auxi.app/promo');
      expect(nav.navigate).not.toHaveBeenCalled();
    });

    it('falls back to Home for a non-http(s) url', () => {
      const nav = makeNavRef();
      resolveNotificationData(
        { kind: 'external', url: 'javascript:alert(1)' },
        nav as any,
      );
      expect(openUrlSpy).not.toHaveBeenCalled();
      expect(nav.navigate).toHaveBeenCalledWith('Home');
    });
  });

  describe('resolveNotificationData — defensive', () => {
    it('falls back to Home on unknown kind', () => {
      const nav = makeNavRef();
      resolveNotificationData({ kind: 'mystery' }, nav as any);
      expect(nav.navigate).toHaveBeenCalledWith('Home');
    });

    it('falls back to Home on missing/empty data', () => {
      const nav = makeNavRef();
      resolveNotificationData(undefined, nav as any);
      expect(nav.navigate).toHaveBeenCalledWith('Home');
    });

    it('does nothing (no throw) when the nav ref is not ready', () => {
      const nav = makeNavRef(false);
      expect(() =>
        resolveNotificationData({ kind: 'route', screen: 'Home' }, nav as any),
      ).not.toThrow();
      expect(nav.navigate).not.toHaveBeenCalled();
    });

    it('does nothing (no throw) when the nav ref is null', () => {
      expect(() =>
        resolveNotificationData({ kind: 'route', screen: 'Home' }, null),
      ).not.toThrow();
    });
  });
  ```
- [ ] **RED — run:** `cd auxi && yarn jest src/services/__tests__/deepLinkHandler.test.ts` → expected **FAIL** (`resolveNotificationData` is not exported).
- [ ] **GREEN — implement** by appending to `auxi/src/services/deepLinkHandler.ts` (it already imports `Linking` from `react-native` and `AppStackParamList`; `NavRef` is already defined in the file). Add after `dispatchDeepLink`:
  ```ts
  // ── Push deep-link routing (Phase 1, push-notification system) ──────────────
  // Curated, param-free screen allowlist — the mobile mirror of spec §5.1's
  // registry. The admin SPA + backend duplicate this list (no shared SDK), so
  // keep these names in sync with API_DOCUMENTATION.md. The registry's PUBLIC
  // name `Creations` maps to the registered RN route `MyCreations` (the route
  // name differs from the contract name); the others map 1:1.

  export const CURATED_PUSH_SCREENS = [
    'Home',
    'Schedule',
    'Favourite',
    'Creations',
    'Settings',
  ] as const;
  export type CuratedPushScreen = (typeof CURATED_PUSH_SCREENS)[number];

  const PUSH_SCREEN_ROUTE: Record<CuratedPushScreen, keyof AppStackParamList> = {
    Home: 'Home',
    Schedule: 'Schedule',
    Favourite: 'Favourite',
    Creations: 'MyCreations',
    Settings: 'Settings',
  };

  const isHttpUrl = (url: string): boolean => /^https?:\/\//i.test(url);

  const isCuratedScreen = (value: string): value is CuratedPushScreen =>
    (CURATED_PUSH_SCREENS as readonly string[]).includes(value);

  /**
   * Resolve an FCM `data` payload to a navigation/open side-effect. FCM data is
   * a flat string map. Rules (spec §5.1):
   *   - kind:'route' + allowlisted screen → navRef.navigate(<mapped route>)
   *   - kind:'external' + http(s) url     → Linking.openURL(url)
   *   - anything unknown / missing        → fallback Home (NEVER crash)
   * No-op (no crash) when the nav tree is not mounted yet.
   */
  export const resolveNotificationData = (
    data: Record<string, string> | undefined,
    navRef: NavRef | null,
  ): void => {
    if (!navRef || !navRef.isReady()) {
      return;
    }
    // Loose cast mirrors AppNavigator's dynamic-target navigate: all curated
    // routes + Home accept undefined params.
    const navigate = navRef.navigate as unknown as (name: string) => void;
    const fallbackHome = () => navigate('Home');

    try {
      if (!data || !data.kind) {
        fallbackHome();
        return;
      }
      if (data.kind === 'route') {
        if (data.screen && isCuratedScreen(data.screen)) {
          navigate(PUSH_SCREEN_ROUTE[data.screen]);
        } else {
          fallbackHome();
        }
        return;
      }
      if (data.kind === 'external' && data.url && isHttpUrl(data.url)) {
        Linking.openURL(data.url).catch(err => {
          console.warn('[deepLinkHandler] openURL failed', err);
        });
        return;
      }
      fallbackHome();
    } catch (err) {
      console.warn('[deepLinkHandler] resolveNotificationData failed', err);
      fallbackHome();
    }
  };
  ```
- [ ] **GREEN — run:** `cd auxi && yarn jest src/services/__tests__/deepLinkHandler.test.ts` → expected **PASS** (9 tests).
- [ ] **Commit:** `feat(push): resolveNotificationData curated tap routing (Creations→MyCreations)`

---

## Task 5: Wire register-on-login / unregister-on-logout / Settings / AppNavigator

**Files:**
- Modify: `auxi/src/context/AuthContext.tsx` (register on sign-in, unregister on logout)
- Modify: `auxi/src/navigation/AppNavigator.tsx` (register tap + token-refresh listeners)
- Modify: `auxi/src/screens/SettingsScreen.tsx` (ensure permission+token when enabling daily reminder; denied → guidance + Open Settings)

**Interfaces:** Consumes — `registerDeviceForPush`, `unregisterDevice`, `registerPushTapHandlers`, `registerTokenRefreshListener`, `ensurePushPermissionAndRegister` from `notificationService` (web stub resolves on the sandbox); `Linking.openSettings()`; existing `toast.show`. Produces — token registered on real sign-in (not cold-start), removed on logout; taps routed app-wide; reminder toggle ensures a token exists.

- [ ] **AuthContext — register on real sign-in.** In `auxi/src/context/AuthContext.tsx`, import the service and call register inside the identity effect's existing `if (justLoggedInRef.current)` block (so it fires ONLY on explicit login / OAuth / SignIn-completion — NOT on cold-start restore, satisfying spec §8 "contextual, not cold on first launch"). Add the import:
  ```ts
  import {
    registerDeviceForPush,
    unregisterDevice,
  } from '../services/notificationService';
  ```
  Inside the identity effect, after the `track('sign_in_completed', { method })` line and before resetting `pendingAuthMethodRef`:
  ```ts
        track('sign_in_completed', { method });
        // Push: request permission + register the FCM device token now that the
        // user is authenticated (contextual, post-login — never cold on launch).
        // Fire-and-forget; the service never throws.
        registerDeviceForPush();
        // Reset to default for the next transition (cold-start
        // restores remain silent because justLoggedInRef stays false).
        pendingAuthMethodRef.current = 'email';
  ```
- [ ] **AuthContext — unregister on logout.** In the `logout` callback, before `setUser(null)`, remove this device's token:
  ```ts
    const logout = useCallback(async () => {
      setIsLoading(true);
      try {
        // Remove this device's push token before clearing the session (the
        // DELETE is Bearer-authed — must run while tokens are still valid).
        await unregisterDevice();
        await authService.logout();
        setUser(null);
        setPendingVerifyEmail(null);
      } catch (error) {
        console.error(error);
      } finally {
        setIsLoading(false);
      }
    }, []);
  ```
- [ ] **AppNavigator — wire tap + refresh listeners** alongside the existing deep-link registration. In `auxi/src/navigation/AppNavigator.tsx`, extend the import and the mount effect:
  ```ts
  import { registerDeepLinkListeners } from '../services/deepLinkHandler';
  import {
    registerPushTapHandlers,
    registerTokenRefreshListener,
  } from '../services/notificationService';
  ```
  ```ts
    useEffect(() => {
      // Linking deep links (verify-email / reset-password) + push notification
      // taps both drive the shared navigationRef.
      const unregisterLinks = registerDeepLinkListeners(() => navigationRef.current);
      const unregisterTaps = registerPushTapHandlers(() => navigationRef.current);
      const unregisterRefresh = registerTokenRefreshListener();
      return () => {
        unregisterLinks();
        unregisterTaps();
        unregisterRefresh();
      };
    }, []);
  ```
- [ ] **SettingsScreen — ensure token when enabling reminders.** In `auxi/src/screens/SettingsScreen.tsx`, import `Linking` (from `react-native`, already importing several RN bits) and `ensurePushPermissionAndRegister`:
  ```ts
  import { Linking } from 'react-native'; // add Linking to the existing RN import
  import { ensurePushPermissionAndRegister } from '../services/notificationService';
  ```
  In `handleReminderToggle`, when the user turns the reminder ON, ensure permission + a token exist; if permission is declined, guide them to OS Settings (the persisted `enabled` flag still saves — the server simply has no token to deliver to). Add at the top of the `enabled === true` path (after the optimistic state set / existing `track('notifications_toggle_changed', …)`):
  ```ts
    if (enabled) {
      ensurePushPermissionAndRegister().then(granted => {
        if (!granted) {
          toast.show({
            type: 'info',
            text1: t('settings.push_permission_needed_title'),
            text2: t('settings.push_permission_needed_body'),
            position: 'bottom',
            visibilityTime: 5000,
            onPress: () => {
              Linking.openSettings().catch(() => {});
            },
          });
        }
      });
    }
  ```
  Add the two i18n keys to all three locale files (`src/translations/en-EN.*`, `vi-VN.*`, `fr-FR.*`) under `settings`:
  - `push_permission_needed_title` — en: "Turn on notifications" · vi: "Bật thông báo" · fr: "Activer les notifications"
  - `push_permission_needed_body` — en: "Tap to enable notifications in Settings so we can send your daily reminder." · vi: "Chạm để bật thông báo trong Cài đặt để nhận nhắc nhở hằng ngày." · fr: "Touchez pour activer les notifications dans Réglages et recevoir votre rappel quotidien."
  > i18n: follow the existing `settings.*` key convention; mirror the exact key set across all 3 locales (tri-locale parity — see the `auxi-i18n-state` memory). Find the actual locale file paths under `auxi/src/translations/` and add the keys in each.
- [ ] **Verify — typecheck + lint + full unit run.** From `auxi/`: `npx tsc --noEmit` (no new errors beyond the `_HomeScreen.tsx` baseline), `yarn lint` (≤ baseline), `yarn jest` (whole suite green — App.test.tsx smoke render must still pass with the new firebase global mock). Then `./scripts/auxi-lint-tokens.sh` from the umbrella root — clean (no hex/font drift; this phase adds no styles).
- [ ] **Commit:** `feat(push): wire register-on-login / unregister-on-logout / tap routing / settings ensure-token`

---

## Task 6: Tracking-plan doc + coordinated native build verify

**Files:**
- Modify: `auxi/docs/analytics/mixpanel-tracking-plan.md` (§5 new subsection + §10 funnel note)

**Interfaces:** Consumes — the 6 shipped events from Tasks 2–4. Produces — the canonical taxonomy entry (mandatory per `.claude/rules/analytics-tracking-required.md`).

- [ ] **Add §5.19 "Push notifications (Phase 1)"** to `auxi/docs/analytics/mixpanel-tracking-plan.md` (insert after §5.18, matching the existing table format with `file:line` once committed):
  ```markdown
  ### 5.19 Push notifications (Phase 1)

  FCM device-token lifecycle + tap routing (push-notification system, Phase 1).
  Permission requested contextually after sign-in (AuthContext identity effect)
  and when enabling the daily reminder (SettingsScreen). All events are
  literal-named via `analytics.ts` helpers.

  | Event | Trigger | Location | Properties |
  |---|---|---|---|
  | `push_permission_requested` | OS notification-permission prompt shown / re-evaluated (login + Settings reminder-enable) | `notificationService.ts` (`requestPushPermission`) via `analytics.ts` | — |
  | `push_permission_granted` | Permission granted or provisionally granted | `notificationService.ts` via `analytics.ts` | — |
  | `push_permission_denied` | Permission denied / not determined | `notificationService.ts` via `analytics.ts` | — |
  | `device_token_registered` | FCM token successfully POSTed to `/api/notifications/device-token` (register + token-refresh re-register) | `notificationService.ts` (`registerCurrentToken`) via `analytics.ts` | — |
  | `push_received` | A push arrived while the app was foregrounded (`onMessage`) | `notificationService.ts` (`registerPushTapHandlers`) via `analytics.ts` | `type` (notification type) |
  | `push_opened` | A push was tapped and routed — cold-start (`getInitialNotification`) or background (`onNotificationOpenedApp`) | `notificationService.ts` (`registerPushTapHandlers`) via `analytics.ts` | `type` (notification type) |

  > PII: none. `type` is the bounded notification-type enum (`daily_reminder` / `planned_outfit` / `admin_broadcast` / `admin_direct` / `admin_segment`) carried in the FCM `data` payload — no token, no deep-link url, no free text. Tokens never enter analytics. Deep-link tap routing uses the curated allowlist (`CURATED_PUSH_SCREENS` in `deepLinkHandler.ts`, the mobile mirror of spec §5.1); the `Creations` registry name maps to the RN route `MyCreations`.
  ```
- [ ] **Add a §10 funnel note** under "Suggested funnels":
  ```markdown
  - **Push opt-in + engagement funnel (push Phase 1):** `push_permission_requested` → `push_permission_granted` → `device_token_registered` measures registration completion (denominator: requested; `push_permission_denied` is the drop branch). Engagement: `push_opened` ÷ `push_received` (foreground) plus cold/background opens — break down by `type` to compare `daily_reminder` vs `planned_outfit` vs `admin_*` open rates.
  ```
- [ ] **Commit:** `docs(analytics): tracking-plan §5.19 + funnel note for push events`
- [ ] **Coordinated native build verify (real device — gated).** Per `.claude/rules/ios-build-workflow-required.md`, confirm with the user that no other Claude Code session is mid-build, THEN: `cd auxi && yarn pods` (iOS pod install for the new firebase pods) → install + run on a **real iOS device** (sim push is unreliable). Send a test push from the Firebase console (or backend) with `data: {kind:'route', screen:'Schedule', type:'planned_outfit'}` → confirm: token registers (backend row exists), tap from quit lands on Schedule, tap from background lands on Schedule, an `external` https payload opens the browser, an unknown payload lands on Home. Verify `push_opened`/`push_received` reach Mixpanel. This is a **manual QA step** (hand off to qa-mobile on a physical device) — not part of CI.

---

## Phase 1 Done When

- [ ] `@react-native-firebase/app` + `@react-native-firebase/messaging` in `package.json` + `yarn.lock`; iOS (`$RNFirebaseAsStaticFramework`, `FirebaseApp.configure()`, `GoogleService-Info.plist`, `aps-environment`, background mode) + Android (`google-services.json`, gradle plugin, `POST_NOTIFICATIONS`) native config in place.
- [ ] `notificationService.ts` ships `registerDeviceForPush` / `unregisterDevice` (+ `ensurePushPermissionAndRegister`, `registerTokenRefreshListener`, `registerPushTapHandlers`) — VERBATIM to the locked surface; `notificationService.web.ts` no-op stub keeps the sandbox building.
- [ ] `deepLinkHandler.ts` exports `resolveNotificationData(data, navRef)` + `CURATED_PUSH_SCREENS`; route/external/unknown all handled, `Creations`→`MyCreations` mapped, never crashes.
- [ ] 6 Mixpanel events shipped via `analytics.ts` literal-name helpers; `mixpanel-tracking-plan.md` §5.19 + §10 updated.
- [ ] Register-on-login (real sign-in only) / unregister-on-logout wired in AuthContext; tap + token-refresh listeners wired in AppNavigator; Settings reminder-enable ensures permission+token with Open-Settings guidance (tri-locale i18n keys added).
- [ ] `cd auxi && npx tsc --noEmit` clean (only the known `_HomeScreen.tsx` baseline), `yarn lint` ≤ baseline, `./scripts/auxi-lint-tokens.sh` clean.
- [ ] `cd auxi && yarn jest` green — including the two new files (`notificationService.test.ts`, `deepLinkHandler.test.ts`) and the existing `App.test.tsx` smoke render (firebase global mock added to `jest.setup.js`).
- [ ] **Real-device manual QA (gated):** a test push with a curated `data` payload registers a token and routes correctly from cold-start, background, and foreground; external/unknown payloads behave per spec. Sim push is unreliable (project memory) → physical device only; final delivery verification is a manual qa-mobile step, not CI.
