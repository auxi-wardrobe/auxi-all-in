# Phase 02 — Backend Endpoints + User Migration

**Owner**: backend-dev
**Priority**: P1 · **Status**: pending · **Effort**: 5d

## 1. Context Links

- Linear: https://linear.app/duncan-1/issue/AU-242 (AC 28 scenarios)
- Gap analysis: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md` §"Backend (wardrobe-backend/) — Endpoints" + L79-87 user-model gap + L84 email service + L88 rate-limit audit
- Spec: `plans/260521-2335-au-242-figma-spec/06-verify-email.md`, `10-forgot-request.md`, `12-reset-new-password.md`, `07-email-google-notice.md`

## 2. Overview

Add 9 new endpoints to `wardrobe-backend/routers/auth.py`, modify `register` + `login`, migrate User model. Behind feature flag `EMAIL_VERIFICATION_REQUIRED` so existing users aren't locked out.

## 3. Key Insights

- Existing auth router has 4 routes only: `/api/register`, `/api/login`, `/api/me` GET+PUT, `/api/me/reset-preferences`. No verification, reset, OAuth, refresh, or logout.
- `RefreshToken` model already exists at `models/token.py` with FK to User — wire it for the new `/refresh` and `/logout` routes.
- `JWT_SECRET_KEY` is configured in `settings.py` — reuse for verify + reset tokens with `type` claim (`'verify'` or `'reset'`) and short TTL.
- `utils/rate_limiter.py` exists but is **not actually applied** to any auth route (only documented) — must wire decorators this phase.
- No email service in `services/` — must add `services/email_service.py` with provider port + at least 2 templates. Provider choice is a blocker (OQ#22 — tech-lead/PM).
- Password min_length currently 6 (Pydantic in `schemas/auth.py`) — spec demands ≥8 (OQ#28).

## 4. Requirements

### Functional
- 9 new endpoints behave per gap analysis target column:
  - `POST /api/auth/verify-email { token }` → 200 / 410 expired / 404 invalid
  - `POST /api/auth/resend-verification { email }` → 200 always (enumeration-safe), 60s per-email cooldown
  - `POST /api/auth/forgot-password { email }` → 200 always, rate-limit 5/min
  - `POST /api/auth/reset-password { token, new_password }` → 200 or 410, invalidates ALL refresh tokens for user
  - `POST /api/auth/refresh { refresh_token }` → new access + (rotated?) refresh token
  - `POST /api/auth/logout` (auth required) → 204, deletes refresh token row
  - `POST /api/auth/google { id_token }` → token response, sets `email_verified_at = now()` (Google guarantees)
  - `POST /api/auth/apple { identity_token, authorization_code }` → token response, stores private-relay flag + first-encounter name
  - `GET /api/auth/account-by-email?email=` → `{ provider: 'email'|'google'|'apple'|'unknown' }`, **rate-limited 10/min/IP** (or replace per OQ#26 — see blockers)
- Modify `register`: create user with `email_verified_at = NULL`, dispatch verify email, return `{ user, verification_required: true }`. No tokens returned.
- Modify `login`: if `email_verified_at IS NULL` AND `EMAIL_VERIFICATION_REQUIRED=true` → 403 `{ code: 'email_not_verified' }`. Else proceed.
- Migration backfills `email_verified_at = created_at` for existing users (grandfathered).

### Non-functional
- `python test_server.py` green (full e2e on :5002).
- pytest coverage ≥80% on new routes.
- All new endpoints documented in `API_DOCUMENTATION.md` (sync done in phase 03).
- Email-send is async (queued or backgrounded) — request returns within 200ms.

## 5. Architecture

```
┌─ routers/auth.py ─────────────────────────────────┐
│  /api/register     (modified — verification gate) │
│  /api/login        (modified — verified check)    │
│  /api/me  GET PUT  (unchanged)                    │
│  /api/auth/verify-email                           │
│  /api/auth/resend-verification                    │
│  /api/auth/forgot-password                        │
│  /api/auth/reset-password                         │
│  /api/auth/refresh                                │
│  /api/auth/logout                                 │
│  /api/auth/google                                 │
│  /api/auth/apple                                  │
│  /api/auth/account-by-email                       │
└────────────────┬──────────────────────────────────┘
                 ↓
┌─ services/auth_service.py (extend) ───────────────┐
│  verify_email(token), generate_verify_token(user) │
│  request_password_reset(email)                    │
│  consume_reset_token(token, new_pwd)              │
│  refresh_session(refresh_token)                   │
│  verify_google_id_token(id_token)                 │
│  verify_apple_identity_token(token)               │
└────────────────┬──────────────────────────────────┘
                 ↓
┌─ services/email_service.py (NEW) ─────────────────┐
│  send_verify_email(user, token)                   │
│  send_reset_password_email(user, token)           │
│  (provider-pluggable: SES | Resend | SMTP)        │
└───────────────────────────────────────────────────┘

┌─ models/user.py ──────────────────────────────────┐
│  + email_verified_at: DateTime (nullable)         │
│  + oauth_provider: String(20) (nullable)          │
│  + oauth_subject: String(255) (nullable, indexed) │
│  + apple_private_relay: Boolean (default False)   │
│  + display_name: String(120) (nullable)           │
└───────────────────────────────────────────────────┘
```

JWT claims for verify/reset:
```json
{ "sub": user_id, "type": "verify"|"reset", "email": "...", "exp": now+TTL, "jti": uuid }
```
Verify TTL 24h, reset TTL 30min. `jti` stored in DB single-use table for reset (replay protection). Verify is idempotent so DB tracking optional.

## 6. Related Code Files

### Modify
- `wardrobe-backend/routers/auth.py` — add 9 routes, modify register + login
- `wardrobe-backend/schemas/auth.py` — bump password min_length 6→8 (gated on OQ#28); add Pydantic schemas for new endpoints
- `wardrobe-backend/models/user.py` — add 5 columns
- `wardrobe-backend/services/auth_service.py` — new methods (or split into `services/email_verification_service.py` if file grows beyond 200 lines per development-rules.md)
- `wardrobe-backend/utils/auth_utils.py` — add `create_verify_token`, `create_reset_token`, `decode_verify_token`, `decode_reset_token`
- `wardrobe-backend/settings.py` — add `EMAIL_VERIFICATION_REQUIRED`, `VERIFY_TOKEN_TTL_HOURS`, `RESET_TOKEN_TTL_MINUTES`, `RESEND_COOLDOWN_SECONDS`, email-provider config
- `wardrobe-backend/main.py` (or `app.py`) — register `email_service` startup

### Create
- `wardrobe-backend/services/email_service.py` — provider-abstracted interface + concrete impl
- `wardrobe-backend/services/templates/verify-email.html` + `reset-password.html` (+ `.txt` plaintext counterparts)
- `wardrobe-backend/models/used_reset_token.py` — single-use jti tracker for password reset (replay protection)
- `wardrobe-backend/alembic/versions/{rev}-au242-user-uac-fields.py` — migration: add 5 columns, backfill `email_verified_at = created_at`, create `used_reset_tokens` table
- `wardrobe-backend/tests/test_auth_uac.py` — pytest coverage for 9 new routes (happy + 4 error paths each)

### Delete
None this phase.

## 7. Implementation Steps

1. Draft migration `au242-user-uac-fields.py`: add 5 columns to `users` (all nullable initially), create `used_reset_tokens` table, backfill UPDATE for existing users `SET email_verified_at = created_at WHERE email_verified_at IS NULL`. Test on a copy of dev DB.
2. Update `models/user.py` to reflect new columns + relationship to `used_reset_tokens` if needed.
3. Bump `schemas/auth.py` password `min_length=8` (confirm OQ#28 first). Update register schema to accept optional `display_name`.
4. Add JWT helpers in `auth_utils.py` for verify + reset tokens (separate functions because TTL + type claim differ).
5. Implement `services/email_service.py` with `EmailServiceProtocol` (Protocol or ABC), then a concrete impl based on PM/tech-lead decision (start with SMTP for dev, SES or Resend for prod — abstract behind env).
6. Render HTML + text templates with Jinja2 (already in deps via FastAPI). Brand placeholder pending OQ#1.
7. Add `/api/auth/verify-email` route: decode token, set `email_verified_at`, return 200. Idempotent — already-verified returns 200 with `{ already_verified: true }`.
8. Add `/api/auth/resend-verification`: rate-limit per email (60s) via existing `utils/rate_limiter.py`. Always 200.
9. Add `/api/auth/forgot-password`: rate-limit 5/min, generate reset token, send email. Always 200.
10. Add `/api/auth/reset-password`: decode token, check `used_reset_tokens` for jti, update password_hash, delete all `RefreshToken` rows for user, insert jti into used table. Return 200.
11. Add `/api/auth/refresh`: validate refresh token row exists + not expired → issue new access. Rotation policy: **rotate refresh** (delete old, insert new) — OQ#25 default unless overridden.
12. Add `/api/auth/logout`: delete the refresh-token row matching presented token. Return 204.
13. Modify `/api/register`: do NOT issue tokens. Set `email_verified_at = NULL`. Call `email_service.send_verify_email`. Response: `{ user, verification_required: true }`.
14. Modify `/api/login`: branch on `email_verified_at IS NULL` + `EMAIL_VERIFICATION_REQUIRED=true` → 403 `{ code: 'email_not_verified', email }`.
15. Add `/api/auth/google`: verify ID token via `google-auth` (`google.oauth2.id_token.verify_oauth2_token`), upsert user with `oauth_provider='google'`, `oauth_subject=<sub>`, `email_verified_at=now()`. Return token response.
16. Add `/api/auth/apple`: verify identity token JWT against Apple JWKS (cache 24h), handle `email_verified` claim, detect `@privaterelay.appleid.com`, set `apple_private_relay=true`. On first encounter, accept `name` from request payload and persist to `display_name`. Return token response.
17. Add `GET /api/auth/account-by-email?email=`: rate-limit 10/min/IP. Returns `{ provider: 'email'|'google'|'apple'|'unknown' }`. **Pending OQ#26** — if tech-lead vetoes, drop this route and remove screen 7 from phase 04.
18. Apply `@rate_limit` decorator on register (5/min), login (10/min), forgot-password (5/min), resend (per email 60s), account-by-email (10/min/IP). Audit existing routes — gap analysis L88 says decorator is documented but not wired.
19. Write pytest cases: happy path + invalid token + expired token + already-consumed (for reset) + wrong email (enum-safe → still 200) per endpoint. Use SQLite test DB.
20. Run `python test_server.py` and `pytest tests/test_auth_uac.py -v`.

## 8. Todo List

- [ ] Resolve OQ#22 email provider choice (block phase start)
- [ ] Resolve OQ#28 password min-length 8 decision
- [ ] Resolve OQ#26 account-by-email keep-or-drop
- [ ] Alembic migration: add 5 columns + backfill + used_reset_tokens table
- [ ] User model + Pydantic schemas updated
- [ ] JWT helpers for verify + reset tokens
- [ ] `services/email_service.py` with provider abstraction
- [ ] HTML + text templates (verify, reset) — brand pending OQ#1
- [ ] Route: verify-email
- [ ] Route: resend-verification
- [ ] Route: forgot-password
- [ ] Route: reset-password (invalidate refresh tokens)
- [ ] Route: refresh (with rotation)
- [ ] Route: logout
- [ ] Route: google
- [ ] Route: apple (+ private relay handling)
- [ ] Route: account-by-email (conditional on OQ#26)
- [ ] Modify register (verification gate)
- [ ] Modify login (verified check)
- [ ] Rate-limit decorators wired on all auth routes
- [ ] pytest coverage ≥80% on new routes
- [ ] `python test_server.py` green

## 9. Success Criteria

- All 9 new endpoints respond per spec, validated by `pytest tests/test_auth_uac.py -v`.
- Migration runs forward + rollback cleanly on a snapshot of dev DB.
- Existing users (created before this phase) can still log in (verified backfill).
- New users created post-deploy CANNOT log in until verify-email is consumed.
- `python test_server.py` exit 0 with email service in DRY_RUN mode for CI.
- Rate-limit hit on 11th login attempt within a minute → 429.

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Migration fails mid-flight on prod (long lock on `users` table) | Low | High | Add nullable columns first (no table rewrite), backfill in a separate transaction, NOT NULL only where strictly required (none in this migration). Test on prod-sized snapshot. |
| Email provider unselected → cannot ship | High | High | **Blocker** — escalate to PM + tech-lead before phase start. Fallback: SMTP via Gmail App Password for dev only. |
| Account-enumeration leak via `/account-by-email` | High | Medium | Aggressive rate-limit + audit logging. Alternative per OQ#26: drop the endpoint and surface "this email uses Google" only post-failed-login. Pre-approve direction before implementation. |
| Refresh-token rotation breaks multi-device sessions | Medium | Medium | OQ#25 — confirm rotation policy. Default: rotate on every refresh (one device at a time per token). Document policy in API_DOCUMENTATION.md. |
| Apple JWKS network call adds latency | Medium | Low | Cache JWKS for 24h in-process; refresh on 401-from-JWKS error. |
| Backend grandfather backfill marks compromised accounts as verified | Low | Low | Acceptable for v1; flag for future audit; communicate via project changelog. |
| Verify-email link expires while in mail queue | Low | Low | TTL 24h is generous; resend-verification button (cooldown 60s) is the recovery path. |

## 11. Security Considerations

- **Account enumeration**: forgot-password, resend-verification, account-by-email must respond identically for known vs unknown emails. Add explicit test: assertEquals(known_email_response, unknown_email_response).
- **Token replay**: reset token jti tracked in `used_reset_tokens`; verify token is idempotent (multiple consumes = same end-state) so jti tracking optional but recommended.
- **Session invalidation on password reset**: hard requirement — delete all RefreshToken rows for user. Test: log in on two devices, reset password, both devices receive 401 on next call.
- **JWT secret rotation**: out of scope; document as future work.
- **Rate limits**: per AC defaults — login 5/15min (NOT 10/min as currently documented — re-check AC), signup 3/hour, reset 3/hour (per spec OQ#7). Confirm with PM before applying.
- **Email content**: no tokens logged in plaintext; emails use HTTPS-only links; verify + reset links contain JWT (signed, expires) not raw user ID.
- **OAuth subject collision**: enforce DB unique constraint on `(oauth_provider, oauth_subject)`. Add explicit test for two users registering same Google account.
- **Apple private relay**: store relayed email as-is; do not attempt to resolve to underlying address. Note future risk: cannot send marketing email to users who later revoke relay.

## 12. Next Steps

- Phase 03 (API_DOCUMENTATION.md sync + service-layer client) starts the day this phase merges.
- Phase 05 (OAuth) depends on `/google` + `/apple` routes shipping here.
- Phase 06 (email service production rollout) depends on `services/email_service.py` port defined here.

**Status**: pending
**Summary**: 9 new routes, User migration, email-service stub, rate-limit wiring. ~5 dev-days. Heavy security/test burden — pytest gate is mandatory.
**Concerns/Blockers**: OQ#22 (email provider), OQ#28 (password length), OQ#26 (account-by-email keep/drop) all must clear before kick-off.
