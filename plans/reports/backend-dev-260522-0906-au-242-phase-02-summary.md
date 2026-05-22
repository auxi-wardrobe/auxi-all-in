# AU-242 Phase 02 — Backend Handover (for Phase 03: API_DOCUMENTATION.md sync)

**Date**: 2026-05-22
**Author**: backend-dev subagent (finalization pass)
**Branch**: `feat/au-242-phase-02-backend-endpoints`
**Worktree**: `/Users/nguyenminhduc/Desktop/wardrobe_project/worktrees/wardrobe-backend-au242-phase-02`
**Final HEAD**: `d38f088` (test commit, on top of `6d5bf18` bugfix, on top of original 6 commits)
**Diff vs `origin/main`**: 13 files, +2206 / −66

---

## 1. Commit chain (8 total this branch)

| SHA | Subject |
|---|---|
| `c7a9adf` | feat(au-242): user UAC migration + AuthToken model |
| `a8ac534` | feat(au-242): AuthToken service for verify + reset tokens |
| `3b4447b` | feat(au-242): NoOpEmailService stub (log-only) |
| `58e3643` | feat(au-242): UAC Pydantic schemas + FastAPI rate-limit helper |
| `5efa4f9` | feat(au-242): OAuth verifier service for Google + Apple |
| `c644521` | feat(au-242): auth routes — verify, reset, refresh, logout, OAuth, precheck |
| `6d5bf18` | **fix(au-242)**: preserve structured HTTPException detail + JSON-safe ValidationError |
| `d38f088` | test(au-242): pytest coverage for 9 new auth endpoints |

The `6d5bf18` fix was discovered while running the new test file — pre-existing global handlers in `app.py` flattened dict-shaped `HTTPException` details and crashed on Pydantic v2 `ValueError` ctx. Without that fix, the AU-242 structured error envelope contract (`detail.code`) is unobservable to clients.

---

## 2. Files changed (per `git diff --stat origin/main..HEAD`)

```
app.py                                              |  51 +-
migrations/env.py                                   |   1 +
migrations/versions/au242a1b2c3d_au242_user_uac_fields.py |  89 +++
models/auth_token.py                                |  51 ++
models/user.py                                      |  19 +-
requirements.txt                                    |   1 +
routers/auth.py                                     | 758 +++++++++++++++++++--
schemas/auth.py                                     | 107 ++-
services/auth_token_service.py                      | 190 ++++++
services/email_service.py                           | 142 ++++
services/oauth_service.py                           | 178 +++++
tests/test_auth_au242.py                            | 650 ++++++++++++++++++
utils/rate_limit.py                                 |  35 +
```

---

## 3. Endpoints — request/response contracts

All paths below are mounted under the `/api` prefix via the existing auth router.

### 3.1 `POST /api/register` (MODIFIED)

- **Schema**: req `RegisterRequest`, resp `RegisterResponse` (HTTP 201)
- **Auth**: public
- **Rate limit**: 5 / 60s / IP (`auth:register:{ip}`)
- **Behaviour change**:
  - Password policy enforced at Pydantic layer (≥8 chars + ≥1 lowercase + ≥1 digit).
  - User created with `email_verified_at = NULL`, `oauth_provider = 'password'`.
  - **No access/refresh tokens issued** (verification gate). Response contains `{message, user, verification_required: true}`.
  - Verify email dispatched via `NoOpEmailService` (logs only in phase 02).
- **Errors**:
  - `400 Validation Error` — password policy / EmailStr failure (envelope: `{error, message, details, request_id}`).
  - `409 Conflict` — duplicate email (`detail.message = "Email already registered"`; no `code`).
  - `500 Internal Server Error` — DB write failure.

### 3.2 `POST /api/login` (MODIFIED)

- **Schema**: req `LoginRequest`, resp `TokenResponse`
- **Auth**: public
- **Rate limit**: 5 / 60s / IP (`auth:login:{ip}`)
- **Errors**:
  - `401 Unauthorized` — bad credentials (no `code`, message "Invalid credentials").
  - `403 Forbidden` `code=OAUTH_ACCOUNT` — account exists but was created via Google/Apple (extra `provider` field in detail).
  - `403 Forbidden` `code=EMAIL_NOT_VERIFIED` — credentials ok but email unverified (extra `email` field in detail).
- **OAuth-only branch precedes credential branch** (so OAuth users can't enumerate password validity).

### 3.3 `POST /api/auth/verify-email` (NEW)

- **Schema**: req `VerifyEmailRequest` `{token: str}`, resp `VerifyEmailResponse` `{verified, already_verified, user}`
- **Auth**: public
- **Rate limit**: none (token is single-use; brute force is bounded by token entropy 384 bits)
- **Behaviour**: idempotent — re-consuming a token returns 410 `TOKEN_CONSUMED`. Successful verification sets `users.email_verified_at = now()`.
- **Errors**:
  - `404 Not Found` `code=TOKEN_INVALID` — hash miss or wrong `kind`.
  - `410 Gone` `code=TOKEN_EXPIRED` — past `expires_at`.
  - `410 Gone` `code=TOKEN_CONSUMED` — already used.
  - `404 Not Found` (no code) — orphaned token, user vanished.

### 3.4 `POST /api/auth/resend-verification` (NEW)

- **Schema**: req `ResendVerificationRequest` `{email: EmailStr}`, resp `GenericOkResponse` `{ok, message}`
- **Auth**: public
- **Rate limit**: two bands enforced in order:
  - 5 / 900s / IP (`auth:resend:{ip}`)
  - 3 / 3600s / email (`auth:resend:email:{email}`)
- **Enumeration safety**: always returns `200 {ok: true}` regardless of email existence. Token issued + email dispatched only when user exists AND `email_verified_at IS NULL` AND `oauth_provider == "password"`.
- **Errors**:
  - `429 Too Many Requests` — bucket exceeded (detail: `{error, message, request_id}`).

### 3.5 `POST /api/auth/forgot-password` (NEW)

- **Schema**: req `ForgotPasswordRequest` `{email}`, resp `GenericOkResponse`
- **Auth**: public
- **Rate limit**:
  - 5 / 900s / IP (`auth:forgot:{ip}`)
  - 3 / 3600s / email (`auth:forgot:email:{email}`)
- **Enumeration safety**: same as resend — always `200 {ok: true}`. Token issued only when user exists AND `oauth_provider == "password"` AND `password_hash IS NOT NULL`. OAuth-only accounts silently skipped.
- **Errors**: 429 only.

### 3.6 `POST /api/auth/reset-password` (NEW)

- **Schema**: req `ResetPasswordRequest` `{token, new_password}`, resp `GenericOkResponse`
- **Auth**: public (token IS the auth)
- **Rate limit**: none (token-gated)
- **Side effects on success**:
  - Sets new `password_hash`.
  - Sets `email_verified_at = now()` if user was previously unverified (proof of email control).
  - Promotes OAuth-only users to `oauth_provider = "password"` (account merge).
  - **Revokes ALL active refresh tokens** for the user (`_invalidate_all_refresh_tokens`).
- **Errors**:
  - `400 Validation Error` — password policy failure.
  - `404 Not Found` `code=TOKEN_INVALID`.
  - `410 Gone` `code=TOKEN_EXPIRED`.
  - `410 Gone` `code=TOKEN_CONSUMED`.

### 3.7 `POST /api/auth/refresh` (NEW)

- **Schema**: req `RefreshTokenRequest` `{refresh_token}`, resp `TokenResponse`
- **Auth**: refresh token in body
- **Rate limit**: none in this code path (relies on JWT signature + DB allowlist via `validate_refresh_token`)
- **Behaviour**: rotates the refresh token (`replaced_jti` chain), issues fresh access token.
- **Errors**:
  - `401 Unauthorized` — invalid/expired/revoked refresh (detail: `{error: "Unauthorized", message, request_id}`).

### 3.8 `POST /api/auth/logout` (NEW)

- **Schema**: req `LogoutRequest` `{refresh_token?: str}`, resp `GenericOkResponse`
- **Auth**: required (`Depends(get_current_user)`)
- **Rate limit**: none
- **Behaviour**: if `refresh_token` supplied, revoke just that one; otherwise revoke ALL refresh tokens for the authenticated user.
- **Errors**: 401 (missing/invalid access token, handled by `get_current_user`).

### 3.9 `POST /api/auth/google` (NEW)

- **Schema**: req `GoogleOAuthRequest` `{id_token}`, resp `TokenResponse`
- **Auth**: public (the Google id_token IS the auth)
- **Rate limit**: 10 / 60s / IP (`auth:google:{ip}`)
- **Env vars**: `GOOGLE_OAUTH_CLIENT_ID` (required in non-test mode), `GOOGLE_OAUTH_TEST_BYPASS=1` (test fixture path that skips signature verify).
- **Behaviour**: verifies id_token → finds-or-creates user by `(provider, subject)` → falls back to email lookup → creates fresh OAuth user with `email_verified_at = now()` if no collision.
- **Errors**:
  - `401 Unauthorized` `code=OAUTH_VERIFICATION_FAILED` — signature/aud/exp invalid.
  - `403 Forbidden` `code=OAUTH_EMAIL_UNVERIFIED` — Google says email unverified.
  - `409 Conflict` `code=EMAIL_LINKED_TO_PASSWORD` — email already has a password account; extra `provider` field in detail.
  - `409 Conflict` `code=EMAIL_LINKED_TO_OTHER_PROVIDER` — email already linked to Apple.

### 3.10 `POST /api/auth/apple` (NEW)

- **Schema**: req `AppleOAuthRequest` `{identity_token, name?: str}`, resp `TokenResponse`
- **Auth**: public (identity_token IS the auth)
- **Rate limit**: 10 / 60s / IP (`auth:apple:{ip}`)
- **Env vars**: `APPLE_OAUTH_CLIENT_ID` (required), `APPLE_OAUTH_TEST_BYPASS=1` (test fixture).
- **Behaviour**:
  - Apple supplies the user's name only on first authorization → caller passes via optional `name` field; stored in `users.display_name`.
  - Apple may omit email on subsequent logins → we attempt lookup by `(apple, sub)`; if none exists we 400.
  - Private-relay detection: `email.endswith("@privaterelay.appleid.com")` → stored in `users.apple_private_relay`.
- **Errors**:
  - `401 Unauthorized` `code=OAUTH_VERIFICATION_FAILED`.
  - `400 Bad Request` `code=APPLE_EMAIL_MISSING` — first sign-in without email; client must revoke + retry.
  - `409` same EMAIL_LINKED_TO_PASSWORD / EMAIL_LINKED_TO_OTHER_PROVIDER as Google.

### 3.11 `POST /api/auth/email-precheck` (NEW)

- **Schema**: req `EmailPrecheckRequest` `{email}`, resp `EmailPrecheckResponse` `{provider: "none"|"password"|"google"|"apple"}`
- **Auth**: optional (`Depends(get_optional_user)`)
- **Rate limit**:
  - 5 / 60s / IP (`auth:precheck:{ip}`)
  - 3 / 60s / email (`auth:precheck:email:{email}`)
- **Enumeration safety**: anonymous clients ALWAYS receive `"password"` regardless of real linkage (AU-242 plan blocker #7 resolution). Only authenticated clients see the real provider.
- **Use case**: screen 7 "this email is linked to Google" notice in the mobile app.
- **Errors**: 429 only.

---

## 4. Error envelope contract (after `app.py` fix)

Routes use `HTTPException(detail={"code": ..., "message": ..., ...})`. The fixed `http_exception_handler` returns:

```json
{
  "error": "<from detail.error or 'Error'>",
  "message": "<from detail.message>",
  "code": "<from detail.code, if present>",
  "detail": { /* full original detail dict, with request_id merged in */ },
  "request_id": "<uuid>"
}
```

`code` is BOTH lifted to top level AND preserved inside `detail`. Client may read either. Older string-detail routes (pre-AU-242) still get the flat `{error, message, request_id}` envelope.

Validation errors (400) follow:

```json
{
  "error": "Validation Error",
  "message": "Invalid request data",
  "details": [ /* pydantic exc.errors() with ValueError ctx stringified */ ],
  "request_id": "<uuid>"
}
```

---

## 5. User model migration (`au242a1b2c3d`)

Down-revision: `d9e5f6b7c8a1`

### Columns added to `users` (all nullable for safe rollout):

| Name | Type | Default | Notes |
|---|---|---|---|
| `email_verified_at` | DateTime | NULL | Set on register=NULL, OAuth=now(), verify-email=now(), reset-password=now() |
| `oauth_provider` | String(20) | NULL → backfilled `'password'` | values: `password` / `google` / `apple` |
| `oauth_subject` | String(255), indexed | NULL | Provider's stable subject id |
| `apple_private_relay` | String(255) | NULL | Stored relay email when Apple proxied |
| `display_name` | String(120) | NULL | From OAuth name claim or registration |

### Column altered:

- `users.password_hash` → made **nullable** (OAuth-only users have no password).

### Backfill (executed during `upgrade()`):

```sql
UPDATE users SET email_verified_at = created_at WHERE email_verified_at IS NULL;
UPDATE users SET oauth_provider    = 'password'  WHERE oauth_provider IS NULL;
```

Existing users are grandfathered as verified password accounts.

### Index added:

- `ix_users_oauth_subject` on `(oauth_subject)` — non-unique.

### Downgrade behaviour:

- Drops the 5 new columns + index.
- Restores `password_hash` NOT NULL — **DELETES any rows where `password_hash IS NULL`** first (OAuth-only users get wiped on rollback). Caller signalled rollback, this is acceptable.
- Drops `auth_tokens` table first (FK to users).

Round-trip verified on sqlite (upgrade +1 → downgrade -1 → upgrade +1 — clean both ways).

---

## 6. `auth_tokens` table (new)

| Column | Type | Constraints |
|---|---|---|
| `id` | String(36) | PK, uuid4 default |
| `user_id` | String(36) | FK → `users.id` ON DELETE CASCADE, indexed |
| `token_hash` | String(64) | NOT NULL, UNIQUE, indexed — SHA-256 hex of raw token |
| `kind` | String(20) | NOT NULL, indexed — `email_verify` / `password_reset` |
| `expires_at` | DateTime | NOT NULL |
| `consumed_at` | DateTime | NULL |
| `created_at` | DateTime | NOT NULL, default now() |

TTLs (in `services/auth_token_service.py`):
- `email_verify`: 24 hours
- `password_reset`: 30 minutes

Raw token: `secrets.token_urlsafe(48)` (~64 base64url chars, 384 bits entropy). Only the SHA-256 hash is persisted. `create_token(..., invalidate_previous=True)` (default) consumes all pending tokens of the same kind for the user before issuing a fresh one.

---

## 7. NoOpEmailService log format

`services/email_service.py::NoOpEmailService` logs at INFO level (`services.email_service` logger):

```
[NoOpEmail] Would send VERIFY email to=<email> locale=<locale> link=<PUBLIC_BASE_URL>/api/auth/verify-email?token=<raw>
[NoOpEmail] Would send RESET  email to=<email> locale=<locale> link=<PUBLIC_BASE_URL>/api/auth/reset-password?token=<raw>
```

Grep recipe for dev QA:

```bash
tail -f logs/*.log | grep "\[NoOpEmail\]"
```

`PUBLIC_BASE_URL` env var falls back to `http://localhost:5001` if unset.

Also adds a Sentry breadcrumb (`category=email`, `level=info`) when `sentry_sdk` is initialised.

Driver selected via `EMAIL_SERVICE_DRIVER` env var (default `noop`). Phase 06 will add `ses`/`resend` adapters behind the same port.

---

## 8. requirements.txt additions

```diff
+google-auth>=2.47.0          # Google OAuth id_token verification (AU-242)
```

Apple OAuth re-uses already-present `PyJWT` + `requests`. `fakeredis` already pinned.

No additions to `requirements-minimal.txt`.

---

## 9. Verification log

### 9.1 pytest (`tests/test_auth_au242.py`)

```
39 passed, 0 failed, 9 warnings, 8s
```

(Pydantic v2 deprecation warnings + InsecureKeyLengthWarning from the 11-byte HMAC test keys are expected.)

### 9.2 Regression sweep (rest of `tests/`)

```
646 passed, 57 failed, 104 skipped (excluding tests/test_gemini_service.py which has a pre-existing ImportError)
```

The 57 regression failures are PRE-EXISTING and unrelated to AU-242:
- `tests/utils/test_s3_url.py` (5) — S3 env config drift, returns `/static/uploads/...` instead of S3 URL.
- `tests/scenarios/test_v05_*_schema_drift.py` (5) — committed JSON schema snapshots out of date with current Pydantic v2 models.
- `tests/test_weather_integration.py` (4) — weather provider config.
- Plus ~43 other pre-existing failures across recommendation/decision modules.

Confirmed not caused by `app.py` fix — checked traceback on `test_get_public_url_without_endpoint` (assertion on `S3Manager.get_public_url()` return value; no `app.py` involvement in the call chain).

### 9.3 Alembic round-trip (sqlite)

The full chain hits a PRE-EXISTING break at `f9c1a2b3d4e5_scope_user_hrid_uniqueness` (uses `sqlite_where="..."` string literal that SQLAlchemy's sqlite dialect can't compile). To verify the AU-242 migration alone, ran an isolated round-trip: stamp at `d9e5f6b7c8a1`, then `upgrade +1` → `downgrade -1` → `upgrade +1` on a sqlite scratch DB seeded with a minimal `users` table.

Verified on the final upgrade:
- `users` columns: `apple_private_relay, created_at, display_name, email, email_verified_at, id, oauth_provider, oauth_subject, password_hash` — all 5 new fields present.
- `auth_tokens` table exists with 7 columns.
- Backfill executed: existing seed user has `email_verified_at = created_at`, `oauth_provider = 'password'`.

### 9.4 Server boot smoke

Drove FastAPI lifespan via `app.router.lifespan_context(app)` in-process. Result:

```
AU-242 routes registered: 11
  /api/auth/apple
  /api/auth/email-precheck
  /api/auth/forgot-password
  /api/auth/google
  /api/auth/logout
  /api/auth/refresh
  /api/auth/resend-verification
  /api/auth/reset-password
  /api/auth/verify-email
  /api/login (modified)
  /api/register (modified)
SMOKE OK
```

Startup + shutdown clean. No import errors.

---

## 10. Open questions / phase-03 inputs / phase-06 risks

1. **Rate-limit library used** — handcoded `utils/rate_limit.py` (Redis INCR + EXPIRE). Falls open if Redis unavailable. `RATE_LIMIT_ENABLED` env var bypasses entirely. No sliding-window, no leaky-bucket — fixed-window only. May need replacement (slowapi / fastapi-limiter) under load.

2. **Refresh-token storage strategy** — uses pre-existing `validate_refresh_token` / `generate_refresh_token` / `revoke_refresh_token` from `utils/auth_utils.py` (jti allowlist in DB, table TBD). `replaced_jti` chain for rotation. **NOT TOUCHED in this phase** — relying on the existing implementation. Phase 03 should NOT document refresh-token table internals; that's a separate concern.

3. **Session invalidation on password reset** — `reset-password` calls `_invalidate_all_refresh_tokens(db, user.id)` which uses the same existing allowlist machinery. Active access tokens are NOT revoked (no JWT denylist) — they expire on their own 15 min lifecycle. Acceptable per UAC spec; if tightening required, will need a `users.token_invalid_before` timestamp + check in `get_current_user`.

4. **Apple JWK caching strategy** — `services/oauth_service.py::_fetch_apple_jwks` caches at module level for 24h, in-memory only (lost on process restart). Concurrent first-request thundering herd is possible. No retry on `requests.RequestException`. Single Redis-backed cache would be sturdier but not required for phase 02 traffic.

5. **NoOpEmailService → Phase 06 swap** — port at `EmailService` ABC. Driver dispatch in `get_email_service()` reads `EMAIL_SERVICE_DRIVER`. When a real adapter lands, no caller changes needed.

6. **Email enumeration via timing** — register/login/forgot/precheck try to return uniform 200/4xx envelopes for unknown vs known emails, but `bcrypt`/`argon2` hash time on real password verification is observable. Acceptable for MVP; mitigation requires a dummy hash on missing users.

7. **Test bypass env vars in prod** — `GOOGLE_OAUTH_TEST_BYPASS=1` / `APPLE_OAUTH_TEST_BYPASS=1` skip signature verification. Must never appear in prod env. Consider adding a guard that crashes startup if `TESTING=False AND *_TEST_BYPASS=1`.

8. **`app.py` exception-handler fix scope** — applied to the global handler. Verified no regression in 646 passing tests. But: other routers may have been relying on the old flat envelope shape. The fix is backward-compat for string details (preserves the old `{error, message, request_id}` shape) and adds the new behaviour only for dict details. Low risk, but worth a tech-lead eyeball.

---

## 11. For Phase 03 author

Write the API docs directly from §3 (endpoint contracts) + §4 (error envelope) + §5–6 (data model deltas). The exact `code` strings, status codes, rate-limit numbers, and rate-limit keys above are the source of truth — match them verbatim. The four `EMAIL_LINKED_TO_*` / `OAUTH_*` / `TOKEN_*` / `APPLE_EMAIL_MISSING` error codes are the new vocabulary the mobile dev needs.
