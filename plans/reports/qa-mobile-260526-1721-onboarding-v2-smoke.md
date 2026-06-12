# Onboarding V2 + Replay-mode smoke — qa-mobile

**Date**: 2026-05-26 17:21–17:35
**Build**: auxi `feat/onboarding-v2-redesign`, fresh debug build, bundle `com.auxi2026.app`
**Device**: iOS Simulator iPhone 16, iOS 18.2 (`6371F8E8-893E-4D7C-8683-8A128B7996F8`)
**Backend**: prod-mirror local on :5001 (env=development), DB `postgresql://postgres@127.0.0.1:5433/wardrobe_local`
**MCP pre-flight**: `./scripts/mcp-doctor.sh` exit 0 (sim booted, WDA :8100 up, mobile-mcp pinned 0.0.56)

## Verdict

| Test | Result |
|---|---|
| **A — Replay Onboarding dev mode** | **BLOCKED** (could not reach onboarding; auth sign-in blocker) |
| **B — V2 happy path** | **BLOCKED / FAIL** (Maestro flow stale + auth sign-in blocker) |
| **C — Deferred completion** | **BLOCKED** (depends on reaching onboarding) |

App launches clean past splash — **no RNLocalize red-box** (react-native-localize linked OK). The blocker is downstream: the redesigned auth entry dead-ends an existing email/password user, so the onboarding stack is unreachable through the UI.

---

## BLOCKER 1 — Existing email user dead-ends at "Create password"; no Sign-In path from Welcome

**Severity**: blocker (login regression for returning email users)
**Repro rate**: 1/1
**Suspected area**: `auxi/src/screens/auth/EmailInputScreen.tsx:126`

### Repro
1. Launch `com.auxi2026.app` (or Maestro `launchApp clearState clearKeychain`).
2. Auth landing = **WelcomeScreen** (`Welcome to Auxi`, buttons `welcome-cta-google` / `welcome-cta-apple` / `welcome-cta-email`).
3. Tap `welcome-cta-email` → EmailInput screen (`email-input-field`).
4. Enter `qa-test@auxi.app`, submit (`email-submit-button`).
5. Lands on **PasswordCreation** ("Create password", `password-submit-button`, with "At least 8 characters / lowercase / number" criteria) — i.e. signup mode — even though this email is an **existing password account**.

### Root cause (verified)
- `WelcomeScreen.tsx:121-122` — the email CTA is hardcoded `navigation.navigate('EmailInput', { mode: 'signup' })`. There is **no separate Sign-In entry** on the Welcome landing for email users.
- `EmailInputScreen.tsx:118-127` — precheck `onSuccess` routes `google`/`apple` → `EmailGoogleNotice`, but for any other provider (incl. `password`) falls straight through to `navigation.navigate('PasswordCreation', …)`. The `provider:'password'` (existing-user) signal is ignored.
- The screen's own docstring (`EmailInputScreen.tsx:16-20`) states `'password' → navigate to SignIn (existing user) OR PasswordCreation (signup mode)` — the SignIn branch is **not implemented**.

### Backend confirmation (airtight)
```
$ curl -s -X POST http://localhost:5001/api/auth/email-precheck \
    -H "Content-Type: application/json" -d '{"email":"qa-test@auxi.app"}'
{"provider":"password"}
```
Backend correctly reports the email is an existing password account; the client ignores it and routes to create-password. Submitting would 409 (no way for a returning email user to sign in from the Welcome landing).
`GET /api/me` (token from `POST /api/login`) confirms the account exists: `"is_first_login":false`, fully onboarded.

### Routing
- **mobile-dev** (UI/state) — fix `EmailInputScreen` precheck handler to branch `provider:'password'` → `SignIn` (per the screen's own docstring), and/or give WelcomeScreen a sign-in affordance for returning email users.

### Evidence
`auxi/docs/qa-findings/screenshots/2026-05-26/qa-mobile-auth-existing-user-create-password-bug.png`

---

## BLOCKER 2 — Maestro flow `onboarding-v2.yaml` is stale vs the redesigned auth entry

**Severity**: major (flow can't run; regression coverage dark)
**Repro rate**: 1/1
**Failing flow**: `auxi/maestro/flows/onboarding/onboarding-v2.yaml`
**Failing step**: post-launch — `assertVisible: id: auth-email-input` (after `launchApp clearState/clearKeychain`)

### Maestro log excerpt
```
Launch app "com.auxi2026.app" with clear state and clear keychain... COMPLETED
Assert that id: auth-email-input is visible... FAILED
Assertion is false: id: auth-email-input is visible
```

### What's actually on screen
After a clean launch the app shows **WelcomeScreen** (auth-choice landing: Google / Apple / Email), NOT a direct email/password form. The flow expects `auth-email-input` immediately; the redesigned auth now requires:
`welcome-cta-email` → EmailInput (`email-input-field`) → [precheck] → SignIn/PasswordCreation.
Selector `auth-email-input` no longer exists on the entry screen (current IDs: `email-input-field`, `email-submit-button`, `password-input-field`, `password-submit-button`, `signin-*`).

### Routing
- **qa-ui** (flow author) — rewrite the cold-login block to drive the new auth: tap `welcome-cta-email`, type into `email-input-field`, submit, then handle the SignIn screen (blocked until BLOCKER 1 is fixed, since an existing user can't currently reach SignIn through this path). Once fixed, the rest of the flow (`onboarding-welcome-cta` → … → `home-screen-root`) is untested but its selectors should be re-validated.

### Evidence
`auxi/docs/qa-findings/screenshots/2026-05-26/qa-mobile-maestro-welcome-landing-not-email-input.png`
Debug artifacts: `logs/maestro/onboarding-v2-debug/.maestro/tests/2026-05-26_173042/`

---

## OBSERVATION — `home-menu-button` testID missing (Test A entry gap)

The dispatch references `home-menu-button` for opening the Home sidebar, but HomeScreen's hamburger is NOT exposed with that testID in the accessibility tree (tapping its pixel location opened the sidebar, but no `home-menu-button` element is queryable). The Maestro flow header already documents this gap: "the Home Sidebar-open button has NO testID yet (HomeScreen.tsx:1085)". Confirmed still open.
- **Routing**: mobile-dev — add `home-menu-button` testID to the HomeScreen sidebar trigger.

NB: Sidebar rows (`sidebar-menu-setting`) and Settings rows (`settings-replay-onboarding-row`) likewise do not surface as queryable elements in the mobile-mcp tree — they're tappable by coordinate but not by testID lookup. Worth a testID/accessibility pass for deterministic Maestro replay-mode coverage. (Did NOT fully exercise the Replay row — see note below.)

## NOTE — transient "Refreshing…" overlay swallows taps on Home/Settings

During Test A, repeated coordinate taps on the Settings "Replay onboarding (dev)" row and the Dark Mode toggle did not register while a "Refreshing…" banner was present (the upper-screen Daily-reminder toggle DID flip, ruling out a global tap failure). On a fresh screen with no refresh overlay (WelcomeScreen / EmailInput), the same lower-screen y-region taps landed fine. Likely a network-refresh state intercepting touches — not pursued further once BLOCKER 1 made onboarding unreachable. Flagging for awareness; not filed as a separate bug.

---

## State left clean
- `qa-test@auxi.app` `is_first_login` was temporarily set `true` to let Maestro path (A) enter onboarding; **restored to `false`** after the run. Account untouched otherwise (no duplicate created — stopped before submitting Create-password).
- Settings Daily-reminder toggle was flipped during a tap-diagnostic and **restored to ON**.

## Unresolved questions
1. Is the auth redesign (Welcome landing → Email precheck → SignIn/PasswordCreation) intended to ship on `feat/onboarding-v2-redesign`, or did it land here unexpectedly and break the existing-user path? (Determines whether BLOCKER 1 is in-scope for this branch.)
2. Once BLOCKER 1 is fixed, qa-ui must re-author `onboarding-v2.yaml` cold-login; should it use a fresh registered email (true signup) instead of the existing qa-test, to exercise PasswordCreation legitimately?
