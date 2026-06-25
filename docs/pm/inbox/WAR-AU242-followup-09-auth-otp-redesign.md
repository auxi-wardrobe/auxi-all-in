---
id: WAR-AU242-FU-09
parent: AU-242
type: feature
title: "Auth redesign — combined login + 6-digit OTP (verify + reset)"
state: Backlog
priority: P2
labels: [type:feature, area:mobile, area:backend, role:mobile-dev, role:backend-dev, role:tech-lead, follow-up, redesign, auth, design-review, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: mobile-dev (UI) + backend-dev + tech-lead (cross-repo contract) — CEO greenlight required
estimate: L (cross-repo, ~5-8d once unblocked)
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
relation: follow-up of AU-242 (auth UAC) · sequel to WAR-AU242-FU-08 (Phase 1 email plumbing)
created: 2026-06-21
linear_sync_status: pending
spec: auxi/plans/260621-2138-auth-otp-redesign/plan.md
---

## BLOCKED BY (do not start)

1. **Phase 1 email-plumbing must be verified LIVE first** — ElasticEmail
   delivery + `mail.auxi.app` DNS (tracked as the Phase 1 plumbing work, sequel
   to WAR-AU242-FU-08). OTP codes are useless if email doesn't land.
2. **CEO greenlight on the OTP model** + resolution of the 3 open decisions
   below — before any build. This ticket is DEFERRED / triage only.

Subtask breakdown comes AFTER the CEO greenlight and the open decisions are
resolved. Do NOT split into subtasks yet.

## Context / Why

Current shipped auth (AU-242: opaque-link-token email verification + an
email-first precheck flow) works once Phase 1 plumbing lands. But the CEO's
claude_design **"Auxi Auth Flow"** board specifies a simpler, more reliable
target UX:

- ONE **combined** login form (email + password together) — drops the
  email-precheck split.
- In-app **6-digit OTP codes** for BOTH email-verification AND password-reset —
  replaces the fragile deep-link / "open mail app" model.

This ticket captures that target so Phase 2 is built deliberately, not guessed.
Full spec: `auxi/plans/260621-2138-auth-otp-redesign/plan.md`.

## Target flows (high level — see spec for error states + business rules)

- **Login (Path 01)**: Welcome → "Continue with email" → combined login form
  (email + password + "Forgot password?") → Home. Google/Apple unchanged.
- **Register (Path 02)**: combined form (email + password + confirm) →
  **Verify email via 6-digit OTP** (auto-advance boxes, resend countdown) → Home.
- **Reset (Path 03)**: Forgot (email) → neutral "check your email" (no
  enumeration) → **Enter reset code (6-digit OTP)** → Set new password
  (invalidates all sessions) → back to log in.

Business rules carried from spec: codes 6 digits, 10-min expiry, resend
rate-limited by visible countdown; password ≥8 chars + ≥1 number; forgot-password
returns identical response whether or not the email exists; repeated failures →
temporary cool-down, not a hard lock.

## Mobile delta (auxi) — role:mobile-dev

- NEW combined `LoginScreen` (email + password + forgot, one form) — replaces
  `EmailInput → SignIn` split.
- NEW combined `RegisterScreen` (email + password + confirm) — replaces
  `EmailInput → PasswordCreation`.
- NEW reusable 6-box OTP component (auto-advance, paste, masked, resend
  countdown) — shared by verify-email AND reset-code.
- REWORK `VerifyEmailScreen`: "open mail app" / deep-link → in-app OTP entry.
- REWORK reset flow: Forgot → CheckMail (neutral) → EnterResetCode (OTP) →
  SetNewPassword → Done.
- RETIRE `EmailInputScreen` (precheck) + `EmailGoogleNoticeScreen`. ⚠️ This
  removes AU-356 enumeration-safe precheck + AU-313 Gmail fast-path — see
  open decision #1.
- Rewire `AuthNavigator`; register all new routes in BOTH
  `src/types/navigation.ts` AND `AppNavigator.tsx` (project convention —
  silent-bug source if missed).
- New `uac.*` i18n keys (en/vi/fr); analytics events per
  `analytics-tracking-required.md` (`otp_code_entered`,
  `verification_code_resent`, etc.) + tracking-plan doc update; `testID` on
  every control.
- Reuse: `AuthContext`, `tokenStorage`, Google/Apple OAuth, `theme.ts` uac
  tokens, shared password-rule checklist.

## Backend contract change (wardrobe-backend) — role:backend-dev + role:tech-lead

CROSS-REPO CONTRACT CHANGE — needs tech-lead sign-off.

- Today verify/reset use **opaque URL tokens**
  (`POST /api/auth/verify-email {token}`,
  `POST /api/auth/reset-password {token, new_password}`).
- Target needs **6-digit codes**: generate/store/email a 6-digit numeric code
  for email-verify + password-reset.
- New/changed endpoints: verify-email-by-code `{email, code}`;
  reset-password-by-code `{email, code, new_password}`; resend already exists.
- Email templates send the CODE, not a link (adjust the Phase-1 ElasticEmail
  adapter copy).
- Port enumeration-safety + 10-min expiry + cool-down from tokens to codes.
- **`API_DOCUMENTATION.md` MUST be updated** as part of AC.

## Open decisions (confirm with CEO BEFORE build)

1. **Drop the email-precheck entirely**, or keep it server-side for
   enumeration-safety while showing the combined form? (claude_design implies
   drop. Dropping retires AU-356 precheck + AU-313 Gmail fast-path.)
2. **Full switch to 6-digit codes** (bigger, matches the board) vs. a hybrid
   that keeps tokens under the hood. Board clearly wants codes.
3. **Migration cutover**: hard cutover vs. support both link + code during a
   transition window (in-flight tokens already issued under the old model).

## Acceptance criteria (draft — finalize after open decisions resolved)

- [ ] Open decisions #1–#3 resolved + recorded; CEO greenlight obtained.
- [ ] Phase 1 email delivery verified live (real OTP lands in real inbox).
- [ ] Backend: 6-digit code issue/verify for email-verify + reset; enumeration-
      safe; 10-min expiry; cool-down on repeated failures.
- [ ] `wardrobe-backend/API_DOCUMENTATION.md` updated for the new/changed routes;
      tech-lead signs off on the contract diff.
- [ ] `python test_server.py` green for the new code paths.
- [ ] Mobile: combined Login + Register forms; reusable OTP component; reworked
      verify + reset flows; old precheck screens retired per decision #1.
- [ ] New routes registered in `src/types/navigation.ts` AND `AppNavigator.tsx`.
- [ ] `uac.*` i18n keys present in en/vi/fr; `testID` on every control.
- [ ] Mixpanel events wired + `auxi/docs/analytics/mixpanel-tracking-plan.md`
      updated.
- [ ] Sequencing respected: backend lands first, then mobile pins the new
      submodule HEAD.
- [ ] Figma→RN gate followed: figma-design-extraction → qa-ui review-extraction
      → figma-to-rn-workflow → auxi-lint-tokens → qa-ui Compare → designer gate
      (6.5) → qa-mobile smoke → PR.

## Out of scope

- Phase 1 plumbing: email delivery (ElasticEmail + `mail.auxi.app` DNS), OAuth
  env config, 30-day access-token bug — handled separately; this redesign
  assumes Phase 1 is done and verified.
- Subtask breakdown — deferred until CEO greenlight + open decisions resolved.

## Sources of truth

- Spec: `auxi/plans/260621-2138-auth-otp-redesign/plan.md`
- claude_design project `auxi` (`019df3b4-ff8b-74c4-bfc6-7d7d597c90a2`):
  `Auxi Auth Flow.html` + `Auxi Auth Guide.html` (re-fetch via DesignSync MCP;
  not copied locally — orchestrator exports to mobile-dev at build time).
- Figma `2849-10084` "Login" section. ⚠️ Figma largely matches the CURRENT
  shipped flow (link-token + precheck). Where Figma and claude_design CONFLICT,
  the **claude_design board wins** for Phase 2.
- Current code map: 11 screens in `auxi/src/screens/auth/`, `services/auth.ts`,
  `context/AuthContext.tsx`, `navigation/AuthNavigator.tsx`.
- Parent epic: AU-242 (`https://linear.app/duncan-1/issue/AU-242`).
