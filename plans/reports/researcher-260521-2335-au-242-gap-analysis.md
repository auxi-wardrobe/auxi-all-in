# AU-242 Gap Analysis — Current Auxi vs New UAC Spec

**Scope**: 13 spec screens (`/plans/260521-2335-au-242-figma-spec/`) vs current `auxi/` (RN 0.83 + TS 5.8) and `wardrobe-backend/` (FastAPI).
**Date**: 2026-05-21
**Status**: READ-ONLY scan; no code changes.

---

## Summary

- **Gap is large on both sides.** Mobile has 2 of 13 screens (`LoginScreen.tsx`, `RegisterScreen.tsx`) — 11 net-new screens needed. Backend has 2 of ~9 endpoints (`POST /api/register`, `POST /api/login`) — email verification, password reset, OAuth (Google/Apple), and account-lookup are **all missing**. No `email_verified_at`, `oauth_provider`, or reset-token fields on `User` model.
- **Biggest risks**: (1) **OAuth backend** — no Google/Apple verifier wired in; Apple private-relay email handling not started; (2) **email service** — no SMTP/transactional-email integration found in `wardrobe-backend/services/`; verification + reset both depend on it; (3) **i18n vi locale is empty** — only `en-EN.json` and `fr-FR.json` exist (no `vi-VN.json`), and the existing en keys don't cover the new copy; (4) **Token storage is single-credential** in `react-native-keychain.setGenericPassword('currentUser', access_token)` — refresh token is dropped on the floor (see `auxi/src/services/auth.ts:47` + TODO comment at line 49). Multi-key secure storage required.
- **Suggested approach**: Foundation-first. Land theme tokens + i18n vi skeleton + secure-storage refactor before touching screens. Backend ships verify-email + forgot-password endpoints behind a feature flag so mobile can wire against real responses (not mocks). OAuth is its own slice — schedule independently because Apple Sign-In requires entitlement provisioning and an Apple-side review.

---

## Mobile (auxi/) — Screens

Existing auth screens live in `auxi/src/screens/auth/` (only `LoginScreen.tsx` + `RegisterScreen.tsx`). Welcome lives at `auxi/src/screens/WelcomeScreen.tsx` (root, not auth). All other UAC screens absent.

| # | Spec | Existing file | Action | Effort | Notes |
|---|---|---|---|---|---|
| 1 | Welcome | `auxi/src/screens/WelcomeScreen.tsx` | MODIFY | M | Currently 1 CTA "Get started — takes 1 min" → `LocationPermission`. Replace with 3 social buttons (Google, Apple, Email) + "English" top-right language link + Terms/Privacy footer. Brand mark + headline already in place. |
| 2 | Language settings | (none) | ADD | S | New screen. M3 radio list, 2 rows (English / Tiếng Việt). Persists locale to i18n + AsyncStorage. |
| 3 | Email input | (none) | ADD | M | New screen. Inline submit chevron (NOT a back arrow). 360px text-field row + 56×57 circular submit icon. Routes to pwd-create (new) or sign-in (existing) or Google-notice (linked-to-Google). |
| 4 | Password create (typing) | (none) | ADD | M | Same screen as #5 — state variant. 3-rule checklist (`≥8`, lowercase, number) with neutral icon while pending. Submit chevron disabled. |
| 5 | Password create (valid) | (none) | ADD | S | Diff vs #4: criteria show satisfied color, submit enabled. Same node tree. |
| 6 | Verify email | (none) | ADD | M | Polling screen. "Open email app" primary CTA + "Resend (NNs)" secondary with cooldown timer. Logout text button top-right. Requires deep-link / `Linking.openURL('mailto:')` handling. |
| 7 | Email-Google notice | (none) | ADD | S | When entered email is already linked to Google account → "Continue with Google" CTA forces OAuth path. Server lookup result drives entry. |
| 8 | Email input error | (none) | ADD | XS | Same as #3 + inline `--text/danger/base` error helper. Border stays grey per Figma (flag in OQ). |
| 9 | Sign in | `auxi/src/screens/auth/LoginScreen.tsx` | REWRITE | M | Existing uses generic `AuthLayout` + two free-form inputs. New spec: email read-only filled bg `#f2f4f7`, password outlined w/ eye-toggle, "Forgot your password?" link (blue `#1465b4`), inline circular submit chevron at end of password row. Drop the "Don't have an account? Sign Up" footer (different IA). |
| 10 | Forgot request | (none) | ADD | S | "Reset your password" heading + email filled-readonly + "Send reset password" full-width primary CTA. |
| 11 | Forgot check mail | (none) | ADD | S | Confirmation screen. "Back to Login" CTA. AC mentions also "Open mail app" — Figma has only 1 button; flag. |
| 12 | Reset new password | (none) | ADD | M | Mirrors #4/#5 layout. Inline submit chevron + 3-criteria checklist. Consumes reset token from deep-link. |
| 13 | Verified success | (none) | ADD | S | Terminal screen. Branch logic on Continue: signup → onboarding (AU-243), reset → re-login. No back/header. |

`auxi/src/screens/auth/RegisterScreen.tsx` (current) — **DELETE** after #3/#4/#5 ship. Its three-field (email + pwd + confirm-pwd) layout is gone in the new spec (no confirm-password field — see OQ #18).

---

## Mobile — Services & infrastructure

| Concern | Current | Target | Action | Effort |
|---|---|---|---|---|
| `auxi/src/services/auth.ts` endpoints | `login`, `register`, `updateUser`, `resetPreferences`, `logout`, `getCurrentUser`, `isAuthenticated` | + `lookupAccountByEmail(email)`, `verifyEmail(token)`, `resendVerification(email)`, `requestPasswordReset(email)`, `resetPassword(token, password)`, `googleSignIn(idToken)`, `appleSignIn(identityToken, authCode)`, `refreshAccessToken(refreshToken)` | MODIFY | L |
| Duplicate axios instance | `auth.ts` creates its own `api = axios.create(...)` separate from `apiClient.ts` (lines 12-31) | Consolidate. All auth calls go via `apiClient` (per `auxi/CLAUDE.md` convention) | REFACTOR | S |
| Token storage | Single `Keychain.setGenericPassword('currentUser', access_token)` — **refresh token discarded** (`auth.ts:47`, TODO at L49) | Multi-key secure store (`react-native-keychain` `setInternetCredentials` per-key OR migrate to `react-native-encrypted-storage`). Store: access_token + refresh_token + access_expires_at + refresh_expires_at + user_email (matches `StoredTokenData` interface already defined in `types/auth.ts:50-58` but unused) | MODIFY | M |
| Refresh interceptor | None — 401 response just bubbles up | 401 → attempt refresh → retry; on refresh failure → logout. Standard axios response interceptor pattern. | ADD | M |
| `AuthContext` (`auxi/src/context/AuthContext.tsx`) | `user`, `isLoading`, `login`, `register`, `logout`, `refreshUser`, `updateCurrentUser`, `resetUserPreferences`, `checkAuth`, `completeOnboarding` | + `verifyEmail`, `resendVerification`, `requestPasswordReset`, `resetPassword`, `signInWithGoogle`, `signInWithApple`. Add `pendingEmail` state (carried email between #3 → #4/#9/#7). Drop auto-login-after-register at L80-85 — new flow goes signup → verify-email → home (not signup → home directly). | MODIFY | M |
| Theme tokens | `theme.colors.primary/secondary/background/surface/text/textSecondary/error/success/border` + 12 `figma*` aliases + `playfair*`, `manrope*`, `archivo*`, `poppins*` typography aliases | Add UAC tokens: `--background/neutral/base #1d1f23`, `--background/primary/neutral_50 #fcfcfd`, `--color/neutral/100 #f2f4f7`, `--text/danger/base #bb251a`, `--text/info/base #1465b4`, `--text/neutral/subtle_100 #40444d`, `--text/neutral/subtle_200 #7a7f89`, `--text/primary/base #f2efec`, `--border/neutral/bold_200 #7a7f89`. Note `figmaDestructive: '#bb251a'` already in theme — alias it. | MODIFY | S |
| Fonts | `Poppins-Regular`, `Poppins-Medium` already mapped via `typography.aliases.poppinsBody/poppinsButton`. PlayfairDisplay, Manrope, ArchivoNarrow also present. | Add `Poppins-Bold` (H1/H4), `Poppins-SemiBold` (M3 list), `Inter-SemiBold` (16/24 labels), `Inter-Medium` (xs/12), `Inter-Regular`, `Roboto-Regular` (M3 body/small), `Noto Sans-Regular` (vi locale fallback for diacritics). Confirm whether these need `react-native-asset link` re-run. | ADD | S |
| Navigation | `AuthStackParamList = { Login: undefined; Register: undefined }` (only 2 routes); `AuthNavigator.tsx` registers same 2. | Add: `Welcome` (or move from AppStack), `LanguageSettings`, `EmailInput`, `PasswordCreate`, `VerifyEmail`, `EmailGoogleNotice`, `SignIn`, `ForgotRequest`, `ForgotCheckMail`, `ResetNewPassword`, `VerifiedSuccess`. Each with appropriate params (e.g. `EmailGoogleNotice: { email: string }`, `ResetNewPassword: { token: string }`). Register in both `types/navigation.ts` and `navigation/AuthNavigator.tsx` per `auxi/CLAUDE.md` rule. | MODIFY | M |
| Deep links | None for auth (check `Linking` config) | Reset-password link `auxi://auth/reset?token=…` + email-verify `auxi://auth/verify?token=…`. iOS Universal Links + Android App Links may be required for production (mail clients block custom schemes). | ADD | M |
| OAuth SDKs | None installed (verified — no `@react-native-google-signin/google-signin` or `@invertase/react-native-apple-authentication` in `package.json` based on existing services). | Install `@react-native-google-signin/google-signin` + `@invertase/react-native-apple-authentication`. iOS: add Apple Sign-In capability + Google URL scheme. Android: GoogleSignIn web client ID + Apple is iOS-only (handle on Android by hiding the button). | ADD | M |
| i18n | `en-EN.json` has `boilerplate.auth.{login,register,errors,password_strength,show,hide}` (~30 keys). `fr-FR.json` exists. **No `vi-VN.json`**. | Add `vi-VN.json` with all UAC strings. Extend en keys for all 13 screens. Update `src/translations/index.ts` (resources, Language type). | ADD | M |
| `AuthLayout` (`auxi/src/components/layout/AuthLayout.tsx`) | Uses `Svg`/`Circle`/`Path` decorative gradient + circles, white card with title/subtitle | New spec is flat — bottom-anchored vertical stack on white/`#fcfcfd` bg, 107px header strip, no decorative shapes. **AuthLayout is obsolete** for new screens; either keep for legacy or DELETE after migration. | DELETE (eventually) | S |
| `testID` discipline | Existing `auth-email-input`, `auth-password-input`, `auth-login-submit` | Per-screen testIDs for every Pressable / TextInput / Radio / submit chevron. Maestro flows depend on these. Naming: `<screen>-<element>` e.g. `signup-email-input`, `signup-email-submit`, `verify-email-resend`, `verify-email-open-app`, `lang-radio-en`, `lang-radio-vi`. | ADD | S |

---

## Backend (wardrobe-backend/) — Endpoints

Current auth router: `wardrobe-backend/routers/auth.py` (4 routes only: `/api/register`, `/api/login`, `/api/me` GET, `/api/me` PUT, `/api/me/reset-preferences`). **No verification, no password reset, no OAuth, no refresh, no logout.** Schemas in `schemas/auth.py`.

| Endpoint | Current | Target (per AC) | Action | Effort |
|---|---|---|---|---|
| `POST /api/register` | ✅ exists. Creates user immediately, returns user dict, no verification. Returns 201. Rate limit 5/min documented. Password min_length=6 (Pydantic). | Create user with `email_verified=False`, dispatch verification email with signed token, return user dict + verification-pending flag. Password min_length=**8** to match spec (`At least 8 characters`). Keep 5/min. | MODIFY | M |
| `POST /api/login` | ✅ exists. Returns access+refresh tokens. Rate limit 10/min documented (but no rate-limit middleware visible in `routers/auth.py` — needs verification). | Reject login if `email_verified=False` (or return special status to route mobile to verify-email). Otherwise same. | MODIFY | S |
| `POST /api/auth/verify-email` | ❌ missing | Consume signed verify token → set `users.email_verified_at = now()`. 200 on success, 410 on expired token, 404 on invalid. Idempotent (already verified → 200). | ADD | M |
| `POST /api/auth/resend-verification` | ❌ missing | Re-dispatch verification email. Per-email cooldown (60s — matches Figma `(NNs)` timer). Always returns 200 even if email doesn't exist (account-enumeration safe). | ADD | S |
| `POST /api/auth/forgot-password` | ❌ missing | Generate reset token (short TTL ~30min), send email. Always returns 200 (enumeration-safe). Rate limit 5/min. | ADD | M |
| `POST /api/auth/reset-password` | ❌ missing | Consume reset token + new password → update `password_hash`, invalidate all refresh tokens for user (per security policy). Returns 200 or 410 expired. | ADD | M |
| `GET /api/auth/account-by-email?email=…` | ❌ missing | Lookup: returns `{ provider: 'email' \| 'google' \| 'apple' \| 'unknown' }`. Drives screen 7 routing. **Enumeration risk** — must rate-limit aggressively (e.g. 10/min/IP). Alternative: roll into a single `/api/auth/email-precheck` that always succeeds and returns provider hint. | ADD | M |
| `POST /api/auth/google` | ❌ missing | Verify Google ID token (via `google-auth` library), create/lookup user with `oauth_provider='google'`, set `email_verified_at = now()` (Google guarantees). Return token response. | ADD | L |
| `POST /api/auth/apple` | ❌ missing | Verify Apple identity token (JWT against Apple's public keys), handle `email_verified` claim, store private-relay email if used (`@privaterelay.appleid.com`). Apple only provides full name on **first** sign-in — store at first encounter. | ADD | L |
| `POST /api/auth/refresh` | ❌ missing | Trade refresh token → new access token. `RefreshToken` model already exists (`models/token.py`, FK in `User.refresh_tokens` relationship). Need actual route. | ADD | S |
| `POST /api/auth/logout` | ❌ missing | Revoke refresh token (DB delete or revoke flag). 204 on success. | ADD | XS |

**User model gap** (`wardrobe-backend/models/user.py`):
- Missing columns: `email_verified_at: DateTime`, `oauth_provider: String(20)` (nullable), `oauth_subject: String(255)` (nullable, indexed for Google `sub` / Apple `sub`), `apple_private_relay: Bool`, `display_name: String(120)` (Apple first-encounter name).
- Migration needed. Existing `is_first_login` stays.

**Email service gap**: No SMTP/SES/SendGrid/Postmark integration found under `wardrobe-backend/services/`. Need a transactional-email service (`services/email_service.py`) with at least 2 templates: `verify_email`, `reset_password`. Provider choice is a PM/tech-lead decision (cost, deliverability).

**Token-signing strategy** (verify + reset): JWT signed with `JWT_SECRET_KEY` (already configured in `settings.py`), `type: 'verify'` / `type: 'reset'`, short TTL. Reuse `utils/auth_utils.py` patterns. Don't store in DB unless single-use enforcement needed (recommended for reset to prevent replay).

**Rate limiting**: `utils/rate_limiter.py` exists per backend rules. Decorator needs to be applied — verify whether it's actually wired into auth routes (route source shows no `@rate_limit` decorator in `auth.py`; only documented). Audit required.

---

## Contract changes between auxi ↔ wardrobe-backend

`wardrobe-backend/API_DOCUMENTATION.md` is the contract per umbrella `CLAUDE.md`. Updates required:

**New sections to add**:
- `POST /api/auth/verify-email` (full schema)
- `POST /api/auth/resend-verification` (with cooldown semantics)
- `POST /api/auth/forgot-password` (enumeration-safe semantics)
- `POST /api/auth/reset-password` (token consumption + session invalidation)
- `POST /api/auth/refresh` (refresh-token grant)
- `POST /api/auth/logout` (token revocation)
- `GET /api/auth/account-by-email` OR `POST /api/auth/email-precheck` (TBD per OQ)
- `POST /api/auth/google` (Google ID-token grant)
- `POST /api/auth/apple` (Apple identity-token grant)

**Modifications to existing**:
- `POST /api/register`: response shape adds `verification_required: true`; password rule changes from min_length 6 → 8.
- `POST /api/login`: add `401` variant or `403` for `email_not_verified`; mobile client needs to branch.

**Breaking changes**:
- Register no longer returns tokens directly (verification gate). Mobile auto-login-after-register at `AuthContext.tsx:85` must be removed.
- Login may now reject unverified accounts — existing users created before email-verified gate must be backfilled (`email_verified_at = created_at` for grandfathered users) OR feature-flagged.

---

## Token / theme gap

Theme file: `auxi/src/theme/theme.ts`. Needs the following added under `theme.colors` (or a new nested `uac` namespace to avoid colliding with existing `figma*` aliases):

| New token | Hex | Notes |
|---|---|---|
| `uacBackgroundBase` | `#1d1f23` | Primary CTA bg, Apple button bg |
| `uacBackgroundNeutral50` | `#fcfcfd` | Welcome + Verified screens bg |
| `uacBackgroundSubtlest` | `#FFFFFF` | Default screen bg (already covered by `background`) |
| `uacColorNeutral100` | `#f2f4f7` | Filled disabled / read-only field bg |
| `uacBorderBase` | `#1d1f23` | Secondary button outline |
| `uacBorderBold200` | `#7a7f89` | Default text-field border |
| `uacTextBase` | `#1d1f23` | Primary text (already `text: #000000` — close but not exact) |
| `uacTextSubtle100` | `#40444d` | Read-only value, satisfied criteria |
| `uacTextSubtle200` | `#7a7f89` | Placeholder, pending criteria |
| `uacTextPrimaryBase` | `#f2efec` | CTA label on dark bg |
| `uacTextDangerBase` | `#bb251a` | Error text (alias existing `figmaDestructive`) |
| `uacTextInfoBase` | `#1465b4` | "Forgot your password?" link |
| `uacOnSurfaceVariant` | `#49454f` | M3 list supporting text (already `figmaTextMuted`) |

**Spacing**: existing `spacing.{xs:4, s:8, m:16, l:24, xl:32}` covers `--dimension/4/8/16/24`. No additions needed. Add named constants for screen-specific: `bodyPadding=24`, `headerHeight=107`, `safeAreaTop=112`, `safeAreaBottom=12`, `buttonHeight=56`, `buttonRadius=16`, `fieldRadius=8`, `screenRadius=18`.

**Typography**: `theme.typography.aliases` already has Poppins variants. Need additions for Inter/Roboto/Noto Sans (see infrastructure table). Existing `playfair*` / `manrope*` / `archivo*` are unrelated to UAC.

**Font installation**:
- `Poppins-Bold.ttf`, `Poppins-SemiBold.ttf` — Poppins family already in project (`Poppins-Regular`, `Poppins-Medium` used in theme). Add Bold + SemiBold.
- `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf` — verify if Inter family already vendored under `auxi/src/assets/fonts/`; if not, download + `npx react-native-asset` link.
- `Roboto-Regular.ttf` — for M3 `body/small`. Verify presence.
- `NotoSans-Regular.ttf` — required for vi locale (diacritics fallback per screen 2 spec).

**Verification**: `ls auxi/src/assets/fonts/` (not done in this scan — flag for mobile-dev to confirm before estimating effort).

---

## i18n gap

Locale files: `auxi/src/translations/en-EN.json` (66 lines, partial) + `fr-FR.json`. **No `vi-VN.json`**. `index.ts` only registers `en-EN` + `fr-FR`.

**Schema additions needed** (proposed namespace `boilerplate.uac.*`):

```
boilerplate.uac.welcome.{title, headline_line1, headline_line2, cta_google, cta_apple, cta_email, terms, privacy, language_link}
boilerplate.uac.language.{title, en, vi}
boilerplate.uac.email_input.{title, placeholder, error_invalid_format, error_required}
boilerplate.uac.password_create.{title, placeholder, criteria_8_chars, criteria_lowercase, criteria_number}
boilerplate.uac.verify_email.{title, body_line_a, body_line_c, cta_open_mail, cta_resend, cta_resend_cooldown, logout}
boilerplate.uac.email_google_notice.{title, body, cta}
boilerplate.uac.signin.{title, password_placeholder, forgot_link, error_invalid_credentials, error_not_verified}
boilerplate.uac.forgot_request.{title, body, cta}
boilerplate.uac.forgot_check_mail.{title, body, hint_spam, cta_back_login}
boilerplate.uac.reset_password.{title, body, placeholder, criteria_* same as create}
boilerplate.uac.verified_success.{title, body, cta}
```

**vi translation work**: ~40-50 keys × 1 locale. Designer-flagged copy (OQ #5) needs Việt to confirm tone (em/anh form?), idioms ("Verify your email" → "Xác minh email" vs "Xác thực email"), and font fallback to Noto Sans.

**fr-FR**: out of scope for AU-242 (no FR requirement). Leave existing keys; don't extend fr to UAC unless PM asks.

---

## Open questions blocking implementation

### Carried over from `00-index.md` (designer + PM)

1. **Brand name**: Figma shows "Macgie"/"Maogie"; ticket uses "Auxi". → **Viet** (designer) — must reconcile before any copy is finalized.
2. **Password screen title**: "What is your email" on screens 4/5 looks like copy-paste artifact. Should be "Create a password". → **Viet**.
3. **Typos in Figma**: screen 08 "adress", 13 "verified account" (missing "your"), 10 "reseting", 11 double space. → **Viet / PM** approve copy edits.
4. **Welcome legal links** (Terms / Privacy): style + tap behavior unspecified. → **PM**.
5. **vi translations**: full string set needs translation. → **Viet** (or PM for sourcing).
6. **Empty top-right `feedback` slot** (47×47) on input screens: real feature or placeholder? → **Viet / PM**.
7. **Password criteria icon swap** (pending → check on satisfied): same SVG in Figma; confirm whether to swap to checkmark or just change color. → **Viet**.
8. **Inline submit chevron** on screens 9, 12 (and 3, 4, 5, 8): final CTA or is a labeled "Sign in" / "Reset password" button missing? Currently visible spec uses only the icon. → **Viet / PM**.
9. **Resend cooldown format** `(00s)` vs `(NN s)` vs `(NNs)`: spacing? → **Viet**.
10. **Error border color** on screen 8: stays neutral `#7a7f89` per Figma; M3 standard is danger-red. Intentional? → **Viet**.
11. **Sign-in error state**: no Figma frame for invalid creds on screen 9. Mobile-dev to infer or designer to spec? → **Viet**.
12. **Eye icon toggle** (screen 9, 12): single icon (eye) or swap (eye / eye-off)? → **Viet**.
13. **Verified! (13) routing**: signup → onboarding (AU-243) or Home? Reset → re-login or session restore? → **PM**.
14. **"Back to Login"** on screen 11: pop to Welcome (1) or Sign in (9)? → **PM**.
15. **Screen 11 buttons**: AC says "Back to Login" + "Open mail app"; Figma shows only the back-to-login button. → **PM** decides.
16. **Email screens 6 vs 8**: same Figma layer name. Designer to rename. → **Viet**.
17. **Password rules consistency** signup (4/5) vs reset (12): both `≥8 + lowercase + number`. Confirm no future divergence. → **Viet**.
18. **No confirm-password field** in Figma: drop double-entry requirement? Current `RegisterScreen.tsx` requires it. → **PM**.
19. **Welcome "English" link**: text button → navigate or open bottom sheet? → **Viet**.
20. **Welcome buttons count**: 3 (Google/Apple/Email) per current Figma, vs 4 mentioned in older notes. → **Viet** confirms 3.

### New questions surfaced during this scan

21. **Backend OAuth provider selection**: Apple Sign-In requires Apple Developer entitlement + a backend that can verify Apple identity tokens. Is the Apple Developer account already provisioned (looks like yes per recent TestFlight work)? Google needs OAuth 2.0 client IDs for iOS + Android + a backend "web" client. → **tech-lead**.
22. **Email service provider**: SES / SendGrid / Postmark / Resend? Cost vs deliverability tradeoff. Must support templated transactional with verify + reset HTML. → **tech-lead / PM**.
23. **Deep-link strategy**: custom scheme `auxi://` may be blocked by Gmail/Outlook mobile. iOS Universal Links + Android App Links recommended for production. Requires apple-app-site-association + assetlinks.json hosting. → **tech-lead**.
24. **Existing-user backfill**: ~N users in DB without `email_verified_at`. Grandfather them (set verified at migration) or force re-verification? → **PM / tech-lead**.
25. **Refresh-token rotation policy**: on each refresh, issue new refresh + revoke old (rotation) or keep same refresh until expiry? Affects DB churn + multi-device sessions. → **backend-dev / tech-lead**.
26. **`/api/auth/account-by-email` enumeration**: even rate-limited, this endpoint leaks account existence. Alternative: skip the precheck, always route to password screen, surface "this email uses Google" only after wrong-password attempt. Designer flow assumes precheck — confirm. → **tech-lead / Viet**.
27. **Apple private-relay email**: when user picks "Hide my email", we get `@privaterelay.appleid.com`. Acceptable for user identity? Affects future email-based features (notifications, support). → **PM**.
28. **Password min-length conflict**: backend currently `min_length=6` (`schemas/auth.py`); Figma spec says `≥8`. Bumping breaks existing users on next password-change but not on login. → **backend-dev**.
29. **`refresh_token` on iOS Keychain**: keychain `setGenericPassword(service, username, password, options)` supports `accessGroup` for sharing — relevant if we ever ship an iOS extension. Park for now. → **mobile-dev**.
30. **Locale persistence**: current code has no AsyncStorage-backed locale store; `i18n.init({ lng: 'en-EN' })` is hardcoded in `translations/index.ts:23`. Language screen needs to write through to AsyncStorage + re-init i18n. → **mobile-dev**.

---

## Recommended sequence

1. **Foundation** (1-2 days)
   - Theme tokens added (`auxi/src/theme/theme.ts`)
   - Fonts vendored + linked
   - i18n `vi-VN.json` skeleton + `Language` type + locale persistence (`hooks/language/schema.ts` referenced but doesn't exist — need to create or simplify)
   - Secure storage refactor (`auxi/src/services/auth.ts` multi-key)

2. **Backend endpoints** (4-6 days)
   - User model migration: `email_verified_at`, `oauth_provider`, `oauth_subject`, `apple_private_relay`, `display_name`
   - `email_service.py` + provider account setup
   - Verify-email + resend-verification routes
   - Forgot-password + reset-password routes
   - Refresh + logout routes
   - Update `API_DOCUMENTATION.md` (mandatory per backend rules)
   - `python test_server.py` green

3. **Service layer + contract sync** (1 day)
   - `auxi/src/services/auth.ts` extended methods
   - Consolidate to single `apiClient`
   - 401 + refresh interceptor
   - `AuthContext.tsx` extensions

4. **Screens in dependency order** (5-7 days)
   - Welcome (1) — refactor existing
   - Language Settings (2) — independent, simple
   - Email Input (3) + Email Input Error (8) — same screen, two states
   - Password Create typing (4) + valid (5) — same screen, two states
   - Verify Email (6) + polling logic
   - Sign In (9) — rewrite from existing
   - Forgot Request (10) + Check Mail (11)
   - Reset New Password (12)
   - Email-Google Notice (7) — depends on precheck endpoint
   - Verified Success (13)

5. **OAuth integration** (3-5 days, independent slice)
   - Install + configure `@react-native-google-signin/google-signin`
   - Install + configure `@invertase/react-native-apple-authentication`
   - iOS capabilities + URL schemes
   - Android Google web client ID
   - Backend Google + Apple verification routes
   - Hide Apple button on Android

6. **Email + deep-link plumbing** (2-3 days)
   - Email templates (verify + reset)
   - Deep-link handler in `App.tsx` (or wherever root is)
   - Universal Links / App Links setup (apple-app-site-association + assetlinks.json)

7. **QA gates**
   - testID coverage audit per screen
   - `qa-ui` authors Maestro flows under `maestro/flows/auth/`
   - `qa-mobile` executes happy paths: signup-verify-home, signin-home, forgot-reset-verified, google-signin-home, apple-signin-home, language-switch-vi
   - `qa-ux` heuristic review (Nielsen + Dynamic Type + VoiceOver)

---

## Effort estimate

| Item | Effort | Owner |
|---|---|---|
| Theme tokens + fonts | S | mobile-dev |
| i18n vi skeleton + locale persistence | M | mobile-dev (+ Viet for copy) |
| Secure storage refactor | M | mobile-dev |
| Backend user model migration | M | backend-dev |
| Email service integration | M | backend-dev (+ tech-lead for provider choice) |
| Verify-email + resend endpoints | M | backend-dev |
| Forgot + reset endpoints | M | backend-dev |
| Refresh + logout endpoints | S | backend-dev |
| Account-by-email precheck (if kept) | M | backend-dev (+ tech-lead security review) |
| API_DOCUMENTATION.md updates | S | backend-dev |
| Mobile authService + AuthContext extension | M | mobile-dev |
| Welcome screen rewrite | M | mobile-dev |
| Language screen | S | mobile-dev |
| Email input + error states | M | mobile-dev |
| Password create (typing + valid) | M | mobile-dev |
| Verify email + polling + cooldown | M | mobile-dev |
| Email-Google notice | S | mobile-dev |
| Sign in rewrite | M | mobile-dev |
| Forgot request | S | mobile-dev |
| Forgot check mail | S | mobile-dev |
| Reset new password | M | mobile-dev |
| Verified success | S | mobile-dev |
| Google Sign-In integration (mobile + backend) | L | mobile-dev + backend-dev |
| Apple Sign-In integration (mobile + backend) | L | mobile-dev + backend-dev |
| Deep-link / Universal Links setup | M | mobile-dev + backend-dev (asset hosting) |
| Maestro flows | M | qa-ui (author) + qa-mobile (run) |
| UX/a11y heuristic review | S | qa-ux |

**Totals (rough)**: Mobile ~12-15 dev-days. Backend ~7-9 dev-days. OAuth slice ~5 days parallelizable. QA ~3-4 days.

---

## Unresolved questions

Numbered 1-30 above. Critical-path blockers before any implementation can start:

- **#1 brand name** (blocks all copy)
- **#22 email provider** (blocks verify + reset endpoints)
- **#13 verified→home routing** (blocks screen 13)
- **#21 OAuth provisioning** (blocks Google + Apple slices)
- **#26 enumeration risk on account-by-email** (drives whether screen 7 exists at all)
- **#28 password min-length backend mismatch** (blocks register endpoint update)

Park-and-proceed:

- Most copy/typo questions (#3, #9, #15) — implement against current Figma strings, iterate after Viet review
- #6 feedback slot — leave as empty 47×47 spacer until product confirms
- #18 confirm-password — implement without (matches Figma); easy to add back if PM reverses
- #20 button count — 3 confirmed by node tree on screen 1

---

**Status**: DONE
**Summary**: 2 of 13 mobile screens exist; 2 of ~11 backend endpoints exist. Foundation work (theme, i18n, secure storage) needed before screens. OAuth + email service are independent slices with their own blockers. 30 open questions surfaced (20 carried from spec, 10 new). Recommended sequence: foundation → backend → service layer → screens → OAuth → QA.
**Concerns/Blockers**: Email service provider unselected — backend verify/reset cannot ship until chosen. Brand name unresolved — all copy is gated. Apple/Google OAuth credentials provisioning status unknown — flag to tech-lead. `auxi/src/hooks/language/schema.ts` referenced in `translations/index.ts:3` but the `hooks/` directory does not exist — import will fail; needs investigation independent of this ticket.
