# Comprehensive Mixpanel Instrumentation — Auxi Mobile

**Date:** 2026-06-16
**Owner:** mobile-dev (this session)
**Authoritative doc:** `auxi/docs/analytics/mixpanel-tracking-plan.md` (will be updated as part of this work)
**Existing setup:** `mixpanel-react-native@3.3.0`, EU endpoint, consent-gated, identify wired in `AuthContext`, ~40 events already shipping.

## 1. Scope

Add **~55 new events** spanning every screen and major user interaction in the auxi mobile app. Coverage tier: **funnel-grade comprehensive** (every screen view, every funnel step, every key action, every error/failure surface).

Out of scope: backend / `wardrobe-admin` SPA / Mixpanel dashboard work / consent UI (the gating mechanism exists; the prompt is a separate ticket).

## 2. Conventions (unchanged from existing plan §2)

- Events: `object_verb`, `snake_case`, **past tense** (`outfit_favorited`).
- Properties: `snake_case`, descriptive.
- Property values: lowercase strings; numbers unquoted; **omit a property when there's no value** (never send `null`/`""`).
- No `$` / `mp_` prefixes on custom props.
- **Never build event names dynamically** — every event name is a literal string constant.
- Every new `track()` call goes through `src/services/analytics.ts` (single integration seam — unchanged).

## 3. Event taxonomy (new events)

### 3.1 Auth flow (~12 events)

Files: `src/screens/auth/*`, `src/context/AuthContext.tsx`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 1 | `sign_up_started` | EmailInputScreen "Continue" tap for new-user path | `method: email` |
| 2 | `sign_up_submitted` | PasswordCreationScreen submit → `register()` call | `method: email` |
| 3 | `sign_up_failed` | `register()` rejects | `method`, `error_reason` |
| 4 | `sign_up_completed` | VerifyEmailScreen confirms code → first authenticated session | `method` |
| 5 | `email_verification_resent` | "Resend code" tap | — |
| 6 | `sign_in_started` | SignInScreen submit button tap | `method: email` |
| 7 | `sign_in_failed` | `login()` rejects | `method`, `error_reason` |
| 8 | `oauth_sign_in_started` | Google / Apple button tap | `provider` (`google` / `apple`) |
| 9 | `oauth_sign_in_completed` | OAuth resolves → AuthContext identifies | `provider` |
| 10 | `forgot_password_requested` | ForgotPasswordRequest submit | — |
| 11 | `password_reset_completed` | ResetNewPassword success | — |
| 12 | `auth_language_changed` | LanguageSettingsScreen pick (auth tier) | `locale` (e.g. `en-US`) |

Updates to existing `sign_in_completed`: extend with `method` property covering `email` / `google` / `apple` (currently hard-coded to `email`).

### 3.2 Onboarding (~9 events)

Files: `src/onboarding/v2/*`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 13 | `onboarding_step_viewed` | useFocusEffect on each step | `step_name`, `step_index` |
| 14 | `welcome_continued` | WelcomeScreen primary tap | — |
| 15 | `location_permission_requested` | system prompt about to fire | — |
| 16 | `location_permission_granted` | result granted | — |
| 17 | `location_permission_denied` | result denied / blocked | `permission_status` |
| 18 | `wardrobe_direction_selected` | OnboardingWardrobeScreen pick | `direction` |
| 19 | `fit_preference_selected` | OnboardingFitScreen pick | `fit` |
| 20 | `style_selected` | OnboardingStylesScreen chip add | `style_name` |
| 21 | `style_deselected` | OnboardingStylesScreen chip remove | `style_name` |

### 3.3 Home + recommendation viewing (~7 events)

Files: `src/screens/HomeScreen.tsx`, `src/components/features/OutfitSwipeDeck.tsx`, `src/components/features/ContextChipsModal.tsx`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 22 | `outfit_recommendation_viewed` ★ | Active sheet settles on a **new** outfit_hash. Dedup'd via in-memory `Set<outfit_hash>` per session. Fires only AFTER the deck has visually settled (onSnap / scroll end). | `outfit_hash`, `position`, `source` (`feed` / `refine`) |
| 23 | `outfit_swiped` | Swipe gesture or arrow tap moves to next/previous outfit | `outfit_hash`, `direction` (`next` / `previous`), `method` (`gesture` / `button`) |
| 24 | `outfit_card_tapped` | Tap on outfit card opens detail / try-on entry | `outfit_hash`, `position` |
| 25 | `outfit_try_on_tapped` | "See on me" action from home | `outfit_hash`, `source: home` |
| 26 | `context_chip_changed` | Occasion / weather / time chip change on home (outside refine modal) | `chip_type`, `value` |
| 27 | `refine_chip_selected` | Chip add inside ContextChipsModal | `chip_type`, `value` |
| 28 | `refine_chip_deselected` | Chip remove inside ContextChipsModal | `chip_type`, `value` |

★ = key engagement signal. Carefully wire to avoid prefetch over-count (see plan §6).

### 3.4 Wardrobe (~8 events)

Files: `src/screens/WardrobeScreen.tsx`, `src/screens/ItemDetailScreen.tsx`, related add-item flow.

Existing events kept: `wardrobe_viewed`, `wardrobe_filter_changed`, `wardrobe_item_opened`, `add_item_opened`, `add_item_method_selected`, `add_item_upload_*`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 29 | `wardrobe_item_added` | Item create-and-upload success → item present in user's wardrobe | `item_id`, `source`, `method` (`search_database` / `import_web` / `take_photo`), `category` |
| 30 | `wardrobe_item_edited` | ItemDetail save with diff | `item_id`, `fields_changed` (array of field names) |
| 31 | `wardrobe_item_deleted` | ItemDetail delete confirm | `item_id`, `category` |
| 32 | `wardrobe_search_initiated` | Database search submit | `source` |
| 33 | `wardrobe_search_result_selected` | Database result tap → adds to wardrobe | `item_id`, `source` |
| 34 | `wardrobe_url_import_submitted` | "Import from URL" submit | `url_domain` (hostname only, never full URL) |
| 35 | `wardrobe_url_import_completed` | URL import API success | `url_domain` |
| 36 | `wardrobe_url_import_failed` | URL import API error | `url_domain`, `error_reason` |
| 37 | `wardrobe_photo_captured` | Camera capture for take-photo flow | `source` |

### 3.5 Favourite + try-on outcomes (~5 events)

Files: `src/screens/FavouriteScreen.tsx`, `src/screens/see-this-on-me/SeeThisOnMeScreen.tsx`.

Existing events kept: `outfit_favorited`, `outfit_unfavorited`, `try_on_started`, `try_on_completed`, `try_on_failed`, `try_on_step_completed`, `try_on_profile_retake`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 38 | `favourite_outfit_opened` | Tap a saved outfit card | `favorite_id` |
| 39 | `favourite_try_on_tapped` | "See on me" from a favourite | `favorite_id` |
| 40 | `try_on_outcome_saved` | User saves the generated try-on image | `outfit_hash` |
| 41 | `try_on_outcome_shared` | Share-sheet open from outcome | `outfit_hash` |
| 42 | `try_on_outcome_retaken` | Retake from outcome screen | `outfit_hash` |

If the share button doesn't exist yet, the event ships as wired but silent — log it in the gap list, not in code as a TODO.

### 3.6 Settings (~9 events)

Files: `src/screens/SettingsScreen.tsx`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 43 | `notifications_toggle_changed` | Daily reminder switch flips | `enabled` (bool) |
| 44 | `daily_reminder_time_changed` | Time picker confirms | `hour` (0-23) |
| 45 | `settings_language_changed` | Locale switch confirms | `locale` |
| 46 | `style_direction_changed` | Style direction edit saves | `direction` |
| 47 | `confidence_level_changed` | Confidence level edit saves | `level` |
| 48 | `analytics_consent_changed` | Consent toggle | `granted` (bool) |
| 49 | `account_logged_out` | Logout confirm | — |
| 50 | `account_deleted` | Delete-account confirm | — |
| 51 | `support_link_tapped` | Support / help link tap | `link_type` (`email` / `web` / `tos` / `privacy`) |

Skip a generic `settings_opened` — `screen_viewed` (§3.8) covers it.

### 3.7 ItemDetail + Body (~4 events)

Files: `src/screens/ItemDetailScreen.tsx`, `src/screens/BodyScreen.tsx`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 52 | `item_detail_opened` | ItemDetailScreen mount | `item_id`, `source` |
| 53 | `body_photo_added` | First photo set in slot | `slot` (`selfie` / `full_body` / `body_shape`) |
| 54 | `body_photo_replaced` | Existing photo replaced | `slot` |
| 55 | `body_photo_deleted` | Photo cleared | `slot` |

`item_detail_edited` / `item_detail_deleted` already covered by `wardrobe_item_edited` / `wardrobe_item_deleted` (§3.4) — single event each, fired from whichever screen.

### 3.8 Global navigation (~1 event)

File: `src/navigation/AppNavigator.tsx`, helper added to `src/services/analytics.ts`.

| # | Event | Trigger | Properties |
|---|---|---|---|
| 56 | `screen_viewed` | React Navigation `onStateChange` → currentRoute change | `screen_name`, optional `previous_screen_name` |

Rules:
- Fire on **route name change only** (not param-only re-renders).
- Skip `OnboardingLoading` (transient, ~2s) — would noise up the funnel.
- Debounce repeated identical screen_name within 500ms (defensive).
- Use the route name straight from React Navigation as `screen_name` (matches the canonical labels in `src/types/navigation.ts`).

## 4. Total event budget

| Bucket | Count |
|---|---|
| Currently shipping (pre-existing) | 40 |
| Auth flow (§3.1) | 12 |
| Onboarding (§3.2) | 9 |
| Home + recommendation (§3.3) | 7 |
| Wardrobe (§3.4) | 8 |
| Favourite + try-on outcomes (§3.5) | 5 |
| Settings (§3.6) | 9 |
| ItemDetail + Body (§3.7) | 4 |
| Global navigation (§3.8) | 1 |
| **New total** | **55** |
| **Grand total after this PR** | **~95** |

## 5. Implementation phases (one per atomic commit)

1. **Phase 1 — Auth flow** (§3.1) → `src/screens/auth/*`, `AuthContext.tsx`
2. **Phase 2 — Onboarding** (§3.2) → `src/onboarding/v2/*`
3. **Phase 3 — Home + recommendation viewing** (§3.3) → `src/screens/HomeScreen.tsx`, `src/components/features/OutfitSwipeDeck.tsx`, `src/components/features/ContextChipsModal.tsx`
4. **Phase 4 — Wardrobe** (§3.4) → `src/screens/WardrobeScreen.tsx`, `src/screens/ItemDetailScreen.tsx`
5. **Phase 5 — Favourite + try-on outcomes** (§3.5) → `src/screens/FavouriteScreen.tsx`, `src/screens/see-this-on-me/SeeThisOnMeScreen.tsx`
6. **Phase 6 — Settings** (§3.6) → `src/screens/SettingsScreen.tsx`
7. **Phase 7 — ItemDetail + Body** (§3.7) → `src/screens/ItemDetailScreen.tsx`, `src/screens/BodyScreen.tsx`
8. **Phase 8 — Global `screen_viewed`** (§3.8) → `src/navigation/AppNavigator.tsx`, `src/services/analytics.ts`
9. **Phase 9 — Update tracking plan doc** → `auxi/docs/analytics/mixpanel-tracking-plan.md`

## 6. Acceptance criteria

- Every event in §3 is fired from the listed screen/file with the listed properties.
- All event names are literal string constants (no template literals / dynamic names).
- All new `track()` calls go through `src/services/analytics.ts` — no direct `mixpanel.track`.
- `npx tsc --noEmit` clean (baseline: legacy `_HomeScreen.tsx` errors expected, no NEW errors).
- `yarn lint` baseline: 4 errors / 3 warnings (all in `_HomeScreen.tsx`); zero new errors / warnings introduced.
- No duplicate events: searching for the same event-name literal anywhere else in src/ returns either the canonical site or none.
- Tracking plan doc updated; §5 (Implemented) reflects new reality; §6 (Designed-not-wired) only retains genuinely deferred items.
- Final report written to `plans/reports/mobile-dev-260616-0950-mixpanel-instrumentation.md`.

## 7. Suggested funnels (delivered in report, not in code)

- **Activation funnel:** `sign_up_started` → `sign_up_submitted` → `sign_up_completed` → `onboarding_step_viewed` (per step) → `onboarding_completed` → first `outfit_favorited`
- **Sign-in funnel:** `sign_in_started` → `sign_in_completed` (with `method` breakdown)
- **OAuth funnel:** `oauth_sign_in_started` → `oauth_sign_in_completed`
- **Onboarding step funnel:** `welcome_continued` → `location_permission_*` → `wardrobe_direction_selected` → `fit_preference_selected` → `style_selected` → `onboarding_generated` → `onboarding_completed`
- **Recommendation engagement funnel:** `outfit_recommendation_viewed` → `outfit_favorited` (the value-moment rate)
- **Try-on funnel:** `outfit_try_on_tapped` → `try_on_started` → `try_on_step_completed` ×N → `try_on_completed` → `try_on_outcome_saved`
- **Wardrobe-grow funnel:** `add_item_opened` → `add_item_method_selected` → `add_item_upload_started` → `wardrobe_item_added`
- **URL-import funnel:** `wardrobe_url_import_submitted` → `wardrobe_url_import_completed` (vs `..._failed`)
- **Refine-engagement funnel:** `refine_modal_opened` → `refine_chip_selected` ×N → `refine_submitted` (vs `refine_cancelled`)
- **Retention insight:** `screen_viewed` (per `screen_name`) over time — identifies dead screens.

## 8. Known remaining gaps (post-PR)

- **Consent UI** — mechanism exists, prompt not built. Until then events are no-ops in production until QA grants consent manually.
- **PROD Mixpanel token** — `PROD_TOKEN` empty in `src/config/analytics.ts` — release-blocker tracked in plan doc.
- **App version super-property** — needs `react-native-device-info` install.
- **Cold/warm app launch** — `app_launched` not in scope; would need AppState wiring.
- **Share / outcome-share availability** — `try_on_outcome_shared` will land in code; if no share button exists yet, event will never fire (waiting on product).
- **Background / foreground transitions** — out of scope; Mixpanel session timing handles engagement-time tracking.

## 9. Risk assessment

| Risk | Mitigation |
|---|---|
| `outfit_recommendation_viewed` over-counts due to prefetch | Wire to deck onSnap/settle + dedup with in-memory `Set<outfit_hash>` per session. Documented in code. |
| `screen_viewed` floods on stack push/pop | Debounce 500ms + filter on route name change only (not focus change). |
| Adding events breaks Maestro selectors | All event additions are inside existing handlers — no new UI / testID changes. Confirmed by sticking to `track()` call additions only. |
| Doc drift between plan.md and code | Phase 9 updates the doc as part of this PR. Single source of truth restored. |
| Property explosion in Mixpanel project | Each event has a fixed shallow set of properties (≤4). No dynamic prop names. |

## 10. Verification gates

- `cd auxi && npx tsc --noEmit` clean (baseline modulo `_HomeScreen.tsx`).
- `cd auxi && yarn lint` clean (baseline 4 / 3).
- Manual smoke (documented in report, not blocking): `yarn ios:sim` → grant consent in dev → run through one full funnel → confirm in Mixpanel EU Live View.
- Sanity grep: `grep -rEn "mixpanel\.track|analytics\.track|^[^/]*track\(" src/ | sort -u` shows only `track()` from `src/services/analytics.ts` callers.

## 11. Out of scope explicitly

- Backend (Valen) analytics — separate concern.
- `wardrobe-admin` SPA — separate Mixpanel project / setup.
- Mixpanel dashboard / Lexicon / Data Standards config — human-driven, tracked in tracking-plan.md §8.
- Refactoring the existing analytics wrapper.
- Adding new screens / features to track new events from.
