# Phase 05 — OAuth (Google + Apple)

**Owner**: mobile-dev + backend-dev (parallel slice — kicks off once phase 02 ships `/auth/google` + `/auth/apple` routes)
**Priority**: P1 · **Status**: pending · **Effort**: 4d

## 1. Context Links

- Linear: https://linear.app/duncan-1/issue/AU-242 (AC scenarios — Google + Apple in welcome flow)
- Spec: `plans/260521-2335-au-242-figma-spec/01-welcome.md` (Google/Apple CTAs), `07-email-google-notice.md` (forced Google for linked email)
- Gap analysis: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md` L74-78 (backend Google/Apple routes), L54 (mobile SDK install), L88 OQ#21 (provisioning blocker)

## 2. Overview

Wire Google + Apple OAuth on mobile, connecting to `/api/auth/google` + `/api/auth/apple` (phase 02). iOS-first per Auxi MVP context — Android Google works "for free", Apple button hidden on Android.

## 3. Key Insights

- No OAuth SDKs in `package.json` per gap analysis L54 — must install.
- Apple Sign-In requires Apple Developer entitlement + xcode capability — OQ#21 blocker (assume provisioned per recent TestFlight work, but tech-lead to verify).
- Apple only sends user's full name on **first** sign-in — backend must persist `display_name` on first encounter (covered in phase 02).
- Apple private-relay email (`@privaterelay.appleid.com`) handled server-side; mobile just passes the identity token through.
- Google needs OAuth 2.0 client IDs: iOS client (for the SDK), web client (for the backend ID-token verification). Both go in `GoogleService-Info.plist` + backend env.
- OAuth account collision risk: user signed up with email/password earlier, now uses Google with same email → backend must decide: link accounts? reject? (See AC high-risk #4 — gap analysis flags this.)

## 4. Requirements

### Functional
- Welcome screen "Continue with Google" → triggers Google Sign-In SDK → on success, get ID token → POST to `/api/auth/google` → store returned access+refresh tokens via `setTokens()` → navigate to Home.
- Welcome screen "Continue with Apple" (iOS only — hidden on Android) → triggers Apple Sign-In → on success, get identity token + authorization code + name (first encounter only) → POST to `/api/auth/apple` → tokens → Home.
- Email-Google notice screen (spec 07) CTA "Continue with Google" → same Google flow.
- OAuth cancel by user → return to Welcome (per AC: "OAuth cancel returns to Welcome").
- Account collision: backend returns `409 { code: 'account_exists_with_password' }` → mobile shows modal "An account with this email already exists. Sign in with password?" → CTA to SignIn pre-filled.
- Apple `name` field captured on first encounter and posted to backend; subsequent sign-ins don't include name (Apple SDK contract).

### Non-functional
- iOS sim verification with real OAuth round-trip (use staging client IDs).
- Apple button hidden on Android via `Platform.OS === 'ios'` check.
- Cold-start path: existing OAuth session (refresh token in Keychain) → silent sign-in via refresh, no SDK call.

## 5. Architecture

```
Welcome.tsx
  ├─ "Continue with Google" Pressable
  │     ↓
  │   useGoogleSignIn() hook
  │     ↓
  │   GoogleSignin.signIn() → { idToken }
  │     ↓
  │   useGoogleSignInMutation → POST /api/auth/google
  │     ↓
  │   setTokens() → navigate Home
  │
  └─ "Continue with Apple" Pressable (iOS only)
        ↓
      useAppleSignIn() hook
        ↓
      appleAuth.performRequest({
        requestedOperation: LOGIN,
        requestedScopes: [EMAIL, FULL_NAME]
      })
        ↓
      { identityToken, authorizationCode, fullName }
        ↓
      useAppleSignInMutation → POST /api/auth/apple
        ↓
      setTokens() → navigate Home
```

Files:
```
auxi/src/services/oauth/
  google-signin.ts       — wrapper around @react-native-google-signin/google-signin
  apple-signin.ts        — wrapper around @invertase/react-native-apple-authentication
  oauth-errors.ts        — mapping SDK errors → AuthError
auxi/src/hooks/auth/
  use-google-signin-mutation.ts
  use-apple-signin-mutation.ts
```

## 6. Related Code Files

### Modify
- `auxi/package.json` — add deps:
  - `@react-native-google-signin/google-signin` (latest stable)
  - `@invertase/react-native-apple-authentication`
- `auxi/ios/Auxi/Info.plist` — add Google URL scheme (reversed client ID)
- `auxi/ios/Auxi.xcodeproj/project.pbxproj` — Sign in with Apple capability
- `auxi/ios/Auxi/GoogleService-Info.plist` — drop in from Google Cloud Console
- `auxi/android/app/build.gradle` — Google Sign-In deps (later — iOS-first)
- `auxi/src/screens/WelcomeScreen.tsx` — wire OAuth buttons (was placeholder in phase 04)
- `auxi/src/screens/auth/email-google-notice-screen.tsx` — wire Google CTA (was placeholder)
- `auxi/src/services/authService.ts` — add `googleSignIn(idToken)`, `appleSignIn(identityToken, authCode, name?)`
- `auxi/src/context/AuthContext.tsx` — add `signInWithGoogle`, `signInWithApple` methods
- `auxi/App.tsx` — `GoogleSignin.configure({ webClientId, iosClientId })` on startup
- `wardrobe-backend/.env.example` — add `GOOGLE_OAUTH_WEB_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`

### Create
- `auxi/src/services/oauth/google-signin.ts` — typed wrapper
- `auxi/src/services/oauth/apple-signin.ts` — typed wrapper
- `auxi/src/services/oauth/oauth-errors.ts` — SDK error mapper
- `auxi/src/hooks/auth/use-google-signin-mutation.ts`
- `auxi/src/hooks/auth/use-apple-signin-mutation.ts`

### Delete
None this phase.

## 7. Implementation Steps

### Pre-flight (OQ#21 — tech-lead verifies before kick-off)
1. Confirm Apple Developer account has Sign in with Apple capability enabled for `com.auxi.app` (or current bundle ID).
2. Create Google Cloud OAuth 2.0 client IDs: iOS client (for SDK) + web client (for backend `audience` verification). Download `GoogleService-Info.plist`.
3. Generate Apple Sign In with Apple private key (`.p8`) + Key ID + Team ID. Store backend-side as env vars.

### Mobile install
4. `cd auxi && yarn add @react-native-google-signin/google-signin @invertase/react-native-apple-authentication`
5. `cd ios && pod install`
6. Add Google `Info.plist` URL scheme (reversed client ID) — `auxi/ios/Auxi/Info.plist`.
7. Xcode: enable "Sign in with Apple" capability on the Auxi target.
8. Drop `GoogleService-Info.plist` into `auxi/ios/Auxi/`. Add to Xcode project resources.
9. `App.tsx` — call `GoogleSignin.configure({ webClientId: process.env.GOOGLE_WEB_CLIENT_ID, iosClientId: process.env.GOOGLE_IOS_CLIENT_ID, offlineAccess: false })`.

### Mobile wiring
10. Create `services/oauth/google-signin.ts`:
    ```ts
    export async function googleSignInRequest(): Promise<{ idToken: string }> {
      await GoogleSignin.hasPlayServices();
      const user = await GoogleSignin.signIn();
      if (!user.idToken) throw new OAuthError('no_id_token');
      return { idToken: user.idToken };
    }
    ```
11. Create `services/oauth/apple-signin.ts`:
    ```ts
    export async function appleSignInRequest(): Promise<{
      identityToken: string;
      authorizationCode: string;
      fullName?: { givenName?: string; familyName?: string };
    }> {
      const res = await appleAuth.performRequest({
        requestedOperation: appleAuth.Operation.LOGIN,
        requestedScopes: [appleAuth.Scope.EMAIL, appleAuth.Scope.FULL_NAME],
      });
      if (!res.identityToken) throw new OAuthError('no_identity_token');
      return { identityToken: res.identityToken, authorizationCode: res.authorizationCode!, fullName: res.fullName };
    }
    ```
12. Map SDK errors in `oauth-errors.ts` — at minimum: `SIGN_IN_CANCELLED` → silent (return to Welcome), `PLAY_SERVICES_NOT_AVAILABLE` → friendly alert, `NETWORK_ERROR` → toast.
13. Create mutation hooks calling `authService.googleSignIn(idToken)` / `authService.appleSignIn(...)`.
14. Wire Welcome CTAs:
    ```ts
    const onGoogle = async () => {
      try {
        const { idToken } = await googleSignInRequest();
        await signInWithGoogle(idToken);  // AuthContext method
        navigation.reset({ index: 0, routes: [{ name: 'Home' }] });
      } catch (e) {
        if (isCancelled(e)) return;
        showAlert(e);
      }
    };
    ```
15. Apple CTA — gate `Platform.OS === 'ios'` before render.
16. Wire EmailGoogleNotice CTA to same Google flow.
17. Handle account collision: if backend returns `409 account_exists_with_password`, show modal → navigate SignIn with prefilled email.

### Backend wiring (in conjunction with phase 02 routes)
18. `wardrobe-backend/routers/auth.py` Google route: use `google.oauth2.id_token.verify_oauth2_token(token, requests.Request(), GOOGLE_WEB_CLIENT_ID)` — verify audience matches our web client ID. Extract `sub`, `email`, `email_verified`, `name`, `picture`.
19. Backend Apple route: fetch + cache Apple JWKS, verify JWT signature + audience (bundle ID) + issuer (`https://appleid.apple.com`). Extract `sub`, `email`, `email_verified`. Check if email ends with `@privaterelay.appleid.com` → set `apple_private_relay=true`. Accept `name` from request payload (first encounter only).
20. Upsert user by `(oauth_provider, oauth_subject)` unique pair. If a user already exists with the same email but `oauth_provider=NULL` → return 409 `{ code: 'account_exists_with_password' }` (defer linking; PM decision per AC high-risk #4).
21. On success: issue access + refresh tokens, set `email_verified_at = now()` (Google/Apple vouch for email).

### Verification
22. iOS sim: `Continue with Google` round-trips against staging backend → user lands on Home. Repeat for Apple.
23. Apple second sign-in test: confirm name is NOT re-sent by Apple (validates first-encounter persistence works on backend).
24. Account collision test: register `foo@bar.com` via email/password, then attempt Google with same email → modal shown, navigate to SignIn.
25. Cancel test: tap Google → SDK opens sheet → swipe down to cancel → app returns silently to Welcome.

## 8. Todo List

- [ ] Pre-flight: OAuth provisioning verified by tech-lead (OQ#21)
- [ ] `yarn add` Google + Apple SDKs
- [ ] `pod install` + Xcode capability + GoogleService-Info.plist drop-in
- [ ] `App.tsx` `GoogleSignin.configure`
- [ ] `services/oauth/google-signin.ts` wrapper
- [ ] `services/oauth/apple-signin.ts` wrapper
- [ ] `oauth-errors.ts` SDK error mapping
- [ ] Mutation hooks for Google + Apple sign-in
- [ ] Wire Welcome buttons + EmailGoogleNotice CTA
- [ ] Apple button hidden on Android via `Platform.OS` check
- [ ] Backend `/api/auth/google` route — Google ID-token verify
- [ ] Backend `/api/auth/apple` route — Apple JWT verify + JWKS cache + private-relay handling
- [ ] Backend account-collision response (409)
- [ ] Mobile account-collision modal + SignIn pre-fill flow
- [ ] iOS sim: Google + Apple happy path round-trip
- [ ] Cancel + collision test scenarios
- [ ] Android build still passes (Apple hidden, Google works)

## 9. Success Criteria

- iOS sim: tapping "Continue with Google" opens Google Sign-In sheet, returns to app on Home with valid session (refresh works after restart).
- iOS sim: tapping "Continue with Apple" opens Apple sheet, returns to app on Home; on subsequent launches `appleAuth.getCredentialStateForUser` returns `AUTHORIZED`.
- Email-Google notice flow (screen 7): tapping CTA bypasses password and signs in via Google.
- Account collision: existing email/password user attempting Google sign-in with same email gets clear UX path to sign in.
- Android: Apple button absent; Google button works (parking Android-specific bugs for follow-up if any).
- `npx tsc --noEmit && yarn lint` pass.

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Apple Developer entitlement not provisioned | Medium | High | **Pre-flight check by tech-lead before phase starts** — if missing, kick off provisioning ticket and pause Apple slice (Google can ship first) |
| Google web client ID misconfigured → backend rejects ID token (`Invalid audience`) | Medium | High | Test against staging early; document `audience` mismatch as #1 OAuth bug to check |
| Apple private-relay email creates user records that cannot be reached via email | High | Low | Accept per spec; store flag; PM informed via project changelog |
| Account collision UX confuses user (they don't remember password) | High | Medium | Modal includes "Forgot your password?" link → ForgotRequest pre-filled with email |
| First-encounter Apple name lost if backend write fails | Low | Low | Wrap upsert in try/catch — if name write fails, sign-in still succeeds; name backfill via support |
| `appleAuth.getCredentialStateForUser` slows cold start | Low | Low | Run async, don't block first paint |
| Google SDK conflicts with Firebase (if Firebase ever added) | Low | Medium | Document for future Firebase integration; not blocking now |
| Bundle size increase from two SDKs | Medium | Low | Measure before/after; tree-shaking should keep <500KB additional |

## 11. Security Considerations

- Google ID token + Apple identity token must be verified server-side — never trust client-decoded JWT.
- `nonce` parameter: Google + Apple support nonce in ID token for CSRF protection — implement nonce challenge per SDK docs (mobile generates nonce, posts to backend, backend verifies nonce in token claims).
- Apple identity token replay: backend tracks the `jti` claim if Apple includes one (it does in modern tokens) to prevent replay.
- Account collision response (`account_exists_with_password`) is itself an enumeration leak — accept for v1 because alternative (silent merge) is worse from a security POV.
- Backend audience claim must match the iOS bundle ID, not the web client ID, for Apple verification.
- `GoogleService-Info.plist` contains client ID but no secret — safe to ship in app bundle. Web client secret stays backend-only.

## 12. Next Steps

- Phase 06 email service handles OAuth users too (no verify email needed but welcome email TBD with PM).
- Phase 07 QA adds Maestro flow for Google happy path; Apple flow harder to Maestro (system sheet) — defer to manual QA.
- Follow-up ticket: Android Apple Sign-In via web view (out of scope here).

**Status**: pending
**Summary**: Two OAuth SDKs + backend token verification + collision handling. ~4 dev-days. Apple is iOS-only; Google works cross-platform.
**Concerns/Blockers**: OQ#21 OAuth provisioning is the gating item. Account-link policy (collision UX) needs PM sign-off — current default is "go to sign-in with existing password" (no auto-link).
