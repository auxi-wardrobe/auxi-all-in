# Phase 07 — QA (Maestro Flows + Regression)

**Owner**: qa-ui (authors YAML) + qa-mobile (executes on iOS sim) + qa-ux (heuristic + a11y review)
**Priority**: P1 · **Status**: pending · **Effort**: 3d

## 1. Context Links

- Linear: https://linear.app/duncan-1/issue/AU-242 (28 AC scenarios)
- Memory: `feedback_qa_uses_maestro_only` — qa-ui authors YAML, qa-mobile executes; **no screenshot reasoning**, **no Figma compare in QA**, testID discipline mandatory
- Memory: `qa_test_account` — `qa-test@auxi.app / QaTest!2026` registered against local backend (must re-verify against new register endpoint)
- Skill: `.claude/skills/auxi-qa-test.md` for QA execution conventions
- Gap analysis: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md` §"Recommended sequence" step 7

## 2. Overview

Lock the AU-242 flow with executable QA: 7 Maestro flows covering happy paths + critical edge cases, a per-screen testID audit, a UX heuristic review by qa-ux. Maestro is the gate — manual QA only for system-sheet flows (Apple Sign-In).

## 3. Key Insights

- qa-ui authors YAML against testIDs added in phase 04; qa-mobile runs them. No screenshot diffing.
- Apple Sign-In flow involves a system sheet that Maestro cannot drive — covered by manual checklist instead.
- QA test account `qa-test@auxi.app / QaTest!2026` was registered before this ticket — may need fresh registration since the register endpoint changed (verification gate). Coordinate with backend-dev to confirm grandfather backfill applies.
- Maestro flows live under `auxi/maestro/flows/auth/` per existing convention (verify path during phase 04 audit).
- Resend cooldown timer flow is timing-sensitive — Maestro's `repeat` block + `assertVisible` with cooldown text required.
- Language-switch flow can validate vi-VN locale renders (independent of all other auth state).
- Deep-link in Maestro: `openLink: "auxi://auth/verify?token=..."` or `openLink: "https://auxi.app/auth/verify?token=..."` — confirm Maestro supports both schemes (it does as of recent versions).

## 4. Requirements

### Functional
- 7 Maestro flows authored + green on iOS sim against local backend on :5001.
- Per-screen testID checklist published — every Pressable, TextInput, Radio, submit chevron has a testID.
- qa-ux heuristic review filed as a report under `plans/reports/qa-ux-…-au242.md`.
- QA test account renewed against new endpoints.
- Manual checklist for Apple Sign-In flow (Maestro can't drive system sheet).

### Non-functional
- Flows run in <5 min per flow (Maestro default timeout).
- All flows runnable in CI (defer CI wiring to follow-up if backend service deps complicate it).
- testID naming matches gap analysis L57 convention: `<screen>-<element>` (e.g. `signup-email-input`).

## 5. Architecture

```
auxi/maestro/flows/auth/
  ├─ happy-signup.yaml
  ├─ happy-signin.yaml
  ├─ google-conflict.yaml
  ├─ forgot-password.yaml
  ├─ email-invalid.yaml
  ├─ resend-cooldown.yaml
  ├─ language-switch.yaml
  └─ _shared/
       reset-app-state.yaml      — common setup (clear keychain, reset locale)
       seed-test-user.yaml       — POST /api/register against backend for fresh state

QA test data backend:
  - Local backend on :5001 (per memory + umbrella CLAUDE.md)
  - Email service in DRY_RUN mode → token logged to backend stdout
  - qa-mobile tails backend log to grab verify token, paste into Maestro openLink step

Manual checklist (markdown):
  - apple-sign-in-manual.md  — checklist of expected outcomes since Maestro can't drive
```

## 6. Related Code Files

### Modify
- `auxi/maestro/` directory — verify structure exists; if not, create
- Per-screen testIDs — phase 04 added them; this phase audits

### Create
- `auxi/maestro/flows/auth/happy-signup.yaml`
- `auxi/maestro/flows/auth/happy-signin.yaml`
- `auxi/maestro/flows/auth/google-conflict.yaml`
- `auxi/maestro/flows/auth/forgot-password.yaml`
- `auxi/maestro/flows/auth/email-invalid.yaml`
- `auxi/maestro/flows/auth/resend-cooldown.yaml`
- `auxi/maestro/flows/auth/language-switch.yaml`
- `auxi/maestro/flows/auth/_shared/reset-app-state.yaml`
- `auxi/maestro/flows/auth/_shared/seed-test-user.yaml`
- `auxi/maestro/flows/auth/apple-sign-in-manual.md` (checklist)
- `auxi/maestro/flows/auth/testid-checklist.md` (per-screen testIDs)
- `plans/reports/qa-ux-260522-au242-heuristic-review.md` (qa-ux output)

### Delete
None this phase.

## 7. Implementation Steps

### testID audit (qa-ui — 0.5d)
1. Walk every screen built in phase 04; verify testIDs present + match convention. Document in `testid-checklist.md`:
   - Welcome: `welcome-google-btn`, `welcome-apple-btn`, `welcome-email-btn`, `welcome-lang-link`, `welcome-terms-link`, `welcome-privacy-link`
   - LanguageSettings: `lang-radio-en`, `lang-radio-vi`, `lang-back-btn`
   - EmailInput: `email-input`, `email-submit-chevron`, `email-error-text`
   - PasswordCreate: `pwd-input`, `pwd-submit-chevron`, `pwd-rule-length`, `pwd-rule-lowercase`, `pwd-rule-number`
   - VerifyEmail: `verify-open-mail-btn`, `verify-resend-btn`, `verify-logout-btn`
   - EmailGoogleNotice: `notice-google-btn`
   - SignIn: `signin-email-readonly`, `signin-pwd-input`, `signin-eye-toggle`, `signin-forgot-link`, `signin-submit-chevron`
   - ForgotRequest: `forgot-email-readonly`, `forgot-send-btn`
   - ForgotCheckMail: `forgot-checkmail-back-btn`
   - ResetNewPassword: `reset-pwd-input`, `reset-submit-chevron`, `reset-rule-length`, etc.
   - VerifiedSuccess: `verified-continue-btn`
2. File issues against mobile-dev for any missing testIDs.

### QA test account renewal (qa-mobile — 0.25d)
3. Confirm `qa-test@auxi.app / QaTest!2026` still works against the new register endpoint (with verification gate). Options:
   - (a) Grandfather backfill applied → existing record still verified → login works → use as-is.
   - (b) Backfill didn't catch them → manually mark `email_verified_at` via DB.
   - (c) Fresh account: register `qa-au242@auxi.app` with `QaAu242!2026`, consume verify token from backend log, use for all flows.
4. Document chosen approach in `_shared/seed-test-user.yaml` notes.

### Author 7 Maestro flows (qa-ui — 1d)

5. **happy-signup.yaml** — full signup happy path:
   ```yaml
   appId: com.auxi.app
   ---
   - launchApp
   - tapOn:
       id: "welcome-email-btn"
   - tapOn:
       id: "email-input"
   - inputText: "happy-signup-${RANDOM}@auxi.app"
   - tapOn:
       id: "email-submit-chevron"
   - assertVisible:
       id: "pwd-input"
   - tapOn:
       id: "pwd-input"
   - inputText: "Maestro!2026"
   - assertVisible:
       id: "pwd-rule-length"
       text: ".*"
   - tapOn:
       id: "pwd-submit-chevron"
   - assertVisible:
       id: "verify-resend-btn"
   # Pull verify token from backend stdout (qa-mobile handles this out-of-band)
   - openLink: "auxi://auth/verify?token=${VERIFY_TOKEN}"
   - assertVisible:
       id: "verified-continue-btn"
   - tapOn:
       id: "verified-continue-btn"
   - assertVisible:
       text: "Home"
   ```
6. **happy-signin.yaml** — returning user:
   - Launch → Welcome → Email (`qa-test@auxi.app`) → SignIn → enter password → submit → Home
7. **google-conflict.yaml** — assumes test user `google-only@auxi.app` exists with `provider=google`:
   - Welcome → Email → notice shown → tap `notice-google-btn` → (manual handoff if Maestro can't drive Google sheet) → assert Home OR stop at notice render assertion.
8. **forgot-password.yaml**:
   - Welcome → Email (existing user) → SignIn → tap `signin-forgot-link` → ForgotRequest → tap `forgot-send-btn` → assert ForgotCheckMail visible → openLink with reset token → assert ResetNewPassword visible → enter new password → assert Verified! → continue → assert SignIn visible
9. **email-invalid.yaml**:
   - Welcome → Email → input "not-an-email" → tap submit chevron → assert `email-error-text` visible with localized error
10. **resend-cooldown.yaml**:
    - Sign up new user → land on VerifyEmail → tap `verify-resend-btn` × 3 in rapid succession → assert button shows "(NNs)" text → wait 60s → assert button reverts to default label
11. **language-switch.yaml**:
    - Welcome → tap `welcome-lang-link` → LanguageSettings → tap `lang-radio-vi` → back → assert Welcome shows vi copy (key: `welcome-email-btn` accessibility label contains "Email")

### qa-ux heuristic review (qa-ux — 0.5d)
12. Run heuristic review against all 13 screens. Cover:
    - Nielsen's 10 (visibility, match, control, consistency, error prevention, recognition, efficiency, minimalism, help, recovery)
    - State coverage (loading, empty, error, success, offline)
    - Touch targets ≥44×44
    - Contrast ratios for text (WCAG AA)
    - Dynamic Type — text scales without overflow
    - VoiceOver labels meaningful, focus order logical
13. File `qa-ux-260522-au242-heuristic-review.md` under `plans/reports/`. Findings only — no fix code per qa-ux scope.

### Apple Sign-In manual checklist (qa-mobile — 0.25d)
14. Document expected manual outcomes in `apple-sign-in-manual.md`:
    - Tap "Continue with Apple" on Welcome → Apple sheet appears
    - First sign-in: full-name shown, email shown OR private-relay option offered
    - Tap "Continue" → app receives identity token → backend creates user → Home shown
    - Subsequent sign-in: name NOT shown again (Apple behavior)
    - Cancel: sheet dismisses, user lands back on Welcome (no error toast)
    - Sign in with relayed email → confirm backend stores `apple_private_relay=true`

### Final gate (qa-mobile — 0.5d)
15. Run all 7 Maestro flows on iOS sim against local backend on :5001 with email-service in DRY_RUN.
16. Verify each flow green; if a flow fails, file a bug back to mobile-dev with screen + assertion that failed.
17. Run Apple manual checklist on real device (sim doesn't support Apple Sign-In well).
18. Confirm `cd auxi && npx tsc --noEmit && yarn lint` + `cd wardrobe-backend && python test_server.py` all green.

## 8. Todo List

- [ ] testID audit per screen — publish checklist
- [ ] File missing-testID bugs back to mobile-dev (if any)
- [ ] Renew QA test account against new endpoints
- [ ] Maestro flow: happy-signup
- [ ] Maestro flow: happy-signin
- [ ] Maestro flow: google-conflict (notice render assertion + manual handoff)
- [ ] Maestro flow: forgot-password
- [ ] Maestro flow: email-invalid
- [ ] Maestro flow: resend-cooldown
- [ ] Maestro flow: language-switch
- [ ] Manual: apple-sign-in-manual.md
- [ ] qa-ux heuristic review report filed
- [ ] All flows green on iOS sim against local backend
- [ ] `npx tsc --noEmit && yarn lint` green
- [ ] `python test_server.py` green

## 9. Success Criteria

- All 7 Maestro flows pass on iOS sim with local backend running.
- Per-screen testID checklist complete, no gaps.
- Apple Sign-In manual checklist passes on real device.
- qa-ux heuristic review report filed with severity-ranked findings.
- All 28 AC scenarios from AU-242 ticket mapped to at least one Maestro flow or manual step.
- No critical or high-severity UX findings outstanding before ticket close (medium/low can ship with follow-up tickets).

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Maestro doesn't support `openLink` with custom scheme | Low | Medium | Verify during phase setup; if unsupported, use Universal Link (`https://auxi.app/...`) — falls back to `auxi://` regardless |
| Resend cooldown flow flaky due to timer drift | Medium | Low | Use Maestro `extendedWaitUntil` with id assertion + text assertion combo; allow ±5s tolerance |
| Maestro YAML version mismatch with installed CLI | Low | Low | Pin Maestro version in `.maestro/config.yaml` if available |
| Email-service DRY_RUN doesn't expose token cleanly to Maestro | Medium | Medium | Add a /test-only endpoint `GET /api/_test/last-token?email=` (env-gated to DEV only) so Maestro can fetch the token via HTTP step |
| QA test account state pollution between flows | Medium | Medium | Use `${RANDOM}` for happy-signup; isolate flows; add `reset-app-state.yaml` before each |
| Apple Sign-In can't be automated → false confidence | Medium | High | Make manual checklist explicit + sign-off required before ticket close |
| qa-ux findings open new tickets that block ship | Medium | Medium | Triage with PM — only critical/high block AU-242; everything else becomes follow-up |
| Locale switch test relies on Vietnamese strings shipped — Viet hasn't translated yet | High | Low | Test against the en-as-placeholder values; full vi assertions in follow-up after Viet translates |

## 11. Security Considerations

- Maestro flows must NOT commit real passwords or tokens. Use `${RANDOM}` or env-injected creds.
- `/api/_test/last-token` endpoint (if added) MUST be env-gated to DEV/TEST only; assert 404 in prod build.
- QA test account password (`QaTest!2026`) is acceptable in a memory note but should NOT be in any committed Maestro YAML.
- Heuristic review must check that error messages don't leak server internals (e.g. SQL errors, stack traces).
- VoiceOver labels for password fields must not read out the password value (`accessibilityElementsHidden` on the value when in secureText mode).

## 12. Next Steps

- Follow-up: wire Maestro flows into CI once backend service deps are dockerized.
- Follow-up: add visual regression suite (out of scope per qa-ui memory note — Maestro only).
- Follow-up: extend flows for Android (deferred until Android-priority cycle).
- Follow-up tickets per any high/medium qa-ux findings.

**Status**: pending
**Summary**: 7 Maestro flows + per-screen testID audit + qa-ux heuristic review + Apple manual checklist. ~3 dev-days. Gates ticket close.
**Concerns/Blockers**: phase 04 testID coverage must be complete before flow authoring starts. Email-service DRY_RUN token exposure needs a test-only endpoint or backend-log grep step — confirm with backend-dev.
