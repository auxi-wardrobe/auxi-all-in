# QA-Mobile — Gmail Login Fix E2E Verify

**Date:** 2026-06-25
**Branch:** fix/gmail-login-password-path (HEAD bce80e4a)
**Device:** iOS Simulator iPhone 17 (UDID 49C350AB-FD18-4311-BFC7-26989F6062A1), iOS 26.5
**App:** Macgie (com.auxi2026.app)
**Backend:** :5001 healthy (development)
**Lane:** mobile-mcp exploratory verify (no Maestro flow for this path yet)

## Verdict: PASS

The gmail-domain short-circuit is gone. A gmail address at the login email step
no longer force-navigates to the "Sign in with Google" notice — it flows through
the normal precheck and reaches a **password screen** with a real password input
field. A non-gmail address behaves identically (sanity check passed). No crash,
no redbox, no stale bundle.

## Per-step results

### Step 1 — Reach the email-input step
- Launched the app; it opened already logged out on the **Welcome** screen (no
  log-out needed).
- Tapped "Continue with Email" (`welcome-cta-email`) → reached **EmailInput**
  (`email-input-label` = "What is your email", `email-input-field`,
  `email-submit-button` present).
- Screenshot: `auxi/docs/qa-findings/screenshots/2026-06-25/qa-mobile-step1-email-input.png`

### Step 2 — PRIMARY (the fix): gmail address
- Typed `tester@gmail.com`, submitted via the inline chevron button.
- **Resulting screen: PasswordCreation (a password screen) — NOT EmailGoogleNotice.**
- Element evidence on the resulting screen:
  - `password-input-field` (SecureTextField) — **password field PRESENT** ✅
  - `password-email-value` = "tester@gmail.com"
  - `password-submit-button` ("Create password"), `password-visibility-show`,
    and `password-criteria-length / -lowercase / -digit` rules present
  - **No "Continue with Google" button, no EmailGoogleNotice** ✅
- Screenshot (decisive): `auxi/docs/qa-findings/screenshots/2026-06-25/qa-mobile-step2-gmail-routes-to-password.png`

### Step 3 — Sanity: non-gmail address
- Relaunched to a clean email field, typed `tester@outlook.com`, submitted via
  the keyboard "Go" key.
- **Resulting screen: PasswordCreation — same as gmail.**
- Element evidence: `password-input-field` present, `password-email-value` =
  "tester@outlook.com", no Google notice. Behavior identical to gmail → confirms
  no domain-based branching remains.
- Screenshot: `auxi/docs/qa-findings/screenshots/2026-06-25/qa-mobile-step3-nongmail-routes-to-password.png`

## Note on mode (signup vs signin)

The task anticipated landing on the **SignIn** screen (signin mode). In the
logged-out auth flow, the only reachable EmailInput entry is from Welcome's
"Continue with Email", which navigates `EmailInput` with **`mode: 'signup'`**
(`WelcomeScreen.tsx:145`). There is no logged-out UI entry into
`mode: 'signin'` — the only `mode: 'signin'` navigation in the codebase is from
`HomeScreen` (a logged-in re-auth path, `HomeScreen/index.tsx:1351-1352`).

This does NOT weaken the verdict. The removed bug (AU-313 gmail short-circuit)
fired BEFORE the precheck and was mode-agnostic — it would have steered gmail to
`EmailGoogleNotice` in any mode. The decisive assertion is "gmail → Google notice
(bug) vs gmail → password screen (fixed)", and that is fully proven. Mode only
changes WHICH password screen (signup→PasswordCreation, signin→SignIn per
`EmailInputScreen.tsx:170` / `:192`); both are password screens, neither is the
Google notice. Code confirms no gmail-domain branch remains in
`EmailInputScreen.tsx` (only an explanatory doc-comment for the revert).

## Blockers
None. App launched fine, logged-out flow reachable without log-out, fix bundle
was live on first launch (no reload needed), no auxi crash in the crash log
(only unrelated `com.apple.dock` system crashes).

## Evidence paths
- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/qa-findings/screenshots/2026-06-25/qa-mobile-step1-email-input.png`
- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/qa-findings/screenshots/2026-06-25/qa-mobile-step2-gmail-routes-to-password.png`
- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/qa-findings/screenshots/2026-06-25/qa-mobile-step3-nongmail-routes-to-password.png`
- Fix under test: `/Users/nguyenminhduc/dev/wardrobe_project/auxi/src/screens/auth/EmailInputScreen.tsx`
