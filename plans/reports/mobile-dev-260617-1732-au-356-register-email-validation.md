# AU-356 — "I can not create a password if I use @user.com" — Fix Report

**Agent:** mobile-dev · **Date:** 2026-06-17
**Ticket:** AU-356 (parent AU-315 auth/registration, Priority: Medium)
**Reporter:** Viet (CEO/designer) — "registered by viettran@macgie.com and I can not go to the next register step."

## TL;DR

Root cause was NOT the email regex. `viettran@macgie.com` passes the format
validator fine. The blocker was the **email-precheck routing** on the
EmailInputScreen: every brand-new signup email was being bounced to the
Sign-In screen instead of advancing to Password Creation, because the backend
precheck is enumeration-safe and always answers `provider: "password"` to
anonymous callers. Fixed by making the post-precheck routing **mode-aware**.

## Root cause (the exact bad logic)

`auxi/src/screens/auth/EmailInputScreen.tsx`, `handleSubmit` precheck
`onSuccess` (pre-fix lines 179–182):

```ts
if (result.provider === 'password') {
  navigation.navigate('SignIn', { email: trimmed });   // <-- the bug
  return;
}
```

Why this blocks every new signup:

- The email format regex `EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/`
  (`EmailInputScreen.tsx:69`) accepts `viettran@macgie.com`. Format gate is
  fine — not the cause.
- `macgie.com` is not a Google/Apple domain, so the flow calls
  `useEmailPrecheckMutation` → `POST /api/auth/email-precheck`.
- That endpoint is **enumeration-safe**: per
  `wardrobe-backend/API_DOCUMENTATION.md:433`, "an unauthenticated client
  ALWAYS receives `{provider: "password"}` regardless of the real linkage."
  The signup user is anonymous, so the response is **always** `'password'`,
  even for a never-before-seen email.
- The handler treated `'password'` as "existing account → go to SignIn",
  so the new user was routed to **SignIn** and could never reach the
  **PasswordCreation** step. → "can not go to the next register step."
- The intended signup happy-path branch (`provider === 'none'`) was **dead
  code** for the public flow — the backend only returns `'none'` to
  authenticated admin/self lookups, never to an anonymous signup caller.

This is a routing/gating bug, not a regex bug. The regex did not need to
change (and I did not change it — it correctly accepts standard emails and
still rejects malformed ones).

## Fix

`auxi/src/screens/auth/EmailInputScreen.tsx` — `handleSubmit` precheck
`onSuccess` now branches on `mode`, not on the (unreliable-for-anonymous)
provider value, after the OAuth-domain hint:

- OAuth result (`google`/`apple`) → `EmailGoogleNotice` (unchanged).
- **signup mode, any other provider** → `track('sign_up_started')` →
  `PasswordCreation`. The genuinely-already-registered case is caught
  server-side at register time: `POST /api/register` returns
  `409 EMAIL_ALREADY_EXISTS`, and `PasswordCreationScreen.tsx:164-165`
  already routes that to `SignIn`. That is the only enumeration-safe place
  to detect an existing account, so signup correctly defers to it.
- **signin mode, `'none'`** → Toast "no account" + bounce to Welcome
  (defensive; only reachable for authenticated callers).
- **signin mode, otherwise** → `SignIn` (returning user logs in — preserves
  the earlier "existing users could not log in" fix for the signin entry).

Also updated the screen's top-of-file doc comment to describe the corrected,
enumeration-safe routing and reference AU-356.

### Files changed (path:line)

- `auxi/src/screens/auth/EmailInputScreen.tsx`
  - `handleSubmit` precheck `onSuccess` block (was ~147–185) — mode-aware
    routing; `sign_up_started` now fires at line **175**.
  - Header doc comment (lines ~21–37) — corrected routing description + AU-356 note.
- `auxi/docs/analytics/mixpanel-tracking-plan.md:58` — updated the
  `sign_up_started` trigger description + line ref (`:171` → `:175`).

No changes to the email regex, password rules, navigation registration,
theme tokens, or translations (all required `uac.email_input.*` keys
already exist in en-EN / vi-VN / fr-FR).

## Validation that the reported value now works

Tracing `viettran@macgie.com` in signup mode through the fixed handler:
format valid → not OAuth domain → precheck returns `'password'` (anonymous)
→ `mode === 'signup'` → `track('sign_up_started')` → navigate
`PasswordCreation`. The user reaches the password step. Full
email → password → VerifyEmail path is unblocked.

## Analytics note

Per `.claude/rules/analytics-tracking-required.md`:

- **No new event needed.** The fix corrects routing logic; it adds no new
  interactive handler and no new validation-failure surface (the existing
  inline `error_invalid` / `error_required` paths are untouched).
- The existing `sign_up_started` event (`method: 'email'`) is **preserved**
  and was simply moved from the previously-unreachable `'none'` branch into
  the reachable signup branch. Net effect: this event now actually fires for
  the public email→password transition, where before it effectively never
  fired in the anonymous signup flow (the branch was dead). Property hygiene
  unchanged — no PII, literal event name, `method: 'email'`.
- Tracking-plan doc updated (`§5` table, `sign_up_started` row): trigger
  description + `EmailInputScreen.tsx:175` reference.

## Verification results

- `npx tsc --noEmit` (Node 20): **clean**, no errors.
- `yarn lint`: pre-existing baseline only — 2 errors + 7 warnings, ALL in
  untouched files (OutfitSwipeDeck, HomeScreen, DatabaseScreen,
  OutfitCanvasScreen, SignInScreen, usePinReducer). `EmailInputScreen.tsx`
  lints **clean** in isolation (`eslint src/screens/auth/EmailInputScreen.tsx`
  → exit 0). No new lint issues introduced.
- `./scripts/auxi-lint-tokens.sh`: 34 pre-existing violations, NONE in
  `EmailInputScreen.tsx`. My change adds no hex/font literals.

## Not done in this session

- Simulator smoke (`yarn ios:sim`) + Maestro flow: **not run** — out of scope
  for this agent (no mobile-mcp grant; sim verify hands off to qa-mobile /
  qa-ui). Recommend qa-mobile run the signup happy-path smoke with a fresh
  non-Gmail email to confirm email → password → verify advances on-device.

## Open questions

- None blocking. Note for review: the `'password' → SignIn` routing in
  **signin** mode still relies on enumeration-safe `'password'` always being
  returned — which is correct here because in signin mode we *want* the user
  to land on SignIn regardless. No change needed, flagging for awareness.

---
**Status:** DONE
**Summary:** AU-356 root cause was enumeration-safe precheck routing, not the
email regex — signup emails always got `provider: 'password'` and were wrongly
bounced to SignIn. Made the post-precheck routing mode-aware so signup advances
to PasswordCreation; existing-account is correctly deferred to the server-side
409 at register time.
**Files changed:** `auxi/src/screens/auth/EmailInputScreen.tsx`,
`auxi/docs/analytics/mixpanel-tracking-plan.md`
**Concerns/Blockers:** None. Sim smoke pending (hand off to qa-mobile).
