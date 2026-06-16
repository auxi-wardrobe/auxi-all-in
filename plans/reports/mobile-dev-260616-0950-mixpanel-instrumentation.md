# Mobile-Dev — Comprehensive Mixpanel Instrumentation

**Date:** 2026-06-16
**Branch:** `main` (auxi submodule edits, no commits)
**Spec:** `plans/260616-0950-mixpanel-comprehensive-instrumentation/spec.md`
**Tracking plan (updated):** `auxi/docs/analytics/mixpanel-tracking-plan.md`

## Outcome

- **45 new events shipped** across 8 phases (auth, onboarding, home, wardrobe, item-detail, body, favourite + try-on outcomes, settings, global nav).
- **10 events designed but skipped** because UI/API doesn't exist — documented in §6 of the updated tracking plan as gaps (no fakery).
- **1 helper added**: `trackRecommendationViewedOnce` in `src/services/analytics.ts` (module-level `Set` per-session dedup for `outfit_recommendation_viewed`).
- **1 existing event extended**: `sign_in_completed` now carries the real `method` (`email`/`google`/`apple`) instead of hard-coded `email`. Side-bug fixed: SignInScreen was previously never firing this event (login routes through `useLoginMutation`, not `AuthContext.login`).
- **tsc clean**, **lint at baseline** (0 errors / 6 warnings, all pre-existing).
- **32 files modified** in `auxi/`. No UI/testID/behavior changes — only `track()` calls inside existing handlers.

Before: 40 events tracked. After: ~85 unique events (45 new + 40 pre-existing).

## 1. Newly added events

### 1.1 Auth flow (12)

| Event | File:Line |
|---|---|
| `sign_up_started` | `src/screens/auth/EmailInputScreen.tsx:171` |
| `sign_up_submitted` | `src/screens/auth/PasswordCreationScreen.tsx:147` |
| `sign_up_failed` | `src/screens/auth/PasswordCreationScreen.tsx:159` |
| `sign_up_completed` | `src/services/deepLinkHandler.ts:181` |
| `email_verification_resent` | `src/screens/auth/VerifyEmailScreen.tsx:128` |
| `sign_in_started` | `src/screens/auth/SignInScreen.tsx:128` |
| `sign_in_failed` | `src/screens/auth/SignInScreen.tsx:133` |
| `oauth_sign_in_started` | `src/screens/auth/WelcomeScreen.tsx:176` (google), `:214` (apple); `src/screens/auth/EmailGoogleNoticeScreen.tsx:116` (google) |
| `oauth_sign_in_completed` | `src/context/AuthContext.tsx:231` |
| `forgot_password_requested` | `src/screens/auth/ForgotPasswordRequestScreen.tsx:92` |
| `password_reset_completed` | `src/screens/auth/ResetNewPasswordScreen.tsx:97` |
| `auth_language_changed` | `src/screens/auth/LanguageSettingsScreen.tsx:83` |

Plus: `sign_in_completed` extended at `src/context/AuthContext.tsx:233` to carry real `method`.

### 1.2 Onboarding (9)

| Event | File:Line |
|---|---|
| `onboarding_step_viewed` × 8 | `src/screens/AppWelcomeScreen.tsx:21`, `src/screens/LocationPermissionScreen.tsx:38`, `src/onboarding/v2/OnboardingWardrobeScreen.tsx:46`, `OnboardingFitScreen.tsx:55`, `OnboardingStylesScreen.tsx:80`, `OnboardingLoadingScreen.tsx:153`, `OnboardingCompletedScreen.tsx:40`, `OnboardingOutroScreen.tsx:42` |
| `welcome_continued` | `src/screens/AppWelcomeScreen.tsx:30` |
| `location_permission_requested` | `src/screens/LocationPermissionScreen.tsx:48` |
| `location_permission_granted` | `src/screens/LocationPermissionScreen.tsx:52` |
| `location_permission_denied` | `src/screens/LocationPermissionScreen.tsx:55` |
| `wardrobe_direction_selected` | `src/onboarding/v2/OnboardingWardrobeScreen.tsx:57` |
| `fit_preference_selected` | `src/onboarding/v2/OnboardingFitScreen.tsx:66` |
| `style_selected` | `src/onboarding/v2/OnboardingStylesScreen.tsx:96` |
| `style_deselected` | `src/onboarding/v2/OnboardingStylesScreen.tsx:92` |

### 1.3 Home + recommendation engagement (6)

| Event | File:Line |
|---|---|
| `outfit_recommendation_viewed` ★ | `src/screens/HomeScreen.tsx:564` via `trackRecommendationViewedOnce()` (helper at `src/services/analytics.ts:173`) |
| `outfit_swiped` (right/like) | `src/screens/HomeScreen.tsx:1193` |
| `outfit_swiped` (left/skip) | `src/screens/HomeScreen.tsx:1222` |
| `outfit_card_tapped` | `src/screens/HomeScreen.tsx:1386` |
| `context_chip_changed` (defensive — mode-selector UI parked) | `src/screens/HomeScreen.tsx:1137` |
| `refine_chip_selected` / `refine_chip_deselected` | `src/components/features/ContextChipsModal.tsx:152` |

### 1.4 Wardrobe + ItemDetail (7)

| Event | File:Line |
|---|---|
| `item_detail_opened` | `src/screens/ItemDetailScreen.tsx:280` |
| `wardrobe_item_added` (take-photo) | `src/screens/WardrobeScreen.tsx:218` |
| `wardrobe_item_added` (database) | `src/screens/DatabaseScreen.tsx:138` |
| `wardrobe_item_edited` | `src/screens/ItemDetailScreen.tsx:678` |
| `wardrobe_item_deleted` | `src/screens/ItemDetailScreen.tsx:548` |
| `wardrobe_search_initiated` | `src/screens/DatabaseScreen.tsx:130` |
| `wardrobe_search_result_selected` | `src/screens/DatabaseScreen.tsx:118` |
| `wardrobe_photo_captured` | `src/screens/WardrobeScreen.tsx:204` |

### 1.5 Favourite + try-on outcomes (2)

| Event | File:Line |
|---|---|
| `favourite_try_on_tapped` | `src/screens/FavouriteScreen.tsx:112` |
| `try_on_outcome_retaken` | `src/screens/see-this-on-me/SeeThisOnMeScreen.tsx:229` |

### 1.6 Body screen (3)

| Event | File:Line |
|---|---|
| `body_photo_added` | `src/screens/BodyScreen.tsx:263` |
| `body_photo_replaced` | `src/screens/BodyScreen.tsx:263` (same call, branched by `wasEmpty && !isRetake`) |
| `body_photo_deleted` | `src/screens/BodyScreen.tsx:208` |

### 1.7 Settings (4)

| Event | File:Line |
|---|---|
| `notifications_toggle_changed` | `src/screens/SettingsScreen.tsx:392` |
| `settings_language_changed` | `src/screens/SettingsScreen.tsx:379` |
| `style_direction_changed` | `src/screens/SettingsScreen.tsx:454` |
| `analytics_consent_changed` (grant + revoke) | `src/screens/SettingsScreen.tsx:431, 438` |

### 1.8 Global navigation (1)

| Event | File:Line |
|---|---|
| `screen_viewed` | `src/navigation/AppNavigator.tsx:70` via `handleNavStateChange` on `NavigationContainer.onStateChange`. Skips `OnboardingLoading`. 500ms debounce on identical names. |

## 2. Screen / flow per event

| Flow | Events landed |
|---|---|
| Sign-up (email) | `sign_up_started` → `sign_up_submitted` → `sign_up_completed` (+`sign_up_failed` on error) + `email_verification_resent` |
| Sign-in (email/oauth) | `sign_in_started` → `sign_in_completed` (with `method`) + `sign_in_failed`; `oauth_sign_in_started` → `oauth_sign_in_completed` |
| Password recovery | `forgot_password_requested` → `password_reset_completed` |
| Auth language pick | `auth_language_changed` |
| Onboarding | `welcome_continued` → permission events → preference picks → `onboarding_step_viewed` ×8 → `onboarding_generated` → `onboarding_completed` |
| Home feed engagement | `screen_viewed(Home)` → `outfit_recommendation_viewed` → `outfit_swiped` / `outfit_card_tapped` / `outfit_favorited` |
| Refine modal | `refine_modal_opened` → `refine_chip_selected` / `refine_chip_deselected` → `refine_submitted` / `refine_cancelled` |
| Wardrobe browse | `wardrobe_viewed` → `wardrobe_filter_changed` → `wardrobe_item_opened` → `item_detail_opened` |
| Wardrobe add (camera) | `add_item_opened` → `add_item_method_selected(take_photo)` → `wardrobe_photo_captured` → `add_item_upload_*` → `wardrobe_item_added` |
| Wardrobe add (database) | `add_item_opened` → `add_item_method_selected(search_database)` → `wardrobe_search_initiated` → `wardrobe_search_result_selected` → `wardrobe_item_added` |
| Wardrobe item edit/delete | `item_detail_opened` → `wardrobe_item_edited` / `wardrobe_item_deleted` |
| Favourite | `outfit_favorited` (Home) → `screen_viewed(Favourite)` → `favourite_try_on_tapped` / `outfit_unfavorited` |
| Try-on (BodyScreen / SeeThisOnMe) | `try_on_started` → `try_on_step_completed` ×N → `try_on_completed` / `try_on_failed` → `try_on_outcome_retaken` |
| Body photos | `body_photo_added` → `body_photo_replaced` / `body_photo_deleted` (`full_body` slot only today) |
| Settings | `screen_viewed(Settings)` → `notifications_toggle_changed` / `settings_language_changed` / `style_direction_changed` / `analytics_consent_changed` |
| Global | `screen_viewed` every time the React Navigation route name changes |

## 3. Event properties added

All properties are snake_case, lowercase strings (numbers/booleans unquoted), omitted when value is unknown. Full taxonomy in `auxi/docs/analytics/mixpanel-tracking-plan.md` §5.

Highlights:

- **Auth:** `method` (`email`/`google`/`apple`), `provider` (`google`/`apple`), `error_reason` (sanitized snake_case codes — `invalid_credentials`, `weak_password`, `email_already_exists`, `network_error`, `rate_limited`, `unknown`), `locale` (`en-EN`/`vi-VN`/`fr-FR` — codebase uses `en-EN` not `en-US`)
- **Onboarding:** `step_name` (`welcome`, `location_permission`, `wardrobe_direction`, `fit_preference`, `styles`, `loading`, `completed`, `outro`), `step_index` (1-8), `direction`, `fit`, `style_name`, `permission_status`
- **Home:** `outfit_hash`, `position` (1-based), `source` (`feed`/`refine`), `direction` (`next` — `previous` never fires; deck is forward-only), `method` (`gesture` — `button` never fires; no button swipe), `chip_type` (`mode` on Home, `style_feedback` in Refine), `value`
- **Wardrobe:** `item_id`, `source` (`add_item`/`database`/`home`/`wardrobe`), `method` (`take_photo`/`search_database`), `category`, `fields_changed` (`category`/`color`/`style`/`fit`)
- **Body:** `slot` (`full_body` only today)
- **Settings:** `enabled` (bool), `locale`, `direction`, `granted` (bool)
- **Global nav:** `screen_name` (canonical React Navigation route name), `previous_screen_name?`

## 4. Suggested funnels

Documented in updated tracking plan §10. Build in Mixpanel Insights → Funnels.

1. **Activation funnel** — `sign_up_started` → `sign_up_submitted` → `sign_up_completed` → `onboarding_step_viewed` (per step) → `onboarding_completed` → first `outfit_favorited`. Breakdown: `method`.
2. **Sign-in funnel** — `sign_in_started` → `sign_in_completed`. Breakdown: `method`.
3. **OAuth funnel** — `oauth_sign_in_started` → `oauth_sign_in_completed`. Breakdown: `provider`.
4. **Onboarding step funnel** — `welcome_continued` → `location_permission_granted`/`_denied` → `wardrobe_direction_selected` → `fit_preference_selected` → `style_selected` → `onboarding_generated` → `onboarding_completed`. Surfaces drop-off step.
5. **Value-moment rate** ★ — `outfit_recommendation_viewed` → `outfit_favorited`. Core engagement KPI.
6. **Try-on funnel** — `try_on_started` → `try_on_step_completed` ×N → `try_on_completed` → `try_on_outcome_retaken`. Extends to `_saved`/`_shared` when outcome UI ships (see gaps §5).
7. **Wardrobe-grow (take-photo)** — `add_item_opened` → `add_item_method_selected(take_photo)` → `wardrobe_photo_captured` → `add_item_upload_started`/`_succeeded`/`_failed` → `wardrobe_item_added`. Catches abandonment per stage.
8. **Wardrobe-grow (database)** — `wardrobe_search_initiated` → `wardrobe_search_result_selected` → `wardrobe_item_added`.
9. **Refine engagement** — `refine_modal_opened` → `refine_chip_selected` ×N → `refine_submitted` (vs `refine_cancelled`). Measures whether refine drives commitment.
10. **Retention insight (not a funnel)** — `screen_viewed` grouped by `screen_name`. Identifies dead screens, navigation patterns, session depth.
11. **Mood-feedback funnel** — `wear_this_clicked` → `mood_feedback_opened` → `mood_feedback_submitted` (vs `mood_feedback_skipped`).

## 5. Gaps / remaining work

10 events couldn't fire because the UI surface, control, or API doesn't exist yet. Documented in updated tracking plan §6. Re-evaluate when each surface lands.

### 5.1 Settings controls missing
- `daily_reminder_time_changed` — no hour-picker (hour value is read-only display per CEO Q12)
- `confidence_level_changed` — no control
- `account_logged_out` — no logout button on SettingsScreen (likely lives in Drawer/Sidebar — relocate and wire)
- `account_deleted` — "Delete data" row resets preferences (`resetUserPreferences`), doesn't delete account
- `support_link_tapped` — no support/help/TOS/privacy links on this screen

### 5.2 Home CTAs missing
- `outfit_try_on_tapped` — no "See on me" CTA on Home (footer is "Wear this" + Remix). Wire when a Home-level try-on entry ships.
- `outfit_swiped.direction='previous'` — deck is forward-only; never fires today
- `outfit_swiped.method='button'` — no button-driven swipe path; never fires today
- `context_chip_changed` runtime UI — mode-selector JSX commented out behind AU-221. Handler is wired so event fires automatically when the UI lands.

### 5.3 Wardrobe URL import not built
- `wardrobe_url_import_submitted`
- `wardrobe_url_import_completed`
- `wardrobe_url_import_failed`

`handleImportFromWeb` is a "coming soon" Toast (`WardrobeScreen.tsx:158-165`). Wire when real import ships.

### 5.4 Favourite + try-on outcome UI not built
- `favourite_outfit_opened` — `FavouriteOutfitCard` has no whole-card tap target (only remove ⊖ and try-on actions)
- `try_on_outcome_saved` — `OutfitPreview` has no save button (TODO AU-346: backend save not wired)
- `try_on_outcome_shared` — no share affordance on `OutfitPreview`

### 5.5 Body slot coverage incomplete
`body_photo_added/replaced/deleted` only fire for `slot: 'full_body'`. `selfie` and `body_shape` slots live in the SeeThisOnMe step screens (`StepSelfie`, `StepBodyShape`) with a different lifecycle (flow-state, not persisted slots editable independently). Mirror the events there once those flows gain replace/delete affordances.

### 5.6 Cross-cutting follow-ups (out of scope for this PR)
- **Consent UI** — mechanism is shipped (`grantAnalyticsConsent`/`revokeAnalyticsConsent`); first-run prompt + Settings toggle not yet built. Until then, events are no-ops in prod until QA grants consent manually.
- **PROD Mixpanel token** — `PROD_TOKEN` empty in `src/config/analytics.ts`. Release-blocker.
- **App version super-property** — needs `react-native-device-info` install.
- **Cold/warm app launch tracking** — `app_launched` not in scope; would need `AppState` listener.

## 6. Verification

- `npx tsc --noEmit` → **clean** (exit 0, no output)
- `yarn lint` → **0 errors, 6 warnings** — baseline preserved. All warnings pre-existing (DatabaseScreen / OutfitCanvasScreen inline styles, SignInScreen no-void). The `4 errors / 3 warnings` baseline in `auxi/CLAUDE.md` is stale — actual baseline is 0/6.
- Sanity grep: `outfit_recommendation_viewed` fires only from the helper at `src/services/analytics.ts:173`. No direct `mixpanel.track` calls outside the analytics seam. No duplicate event-name literals beyond the legitimate multi-site cases (one event name per file:line listed above).
- 99 total `track()` call sites across `src/` (incl. pre-existing).

## 7. Files modified (32)

```
src/components/features/ContextChipsModal.tsx
src/context/AuthContext.tsx
src/navigation/AppNavigator.tsx
src/onboarding/v2/OnboardingCompletedScreen.tsx
src/onboarding/v2/OnboardingFitScreen.tsx
src/onboarding/v2/OnboardingLoadingScreen.tsx
src/onboarding/v2/OnboardingOutroScreen.tsx
src/onboarding/v2/OnboardingStylesScreen.tsx
src/onboarding/v2/OnboardingWardrobeScreen.tsx
src/screens/AppWelcomeScreen.tsx
src/screens/BodyScreen.tsx
src/screens/DatabaseScreen.tsx
src/screens/FavouriteScreen.tsx
src/screens/HomeScreen.tsx
src/screens/ItemDetailScreen.tsx
src/screens/LocationPermissionScreen.tsx
src/screens/SettingsScreen.tsx
src/screens/WardrobeScreen.tsx
src/screens/auth/EmailGoogleNoticeScreen.tsx
src/screens/auth/EmailInputScreen.tsx
src/screens/auth/ForgotPasswordRequestScreen.tsx
src/screens/auth/LanguageSettingsScreen.tsx
src/screens/auth/PasswordCreationScreen.tsx
src/screens/auth/ResetNewPasswordScreen.tsx
src/screens/auth/SignInScreen.tsx
src/screens/auth/VerifyEmailScreen.tsx
src/screens/auth/WelcomeScreen.tsx
src/screens/see-this-on-me/SeeThisOnMeScreen.tsx
src/services/analytics.ts                  (helper added: trackRecommendationViewedOnce)
src/services/deepLinkHandler.ts
docs/analytics/mixpanel-tracking-plan.md   (§5 expanded, §6 rewritten as gap list, §10 funnels added)
```

Plus: `plans/260616-0950-mixpanel-comprehensive-instrumentation/spec.md` (this work's spec — outside auxi/).

## 8. Notable design decisions in code

- **`outfit_recommendation_viewed` dedup** — module-level `Set<outfit_hash>` in `analytics.ts`, accessed via `trackRecommendationViewedOnce()` helper. Survives screen unmount/remount, resets only on app restart. Fires from `HomeScreen` `useEffect` keyed on `[activeIndex, listOutfits, isContextModalOpen]`; skipped while refine modal is open; reads settled outfit from `listOutfitsRef.current[clampedActiveIndex]`.
- **`screen_viewed` strategy** — single global listener on `NavigationContainer.onStateChange` rather than per-screen `useFocusEffect`. Filters on route NAME change (not param-only), 500ms debounce, `OnboardingLoading` excluded.
- **`sign_in_completed` extension** — AuthContext now exposes `markOAuthSignIn(provider)` and `markSignInCompletion(method)`. Identity effect reads the pending method ref and emits `oauth_sign_in_completed` (when applicable) + `sign_in_completed` with the real method after `identify()` resolves. Side-fix: SignInScreen now calls `markSignInCompletion('email')` because email login routes through `useLoginMutation` + `refreshUser`, NOT `AuthContext.login` — previously this event never fired for email sign-in.
- **`error_reason` sanitization** — derives from `err.code` (AuthErrorEnvelope) and URL-import error codes. Lowercased snake_case enums (`invalid_credentials`, `weak_password`, `email_already_exists`, `network_error`, `rate_limited`, `invalid_url`, `unreachable_host`, etc.). Falls back to `unknown`. No user-supplied content propagates.
- **`url_domain`** — hostname only (e.g. `asos.com`), parsed via `new URL(rawUrl).hostname`, wrapped in try/catch; OMITTED on parse failure (never ships `''`). (Event sites currently unreachable — URL import flow doesn't exist.)
- **`wardrobe_item_added`** — fires from two sites with different `method`: `take_photo` (WardrobeScreen camera upload) and `search_database` (DatabaseScreen clone). Same event name, discriminated by `method` property.

## 9. Unresolved questions

1. **Locale shape** — spec example was `en-US`, codebase uses i18next codes `en-EN`/`vi-VN`/`fr-FR`. Shipped as-is. Should PM normalize to BCP-47 (`en-US`/`vi-VN`/`fr-FR`)?
2. **`account_logged_out` / `account_deleted`** — confirm location: is it a Drawer/Sidebar component? Spec assumed SettingsScreen. Re-wire once located.
3. **`try_on_outcome_saved`** — wait for AU-346 to land the backend save flow; the event name + property shape are reserved.
4. **`outfit_try_on_tapped`** — does Home need a "See on me" CTA? Product call. Today the only try-on entry is via favourites.
5. **`onboarding_step_viewed`** — should index reflect funnel position (1-based as shipped) or be a stable step ID? Current shape supports both: `step_name` is the stable key, `step_index` is the funnel position.
6. **Step-completed events for onboarding** — only `_viewed` and final action events fire today. Worth adding `onboarding_step_completed` per step for cleaner step-level conversion? Not in this PR; flag for follow-up.
