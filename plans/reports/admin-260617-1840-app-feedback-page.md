# App Feedback Review Page — Admin SPA

**Date:** 2026-06-17
**Scope:** `wardrobe-backend/wardrobe-admin` (React 19 + Vite + TS + Tailwind + TanStack Query 5)
**Package manager:** npm (per `package.json` scripts + CLAUDE.md; `package-lock.json` present)

## What was built

An internal admin page to read and triage in-app user feedback, backed by the existing
`/admin/feedback` endpoints. Mirrors the `RecommendationFeedback` page idioms exactly
(native HTML table + Tailwind, TanStack `useQuery` keyed by filters, `useMutation` for writes,
expandable rows, Prev/Next pagination). KISS — no bulk actions, export, or soft-delete.

### Files created
- `src/services/appFeedbackService.ts` — `listAppFeedback(filters)` → `GET /admin/feedback`;
  `updateAppFeedbackStatus(id, status)` → `PATCH /admin/feedback/{id}/status`. Strips empty
  filter keys so they don't serialize as `"undefined"`. Exports `CATEGORY_OPTIONS`,
  `STATUS_OPTIONS`, `PLATFORM_OPTIONS` label maps.
- `src/pages/AppFeedback.tsx` — full page: filters bar (category / status / platform dropdowns +
  user_id text), native table, expandable detail row, per-row status triage `<select>`, pagination.

### Files edited
- `src/types/index.ts` — added `AppFeedbackItem`, `AppFeedbackListResponse`, `AppFeedbackFilters`,
  and the `AppFeedbackCategory` / `AppFeedbackStatus` / `AppFeedbackPlatform` / `AppFeedbackUser` unions.
- `src/App.tsx` — imported `AppFeedback`, registered `<Route path="app-feedback">` under the
  protected `<Layout>`.
- `src/components/layout/Layout.tsx` — added nav entry `App Feedback → /app-feedback` using the
  `ChatText` Phosphor icon (distinct from `ChatCenteredDots` used by Recommendation Feedback).

## Page behavior

- **Reach it at:** sidebar "App Feedback" → route `/app-feedback` (e.g.
  `https://wardrobe-admin.duc2820.workers.dev/app-feedback` in prod, `/app-feedback` locally).
- **Filters:** category, status, platform `<select>` + optional user_id text input. Filter state
  in `useState`; offset resets to 0 on any filter change. Reset button restores defaults.
- **Table columns:** user email (or italic "anonymous" when `user` is null) · category (icon badge) ·
  message (truncated to 80 chars, full text on hover title) · rating (star + number, or "—") ·
  platform · app_version · status (colored badge) · created_at (locale-formatted).
- **Expand:** click any row → inline detail with the FULL message, triage `<select>`, user ID, feedback ID.
- **Triage:** changing the per-row status `<select>` fires `useMutation` → `PATCH …/status`; on
  success invalidates the `['app-feedback']` query so the list refetches. A `Spinner` shows on the
  pending row; a dedicated amber banner surfaces mutation errors.
- **No stats endpoint** is called (none exists). Total count is shown from the list response
  `total` (in the header subtitle and the pagination range).
- **States:** loading spinner, empty state, list-error banner (rose), triage-error banner (amber) —
  all matching the RecommendationFeedback styling.

## Verification

- `npx tsc --noEmit` — clean (no errors).
- `npm run build` (`tsc -b && vite build`) — **exit 0**, 8632 modules transformed, built in ~8s.
  Pre-existing/unrelated warnings only (Space Grotesk `.woff` runtime-resolution notices + the
  global >500 kB chunk-size advisory — both present before this change, not from new files).
- `npx eslint` on all 5 changed files — clean (exit 0).
- Existing pages untouched beyond the two additive lines in `App.tsx` / `Layout.tsx`.

## Notes / conventions

- Service file is camelCase (`appFeedbackService.ts`) per the admin CLAUDE.md service convention
  (`v05RecommendationService.ts`, `commonItemsService.ts`) and the task spec — overrides the generic
  kebab-case hook suggestion. Page is PascalCase per the `src/pages/` convention.
- Analytics/Mixpanel tracking rule does NOT apply here: it is mobile-app (`auxi/`) only; the admin
  SPA is explicitly out of scope per `.claude/rules/analytics-tracking-required.md`.
- Backend `API_DOCUMENTATION.md` was not touched — no backend routes were changed (endpoints already exist).

## Unresolved questions
- None. Endpoints were treated as authoritative per the task brief; no live backend call was made
  to smoke-test the actual response shape (build/typecheck only). A manual smoke against a real
  backend with admin auth is the recommended next step.
