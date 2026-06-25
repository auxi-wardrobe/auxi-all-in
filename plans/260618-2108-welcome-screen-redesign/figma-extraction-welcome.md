# Figma Extraction — Welcome (auth root) redesign

- **Figma**: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-10085
- **Node**: `2849:10085` ("Welcome Home"), 390×844
- **Target screen**: `auxi/src/screens/auth/WelcomeScreen.tsx` (route `Welcome`, auth stack root) — RESTYLE, not new screen
- **Decision (CEO)**: logo slot uses **MacgieLoader motion** (lively: ±4° dwelling sway + pupil tracking + ~9% bob), rendered as a *logo* — **no "Loading" caption, image a11y ("Macgie"), not busy state**.

## What already exists (keep)
- Full OAuth wiring: Google/Apple mutations, `socialBusy` spinner window, conflict-error routing (`EMAIL_LINKED_TO_PASSWORD` → SignIn, `EMAIL_LINKED_TO_OTHER_PROVIDER` → toast), `isOAuthConfigured()` guard, cancel handling.
- Analytics: `track('oauth_sign_in_started', {provider})` on Google + Apple.
- Inline glyphs: `GoogleGlyph`, `AppleGlyph`, `EnvelopeGlyph`, `CaretDownGlyph` (24×24, on-token colors).
- Language button top-right → `navigation.navigate('LanguageSettings')`.
- Apple CTA iOS-gated (`Platform.OS === 'ios'`) — KEEP (Figma always shows it; iOS gating is correct platform behavior).

## Gaps vs Figma (the work)
1. **Hero logo** — MISSING. Add `MacgieLoader` (lively motion) in logo slot. Figma node `macgie-animate-2`, 103×126. Render ~126 height, no label, `accessibilityRole="image"` + label "Macgie", drop busy state. Import from `src/components/macgie`.
2. **Heading block** — Figma: "Welcome to Macgie" (2 lines) H1 + subtitle "Get dressed with more clarity, less pressure." (2 lines). Current ships only a single centered headline; subtitle is MISSING.
3. **Layout** — Figma groups logo+heading+subtitle near the TOP (group top ≈ 171/844, 7px gaps), button stack pinned BOTTOM (group top ≈ 546/844). Current vertically-centers the headline (`flex:1` center). Restructure: top logo/heading group + bottom action stack.
4. **"or" divider** — Figma: two horizontal M3 dividers with **"or"** centered between (Inter 12 regular). Current is a single 1px line. Replace with line — "or" — line.

## Tokens / type (variable defs from Figma)
| Figma var | value | auxi token |
|---|---|---|
| background/primary/neutral_50 | #fcfcfd | `colors.uacBackgroundNeutral50` (already used) |
| text/neutral/base, border/neutral/base, background/neutral/base | #1d1f23 | `uacTextBase` / `uacBorderBase` / `uacBackgroundBase` |
| text/primary/base | #f2efec | `uacTextPrimaryBase` |
| body/md | Poppins Medium 16/24, ls 0 | `typography.aliases.uacBodyMdMedium` (Poppins-Medium bundled) |
| body/xs | Inter Regular 12/16 | `uacBodyXsRegular` (Inter-Regular bundled) |
| heading/H1 | **Nunito Sans** Regular 36/44, ls −0.72 | `uacH1Bold` + `letterSpacing:-0.72` (current) — **Nunito Sans NOT bundled**; keep existing heading family, FLAG font + weight (400 vs bold) discrepancy for designer/CEO. Do NOT add a new font family. |

### Buttons (327 wide, centered)
- **Google** — outlined: border 1.5px `uacBorderBase`, radius **17**, px20 py16, label `uacBodyMdMedium`/`uacTextBase`, GoogleGlyph 24 trailing.
- **Apple** — filled `uacBackgroundBase`, radius **16**, height 56, label `uacBodyMdMedium`/`uacTextPrimaryBase`, AppleGlyph 24.
- **Email** — outlined like Google (radius 17), EnvelopeGlyph 24.
- Verify radius tokens: outlined=17, filled=16 (Figma differs by 1px). Use existing radius tokens if they match; don't hardcode.
- Group gaps: social sub-group 12px; outer action stack 16px.

### Legal footer
- Inter 12 regular `uacTextBase`: "By continuing, you agree to our **Terms of Service** and **Privacy Policy**" (links underlined in Figma). Current ships single non-link Text. Linkifying is a PM open-Q — keep as-is unless trivially linkable; if linkified, both links need testIDs + tracking.

## Analytics gaps (rule: analytics-tracking-required.md)
- Email CTA tap (`onPressEmail`) — currently UNTRACKED. Add an event (check §5 taxonomy for an existing `email`-path name before inventing; likely `email_sign_in_started` or reuse pattern of `oauth_sign_in_started`).
- Language button tap — UNTRACKED. Add if a matching event/funnel fits; else log §6 gap.
- Welcome screen view — confirm a `screen_viewed`/equivalent fires; if not, add per existing screen-view pattern.
- Update `auxi/docs/analytics/mixpanel-tracking-plan.md` (§5 shipped / §6 gaps).

## i18n
- New subtitle string → `uac.welcome.subtitle` (or similar). 3-locale parity required: en-US, vi-VN, fr-FR (see i18n conventions). Confirm `uac.welcome.headline` already reads "Welcome to Macgie".

## Verification
- `npx tsc --noEmit` clean (legacy `_HomeScreen.tsx` errors expected).
- `yarn lint` no new errors/warnings over baseline (4 err/3 warn in `_HomeScreen.tsx`).
- `./scripts/auxi-lint-tokens.sh` clean (no new hex / font-family drift).
- testID on every interactive element (existing ones already named `welcome-*`).
