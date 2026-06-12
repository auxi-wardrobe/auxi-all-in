# V05 Tester Simple Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite admin `/v05-tester` so a fashion designer picks a user → profile auto-loads → weather + Safe/Power/Creative mode → 3 mobile-identical outfit cards with Try Another + 👍/👎. All engine/debug UI deleted.

**Architecture:** Frontend-only change in `wardrobe-backend/wardrobe-admin`. Page becomes a slim orchestrator; UI split into 5 small components under `components/v05-tester/`. Payload mirrors mobile `HomeScreen.tsx:608` exactly. Backend untouched (uses existing `build_as_user`, `try_another_as_user`, `GET /admin/users/{id}`, `GET /api/weather`).

**Tech Stack:** React 19, TS 5, TanStack Query 5, Tailwind, antd Select, phosphor icons.

**Spec:** `wardrobe-backend/docs/superpowers/specs/2026-06-11-v05-tester-simple-mode-design.md`

**Verification gates (no unit test runner in this repo):** `npx tsc --noEmit` + `npm run lint` clean, run from `wardrobe-backend/wardrobe-admin/`.

---

## Task 0: Branch + commit spec

- [ ] `cd wardrobe-backend && git checkout -b feature/v05-tester-simple-mode`
- [ ] `git add docs/superpowers/specs/2026-06-11-v05-tester-simple-mode-design.md && git commit -m "docs: spec for v05-tester simple mode redesign"`

## Task 1: Service layer — weather helper, profile type, error helpers

**Files:** Modify `wardrobe-backend/wardrobe-admin/src/services/v05RecommendationService.ts`

- [ ] **Step 1:** Add import at top: `import type { RecommendationProfile } from '../types';`
- [ ] **Step 2:** Extend `AdminUserDetail` with `recommendation_profile?: RecommendationProfile;`
- [ ] **Step 3:** Add weather fetch helper (`SAIGON_COORDS = {lat: 10.776, lon: 106.7}`, `AdminWeather {temp_c, condition, icon_code}`, `fetchAdminWeather()` → `GET /weather`)
- [ ] **Step 4:** Add shared error helpers `isV05SessionExpired(error)` (410 / detail.code === 'session_expired') and `getV05ErrorMessage(error)` (string detail incl. pool_insufficient → "Tủ đồ user này chưa đủ item cho thời tiết/mode này — thử đổi mode hoặc nhiệt độ."; object detail → .message; fallbacks message/error keys)
- [ ] **Step 5:** `npx tsc --noEmit` → clean

## Task 2: `V05ModePill.tsx`

**Files:** Create `wardrobe-backend/wardrobe-admin/src/components/v05-tester/V05ModePill.tsx`

- [ ] Export `V05TesterMode = 'safe' | 'power' | 'creative'` + `MODE_TO_MOOD: Record<V05TesterMode, V05Mood> = { safe: 'calm', power: 'confident', creative: 'playful' }` (same map as mobile HomeScreen moodMap)
- [ ] Segmented pill button group (Safe / Power / Creative), Tailwind style matching page, props `{value, onChange}`
- [ ] `npx tsc --noEmit` → clean

## Task 3: `V05WeatherCard.tsx`

**Files:** Create `wardrobe-backend/wardrobe-admin/src/components/v05-tester/V05WeatherCard.tsx`

- [ ] useQuery `['admin-weather-saigon']` → `fetchAdminWeather`, staleTime 10min, retry 1
- [ ] Seed parent form ONCE via ref guard: on data → `onTempChange(round(temp_c))` + `onRainyChange(condition ∈ {Rain, Drizzle, Thunderstorm})`; on error → seed 18°C (mobile NEUTRAL_WEATHER)
- [ ] Status line: "Sài Gòn now: X°C — Condition" / fetching / unavailable-fallback
- [ ] Editable temp number input + rainy toggle (controlled by parent via props `{tempC, isRainy, onTempChange, onRainyChange}`)
- [ ] `npx tsc --noEmit` → clean

## Task 4: `V05UserPicker.tsx`

**Files:** Create `wardrobe-backend/wardrobe-admin/src/components/v05-tester/V05UserPicker.tsx`

- [ ] Extract debounced (350ms) antd `Select showSearch` email search from old page lines 460-495 + 604-667; props `{targetUser, onSelect, onClear}`; label "View as user"; hint "Pick a user to load their wardrobe + onboarding profile" when none selected. No self-test copy.
- [ ] `npx tsc --noEmit` → clean

## Task 5: `V05UserProfileCard.tsx`

**Files:** Create `wardrobe-backend/wardrobe-admin/src/components/v05-tester/V05UserProfileCard.tsx`

- [ ] Props `{detail: AdminUserDetail | undefined, isLoading}`; render onboarding picks from `detail.recommendation_profile?.onboarding`: wardrobe_direction, fit_preference, ranked style_preferences chips; "User has not completed onboarding yet." when absent
- [ ] Wardrobe count badge (rose when 0 + warning "Tủ đồ trống — kết quả sẽ thưa hoặc không build được.")
- [ ] `npx tsc --noEmit` → clean

## Task 6: `V05SimpleOutfitCard.tsx`

**Files:** Create `wardrobe-backend/wardrobe-admin/src/components/v05-tester/V05SimpleOutfitCard.tsx`

- [ ] Simplified inline `ItemCard` (image, name, category_family only — no style tags/color code/HRID)
- [ ] Card = title "Outfit #N" + items grid + Styling Note (`reasoning_human`) — NO score/hash/star/vibe/debug
- [ ] `Try another` button → `tryAnotherV05AsUser(targetUserId, {session_id, current_outfit_hash, axis: null, style_feedback: null})`; success with outfit → `onReplaced(outfit)` (in-place swap); success with null outfit → amber notice from `res.message`; 410 session_expired → `onSessionExpired()`; other errors → `getV05ErrorMessage` notice. Button hidden when `sessionId` null.
- [ ] Keep `V05OutfitFeedback` with contextSnapshot `{source: 'admin_v05_tester', outfit_index, session_id?, target_user_id}`
- [ ] `npx tsc --noEmit` → clean

## Task 7: Rewrite page, delete debug panels, prune dead service code

**Files:**
- Rewrite: `src/pages/V05RecommendationTester.tsx` (full replace, ~210 lines)
- Delete: `src/components/v05-tester/V05DiagnosticsPanel.tsx`, `src/components/v05-tester/V05TryAnotherPanel.tsx`
- Modify: `src/services/v05RecommendationService.ts` (dead code prune)

- [ ] **Page state:** targetUser, tempC (default 30, seeded by WeatherCard), isRainy, mode ('safe'), outfits (V05Outfit[] | null), sessionId, sessionExpired, formError. Detail query `['admin-user-detail', id]` → `getAdminUserDetail`.
- [ ] **handleBuild payload (mobile mirror):** `{weather: {temp_c, is_rainy}, user: {gender: 'U', occasion: mode}, intent: {mood: MODE_TO_MOOD[mode]}, memory: {recent_signatures: [], recent_reasoning_used: []}, exclude_ids: [], count: 3, seed: null}` → `buildV05AsUser(targetUser.id, req)`; onSuccess store outfits + session_id; onError `getV05ErrorMessage` → formError.
- [ ] **Layout:** header (simplified copy "See exactly what a user sees on mobile…") → picker section → profile card → (only when user picked) two-column: left = WeatherCard + Mode + error + "Get Outfits" button; right = spinner / empty-state / sessionExpired amber notice ("Phiên hết hạn — bấm Get Outfits lại để tiếp tục Try another.") + outfit cards with `onReplaced` swapping index in outfits array, key `${idx}-${outfit_hash}`.
- [ ] `git rm` the two debug panel components
- [ ] Grep `buildV05Recommendation|tryAnotherV05Recommendation|V05_VARIATION_AXES` outside service → if no consumers, delete them from service (keep types: V05Trace, V05TryAnotherRequest/Response, V05VariationAxis still used by `tryAnotherV05AsUser`)
- [ ] `npx tsc --noEmit` → clean; `npm run lint` → clean
- [ ] Commit: `feat(admin): v05-tester simple mode — view-as-user page, strip engine debug UI`

## Task 8: Final verification

- [ ] `npx tsc --noEmit` clean, `npm run lint` clean, `npm run build` succeeds
- [ ] Manual smoke if local backend available: pick onboarded user → profile matches; Get Outfits → 3 cards; Try another swaps in place; 👍 recorded

## Task 9: Ship (gated — owner confirms)

- [ ] Push branch + `gh pr create` in wardrobe-backend
- [ ] **Deploy `npm run deploy:prod` only after owner confirms** (prod Cloudflare worker — outward-facing)

---

## Self-review notes

- Spec coverage: user-pick+auto-profile (T4/T5), weather auto-fetch+override (T3), mode pill (T2), mobile payload (T7), simple cards + in-place try-another + feedback (T6), deletions (T7), error handling (T1/T5/T6/T7), zero backend changes. ✔
- Type consistency: `V05TesterMode`/`MODE_TO_MOOD` (T2→T7); `AdminWeather`/`fetchAdminWeather` (T1→T3); `isV05SessionExpired`/`getV05ErrorMessage` (T1→T6/T7). ✔
- No TDD tasks: repo has no JS test runner; gates are tsc+lint+manual smoke per `wardrobe-admin/CLAUDE.md`. ✔
