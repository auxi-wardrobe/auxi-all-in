---
id: WAR-AU242-FU-09
parent: AU-242
type: feature
title: "Auth redesign — combined login + 6-digit OTP (verify + reset)"
state: Triage
priority: P2
labels: [type:feature, area:mobile, area:backend, role:tech-lead, role:mobile-dev, role:backend-dev, redesign, auth, design-review, source:au-242-followup, deferred]
team: Auxi
workspace: duncan-1
owner: tech-lead (contract sign-off) · mobile-dev (UI) · backend-dev (codes) — assign after CEO greenlight
estimate: L (cross-repo, multi-screen + contract change)
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
linear_sync_status: synced
linear_id: AU-368
linear_url: https://linear.app/duncan-1/issue/AU-368/auth-redesign-combined-login-6-digit-otp-verify-reset
created: 2026-06-21
blocked_by: "Phase 1 email-plumbing (ElasticEmail + mail.auxi.app DNS) verified live; CEO greenlight on OTP model"
spec: /Users/nguyenminhduc/dev/wardrobe_project/auxi/plans/260621-2138-auth-otp-redesign/plan.md
---

> NOTE: Linear was not reachable from this PM session (no Linear MCP server wired
> into `.mcp.json`; the `mcp__linear__*` tool surface was not callable, and the
> Gemini CLI fallback is unauthenticated). Per PM fallback protocol this ticket
> is captured here in `docs/pm/inbox/` mirroring the Linear schema so nothing is
> lost. **Action for whoever has live Linear access:** create the issue under team
> Auxi / parent AU-242 with the fields above, set state = Triage/Backlog, link as
> a follow-up of AU-242, then flip `linear_sync_status: pending` → `synced` and
> record the AU-### id + URL here.

## Context (why)

Current shipped auth (AU-242: opaque-link-token email verification + an
email-first precheck flow) WORKS — once Phase 1 plumbing lands (email delivery
via ElasticEmail + `mail.auxi.app` DNS; tracked separately, NOT this ticket).

The CEO's `claude_design` **"Auxi Auth Flow"** board specifies a simpler, more
reliable target UX we want to move to:

1. **ONE combined login form** (email + password together) — drops the
   email-precheck split.
2. **In-app 6-digit OTP codes** for BOTH email-verification AND password-reset —
   replaces the fragile deep-link / "open mail app" model.

This is a **UX upgrade**, not the urgent fix. The urgent fix is Phase 1 plumbing
(see `WAR-AU242-FU-08` / the live ElasticEmail work). This ticket exists so
Phase 2 is built deliberately, not guessed, once Phase 1 is verified and the CEO
greenlights the OTP model + the open decisions below.

Full spec (read before any build):
`auxi/plans/260621-2138-auth-otp-redesign/plan.md`

## Target flows (high level — from the CEO Auth Guide)

- **Login (Path 01):** Welcome → "Continue with email" → combined login form
  (email + password + "Forgot password?") → "Signing you in…" → Home. Plus
  Google / Apple. "Create account" → Register. (wrong creds → inline error,
  clear password keep email; cancelled social consent → silent return.)
- **Register (Path 02):** Welcome → "Create account" → combined form (email +
  password + confirm + rule line) → "Creating account…" → **Verify email
  (6-digit OTP)** with auto-advance boxes + resend countdown → "Email verified"
  → Home. (email-exists → 409 inline + link to log in; wrong/expired code → red
  boxes, 10-min expiry → resend.)
- **Reset (Path 03):** Login "Forgot password?" → Forgot (email only) → "Send
  reset code" → neutral enumeration-safe confirmation → **Enter reset code
  (6-digit OTP)** → "Set a new password" → "Update password" → all sessions
  invalidated → back to log in. (invalid/expired code → red boxes; 5 fails →
  cool-down.)

Business rules (from the guide): email account inactive until 6-digit verified;
social arrives pre-verified; password ≥8 chars + ≥1 number, confirm must match;
codes are 6 digits, expire 10 min, resend rate-limited by a visible countdown;
forgot-password returns an identical response whether or not the email exists
(no enumeration); successful reset invalidates ALL sessions; repeated failures →
temporary cool-down (not a hard lock).

## Mobile delta (auxi) — mobile-dev

- **NEW** combined `LoginScreen` (email + password + forgot, one form) — replaces
  the `EmailInput → SignIn` split.
- **NEW** combined `RegisterScreen` (email + password + confirm) — replaces
  `EmailInput → PasswordCreation`.
- **NEW** reusable 6-box OTP component (auto-advance, paste, masked, resend
  countdown) — shared by verify-email AND reset-code.
- **REWORK** `VerifyEmailScreen`: from "open mail app" / deep-link → in-app OTP
  entry hitting a verify-by-code endpoint.
- **REWORK** reset flow: Forgot → CheckMail (neutral) → EnterResetCode (OTP) →
  SetNewPassword → Done (current `ResetNewPassword` becomes code-gated, not
  reached via a reset link).
- **RETIRE** `EmailInputScreen` (precheck) + `EmailGoogleNoticeScreen` — combined
  login drops the email-first precheck. ⚠️ This removes AU-356 enumeration-safe
  precheck + AU-313 Gmail fast-path — see Open decision #1.
- Rewire `AuthNavigator`; register every new screen in BOTH
  `src/types/navigation.ts` AND `AppNavigator.tsx` (project's #1 silent-bug
  source); new `uac.*` i18n keys (en/vi/fr) for the combined forms + OTP;
  Mixpanel events (`otp_code_entered`, `verification_code_resent`, etc. per
  `analytics-tracking-required.md`) + tracking-plan doc update; `testID` on every
  control.
- **Reuse:** `AuthContext`, `tokenStorage`, Google/Apple OAuth, `theme.ts` uac
  tokens, the shared password-rule checklist.

## Backend contract change (wardrobe-backend) — backend-dev + tech-lead

CROSS-REPO CONTRACT CHANGE — requires tech-lead sign-off.

- Today verify/reset use **opaque URL tokens**
  (`POST /api/auth/verify-email {token}`,
  `POST /api/auth/reset-password {token, new_password}`). Target needs
  **6-digit numeric codes**:
  - generate / store / email a 6-digit code for email-verify + password-reset.
  - new/changed endpoints: verify-email-by-code `{email, code}`;
    reset-password-by-code `{email, code, new_password}`; resend already exists.
  - email templates send the CODE, not a link (adjust the Phase-1 ElasticEmail
    adapter copy).
  - port enumeration-safety + 10-min expiry + cool-down from the token path to
    the code path.
- **`API_DOCUMENTATION.md` update is mandatory** for the route change + tech-lead
  contract review + coordinated mobile/backend rollout (backend lands first,
  then auxi pins the new submodule HEAD).

## Open decisions (resolve with CEO BEFORE build — no subtasks until then)

1. **Drop the email-precheck entirely**, or keep it server-side for
   enumeration-safety while showing the combined form? (claude_design implies
   drop — but dropping retires AU-356 precheck + AU-313 Gmail fast-path.)
2. **Full switch to 6-digit codes** (bigger, matches the board) vs. a **hybrid**
   that keeps tokens under the hood. Board clearly wants codes.
3. **Migration / cutover**: hard cutover vs. support both link + code during a
   transition window (in-flight tokens already issued to users).

## BLOCKED BY

- **Phase 1 email-plumbing must be verified live first** — ElasticEmail delivery
  + `mail.auxi.app` DNS working end-to-end (tracked separately; see
  `WAR-AU242-FU-08` and the live ElasticEmail work). This redesign assumes
  Phase 1 is done and verified.
- **CEO greenlight on the OTP model** + resolution of the 3 open decisions above
  before any build starts.

## Acceptance criteria (epic-level — refine into subtasks after greenlight)

- [ ] CEO greenlight on the OTP model recorded; 3 open decisions resolved.
- [ ] Backend: 6-digit code generate/verify for email-verify + reset; endpoints
      land; enumeration-safety + 10-min expiry + cool-down preserved;
      `API_DOCUMENTATION.md` updated; `python test_server.py` green; tech-lead
      contract sign-off.
- [ ] Mobile: combined Login + Register forms; shared 6-box OTP component;
      VerifyEmail + reset reworked to code entry; `EmailInput` /
      `EmailGoogleNotice` retired per decision #1; new screens registered in
      `navigation.ts` + `AppNavigator.tsx`; `uac.*` i18n en/vi/fr; analytics
      events wired + tracking-plan updated; `testID` on every control;
      `npx tsc --noEmit` + `yarn lint` clean (no new baseline errors).
- [ ] Figma→RN gate followed: figma-design-extraction → qa-ui review-extraction
      → figma-to-rn-workflow → `auxi-lint-tokens.sh` clean → qa-ui Compare →
      **designer gate (6.5) PASS** → qa-mobile smoke.
- [ ] Coordinated rollout: backend deployed + verified, then auxi submodule HEAD
      pinned; smoke against real backend (not mocks).

## Out of scope

- Phase 1 email delivery (ElasticEmail + `mail.auxi.app` DNS), OAuth env config,
  the 30-day access-token bug — handled separately.
- Magic-link / phone-number sign-in.
- Subtask breakdown — comes AFTER CEO greenlight + open-decision resolution.

## Next steps

1. Phase 1 plumbing verified live → ping CEO for greenlight on the OTP model.
2. CEO resolves the 3 open decisions.
3. THEN PM splits into subtasks: (a) wardrobe-backend code endpoints + doc,
   (b) auxi combined forms + OTP component + rework, (c) parent tracking both,
   sequenced backend-first.

## Refs

- Spec: `auxi/plans/260621-2138-auth-otp-redesign/plan.md`
- CEO design: `claude_design` project `auxi`
  (`019df3b4-ff8b-74c4-bfc6-7d7d597c90a2`) — `Auxi Auth Flow.html` +
  `Auxi Auth Guide.html` (re-fetch via DesignSync; not copied locally).
- Figma: `2849-10084` "Login" section (⚠️ largely matches the CURRENT
  link-token flow; where it conflicts with the claude_design board, the board
  wins for Phase 2).
- Parent epic: AU-242 (`https://linear.app/duncan-1/issue/AU-242`).
- Phase 1 blocker: `WAR-AU242-FU-08` (email service) + live ElasticEmail work.
- Current code map: `auxi/src/screens/auth/` (11 screens),
  `auxi/src/services/auth.ts`, `auxi/src/context/AuthContext.tsx`,
  `auxi/src/navigation/AuthNavigator.tsx`.
