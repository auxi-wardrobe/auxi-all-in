# Phase 06 — Email Service + Deep-Links

**Owner**: backend-dev (+ tech-lead for provider decision, devops-adjacent for Universal Links hosting)
**Priority**: P1 · **Status**: pending · **Effort**: 3d

## 1. Context Links

- Linear: https://linear.app/duncan-1/issue/AU-242 (AC #14 — verify link opens app; AC #20 — reset link opens app)
- Gap analysis: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md` L84 ("Email service gap — no SMTP/SES/SendGrid/Postmark integration found"), L53 deep-links, OQ#22/#23 (provider + deep-link strategy)
- Spec: `plans/260521-2335-au-242-figma-spec/06-verify-email.md`, `11-forgot-check-mail.md`

## 2. Overview

Pick + integrate an email provider, ship verify + reset templates with i18n + brand support, and stand up iOS Universal Links so verify/reset URLs open the app directly (custom scheme `auxi://` gets blocked by mail clients).

## 3. Key Insights

- Phase 02 stubbed `services/email_service.py` with a provider port. This phase lands the real provider + production wiring.
- Custom scheme `auxi://` is unreliable in production — Gmail and Outlook mobile block it. iOS Universal Links + Android App Links recommended (OQ#23).
- Universal Links require hosting `apple-app-site-association` at `https://<domain>/.well-known/apple-app-site-association` with no extension, served as `application/json`. Requires a stable web domain.
- Apple/Google OAuth users **do not need** verify emails — `email_verified_at` set on first OAuth login. Welcome email is a product decision (OQ — file under PM).
- Recipients without the app installed must land on a fallback web page (or generic "Open in app" page). Out of scope here unless PM decides otherwise.

## 4. Requirements

### Functional
- Concrete `EmailService` implementation (pluggable provider via env).
- 2 templates: `verify_email`, `reset_password`. Each has HTML + plaintext, supports en + vi locales, contains brand-aware copy (OQ#1 — placeholder if brand unresolved).
- Verify email delivered within 30s of register; reset email within 30s of forgot-password request.
- Each email contains a Universal Link: `https://auxi.app/auth/verify?token=…` / `https://auxi.app/auth/reset?token=…`.
- iOS app intercepts these URLs and routes to in-app screens (verify → VerifiedSuccess; reset → ResetNewPassword).
- Fallback if app not installed: redirect to App Store (per `apple-app-site-association` rules).
- Send failures retried once async; if both fail, error logged + flagged for ops alert.

### Non-functional
- Delivery success rate >95% in staging tests against test inbox.
- Send latency <200ms p50 (async queue).
- `python test_server.py` green with email provider in DRY_RUN mode (no real send in CI).

## 5. Architecture

```
backend
  routers/auth.py
    register / forgot-password / resend-verification
       ↓
    services/email_service.py
       ├─ EmailServiceProtocol (port)
       │     send_verify(user, token)
       │     send_reset(user, token)
       └─ Provider impl (chosen via env):
             SESEmailProvider
             ResendEmailProvider
             SMTPEmailProvider (dev only)
       ↓
    templates/
       verify-email.html / .txt    (Jinja2)
       reset-password.html / .txt  (Jinja2)
       _layout.html                (shared brand frame)
       i18n: locale.<lang>.yaml    (en + vi)
       ↓
    actual email
       contains: https://auxi.app/auth/{verify|reset}?token=<jwt>
       ↓
    user taps in mail app
       ↓
    iOS resolves apple-app-site-association
       ├─ App installed → opens Auxi → AppDelegate handles URL → RN Linking event
       └─ App not installed → opens App Store / web fallback
       ↓
    auxi/App.tsx Linking handler routes to right screen
```

Deep-link routing in mobile:
```
https://auxi.app/auth/verify?token=…   →  VerifiedSuccess (after token consume)
https://auxi.app/auth/reset?token=…    →  ResetNewPassword
https://auxi.app/*                     →  ignored (let normal Linking handle)
auxi://auth/{verify|reset}?token=…     →  fallback (still supported, esp. for dev/sim)
```

## 6. Related Code Files

### Modify
- `wardrobe-backend/services/email_service.py` — replace stub with provider-pluggable concrete impl
- `wardrobe-backend/settings.py` — add `EMAIL_PROVIDER`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`, provider-specific creds, `EMAIL_DRY_RUN`
- `wardrobe-backend/.env.example` — document new env vars
- `wardrobe-backend/main.py` (or `app.py`) — register email-service singleton on startup
- `auxi/ios/Auxi/Info.plist` — add Associated Domains (`applinks:auxi.app`)
- `auxi/ios/Auxi.xcodeproj/project.pbxproj` — Associated Domains capability
- `auxi/App.tsx` — `Linking` listener handles both `https://auxi.app/auth/…` and `auxi://auth/…`
- `auxi/src/utils/deep-link-handler.ts` (created in phase 04) — extend to handle Universal Link domain

### Create
- `wardrobe-backend/services/email_providers/ses-email-provider.py`
- `wardrobe-backend/services/email_providers/resend-email-provider.py`
- `wardrobe-backend/services/email_providers/smtp-email-provider.py`
- `wardrobe-backend/services/email_providers/__init__.py` — provider factory based on env
- `wardrobe-backend/templates/emails/verify-email.html`
- `wardrobe-backend/templates/emails/verify-email.txt`
- `wardrobe-backend/templates/emails/reset-password.html`
- `wardrobe-backend/templates/emails/reset-password.txt`
- `wardrobe-backend/templates/emails/_layout.html` — shared header/footer
- `wardrobe-backend/templates/emails/i18n/en.yaml`, `vi.yaml`
- `wardrobe-backend/tests/test_email_service.py` — provider stub + template rendering tests
- **Hosted file**: `https://auxi.app/.well-known/apple-app-site-association` (Cloudflare Pages or Netlify or Vercel — devops decision, may piggyback wardrobe-admin's existing Cloudflare deploy per umbrella CLAUDE.md mention)
- **Hosted file** (Android, later): `https://auxi.app/.well-known/assetlinks.json`

### Delete
None this phase.

## 7. Implementation Steps

### Pre-flight (OQ#22 — gating decision)
1. tech-lead + PM select provider. **Recommendation**: Resend ($20/mo, modern API, simple) for prod; SMTP for dev. SES is cheaper at scale but requires SPF/DKIM setup + warm-up. Pick before phase starts.
2. Verify a hosting target exists for `apple-app-site-association`. Options: Cloudflare Pages (consistent with wardrobe-admin deployment per umbrella CLAUDE.md), or a small static-page workflow under the main domain. Confirm domain.

### Backend — email service
3. Define `EmailServiceProtocol` (Protocol) in `services/email_service.py`:
   ```python
   class EmailServiceProtocol(Protocol):
       async def send(self, *, to: str, subject: str, html: str, text: str) -> None: ...
   ```
4. Build provider classes:
   - `SESEmailProvider` — uses `aioboto3` (already in deps?), sends via SES.
   - `ResendEmailProvider` — uses `httpx` to POST `https://api.resend.com/emails`.
   - `SMTPEmailProvider` — `aiosmtplib`, Gmail App Password (dev only).
5. Provider factory in `__init__.py`: returns instance based on `settings.EMAIL_PROVIDER`. DRY_RUN mode returns a log-only stub for CI.
6. Build `_layout.html` with Auxi header/footer (brand name placeholder pending OQ#1) + responsive table layout (email-client-safe HTML).
7. Build `verify-email.html` + `.txt`: greeting, "Verify your email" CTA, Universal Link URL, expiry note, support line.
8. Build `reset-password.html` + `.txt`: greeting, "Reset password" CTA, Universal Link URL, "ignore if you didn't request", expiry note.
9. i18n: render templates with Jinja2 `{{ t('subject') }}` calls — translation strings loaded from `en.yaml` / `vi.yaml` based on `user.locale` (fall back to en).
10. `email_service.send_verify_email(user, token)` — pick locale, render html+text, call provider `send()`.
11. Wire retry: on first send failure, sleep 1s, retry once. On second failure, log structured error with user_id + email + template_name. Use FastAPI BackgroundTasks or a real queue (Celery deferred — KISS for v1).
12. Test: `pytest tests/test_email_service.py` — template rendering snapshot + provider stub.

### iOS Universal Links
13. Configure Apple Developer: app's Associated Domains entitlement → `applinks:auxi.app`.
14. Add Associated Domains capability in Xcode for Auxi target.
15. Author `apple-app-site-association`:
    ```json
    {
      "applinks": {
        "details": [{
          "appIDs": ["TEAMID.com.auxi.app"],
          "components": [
            { "/": "/auth/verify*" },
            { "/": "/auth/reset*" }
          ]
        }]
      }
    }
    ```
16. Host at `https://auxi.app/.well-known/apple-app-site-association` (no extension, `Content-Type: application/json`). Validate with `https://branch.io/resources/aasa-validator/`.
17. `Info.plist`: ensure URL scheme `auxi` is still registered (fallback for dev).

### Mobile deep-link handler
18. In `App.tsx`, add `Linking.getInitialURL()` + `Linking.addEventListener('url', handler)`.
19. `deep-link-handler.ts` — parse URL: if host `auxi.app` AND path matches `/auth/verify` or `/auth/reset` → extract token query param → dispatch in-app navigation.
20. Race-condition guard: hold deep-link intent until `AuthContext.bootstrap()` resolves (added in phase 04), then dispatch.
21. Sim verify: paste `auxi://auth/verify?token=…` into Safari on sim → app opens; paste `https://auxi.app/auth/verify?token=…` (after AASA hosted) → app opens via Universal Link.

### Validation
22. End-to-end: register on iOS sim → check inbox → click verify link in Gmail → app opens to Verified! screen.
23. Forgot password flow: trigger reset → email arrives → click reset link → app opens to ResetNewPassword → set new password → all sessions invalidated (verified by hitting /me on second device, expect 401).
24. Failure path: trigger 2x send failure (block provider in test) → assert error logged + user-facing error (verify-email screen displays "Couldn't send email — try Resend").

## 8. Todo List

- [ ] Resolve OQ#22 email provider (block phase start)
- [ ] Resolve OQ#23 deep-link domain hosting target
- [ ] `EmailServiceProtocol` + 3 provider impls + factory
- [ ] Verify-email template (HTML + text + en/vi)
- [ ] Reset-password template (HTML + text + en/vi)
- [ ] `_layout.html` shared brand frame (brand pending OQ#1)
- [ ] Retry + structured error logging
- [ ] pytest coverage for template rendering + provider stub
- [ ] Apple Associated Domains capability + entitlement
- [ ] Host `apple-app-site-association` at `https://auxi.app/.well-known/...`
- [ ] AASA validated via Apple validator
- [ ] Mobile deep-link handler covers Universal Link + custom scheme
- [ ] Race-condition guard for cold-start auth bootstrap
- [ ] iOS sim: real email round-trip (verify + reset)

## 9. Success Criteria

- Verify email arrives in test inbox within 30s of register call.
- Reset email arrives within 30s of forgot-password call.
- Tapping verify Universal Link in iOS Mail app opens Auxi → VerifiedSuccess (NOT Safari).
- Tapping reset Universal Link → opens Auxi → ResetNewPassword with token in route params.
- Resetting password invalidates all sessions for the user (verified on second device).
- `pytest tests/test_email_service.py` green.
- AASA validator returns no errors.
- Email provider can be swapped via env var without code change.

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Provider unselected → phase cannot ship | High | High | **Blocker** — escalate before phase starts. Fall back to Resend (lowest setup friction). |
| Universal Link AASA misconfigured → mail client opens Safari instead of app | High | High | Use Apple's AASA validator early; test on real iOS device (sim AASA support is flaky). Keep `auxi://` scheme as fallback in email link as second URL ("Tap this if the button doesn't work"). |
| Email goes to spam (cold sending domain) | High | Medium | SPF + DKIM + DMARC for `auxi.app` domain. Warm-up window for SES. Use Resend's shared IP pool for v1 to skip warm-up. |
| Send failure swallowed silently → user stuck on Verify screen | Medium | High | Structured logging + ops alert on second consecutive failure. UI shows clear "Couldn't send" + Resend button. |
| Token expires in user's mailbox before they click | Medium | Low | Verify TTL 24h; resend cooldown 60s with regen on cooldown timeout. |
| AASA hosting domain (`auxi.app`) does not exist or is broken | Medium | High | Verify domain status with devops before phase. If not available, defer Universal Links to a follow-up ticket and ship with `auxi://` scheme only (acceptable for TestFlight builds). |
| HTML email rendering broken in Outlook | Medium | Low | Stick to table-based layout + inline styles. Use a litmus test in `_layout.html` (one row, plain text fallback). |
| vi diacritics rendered wrong in plaintext email | Low | Low | Specify `charset=utf-8` in MIME headers. |

## 11. Security Considerations

- Reset token replay: enforced server-side via `used_reset_tokens` (phase 02) — phase 06 verifies single-use behavior in E2E test.
- Verify token in URL is JWT (signed, expires); even if intercepted, expires in 24h.
- Universal Link domain must be HTTPS — Apple rejects HTTP AASA.
- AASA file must NOT be cached publicly with long TTL (use short Cache-Control); changes to allowed paths should propagate quickly.
- Reset link arriving in app while user is already authenticated — phase 04 added a confirm dialog; this phase ensures the deep-link handler triggers that confirmation, not direct password reset.
- Email body should not include the user's password or any sensitive data — only a link.
- `From` address should be a real reply-to monitored mailbox to comply with anti-spam laws (or use no-reply with clear support contact in body).

## 12. Next Steps

- Phase 07 QA validates email flows in Maestro using a test inbox (mailosaur or mailcatcher in dev — TBD with qa-ui).
- Follow-up ticket: Android App Links (assetlinks.json) when Android becomes priority.
- Follow-up ticket: welcome email for OAuth users (PM decision).

**Status**: pending
**Summary**: Provider integration + 2 templates + Universal Links. ~3 dev-days. Two blockers: provider choice + domain hosting.
**Concerns/Blockers**: OQ#22 email provider, OQ#23 deep-link strategy, `auxi.app` domain availability/control.
