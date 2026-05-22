# Phase 04 — Screens (11 New + 2 Modified)

**Owner**: mobile-dev (follows `figma-design-extraction` + `figma-to-rn-workflow` skills together — designer Viet Tran is CEO; visual fidelity non-negotiable)
**Priority**: P1 · **Status**: pending · **Effort**: 7d

## 1. Context Links

- Linear: https://linear.app/duncan-1/issue/AU-242 (28 AC scenarios)
- Figma: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-8205&m=dev
- 13 spec files: `plans/260521-2335-au-242-figma-spec/01-welcome.md` through `13-verified-success.md`
- Gap analysis: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md` §"Mobile (auxi/) — Screens"

## 2. Overview

Implement the 11 net-new screens + rewrite `WelcomeScreen.tsx` + `LoginScreen.tsx`. Land in dependency order. Vertical slice first: Welcome → Email → Password → Verify → Verified! is the MVP signup path; ship that before forgot/reset/Google-notice screens.

## 3. Key Insights

- Existing `AuthStackParamList = { Login; Register }` (only 2 routes). Must extend to 11+ routes with TS-typed params — registered both in `types/navigation.ts` and `navigation/AuthNavigator.tsx` per `auxi/CLAUDE.md` rule.
- Welcome currently routes to `LocationPermission` after "Get started — takes 1 min" — rewrite to show 3 social buttons + language link.
- `AuthLayout.tsx` is decorative (SVG circles + gradient) — **obsolete** for UAC; new screens are flat with bottom-anchored vertical stacks. Keep AuthLayout for legacy fallback (feature-flag), delete in cleanup phase.
- `RegisterScreen.tsx` (current) requires confirm-password — gone in new spec (no confirm-password field). Delete after #3/#4/#5 ship.
- Screens 3+8 are the same screen with two states (input vs error); screens 4+5 same (typing vs valid). Implement as single component each with state.
- testID discipline mandatory per memory note `feedback_qa_uses_maestro_only` — naming: `<screen>-<element>` (e.g. `signup-email-input`, `verify-email-resend`).
- "English"/Vietnamese link on Welcome (OQ#19) — implement as text button navigating to LanguageSettings, NOT a bottom sheet (KISS, matches Figma).

## 4. Requirements

### Functional
- All 28 AC scenarios from AU-242 pass on iOS sim.
- Each screen registered with typed params in `AuthStackParamList`.
- testIDs present on every Pressable, TextInput, Radio, submit chevron.
- Inline submit chevron (Figma circular icon) on screens 3/4/5/8/9/12 acts as primary CTA (per OQ#8 — implement as labeled-icon button; designer to confirm if label needed). Disabled state when form invalid.
- Resend cooldown on screen 6: 60s countdown, button label `Resend verification email (NNs)` while counting, reverts to `Resend verification email` at 0.
- Password criteria checklist (screens 4/5/12): 3 rules (≥8 chars, lowercase, number). Each row swaps icon color from `uacTextSubtle200` (pending) to `uacTextSubtle100` (satisfied). Per OQ#7 default: just color change, no SVG swap.
- Language Settings (screen 2) writes to AsyncStorage + calls `i18n.changeLanguage`.
- Email-Google notice (screen 7) renders only when `/account-by-email` returns `provider: 'google'`. CTA triggers Google OAuth (handed off to phase 05).
- Verified! (screen 13) routes per OQ#13 — placeholder: signup → Home (since AU-243 not yet shipped); reset → Sign in pre-filled.
- Deep-link handler accepts `auxi://auth/verify?token=…` → triggers `verifyEmail` mutation → navigate to Verified!; accepts `auxi://auth/reset?token=…` → navigate to ResetNewPassword.

### Non-functional
- Visual fidelity to Figma (mobile-dev runs `figma-design-extraction` skill first).
- iOS sim verification on every screen (per memory: "mobile-dev fixes stay code-only" + Figma-faithful workflow).
- Each screen file <200 lines (split components per `development-rules.md`).
- Dynamic Type + VoiceOver labels on all interactive elements.

## 5. Architecture

```
AuthStackParamList (new):
  Welcome: undefined
  LanguageSettings: undefined
  EmailInput: { mode: 'signup' | 'signin' }  // distinguishes flow
  PasswordCreate: { email: string }
  VerifyEmail: { email: string }
  EmailGoogleNotice: { email: string }
  SignIn: { email: string }                  // email always prefilled
  ForgotRequest: { email: string }
  ForgotCheckMail: { email: string }
  ResetNewPassword: { token: string; email?: string }
  VerifiedSuccess: { origin: 'signup' | 'reset' }
  // legacy (feature-flagged):
  Login: undefined
  Register: undefined

Screen → AuthContext → mutation hook → service → backend
  ↓                                                ↓
  navigation.navigate(next, params)        ←  response routes
```

Branching at EmailInput.onSubmit:
```
GET /account-by-email?email=…
  ├─ unknown   → PasswordCreate (signup)
  ├─ email     → SignIn (returning user)
  ├─ google    → EmailGoogleNotice
  └─ apple     → EmailGoogleNotice (variant copy) — TBD with Viet
  ├─ 429/500   → inline error
  └─ invalid format → EmailInput error state (screen 8)
```

If OQ#26 vetoes account-by-email: skip the lookup, always route to PasswordCreate; surface "this email uses Google" only post-failed-login (different flow — flag with PM if direction flips).

## 6. Related Code Files

### Modify
- `auxi/src/screens/WelcomeScreen.tsx` — rewrite per spec 01
- `auxi/src/screens/auth/LoginScreen.tsx` — rewrite per spec 09 (becomes SignIn)
- `auxi/src/navigation/AuthNavigator.tsx` — register 11+ new routes
- `auxi/src/types/navigation.ts` — extend `AuxiAuthStackParamList`
- `auxi/App.tsx` (or `RootLayout`) — add deep-link handler for `auxi://auth/{verify,reset}`
- `auxi/src/context/AuthContext.tsx` — wire `pendingEmail` reads from screens (state added in phase 03)

### Create
- `auxi/src/screens/auth/language-settings-screen.tsx`
- `auxi/src/screens/auth/email-input-screen.tsx` (handles spec 03 + spec 08 error state)
- `auxi/src/screens/auth/password-create-screen.tsx` (spec 04 + 05)
- `auxi/src/screens/auth/verify-email-screen.tsx` (spec 06)
- `auxi/src/screens/auth/email-google-notice-screen.tsx` (spec 07) — conditional on OQ#26
- `auxi/src/screens/auth/forgot-request-screen.tsx` (spec 10)
- `auxi/src/screens/auth/forgot-check-mail-screen.tsx` (spec 11)
- `auxi/src/screens/auth/reset-new-password-screen.tsx` (spec 12)
- `auxi/src/screens/auth/verified-success-screen.tsx` (spec 13)
- `auxi/src/components/auth/uac-header.tsx` — 107px top bar with back chevron + empty 47×47 trailing slot (OQ#6 — placeholder until product confirms)
- `auxi/src/components/auth/uac-primary-button.tsx` — 56h dark CTA
- `auxi/src/components/auth/uac-secondary-button.tsx` — 56h outlined
- `auxi/src/components/auth/uac-text-field.tsx` — M3 outlined + filled (read-only) variants
- `auxi/src/components/auth/uac-submit-chevron.tsx` — circular icon button (56×57)
- `auxi/src/components/auth/password-criteria-checklist.tsx` — 3-row checklist
- `auxi/src/utils/password-rules.ts` — validator returning `{ length: bool; lowercase: bool; number: bool; allValid: bool }`
- `auxi/src/utils/deep-link-handler.ts` — parses `auxi://auth/...` and dispatches navigation

### Delete (after vertical slice ships and flag flips ON)
- `auxi/src/screens/auth/RegisterScreen.tsx` (replaced by EmailInput + PasswordCreate)
- `auxi/src/components/layout/AuthLayout.tsx` (replaced by flat UAC layout) — keep for now, delete in cleanup phase

## 7. Implementation Steps

Build in 5 vertical slices. Land each slice (screens + navigator wiring + i18n keys + sim verification) before starting the next.

### Slice A — Foundation components + navigator + Welcome (~1.5d)
1. Build `uac-header.tsx`, `uac-primary-button.tsx`, `uac-secondary-button.tsx`, `uac-text-field.tsx`, `uac-submit-chevron.tsx`.
2. Extend `AuthStackParamList` with all 11 new route types.
3. Register all 11 routes in `AuthNavigator.tsx` (stub components for ones not yet built).
4. Rewrite `WelcomeScreen.tsx` per spec 01 — 3 social buttons + "English" link to LanguageSettings + Terms/Privacy footer. Brand mark placeholder pending OQ#1.
5. Sim verify Welcome against Figma.

### Slice B — Signup happy path (~2d)
6. Build `language-settings-screen.tsx` per spec 02 — M3 radio list, persist to AsyncStorage.
7. Build `email-input-screen.tsx` per spec 03 + 08 error state.
   - State: `email`, `error: 'invalid' | 'required' | null`, `loading`.
   - On submit: validate format → call `useAccountByEmailQuery` → branch per result.
8. Build `password-criteria-checklist.tsx` + `password-rules.ts`.
9. Build `password-create-screen.tsx` per spec 04 + 05.
   - State: `password`, `criteria = validatePassword(password)`. Submit chevron disabled until `criteria.allValid`.
   - On submit: call `useRegisterMutation` with `{ email: pendingEmail, password }` → on success navigate to VerifyEmail.
10. Build `verify-email-screen.tsx` per spec 06.
    - 60s cooldown timer state (useEffect with setInterval).
    - "Open mail app" → `Linking.openURL('message://')` on iOS (Mail app) with fallback to `mailto:`.
    - "Resend" calls `useResendVerificationMutation`, restart timer.
    - Logout text button top-right → `AuthContext.logout()`.
11. Build `verified-success-screen.tsx` per spec 13. Continue CTA branches on `route.params.origin`.
12. Wire deep-link handler in `App.tsx`: on `auxi://auth/verify?token=…` → call `useVerifyEmailMutation` → navigate to VerifiedSuccess with `origin: 'signup'`.
13. Sim verify full happy path: Welcome → Email (new) → Password → Verify → tap deep-link in Safari/sms → Verified! → Continue.

### Slice C — Signin path (~1d)
14. Rewrite `LoginScreen.tsx` per spec 09 (rename file to `signin-screen.tsx` or keep file but rename route to `SignIn`).
    - Email field is filled-readonly with `pendingEmail`.
    - Password outlined w/ eye toggle (OQ#12 — implement eye/eye-off swap).
    - "Forgot your password?" link → navigate to ForgotRequest with email.
    - Submit chevron on password row → `useLoginMutation`.
    - Drop existing "Don't have an account? Sign Up" footer.
15. Wire EmailInput → SignIn branch.
16. Sim verify signin happy path: Welcome → Email (returning user) → SignIn → Home.

### Slice D — Forgot/reset (~1.5d)
17. Build `forgot-request-screen.tsx` per spec 10. Email filled-readonly. "Send reset password" → `useForgotPasswordMutation` → navigate to ForgotCheckMail.
18. Build `forgot-check-mail-screen.tsx` per spec 11. "Back to Login" → pop to SignIn (OQ#14 default). Per OQ#15 do NOT add "Open mail app" until PM confirms (Figma doesn't have it).
19. Build `reset-new-password-screen.tsx` per spec 12. Reuses `password-criteria-checklist`. On submit: `useResetPasswordMutation` → navigate to VerifiedSuccess with `origin: 'reset'`.
20. Wire deep-link `auxi://auth/reset?token=…` → ResetNewPassword.
21. Sim verify forgot/reset path: Welcome → Email → Forgot → CheckMail → tap reset link → ResetNewPassword → Verified! → Sign in pre-filled.

### Slice E — Google-notice + polish (~1d)
22. Build `email-google-notice-screen.tsx` per spec 07. "Continue with Google" → triggers Google OAuth (handoff to phase 05; placeholder Alert until phase 05 lands).
23. i18n full pass — every hard-coded string moved to `boilerplate.uac.*` namespace. Confirm vi-VN.json has all keys (Viet translates in parallel).
24. testID coverage audit — per gap analysis L57 naming convention.
25. Dynamic Type + VoiceOver pass — `accessibilityLabel` + `accessibilityRole` on every interactive element.
26. Final lint + tsc + sim cold-start verification.

## 8. Todo List

- [ ] Slice A: foundation components + navigator + Welcome
- [ ] Slice B: language settings + email input + password create + verify email + verified success + deep-link handler
- [ ] Slice C: signin rewrite
- [ ] Slice D: forgot request + check mail + reset new password + reset deep-link
- [ ] Slice E: email-google notice + i18n full pass + testID audit + a11y pass
- [ ] Delete `RegisterScreen.tsx` (after flag flip ON)
- [ ] `npx tsc --noEmit && yarn lint` pass
- [ ] iOS sim cold-start through each happy path

## 9. Success Criteria

- 11 new screens + 2 modified render Figma-faithfully on iPhone 14 Pro sim (414×896 reference, per spec 00-index.md).
- All 28 AC scenarios from AU-242 ticket pass via manual test or Maestro flow (phase 07).
- Every interactive element has a testID matching the convention.
- VoiceOver reads correct label for every element; screen 13 (Verified!) announces "Verified" on focus.
- Switching locale to vi-VN on Language Settings re-renders Welcome with vi copy (placeholder en if Viet hasn't translated yet).
- Deep-link `auxi://auth/verify?token=…` opens app to Verified! when valid token, error state when expired.
- `RegisterScreen.tsx` removed; no broken imports.

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| 11 net-new screens overrun 7d budget | High | Medium | Vertical slice — ship signup happy path (Slice A+B) as a working MVP; subsequent slices independently mergeable |
| Figma wireframe state (logo "Mg", grayscale) misinterpreted as final design | High | Medium | Per OQ#1 — confirm with Viet before implementing brand mark; treat as layout-final, apply current Auxi theme accents |
| Deep-link handler races with cold-start auth check → wrong navigation target | Medium | Medium | Hold deep-link intent in a queue until `AuthContext.bootstrap()` resolves; then dispatch |
| Email-mailto fallback fails on physical device without mail app | Low | Low | Catch `Linking.openURL` rejection; show toast "Open your email app to verify" |
| Resend cooldown timer drifts across background/foreground | Medium | Low | Store `lastResendAt` timestamp; on resume compute remaining from now() — lastResendAt + 60s |
| Eye-toggle on password field clashes with native iOS password autofill | Low | Low | Test with Keychain autofill enabled; if conflict, document and let autofill win |
| `LoginScreen.tsx` rewrite breaks existing logged-in users' deep-links / session | Low | Medium | Gate behind `UAC_V2_ENABLED` flag — both paths coexist until cutover |

## 11. Security Considerations

- Password fields use `secureTextEntry=true`; toggle only flips for visible session, never persisted.
- `pendingEmail` is fine in AsyncStorage (non-sensitive); tokens stay in Keychain only.
- Deep-link tokens consumed once — after `useVerifyEmailMutation` resolves, clear the URL from `Linking.getInitialURL` cache.
- "Open mail app" intent uses `Linking.openURL('message://')` — no user data leaked to OS.
- testIDs must NOT include user data (e.g. don't include email in testID string).
- Reset deep-link arriving in app while user is already authenticated — show confirm dialog "Reset password while signed in?" before navigating to ResetNewPassword (prevents session hijack via leaked link).

## 12. Next Steps

- Phase 05 (OAuth) wires Google + Apple buttons on Welcome and Google-notice CTA.
- Phase 06 confirms deep-link Universal Links land in app on real device (not just sim).
- Phase 07 authors Maestro flows against testIDs added here.

**Status**: pending
**Summary**: 5 vertical slices over ~7 dev-days, ship signup happy path first. Heavy Figma-fidelity work — `figma-design-extraction` + `figma-to-rn-workflow` skills mandatory.
**Concerns/Blockers**: OQ#1 brand name, OQ#13 verified-routing, OQ#26 account-by-email, OQ#8 submit-chevron-as-CTA all must clear with Viet/PM before respective screens ship.
