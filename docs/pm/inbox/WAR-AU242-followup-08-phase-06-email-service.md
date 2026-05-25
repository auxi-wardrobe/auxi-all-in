---
id: WAR-AU242-FU-08
parent: AU-242
type: feature
title: "[A1] Phase 06: Email service provider selection + integration"
state: Backlog
priority: P1
labels: [type:feature, area:backend, role:backend-dev, role:tech-lead, blocks-launch, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: backend-dev + tech-lead (provider decision)
estimate: 3d
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

Phase 02 shipped `NoOpEmailService` (a stub that logs verify and
reset links to stdout). That's sufficient for local dev and the
Maestro test harness — it is NOT sufficient for production launch.

Real email delivery is required for:

- Email verification (signup confirms via link)
- Password reset (forgot-password flow needs a real link in real inbox)
- Apple private relay address handling (forward through provider)

Provider candidates (decision needed before implementation):

- **AWS SES** — cheap (~$0.10 per 1000), requires DKIM/SPF setup,
  daily quota ramp-up, IAM. Fits if we're already on AWS.
- **Resend** — modern, simple API, ~$20/mo for 50k/month, great DX,
  no infra. Fastest path to ship.
- **SMTP (Gmail App Password)** — dev / staging only, NOT for prod.

Plus deep-link config for verify/reset URLs is required: Universal
Links on iOS need an Apple App Site Association (AASA) file hosted
at `https://auxi.app/.well-known/apple-app-site-association`.

This ticket blocks production launch of AU-242. Phase 06 plan file
already exists.

## Acceptance criteria

- [ ] Tech-lead documents provider decision with rationale in plan
      file and `API_DOCUMENTATION.md` env section.
- [ ] Implement `wardrobe-backend/services/email_service.py` real adapter
      (replaces `NoOpEmailService`); abstract interface kept so tests
      can swap to a fake.
- [ ] Verify email + reset email templates (text + HTML) — copy by Viet.
- [ ] Staging end-to-end: signup on staging → real email lands in real
      inbox → tap link → backend marks `email_verified_at`.
- [ ] Universal Links work on iOS sim and a real device — tapping link
      opens app at VerifyEmail screen with token param.
- [ ] AASA file hosted on `auxi.app`, served as JSON with correct
      MIME type; `applinks` entry includes the production bundle ID.
- [ ] Android App Links assetlinks.json hosted equivalently if Android
      build in scope (else flag as follow-up).
- [ ] Quota / rate-limit monitoring wired (alarm on >10% failure rate).
- [ ] Bounces and complaints handled per provider (SES SNS topic or
      Resend webhook).
- [ ] Secrets stored via deploy secrets manager, NEVER committed.

## Out of scope

- Transactional emails beyond verify + reset (welcome blast, drip
  campaigns — separate tickets).
- Localized email templates beyond en-US + vi-VN (covered by M3).

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding A1
- Plan: `plans/260521-2335-au-242-uac-impl/phase-06-email-service.md`
- Stub: `wardrobe-backend/services/email_service.py` (NoOpEmailService)
- Parent: AU-242
