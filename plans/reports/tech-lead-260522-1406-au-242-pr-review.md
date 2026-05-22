# AU-242 PR Review — Tech Lead Sign-off

**Date**: 2026-05-22 14:06
**Reviewer**: tech-lead (read-only, no edits)
**PRs**:
- BE PR #62 `feat/au-242-phase-02-backend-endpoints` → `main`
- Mobile PR #24 `feat/au-242-phase-01-foundation` → `main`
- Mobile PR #25 `feat/au-242-phase-03-service-layer` → PR #24
- Mobile PR #26 `feat/au-242-phase-04-integration` → PR #25

Source-of-truth files inspected: `wardrobe-backend/{API_DOCUMENTATION.md, routers/auth.py, schemas/auth.py, services/auth_token_service.py, services/oauth_service.py, app.py, migrations/versions/au242a1b2c3d_*.py, tests/test_auth_au242.py}` + `auxi/src/{services/auth.ts, services/authTypes.ts, services/apiClient.ts, services/tokenStorage.ts, services/deepLinkHandler.ts, hooks/auth/useAuthMutations.ts, context/AuthContext.tsx, navigation/AuthNavigator.tsx, types/navigation.ts, config/featureFlags.ts, utils/password-rules.ts, screens/auth/*.tsx}`.

---

## Verdict per PR

| PR | Sign-off | Conditions |
|---|---|---|
| #24 phase 01 foundation | **APPROVE** | None — additive, tsc clean, no behavior change. |
| #25 phase 03 service layer | **APPROVE** | None — types/clients/hooks match backend 1:1; 401 refresh interceptor correctly designed (singleton + retry-once + refresh-endpoint skip). |
| #26 phase 04 integration | **APPROVE WITH CONDITIONS** | Land C1 (i18n vi-VN placeholders flagged) + C2 (testID stability on resend) as follow-up tickets, not merge blockers. Sim-verified happy paths cover signup + signin. |
| #62 backend endpoints | **APPROVE WITH CONDITIONS** | Land B1 (doc drift on register-409 / login-401 `code` field) as a doc-only patch BEFORE merging to main, and B2 (OAuth `*_TEST_BYPASS` prod guard) as a follow-up. |

**Net cross-repo verdict**: APPROVE — ship, with B1 fixed in-PR.

---

## API Contract Sign-off

Endpoint-by-endpoint matrix. **B** = backend exposes, **M** = mobile consumes, **V** = verdict.

| Endpoint | B request | M request | B response | M response | V |
|---|---|---|---|---|---|
| `POST /api/register` | `{email, password, display_name?}` `schemas/auth.py:36-53` | `{email, password}` `authTypes.ts:42-45` | `{message, user, verification_required:true}` (no tokens) `routers/auth.py:216-220` | `RegisterResponse` 1:1 `authTypes.ts:47-51` | ✓ — mobile omits optional `display_name`, backend default `None` |
| `POST /api/login` | `{email, password}` | `{email, password}` | `TokenResponse` `schemas/auth.py:56-62` | `LoginResponse=TokenResponse` `authTypes.ts:62` | ✓ |
| `POST /api/auth/verify-email` | `{token}` | `{token}` `authTypes.ts:80-82` | `{verified, already_verified, user}` `routers/auth.py:446-450` | `VerifyEmailResponse` `authTypes.ts:84-88` | ✓ |
| `POST /api/auth/resend-verification` | `{email}` | `{email}` | `{ok, message}` enum-safe | `GenericOkResponse` | ✓ |
| `POST /api/auth/forgot-password` | `{email}` | `{email}` | `{ok, message}` enum-safe | `GenericOkResponse` | ✓ |
| `POST /api/auth/reset-password` | `{token, new_password}` `schemas/auth.py:171-178` | `{token, new_password}` `authTypes.ts:114-117` | `{ok, message}` | `GenericOkResponse` | ✓ |
| `POST /api/auth/refresh` | `{refresh_token}` | `{refresh_token}` | `TokenResponse` | `RefreshTokenResponse=TokenResponse` | ✓ |
| `POST /api/auth/logout` | `{refresh_token?}` (auth required) | `{refresh_token?}` | `GenericOkResponse` | `LogoutResponse=GenericOkResponse` | ✓ |
| `POST /api/auth/google` | `{id_token}` `schemas/auth.py:181-182` | `{id_token}` `authTypes.ts:145-147` | `TokenResponse` | `GoogleSignInResponse=TokenResponse` | ✓ |
| `POST /api/auth/apple` | `{identity_token, name?}` `schemas/auth.py:185-188` | `{identity_token, name?}` `authTypes.ts:155-158` | `TokenResponse` | `AppleSignInResponse=TokenResponse` | ✓ |
| `POST /api/auth/email-precheck` | `{email}` (optional auth) | `{email}` (no auth — anon mode) | `{provider: 'none'\|'password'\|'google'\|'apple'}` `schemas/auth.py:200-203` | `EmailPrecheckResponse` `authTypes.ts:170-178` | ✓ |

**Error code vocabulary alignment**: every code emitted by `routers/auth.py` is mirrored in the mobile `AuthErrorCode` union `authTypes.ts:200-222`. `mapAuthError` `services/auth.ts:114-169` reads both top-level `code` and `detail.code` per the `app.py` exception handler at `app.py:135-156`. ✓

**Token response shape**: `TokenResponse` server-side has no `user` field `schemas/auth.py:56-62`; mobile `TokenResponse` declares `user?: User` `authTypes.ts:30` as optional — non-breaking. ✓

---

## Security findings

1. **[medium]** OAuth test-bypass env vars (`GOOGLE_OAUTH_TEST_BYPASS`, `APPLE_OAUTH_TEST_BYPASS`) have NO startup guard against accidental prod set `services/oauth_service.py:58, 134`. Setting either to "1" in prod silently disables signature verification on Google/Apple id_tokens — total account takeover via forged unsigned JWT. Backend PR body acknowledges the gap. Action: add `if settings.ENV in ("production","staging") and any of these are set → raise` in `app.py` lifespan or settings validation. Post-merge follow-up acceptable provided prod env is verified clean today.
2. **[low]** `verify_apple_identity_token` does not assert `email_verified` from claims `services/oauth_service.py:166-178`. `is_private_relay` is derived from the email suffix, but a forged un-verified `email_verified=false` Apple claim still mints a session. Mitigation: Apple ID tokens are verified against the JWKS so non-Apple-issued tokens can't reach this branch — acceptable. Add `if not claims.email_verified` guard symmetric to Google `routers/auth.py:760-770` as defence-in-depth.
3. **[low]** `forgot-password` rate-limit at 3/hour/email `routers/auth.py:516-520` is generous when paired with a real email service. Acceptable for phase 06 swap; bump to 3/24h once SES/Resend lands or attacker spam costs the user.
4. **[low]** `email-precheck` enumeration safety relies on anonymous callers — but mobile `apiClient.ts:23-33` injects `Authorization` Bearer from Keychain on every request, including precheck. If a previously-logged-in user signs out incompletely (Keychain not cleared) and re-installs, precheck calls could re-classify as authenticated. Confirmed not exploitable today (`clearTokens` wipes all 5 fields + legacy `apiClient.ts:160-174`), but worth a `noAuth` axios instance for the precheck call. Mobile-side concern, not a backend break.
5. **[low]** Refresh token rotation: `refresh` endpoint replaces JTI but does NOT revoke the presented refresh token explicitly — relies on the `replaced_jti` chain `routers/auth.py:633-635`. Verify `validate_refresh_token` in `utils/auth_utils.py` rejects already-rotated jtis (not in this PR's diff but adjacent to it).
6. **[low]** `reset_password` correctly invalidates all refresh tokens `routers/auth.py:601`. ✓ Documented behavior matches.
7. **[low]** Apple private-relay handling: `_attach_or_create_oauth_user` stores `private_relay=claims.email` when relay detected `routers/auth.py:837`, but the public `email` column also stores the same relay address. On a future "send real-mail" workflow there's no way to know that `users.email` is a relay vs real. Acceptable for AU-242; flag for phase 06 email work.
8. **[low]** Password policy is identical on backend (`schemas/auth.py:_validate_password_strength`) and mobile (`utils/password-rules.ts:39-49`). Both enforce ≥8 chars + lowercase + digit. ✓ — drift-free by construction.

---

## Architecture findings

1. **[good]** AuthContext bridge to AppNavigator: `useAuth().refreshUser()` is called by SignIn `screens/auth/SignInScreen.tsx:131-135` after `loginMutation.onSuccess` (this is the fix shipped in `ce95bb5e` per PR #26 body). PasswordCreation does NOT call refreshUser — correct, because register doesn't issue tokens.
2. **[good]** 401 refresh interceptor design `services/apiClient.ts:154-189`: singleton in-flight promise `apiClient.ts:70-117` prevents dogpiling, `_au242_retried` marker prevents loops, refresh endpoint excluded from interceptor. Bare axios POST avoids interceptor re-entrance `apiClient.ts:78-83`. ✓
3. **[good]** Session-expired listener pattern `apiClient.ts:126-147` correctly decouples AuthContext from apiClient (avoids require cycle). Guarded by `sessionExpiredFiredRef` `AuthContext.tsx:42-44` against duplicate toasts.
4. **[good]** `mapAuthError` reads top-level `code` first then `detail.code` `services/auth.ts:130-132` — robust against the dual-emit pattern in `app.py:145-156` and the older string-detail envelope.
5. **[good]** `validatePassword` lives in shared `utils/password-rules.ts` and is consumed by both `PasswordCreationScreen.tsx:53,132` and `ResetNewPasswordScreen.tsx:51,72` — prevents the signup-vs-reset drift the PR body claimed to address. ✓
6. **[good]** Feature flag `UAC_V2_ENABLED` `config/featureFlags.ts:32` correctly defaults to `__DEV__` (i.e., dev=true, release=false). Legacy `Login`/`Register` retained `navigation/AuthNavigator.tsx:89-94` for rollback. ✓ Production rollout requires flipping default to `true` once batch QA passes — call this out in release notes.
7. **[good]** Migration is additive, columns nullable, backfill SQL grandfathers existing users `migrations/.../au242a1b2c3d:31-49` and `email_verified_at=created_at` / `oauth_provider='password'`. Downgrade DELETEs OAuth-only rows (documented in `API_DOCUMENTATION.md:528`). Acceptable risk per phase 02 contract.
8. **[good]** Token storage layout `services/tokenStorage.ts` correctly multi-keys access/refresh/expiry/email; `migrateLegacyKeychain:186-220` is idempotent and falls back safely.
9. **[medium]** Deep-link handler `services/deepLinkHandler.ts:167-182` calls `verifyEmail` and navigates to `Verified` optimistically. Failure surfaces only via `console.warn:180` — the Verified screen has no path to display an error. PR #26 body acknowledges as open follow-up. Acceptable for sim-verified happy path; mobile follow-up ticket required to wire mutation state into Verified.
10. **[medium]** `EmailGoogleNoticeScreen.tsx:59-85` Google CTA is a toast stub — no Google SDK wired. Backend route exists and is contract-correct. Phase 05 (mobile-dev's open follow-up) is the right home; do NOT block merge.
11. **[low]** `apiClient.ts` instance and `services/auth.ts` create separate axios clients (`api = axios.create` `auth.ts:41-46` + `apiClient` `apiClient.ts:12-17`). The auth-only client does NOT have the 401-refresh interceptor — meaning a 401 on `/api/me` triggered via `authService.getCurrentUser()` does NOT auto-refresh. AuthContext's `checkAuth.catch` falls through to `logout()` `AuthContext.tsx:78-87`. This is functionally correct (bad token = log out) but inconsistent with the documented "401 retries refresh once" contract. Recommend consolidating to a single client post-merge.
12. **[low]** `LogoutRequest` is sent even when AuthContext.logout() bypasses the API call `AuthContext.tsx:153-164` — `authService.logout` doesn't call `/auth/logout` at all `services/auth.ts:238-247`, only clears tokens. Refresh tokens persist server-side until natural expiry. Functional but wasted token validity. Move to `useLogoutMutation` once integration stabilizes.

---

## Drift risks identified

1. **[B1 — major]** `API_DOCUMENTATION.md:72` says register-409 emits `no code field` and `:121` says login-401 emits `no code`. **But** `routers/auth.py:178-179, 270-272` DO emit `EMAIL_ALREADY_EXISTS` and `INVALID_CREDENTIALS` (added in commit `473beea`). Mobile depends on these codes — `PasswordCreationScreen.tsx:158` switches on `EMAIL_ALREADY_EXISTS`, `SignInScreen.tsx:113` switches on `INVALID_CREDENTIALS`. Code → mobile contract is fine; the doc is stale. **Action**: doc-only patch updating both error tables + the AU-242 error-code-vocabulary matrix `API_DOCUMENTATION.md:486-499` to include `EMAIL_ALREADY_EXISTS (409, /api/register)` and `INVALID_CREDENTIALS (401, /api/login)`. Fix in PR #62 before merge. Severity: major because the doc IS the cross-repo contract per CLAUDE.md.
2. **[B2 — minor]** Mobile `AuthErrorCode` union includes `WEAK_PASSWORD` `authTypes.ts:211`, but backend never emits this code — password-policy failures emit `400 Validation Error` envelope (Pydantic). `mapAuthError` `services/auth.ts:148-150` correctly coerces 400-validation into `VALIDATION_ERROR`. Mobile screens that check `WEAK_PASSWORD` (`PasswordCreationScreen.tsx:161`, `ResetNewPasswordScreen.tsx:107`) will never hit that branch; the `VALIDATION_ERROR` fallback path applies. Cosmetic — document or remove `WEAK_PASSWORD` from the union next iteration.
3. **[B3 — low]** Mobile `EmailPrecheckResponse.provider` includes `'none'` `authTypes.ts:177`, but anonymous callers never receive `'none'` per backend enumeration safety `routers/auth.py:877-879`. Branch is dead for anonymous calls but correct for the future authenticated-admin precheck. No action.
4. **[B4 — low]** `oauth_provider` literal: backend stores arbitrary string of len ≤ 20 `models/user.py` (`String(20)`), but only `password|google|apple` are valid. Mobile `OAuthProvider` is the strict literal. Backend should enforce via CHECK constraint or validator if column ever becomes write-from-payload (not today — it's set from server logic only).
5. **No third-repo impact**: `wardrobe-admin/` is not affected by AU-242. Backend public routes (`/api/auth/*`) live outside the `/admin/*` namespace; admin SPA doesn't touch register/login/refresh. Confirmed by checking `routers/admin/` was unchanged in PR #62 file list.

---

## Blockers (must fix before merge)

**None hard-block individual PR merge with the standard sequencing**, but for the cross-repo release order to be sound:

1. **B1 fix in PR #62**: update `API_DOCUMENTATION.md` to document `EMAIL_ALREADY_EXISTS` (register 409) and `INVALID_CREDENTIALS` (login 401) error codes. Add both rows to the error vocab table at line 486. **Doc-only diff, no code change, must land in this PR not a follow-up — the doc IS the contract.**

---

## Recommended follow-ups (post-merge)

1. **B2 prod-guard for OAuth bypass** — Add startup assertion in `app.py` lifespan: refuse to boot if `settings.ENV != "development"` and either `GOOGLE_OAUTH_TEST_BYPASS` or `APPLE_OAUTH_TEST_BYPASS` is set. Owner: backend-dev. Priority: high (before any prod deploy with this code).
2. **A1 Apple `email_verified` defence-in-depth** — Symmetric guard with Google's `OAUTH_EMAIL_UNVERIFIED` 403. Owner: backend-dev.
3. **M1 VerifyEmail screen wires deep-link verify result** — Pass mutation state from `deepLinkHandler.dispatchDeepLink` into `VerifyEmailScreen` or `VerifiedScreen` so the user sees success/failure (currently only `console.warn`). Owner: mobile-dev. AC: deep-link with invalid token shows error state instead of silent Verified screen.
4. **M2 Google SDK wiring** — Phase 05 ticket (`@react-native-google-signin/google-signin` + Apple Authentication Services). `EmailGoogleNoticeScreen` stub becomes the wired CTA. Owner: mobile-dev.
5. **M3 vi-VN translations** — 156 keys present, content is `[VI] <english>` placeholders. Owner: PM + Việt translator. AC: native VN copy review by anh Việt before public release.
6. **M4 consolidate axios clients** — Migrate `services/auth.ts` to use `apiClient` instead of its own `api = axios.create`. Eliminates the two-instance refresh-interceptor inconsistency (finding §11).
7. **M5 wire `useLogoutMutation`** — AuthContext.logout currently bypasses the `/auth/logout` route. Wire the mutation so server-side refresh tokens are revoked at sign-out.
8. **M6 `WEAK_PASSWORD` cleanup** — Remove from `AuthErrorCode` union or have backend emit it; pick one. Update mobile switch cases accordingly.
9. **M7 admin-doc note** — Inform wardrobe-admin maintainer that `users.password_hash` is now nullable and `oauth_provider` column exists; admin user-list UI may want to badge OAuth users. Non-breaking, courtesy ping per CLAUDE.md two-client policy.
10. **B3 Apple relay email-of-record** — Distinguish `users.email` (login key) from "deliverable email"; today they collide for relay users. Phase 06 email-provider swap is the right window.

---

## Merge order recommendation

Sequencing per CLAUDE.md (backend doc-first; mobile syncs to a pinned submodule HEAD):

```
1. Fix B1 in PR #62 (doc-only diff updating API_DOCUMENTATION.md error tables)
2. Merge PR #62 → wardrobe-backend/main
3. Deploy backend (staging → prod) — verify B1 doc reflects shipped behavior
4. Bump umbrella submodule HEAD for wardrobe-backend
5. Merge mobile stack BOTTOM-UP:
   5a. PR #24 → auxi/main      (foundation: tokens/theme/i18n/keychain)
   5b. Rebase PR #25 onto auxi/main; merge → auxi/main
   5c. Rebase PR #26 onto auxi/main; merge → auxi/main
6. Bump umbrella submodule HEAD for auxi
7. File post-merge follow-ups M1–M7 + A1 + B2 as separate Linear tickets
8. Verify gates per CLAUDE.md:
   - `cd wardrobe-backend && python test_server.py` green
   - `cd auxi && npx tsc --noEmit && yarn lint` baseline preserved
9. Tag UAC v2 enablement: flip `UAC_V2_ENABLED` default from `__DEV__` to `true`
   in a separate small PR after QA signs off on the new flow on a real device
   (not just sim).
```

**Why this order**: backend must ship + deploy first so mobile's pinned submodule HEAD points at a contract-stable backend. Mobile PRs stack — merging out-of-order breaks the chain. The UAC v2 flag stays `__DEV__`-only until QA verifies on TestFlight to allow a clean rollback.

**Production-trip-wire**: do NOT roll the backend to prod before B2 (OAuth bypass guard) is fixed, OR explicitly verify prod env has neither `*_TEST_BYPASS` env var set. The bypass is a complete-takeover vector if mis-set.

---

## Summary

Cross-repo contract is **clean** — every endpoint and every error code emitted by the backend has a matching mobile client and type. The five sim-verified happy paths in PR #26 body cover the critical-path AC scenarios. One doc-drift (B1) must land in PR #62 before merge; OAuth bypass prod-guard (B2) is a high-priority follow-up but acceptable as a post-merge ticket if prod env is verified clean. Mobile architecture (401 interceptor + AuthContext bridge + shared password rules) is sound and the feature flag gives clean rollback. Recommended sequence: fix B1 → merge BE → bump submodule → merge mobile stack bottom-up.

**Status**: DONE_WITH_CONCERNS
**Concerns**: B1 (doc drift on register-409 / login-401 `code` field — fix in-PR) and B2 (OAuth `*_TEST_BYPASS` prod guard — high-priority follow-up). Neither blocks the contract review; both are documented above with clear remediation.
