---
id: WAR-AU242-FU-02
parent: AU-242
type: feature
title: "[M1] VerifyEmail screen needs polling for deep-link verify status"
state: Backlog
priority: P2
labels: [type:feature, area:mobile, role:mobile-dev, source:au-242-followup]
team: Auxi
workspace: duncan-1
owner: mobile-dev
estimate: 0.5d
linear_parent_url: https://linear.app/duncan-1/issue/AU-242
created: 2026-05-22
linear_sync_status: pending
---

## Context

Phase 04 screen `auxi/src/screens/auth/VerifyEmailScreen.tsx` displays
a static "Waiting for email to be verified" spinner but never polls
the backend to detect when the user taps the verify link in their mail
app (often on another device). Result: user has to manually navigate
back, doesn't know the verification went through.

Per Figma spec 06: polling indicator implies live status detection.

## Acceptance criteria

- [ ] Poll `GET /api/me` (or `/api/auth/me`) every 5s while screen mounted.
- [ ] Cap polling at 5 minutes; on cap, show retry CTA + "Resend email".
- [ ] On response `email_verified_at != null`, navigate to Verified
      screen with route param `source: 'signup'`.
- [ ] Use `useFocusEffect` to gate polling to foreground (no background
      battery drain).
- [ ] Add `testID="verify-email-polling-active"` while polling, swap to
      `testID="verify-email-polling-done"` on success.
- [ ] Add `testID="verify-email-poll-timeout"` on the cap-reached state.
- [ ] Maestro flow covering signup → verify-email → simulated backend
      flip → auto-nav to Verified.

## Out of scope

- Push-notification-based verify (no APNs/FCM in MVP).
- Real-time WebSocket — polling is fine for MVP.

## Refs

- Source: `plans/reports/tech-lead-260522-1406-au-242-pr-review.md` finding M1
- Figma spec: `plans/260521-2335-au-242-figma-spec/06-verify-email-screen.md`
- File: `auxi/src/screens/auth/VerifyEmailScreen.tsx`
- Parent: AU-242
