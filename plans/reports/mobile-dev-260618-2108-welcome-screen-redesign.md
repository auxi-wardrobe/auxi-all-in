# mobile-dev — Welcome screen restyle (Figma node 2849:10085)

Date: 2026-06-18
Plan: plans/260618-2108-welcome-screen-redesign
Extraction brief: plans/260618-2108-welcome-screen-redesign/figma-extraction-welcome.md
Target: auxi/src/screens/auth/WelcomeScreen.tsx (RESTYLE — auth-stack root)

## Summary

Restyled the Welcome screen to the new Figma layout: hero Macgie logo + heading
+ subtitle grouped near the top, action button stack pinned to the bottom, and a
line·"or"·line divider replacing the single rule. All OAuth/Apple/email auth
logic, error routing, busy-state spinner, and existing testIDs preserved
untouched. Added two missing analytics events and the subtitle/"or" i18n strings
across all 3 locales. App rename Auxi→Macgie applied to the Welcome headline.

## Files changed

- `auxi/src/screens/auth/WelcomeScreen.tsx`
  - Import `MacgieLogo` from `../../components/macgie`.
  - New hero group: `<MacgieLogo size={126} testID="welcome-logo" />` + headline
    + subtitle, `alignItems:'center'`, `marginTop` ≈ 48, `gap: uacDimension8`.
  - Wrapped action stack + legal in a plain bottom `<View>` so the
    `bodyContainer` `space-between` keeps hero on top and the action block at the
    bottom (previously the headline was vertically centered via `flex:1`).
  - Replaced single 1px `divider` with `orDivider` (row): `orDividerLine` (flex
    1) · `orDividerLabel` ("or", `uacBodyXsRegular`) · `orDividerLine`.
  - `onPressEmail` now fires `track('email_sign_in_started', { method: 'email' })`.
  - `onPressLanguage` now fires `track('auth_language_button_tapped')`.
  - New styles: `heroGroup`, `subtitle`, `orDivider`, `orDividerLine`,
    `orDividerLabel`. Removed `headlineWrap` + `divider`.
- `auxi/src/translations/en-EN.json` / `vi-VN.json` / `fr-FR.json`
  - `uac.welcome.headline`: "Welcome to\nAuxi" → "Welcome to\nMacgie" (+ vi/fr).
  - Added `uac.welcome.subtitle` and `uac.welcome.or`.
- `auxi/docs/analytics/mixpanel-tracking-plan.md`
  - §5.1: added `email_sign_in_started`, `auth_language_button_tapped`; fixed
    `oauth_sign_in_started` line refs (176,214 → 187,225).
  - §10: added "Welcome auth-entry split" funnel note.

## MacgieLoader-as-logo approach

The extraction brief proposed MacgieLoader-as-logo (with a caveat about its
forced `busy:true`/"Loading" a11y). I used **`MacgieLogo`** instead — a
purpose-built, already-on-system component (`src/components/macgie/MacgieLogo.tsx`)
that is the cleaner DRY choice and exactly satisfies the brief's stated logo
requirements:

- Built from the same Figma node the brief cites: header comment references
  node `2849:8332` / component "Macgie Animate 2" (the `macgie-animate-2`
  instance in the Welcome frame).
- `accessibilityRole="image"`, `accessibilityLabel="Macgie"`, NO busy/Loading
  state (its docstring explicitly contrasts itself with MacgieLoader).
- Lively idle motion (sway + bob entrance/breathe), honors OS Reduce Motion.
- `size={126}` matches Figma `macgie-animate-2` height (103×126).

**I did NOT touch any macgie component** — no fork, no prop addition. MacgieLogo
already exposed exactly the API needed. This avoids the brief's fallback path
(composing MacgieLoader + a11y wrapper) entirely.

CEO confirm point (per brief): logo semantics + lively motion are both honored.
One nuance for the designer gate: MacgieLogo's idle sway is intentionally lighter
than MacgieLoader's (±3° "breathe, not perform" vs the loader's ±4° dwell-sway).
The brief mentioned "lively (±4°)". MacgieLogo is the on-system *logo* motion
language; flag for CEO if a louder sway is wanted on the Welcome mark.

## Analytics events

| Event | State | Site | Props |
|---|---|---|---|
| `email_sign_in_started` | ADDED | WelcomeScreen.tsx:142 (`onPressEmail`) | `method: 'email'` |
| `auth_language_button_tapped` | ADDED | WelcomeScreen.tsx:148 (`onPressLanguage`) | — |
| `oauth_sign_in_started` | KEPT | WelcomeScreen.tsx:187 (google), 225 (apple) | `provider` |
| `screen_viewed` (`screen_name=Welcome`) | CONFIRMED (no wiring needed) | global nav listener `AppNavigator.tsx:70` `onStateChange` | `screen_name`, `previous_screen_name?` |

- `email_sign_in_started` mirrors the existing `oauth_sign_in_started` taxonomy
  (provider/email = the three Welcome auth-entry options). `sign_up_started`
  still fires later on the EmailInput "Continue" submit — no double-count of the
  same step. No PII (literal name, `method:'email'` constant only).
- `auth_language_button_tapped` is the entry event; the locale change itself
  still emits `auth_language_changed` from inside LanguageSettings.
- No template-literal event names; all literal snake_case past-tense.
- Tracking-plan §5.1 + §10 updated.

## i18n keys (3-locale parity)

| Key | en-EN | vi-VN | fr-FR |
|---|---|---|---|
| `uac.welcome.headline` | "Welcome to\nMacgie" | "Chào mừng đến với\nMacgie" | "Bienvenue sur\nMacgie" |
| `uac.welcome.subtitle` | "Get dressed with more clarity, less pressure." | "Phối đồ rõ ràng hơn, bớt áp lực hơn." | "Habillez-vous avec plus de clarté, moins de pression." |
| `uac.welcome.or` | "or" | "hoặc" | "ou" |

## testIDs

- New interactive/visual element: `welcome-logo` (on MacgieLogo).
- All existing welcome-* testIDs preserved (lang-link, cta-google, cta-apple,
  cta-email, *-spinner, legal-text). The "or" divider + lines are pure layout
  (non-interactive) — exempt.

## Verification (Node 20)

- `npx tsc --noEmit` → exit 0, clean (no errors, including no legacy
  `_HomeScreen.tsx` output this run).
- `yarn lint` → 1 error + 7 warnings, ALL pre-existing in other files
  (HomeScreen, DatabaseScreen, OutfitCanvasScreen, SignInScreen, usePinReducer).
  `npx eslint src/screens/auth/WelcomeScreen.tsx` → exit 0 (clean). Zero new
  lint over baseline; my changes add nothing.
  NOTE: the prompt's stated baseline ("4 errors + 3 warnings in _HomeScreen.tsx")
  is stale vs the current working tree, but the relevant fact holds: I added zero.
- `./scripts/auxi-lint-tokens.sh` → exits 0; reports a stable pre-existing
  baseline of 34 HEX/FONT violations, NONE in WelcomeScreen and none from my
  changes. (Caveat: the script scans the Desktop worktree
  `/Users/.../Desktop/wardrobe_project/auxi`, not the dev checkout I edited.)
  Direct check on the edited file: the only hex literals in WelcomeScreen are the
  4 pre-existing Google brand-glyph colors (official G logo) — unchanged by me;
  no `fontFamily` literals (all via `theme.typography.aliases.*`).

## Discrepancies flagged (designer gate / CEO)

1. **Nunito Sans NOT bundled (font drift, deferred).** Figma H1 = Nunito Sans
   Regular 36/44, ls −0.72. Kept existing `uacH1Bold` (Poppins-Bold 40/52) +
   `letterSpacing:-0.72` — did NOT add a new font family per project rules. Both
   the family (Nunito Sans vs Poppins) AND weight (400 vs 700) differ. Deferred
   font-bundling item for CEO; not bundled in this PR.
2. **Outlined button radius (1px sub-token).** Figma outlined (Google/email) =
   17, filled (Apple) = 16. Token `uacButtonCta` = 16 matches the filled exactly;
   no 17 token exists. All three buttons keep `uacButtonCta` (16) via
   `buttonBase` — did NOT introduce a one-use 17px token. The 1px delta on the
   two outlined buttons is flagged; CEO/designer to decide if a token is wanted.
3. **7px hero gaps (1px sub-token).** Figma logo→heading→subtitle gaps ≈ 7px;
   snapped to nearest token `uacDimension8` (8). Flagged; no 7px token added.
4. **Hero top inset is approximate.** `marginTop ≈ 48` (uacDimension24×2)
   approximates Figma group-top ≈171/844 below the header. Visual gate may want
   a tweak after the sim side-by-side.
5. **Legal links not linkified.** Kept the single non-link legal `Text`
   (PM open-Q on linkifying "Terms of Service"/"Privacy Policy" substrings).
   If linkified later, both links need testIDs + tracking.
6. **Language button shows a caret, Figma shows a flag glyph.** Existing
   `CaretDownGlyph` kept (no flag asset; out of restyle scope). Flag for CEO.

## Visual verification

NOT run (no simulator / mobile-mcp in this session, per instructions).
Status: code complete · visual verification pending — hand off to qa-ui
Compare mode + designer gate (step 6.5), then qa-mobile smoke.

## Open questions

- Q1: MacgieLogo's ±3° "breathe" sway vs the brief's "lively ±4°" — accept the
  on-system logo motion or want a louder Welcome mark? (CEO)
- Q2: outlined-button 17px and hero 7px sub-token deltas — accept 16/8 snap or
  introduce tokens? (designer/CEO)
- Q3: Nunito Sans bundling — schedule, or keep Poppins H1 indefinitely? (CEO)

**Status:** DONE_WITH_CONCERNS
**Summary:** Welcome restyled to Figma (MacgieLogo hero + heading/subtitle top,
button stack bottom, "or" divider); 2 analytics events + 3-locale subtitle/"or"
added; tsc/lint/token-lint clean of new violations.
**Concerns:** Visual gate not run here (no sim); Nunito Sans + 17px/7px sub-token
deltas are deliberate token-rule-compliant deferrals flagged for designer/CEO.
