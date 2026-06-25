# App Feedback Screen — delivery report

**Agent:** mobile-dev · **Date:** 2026-06-17 · **Scope:** `auxi/` only
**Task:** Build the App Feedback screen, wire it to `POST /api/feedback`, hook up the sidebar menu item.

## Summary

New `Feedback` screen (category pills · multiline message + counter · optional
1–5 star rating · filled submit with loading state). Submits via TanStack
`useMutation` → `feedbackService` → `POST /api/feedback`. Success Toast + form
reset; error Toast with 429 → rate-limit copy. Sidebar "Feedback" item now
navigates instead of just closing the drawer. Two analytics events wired,
tracking-plan doc updated. tsc clean, no new lint problems.

## Files created

| File | Purpose |
|---|---|
| `auxi/src/services/feedbackService.ts` | Typed wrapper for `POST /feedback` — `FeedbackSubmitRequest` / `FeedbackSubmitResponse` / `FeedbackCategory`. Goes through `apiClient` (no axios import). |
| `auxi/src/screens/FeedbackScreen.tsx` | The screen. `SafeAreaView` + hamburger header (mirrors SettingsScreen), 4 category pills, message `TextInput` (maxLength 2000 + live counter), optional star rating, `PillButton variant="filled"` submit. Theme tokens only, no literal hex. |

## Files edited

| File | Change |
|---|---|
| `auxi/src/types/navigation.ts` | Added `Feedback: undefined;` to `AppStackParamList`. |
| `auxi/src/navigation/AppNavigator.tsx` | Imported + registered `<Stack.Screen name="Feedback">` in the post-onboarding block. |
| `auxi/src/components/layout/SidebarMenu.tsx` | Feedback `MenuItem` `onPress` `close` → `() => go('Feedback', close)` + `isActive={routeName === 'Feedback'}` (matches siblings). |
| `auxi/src/translations/en-EN.json` | Added `feedback` namespace (under `boilerplate`). |
| `auxi/src/translations/fr-FR.json` | Same keys, proper French. |
| `auxi/src/translations/vi-VN.json` | Same keys, proper Vietnamese. |
| `auxi/docs/analytics/mixpanel-tracking-plan.md` | New §5.12 (App Feedback) with file:line + props; new app-feedback funnel in §10. |

i18n key parity across all 3 locales: `title`, `subtitle`, `a11y_open_menu`,
`category_bug|idea|general|praise`, `message_label`, `message_placeholder`,
`rating_label`, `a11y_rate_stars`, `submit`, `success`, `error_generic`,
`error_rate_limit`.

## Analytics (per `.claude/rules/analytics-tracking-required.md`)

| Event | Props | Notes |
|---|---|---|
| `feedback_submitted` | `category`, `rating?` | rating omitted when unset (never null). |
| `feedback_submit_failed` | `error_code` | sanitized snake_case: `rate_limited` / `validation_error` / `auth_error` / `network_error` / `server_error`. Never the raw message. |

- Both go through `src/services/analytics.ts` `track()` with **literal** event names.
- **No PII**: free-text `message` is never tracked — only `category` + `rating` leave the device.
- `screen_viewed` for `Feedback` fires from the global nav listener (`AppNavigator.tsx`), not double-tracked.
- `platform` rides the existing global super-property (`Platform.OS`); also sent in the request body per contract.

## testIDs (every interactive element)

`feedback-menu-button`, `feedback-category-{bug|idea|general|praise}`,
`feedback-message-input`, `feedback-message-counter`,
`feedback-rating-{1..5}`, `feedback-submit` (PillButton emits
`feedback-submit-loading` for the spinner). Icon-only / star controls also carry
distinct `accessibilityLabel`s (a11y label ≠ testID per CLAUDE.md).

## Decisions / deviations

- **`app_version` OMITTED.** No real version source exists: `react-native-device-info`
  is not installed (confirmed in `analytics.ts` comment + `package.json`), and
  there's no version constant in `src/config`. Per the AUTO-FILLED FIELDS rule,
  omitted entirely rather than faked. The `app_version?` field stays on the
  request type for when a real source lands.
- **On success → reset form** (not navigate back). Task allowed either; reset
  keeps the user on-screen to send more, and the success Toast confirms.
- **Rating uses ★/☆ text glyphs**, not an SVG asset. No `Star` icon exists in
  `src/assets/icons/`; rather than invent one outside Figma (would need
  figma-icons-sync), I used theme-colored typographic glyphs. KISS. If the CEO
  has a Figma star spec, swap to an exported SVG then.
- **Rating is clearable** — tapping the currently-selected star resets to unset
  (it's an optional field).
- Submit button uses the existing `PillButton` primitive (`variant="filled"`,
  `loading` prop) — gets the disable + cross-fade spinner for free, consistent
  with the rest of the app. Disabled until the trimmed message is non-blank.

## Verification

- `nvm use 20 && npx tsc --noEmit` → **clean** (no errors).
- `yarn lint` → **8 problems (1 error, 7 warnings), all pre-existing.** None in
  any file I touched. The single error is `HomeScreen.tsx:685` (exhaustive-deps);
  the 7 warnings are inline-styles / no-void in DatabaseScreen / OutfitCanvas /
  usePinReducer / SignInScreen.
- **Baseline drift note:** `auxi/CLAUDE.md` records the lint baseline as "4
  errors all in `_HomeScreen.tsx`". The actual current baseline is **1 error in
  `HomeScreen.tsx`** — the legacy `_HomeScreen.tsx` no longer surfaces in lint.
  My change added 0 net problems regardless; flagging the doc drift for the
  tech-lead to reconcile.
- **Simulator: NOT run** (mobile-dev has no mobile-mcp). `yarn ios:sim` smoke +
  deterministic verify should be handed to **qa-mobile** (and qa-ui if a Figma
  ref for this screen exists — none was provided, so spacing/typography were
  matched to the SettingsScreen/Favourite idiom, not a pixel spec).

## Open questions

1. No Figma reference was provided for this screen — layout follows existing
   header/list idioms. If the CEO has a design, a qa-ui compare pass is needed.
2. Backend `POST /api/feedback` contract was taken as authoritative from the
   task prompt. I did not independently verify it in
   `wardrobe-backend/API_DOCUMENTATION.md` (out of my repo scope). If the doc
   disagrees (e.g. field names), tech-lead/backend-dev should reconcile.
3. Rating glyph vs SVG icon — confirm with CEO if a Figma star asset is expected.
