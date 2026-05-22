---
title: "AU-242 — UAC Authentication & Account Access Flow"
description: "Email + Google + Apple sign-in/up with verification, password reset, i18n (en/vi), and 11 net-new RN screens."
status: pending
priority: P1
effort: 22d
branch: main
tags: [auth, oauth, email-verification, mobile, backend, i18n, au-242]
created: 2026-05-22
---

# AU-242 — UAC Authentication & Account Access Flow

- **Linear**: https://linear.app/duncan-1/issue/AU-242 (Priority High · Assignee duc2820)
- **Figma**: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-8205&m=dev
- **Spec**: `plans/260521-2335-au-242-figma-spec/` (13 screens + index)
- **Gap analysis**: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md`
- **Status**: Phase plans drafted — awaiting blocker resolution before kick-off

## Goal

Ship the full account-access flow per Figma spec (13 screens, 28 AC scenarios): Welcome → Email/Google/Apple → verify-email → Home, with sign-in, forgot/reset, and language switching on the mobile side; backend gets 9 new endpoints, email service, OAuth verification, and User model migration.

## Phases

| # | Name | Owner | Effort | Depends on | Key deliverable |
|---|---|---|---|---|---|
| 01 | Foundation (theme, i18n, secure storage) | mobile-dev | 2d | — | UAC tokens in `theme.ts`, `vi-VN.json`, multi-key Keychain |
| 02 | Backend endpoints + User migration + `NoOpEmailService` stub | backend-dev | 5d | — | 9 new routes, Alembic migration, pytest green, log-only email stub |
| 03 | Service layer + API doc contract | backend-dev + mobile-dev | 1d | 01, 02 | `API_DOCUMENTATION.md` updated + tech-lead sign-off; typed client + mutations in auxi |
| 04 | Screens (11 new + 2 modified) | mobile-dev | 7d | 01, 03 | Welcome, Lang, Email, PassCreate, Verify, GoogleNotice, SignIn, Forgot×2, Reset, Verified! |
| 05 | OAuth Google + Apple | mobile-dev + backend-dev | 4d | 02 | Both flows round-trip on iOS sim |
| 06 | ~~Email service + deep-links~~ **DEFERRED** | backend-dev | 3d | post-MVP | Verify + reset templates real send; Universal Links open app. Skipped this milestone — dev uses console log. |
| 07 | QA (Maestro flows + heuristic) | qa-ui + qa-mobile + qa-ux | 3d | 04, 05 | 7 Maestro flows green, UX review filed |

**Total active**: ~19 dev-days (22 − 3 phase 06 deferred). Parallelizable: 05 runs alongside 04 once 03 ships.

## Blocker resolutions (2026-05-22)

| # | Blocker | Resolution | Impact |
|---|---|---|---|
| 1 | **Email service provider** | **DEFER** — anh duc2820 quyết bỏ qua tạm thời. Phase 02 + 06 dùng log-only `NoOpEmailService` stub trong dev/staging; token tạo + lưu DB như thường, link verify/reset đọc qua test endpoint hoặc console log. Phase 06 deferred sau MVP. | Phase 02 ship được; Phase 06 → pause; dev tester dùng admin route hoặc console log để lấy token |
| 2 | **Brand name** | **RESOLVED** — ship name "**Macgie**" (keep Figma copy). Project/repo/Linear team vẫn là "Auxi" (codebase identifier). User-visible strings dùng Macgie. | Update toàn bộ user-facing copy across phases 04, 06 |
| 3 | **OAuth credentials provisioned** | **OK** — anh confirm proceed; provisioning handle khi vào phase 05 (mobile-dev tự chuẩn bị plist/json + entitlements khi kick off). | Phase 05 unblocked |
| 4 | **Password min-length** | **RESOLVED** — adopt spec: **8 chars + lowercase + digit** (Figma criteria). Backend `register` validator nâng từ 6 → 8. | Phase 02 register route + Phase 04 password screens dùng cùng 1 rule |
| 5 | **Broken import `auxi/src/hooks/language/schema.ts`** | **ASSUMPTION (em tự xử)** — fix trong phase 01: tạo `auxi/src/hooks/language/schema.ts` với Zod schema cho language codes, hoặc redirect import về `auxi/src/translations/schema.ts` nếu schema sống ở đó. Bug tồn tại từ trước AU-242, không cần product input. | Phase 01 unblocked |
| 6 | **Verified! routing target** | **ASSUMPTION pending PM confirm** — propose:<br>• Sign-up flow: Verified! → tap "Continue" → AU-243 onboarding (nếu ready) hoặc Home (fallback)<br>• Password reset flow: Verified! → tap "Continue" → Sign in screen với email pre-filled, user nhập password mới. | Phase 04 screen 13 implement với feature flag `UAC_POST_VERIFY_DEST` (`onboarding` \| `home` \| `signin`) |
| 7 | **Email-precheck enumeration risk** | **ASSUMPTION pending tech-lead** — implement screen 7 (Google-linked notice) qua endpoint `POST /api/auth/email-precheck` thay vì GET, **rate-limit 5 req/min/IP + 3 req/min/email**, response always 200 với enum `{none, password, google, apple}` cho authenticated client; unauthenticated client luôn nhận `password` (default) để tránh enumeration. | Phase 02 endpoint tweak + Phase 04 screen 07 |

## Open questions

**30 total** tracked in gap analysis sections "Carried over from 00-index.md" + "New questions surfaced during this scan". Park-and-proceed list at end of that report. Per-phase blockers re-listed inline in each phase file.

## Rollback strategy

- **Phase 01**: theme tokens are additive (no rename). vi-locale fallback is en. Multi-key Keychain ships with one-time migration from single-entry; on rollback, write-through to old key. Low risk.
- **Phase 02**: User-model migration adds nullable columns + backfills `email_verified_at = created_at` for existing users (no forced re-verification). Rollback = Alembic downgrade, drop new columns. New routes are pure additions — no existing route signature change except `register` (which gains a flag — old clients ignore it) and `login` (new 403 variant — old clients show generic error, no crash).
- **Phase 03**: API doc change is documentation only; rollback = revert markdown. Mobile client functions are new — flip a feature flag to disable.
- **Phase 04**: Each screen behind a navigator route. Rollback = revert AuthNavigator to Login+Register-only. Welcome refactor is gated behind a feature flag (`UAC_V2_ENABLED`) so we can fall back to legacy WelcomeScreen.
- **Phase 05**: OAuth buttons are conditionally rendered. Disable via flag if SDK or provisioning breaks.
- **Phase 06**: Email provider abstracted behind `EmailService` port — swap provider without code change. Universal Links degrade gracefully to custom scheme.
- **Phase 07**: Maestro flows are CI-only; rollback irrelevant.

**Global feature flag**: `UAC_V2_ENABLED` (env var + remote config). When off, app uses existing LoginScreen + RegisterScreen and Welcome→LocationPermission flow. Allows progressive rollout per platform.

## File ownership map (no overlap)

- `auxi/src/theme/*`, `auxi/src/translations/*`, `auxi/src/services/auth.ts`, `auxi/src/services/authService.ts` — phase 01 + 03 (mobile-dev)
- `auxi/src/screens/auth/*`, `auxi/src/screens/WelcomeScreen.tsx`, `auxi/src/navigation/AuthNavigator.tsx`, `auxi/src/types/navigation.ts` — phase 04 (mobile-dev)
- `auxi/src/services/oauth/*` (new) — phase 05 (mobile-dev)
- `wardrobe-backend/routers/auth.py`, `wardrobe-backend/schemas/auth.py`, `wardrobe-backend/models/user.py`, `wardrobe-backend/services/email_service.py` (new), Alembic migrations — phases 02, 05, 06 (backend-dev)
- `wardrobe-backend/API_DOCUMENTATION.md` — phase 03 (backend-dev writes, tech-lead reviews)
- `auxi/maestro/flows/auth/*` (new) — phase 07 (qa-ui)

No two phases edit the same file concurrently. Phases 04 and 05 both touch `AuthContext.tsx` — sequencing: 04 lands first, 05 layers OAuth methods on top.

## Success criteria (umbrella)

- All 28 AC scenarios from AU-242 ticket pass on iOS sim (qa-mobile sign-off via Maestro)
- `cd wardrobe-backend && python test_server.py` green
- `cd auxi && npx tsc --noEmit && yarn lint` green
- API_DOCUMENTATION.md diff approved by tech-lead
- en + vi locales render all UAC copy without hard-coded strings
- Token roundtrip works on app restart (refresh interceptor exercised)

**Status**: ready (pending 2 assumption confirmations)
**Summary**: Sau resolution 2026-05-22 (email defer, brand=Macgie, OAuth ok, pwd 8 chars), 5/7 blockers cleared. Active scope = 6 phases / ~19 dev-days. Phase 06 deferred sau MVP.
**Open assumptions** (em proceed mặc định, anh có thể veto sau):
- #5 Broken import — em tự fix trong phase 01
- #6 Verified! routing — feature flag `UAC_POST_VERIFY_DEST`, default `signin` (reset) / `home` (signup)
- #7 Email-precheck — POST endpoint + rate-limit + enumeration-safe default
