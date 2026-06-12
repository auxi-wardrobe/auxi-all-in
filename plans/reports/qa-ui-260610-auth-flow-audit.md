# QA-UI Audit — Auth login-flow fixes (AU-313 / AU-314 / AU-315)

- **Date:** 2026-06-10
- **Agent:** qa-ui (Maestro authoring + code/UX review)
- **Mode:** Code + UX/visual review (sim NOT built → on-sim/Maestro execution DEFERRED to qa-mobile)
- **Branch:** main · work context `auxi/`
- **Scope:** review the 3 new auth states, author testID-based Maestro flows, verdict per ticket.

## TL;DR

| Ticket | Verdict | Why |
|---|---|---|
| **AU-313** (gmail → Google route) | **PASS** | Client-side gmail route to `EmailGoogleNotice` is correct, mirrors the OAuth path, i18n + theme tokens clean, testIDs present. One cosmetic gap (placeholder Google "G" glyph) + one stale pre-existing flow selector noted. |
| **AU-314** (unregistered → login msg) | **PASS-WITH-CONSTRAINT** | Code is correct and defensive. The intended "no account" toast path is **currently unreachable** for normal users by design (enumeration-safe anonymous precheck + no `mode:'signin'` entry point). This is **expected-current-behavior, not a bug** — backend decision pending. Flow asserts actual fall-through behavior. |
| **AU-315** (forgot → gmail notice) | **PASS** | The dead no-op is fixed: gmail address now shows inline info guidance and does NOT advance to the never-arriving check-mail screen. i18n + info-color token + testID all present. |

**Execution status:** DEFERRED. No native build / sim boot performed (per task). Maestro flows authored and parse-validated only. Pass-3 (sim screenshots) and Maestro run hand off to **qa-mobile** after a build.

---

## What I reviewed

- `src/utils/email-provider.ts` — `isGoogleEmail()` / `getEmailDomain()`
- `src/screens/auth/EmailInputScreen.tsx` — AU-313 route + AU-314 toast/bounce
- `src/screens/auth/EmailGoogleNoticeScreen.tsx` — AU-313 live Google OAuth wiring
- `src/screens/auth/ForgotPasswordRequestScreen.tsx` — AU-315 gmail notice
- Supporting: `WelcomeScreen.tsx`, `SignInScreen.tsx`, `services/auth.ts` (precheck),
  `services/authTypes.ts`, `types/navigation.ts`, en-EN/vi-VN translations.

---

## Per-ticket findings

### AU-313 — gmail routes to Google sign-in (PASS)

Code review (`EmailInputScreen.tsx:119-126`):
- Gmail-domain emails short-circuit to `navigation.navigate('EmailGoogleNotice', { email })` BEFORE the precheck call. Correct: the precheck is enumeration-safe and can't return `google` to an anonymous caller, so the domain heuristic is the only client-side signal. Sound design.
- `isGoogleEmail` covers `gmail.com` + `googlemail.com`, lowercased, malformed-safe (`getEmailDomain` returns null on no-`@` / trailing-`@`). Good.
- **Parity with Apple/Google flow:** `EmailGoogleNoticeScreen.onContinuePress` drives the same live path WelcomeScreen uses (`googleSignInRequest → /api/auth/google → refreshUser → AppStack`). Error handling mirrors `WelcomeScreen.handleAuthError` (cancel = silent, `EMAIL_LINKED_TO_PASSWORD` → SignIn, other-provider → info toast, not-configured → info toast). Parity confirmed.

UX / visual:
- Strings via i18n (`uac.email_google_notice.*`). No hardcoded copy. ✅
- Colors via theme tokens (`uacTextBase`, `uacBackgroundNeutralSubtlest`, `uacBorderBase`). No literal hex. ✅
- testIDs present: `email-google-notice-screen` / `-back` / `-headline` / `-body` / `-continue` / `-continue-spinner`. ✅
- `accessibilityState={{ disabled, busy }}` on the CTA — good a11y; spinner has its own testID for busy-state assertion. ✅
- No dead end: back chevron returns to email step.

Minor (LOW, cosmetic — route to mobile-dev, not blocking):
- `EmailGoogleNoticeScreen.tsx:204-207, 299-306` — the Google "G" mark is a **placeholder bordered square**, not the brand glyph. Flagged as an open question in the screen's own header. Per the Figma→RN workflow this is a `figma-icons-sync` export (`currentColor` SVG), not a per-screen literal. Cosmetic only; does not block AU-313 functionally.
- `email_google_notice.headline` copy is literally `"Google"` (en) — terse but matches the Figma spec node referenced in the file header. Designer (CEO) call; not a defect.

Pre-existing flow bug found (NOT introduced by this work — flag to qa-ui/qa-mobile):
- `maestro/flows/auth/uac-google-conflict.yaml:67` asserts `id: email-google-notice-continue-google`, but the screen's testID is **`email-google-notice-continue`** (no `-google` suffix). That existing flow will fail on this step. Recommend a follow-up fix to that file (out of scope for this audit; not touched).

### AU-314 — unregistered email → "no account" + login (PASS-WITH-CONSTRAINT)

Code review (`EmailInputScreen.tsx:136-163`):
- The `'none'` branch is correct and defensive: in `signin` mode it shows an info Toast (`uac.email_input.error_no_account`) and `navigate('Welcome')`; in `signup` mode `'none'` is the happy path → `PasswordCreation`. `'password'` → `SignIn` (honors precheck so existing users can log in). Logic is right.
- Toast (not inline error) is the correct choice here — the inline error would die with the unmounting screen on navigate. Good reasoning.

**Known limitation (documented, expected-current-behavior — NOT a failure):**
1. **Enumeration-safe anonymous precheck.** `services/auth.ts:476-478` + `authTypes.ts:170-177`: `/api/auth/email-precheck` returns `provider:"password"` to every anonymous caller regardless of registration. `provider:"none"` is only visible to authenticated admin/staff. So for a normal unauthenticated user, an unregistered email routes to **`SignIn`**, where login returns `INVALID_CREDENTIALS` and renders the inline `signin-error`. The AU-314 toast/Welcome-bounce never fires.
2. **No sign-in entry point.** The only `EmailInput` navigation is `WelcomeScreen.tsx:137` with `mode:'signup'`. There is **no `mode:'signin'` call site anywhere** in the app, so the `mode === 'signin'` guard that gates the AU-314 toast is unreachable from the UI today.

Net: the AU-314 code is correct but dormant. Unblocking it requires a **backend decision** (authenticated precheck, or relaxing enumeration safety) AND a product decision (a dedicated `mode:'signin'` entry). Both are out of qa-ui scope → **route to tech-lead / backend-dev + pm**, do not log as a mobile-dev bug. The current fall-through (clear `INVALID_CREDENTIALS` message, forgot-password affordance, no dead end) is acceptable UX in the interim.

The authored flow asserts the **actual current behavior** and carries the deferred toast/Welcome assertion block commented inline, ready to enable once the path is reachable.

### AU-315 — forgot-password gmail notice (PASS)

Code review (`ForgotPasswordRequestScreen.tsx:72-85`):
- Gmail address now short-circuits: `setGmailNotice(t('uac.forgot_request.gmail_notice'))` and **returns without calling the mutation and without navigating**. This is exactly the fix — the old path fired a backend no-op (OAuth-only accounts skipped) then advanced to a check-mail screen that never receives mail. Dead-end eliminated. ✅
- Notice is neutral/info, separate state from `submissionError` — rendered via `forgot-request-gmail-notice` with `uacTextInfoBase` color token (info, not danger). Correct semantics. ✅
- Editing the email clears both `submissionError` and `gmailNotice` (`onChangeText`, lines 152-156) — good, no stale notice.

UX / visual:
- Strings via i18n (`uac.forgot_request.gmail_notice`). No hardcoded copy. ✅
- Info color via theme token (`uacTextInfoBase`), not literal hex. ✅
- testIDs present: `forgot-request-gmail-notice`, `forgot-request-email-input`, `forgot-request-submit`, `forgot-request-error`, `forgot-request-heading`, `forgot-request-back`. ✅

Minor (LOW, cosmetic — not blocking):
- The back chevron and CTA arrow use glyph text (`'‹'` / `'›'`, lines 123/199) instead of SVG icons. Per the Figma→RN convention this should be a `figma-icons-sync` SVG with `currentColor`, not a `<Text>` glyph. Pre-existing in this screen (batch D self-contained inlining), not introduced by AU-315. Route to mobile-dev as a cleanup item, low priority.

---

## Cross-cutting observations

1. **VI translations are placeholders.** `vi-VN.json` has `"error_no_account": "[VI] No account found…"` and `"gmail_notice": "[VI] This email uses Google…"` — literal `[VI]` prefixes, untranslated. Ships English-with-prefix to Vietnamese users. Route to pm/mobile-dev for real translation. (LOW — copy, not logic.)
2. **testID discipline is good** across all three screens — every interactive element and every new state has a stable testID, and stateful ones (busy spinner) are separately addressable. Matches `auxi/CLAUDE.md` rules. This made the flows clean to author.
3. **Two pre-existing Maestro selector drifts** surfaced while matching conventions (not my changes, flag for a separate cleanup pass):
   - `uac-google-conflict.yaml:67` → `email-google-notice-continue-google` (should be `…-continue`).
   - `uac-forgot-password.yaml:60` + `:69` assert `forgot-password-request-screen` / `forgot-password-check-mail-screen`; the request screen's actual screen-level testID is `forgot-request-header` (no `forgot-password-request-screen` exists). Verify the check-mail one too.

---

## Maestro flows authored (testID-based, parse-validated)

All under `auxi/maestro/flows/auth/`, registered in `auxi/maestro/README.md` inventory:

- `au313-gmail-google-route.yaml` — gmail email → `EmailGoogleNotice` reached, headline/body/continue visible, did-not-fall-through-to-password asserted, back returns to email step. Pure-client; **no backend seed**. Stops before the native Google SDK sheet (Maestro can't drive out-of-process OAuth headlessly).
- `au314-unregistered-email.yaml` — asserts **current** behavior: unregistered email → SignIn → `INVALID_CREDENTIALS` (`signin-error`) + forgot-link present (no dead end). Carries the **deferred** toast/Welcome assertion block inline + a full header explaining the enumeration-safety + entry-point constraints.
- `au315-forgot-gmail-notice.yaml` — reach ForgotPasswordRequest via SignIn→forgot-link (verified `qa-signin@auxi.app` seed), overwrite field with a gmail address, submit → `forgot-request-gmail-notice` shown, **NOT** advanced to check-mail, no error state, editing clears the notice.

### Seeds / run notes for qa-mobile (execution phase)
- AU-313: no seed. `-e QA_GMAIL=qa-gmail-au313@gmail.com`.
- AU-314: no seed. `-e QA_UNREG_EMAIL=qa-nobody-au314@example.com -e QA_DUMMY_PASSWORD=Wrong1234`.
- AU-315: needs the existing verified `qa-signin@auxi.app / Pass1234` seed (see `uac-happy-signin.yaml` header for commands). `-e QA_GMAIL=qa-gmail-au315@gmail.com`.
- Backend must be local prod-mirror on :5001 (qa-test/qa-signin 401 against Railway-backed prod — see memory note).
- Run only after `./scripts/qa-boot.sh` + a fresh build with these screens.

---

## Routing

- **mobile-dev (LOW, non-blocking cleanup):** Google "G" placeholder glyph → `figma-icons-sync` SVG; forgot-screen `‹`/`›` glyphs → SVG icons; real VI translations for `error_no_account` + `gmail_notice`.
- **tech-lead + backend-dev + pm (AU-314 dormancy):** decide whether to surface `provider:"none"` to the relevant caller and/or add a `mode:'signin'` EmailInput entry so the AU-314 "no account → Welcome" path becomes live. Until then, AU-314 ships as-is (acceptable interim UX).
- **qa-ui / qa-mobile (separate cleanup):** fix the two stale selectors in `uac-google-conflict.yaml` + `uac-forgot-password.yaml`.
- **qa-mobile (execution):** build + run the 3 new flows after `qa-boot.sh`.

## Unresolved questions
1. AU-314: is the intended end-state a live "no account → Welcome" path, or is the SignIn fall-through acceptable as the permanent UX? (Backend enumeration-safety vs. UX trade-off — needs CEO/tech-lead call.)
2. AU-313: is the placeholder Google "G" square acceptable for the current build, or does the brand glyph block ship? (Designer/CEO.)
3. Should the AU-314 toast get a dedicated `testID` (over a `text:` match) before the deferred assertion is enabled? (mobile-dev — preferred, i18n-fragile otherwise.)

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Code + UX review of AU-313/314/315 complete; 3 testID-based Maestro flows authored + parse-validated; on-sim/Maestro execution deferred (no build) → qa-mobile. **Verdict per ticket:** AU-313 PASS · AU-314 PASS-WITH-CONSTRAINT (anonymous-caller "no account" path dormant by design — expected-current-behavior, backend decision pending) · AU-315 PASS. **Maestro flows:** `auxi/maestro/flows/auth/au313-gmail-google-route.yaml`, `auxi/maestro/flows/auth/au314-unregistered-email.yaml`, `auxi/maestro/flows/auth/au315-forgot-gmail-notice.yaml`.
**Concerns/Blockers:** (1) AU-314 toast/Welcome path unreachable for normal users — enumeration-safe anonymous precheck always returns `password` + no `mode:'signin'` entry point exists; flagged as known constraint, route to tech-lead/backend-dev/pm, NOT a mobile-dev bug. (2) Execution deferred — flows reviewed/parsed but not run; qa-mobile must build + run after `qa-boot.sh`. (3) Two pre-existing stale selectors in older auth flows surfaced (`uac-google-conflict.yaml`, `uac-forgot-password.yaml`). (4) LOW cosmetic: Google-G placeholder glyph, `‹`/`›` text glyphs, `[VI]` placeholder translations.
