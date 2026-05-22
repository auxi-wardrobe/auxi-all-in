# Screen: Email–Google Notice (existing Google account)

**Node**: `2849:10267`
**Dimensions**: 414×896
**Purpose**: Inform the user that the email they entered is already linked to an existing Google account and route them to sign in with Google instead.
**Maps to AC scenario**: AU-242 — "Given a user enters an email associated with an existing Google account, when they continue with email, then the app must surface a 'Sign in with Google' affordance and prevent password-based sign-in for that account."

## Layout
- Container: column auto-layout, `padding: 112px 24px 12px 24px`, gap = 0 (`--line-heigh/none`), centered items, anchored to bottom, full screen 414×896, `borderRadius: 16px`.
- Inner stack (`2849:10269`): column auto-layout, full width, gap = `24px` (`--dimension/24---1_5-rem`), `items-center`.
  - Inside it, the body block (`2849:10270`) is width `360px`, column auto-layout, gap = 0 with internal `gap: 16px` between the two text blocks (`2849:10271`), paddingY `12px`.
- Background: `--background/neutral/subtlest` (`#FFFFFF`).
- Status bar / Safe area: header zone reserves top `112px`.

## Header / Top bar
- Top bar absolute, `height: 107px`, full width `414px`, top = 0.
- Inner row: `width: 370px`, centered, top = 45px, `justify-between`.
- Leading: **Back** icon button `45×45` (asset `imgBack`). Action: `pop()` back to the email-input step.
- Trailing: **feedback** slot `47×47` (empty placeholder in this variant).
- **No title text on this screen** (unlike Language screen) — header carries back only.

## Body sections (top-to-bottom)

### 1. Headline — "Google"
- Component: text node (`2849:10272`).
- Text: "Google"
- Style ref: `Text-md (l-24)/Semibold` — Inter Semi Bold 600 / 16px / lineHeight 24px.
- Color: `--text/neutral/base` (`#1D1F23`).
- Width: full (360px), left-aligned.
- Spacing below: 16px gap to next text block.

### 2. Supporting paragraph
- Component: text node (`2849:10273`).
- Text: "This email is linked to a Google account. Please sign in with Google instead"
- Style ref: `Text-md (l-24)/Regular` — Poppins Regular 400 / 16px / lineHeight 24px.
- Color: `--text/neutral/base` (`#1D1F23`).
- Width: full (360px), left-aligned, multi-line wrap (`word-break: break-word`).
- Spacing below: 24px to button (outer stack gap).

### 3. CTA — Continue with Google (Secondary, outlined)
- Component: `Button` (`Hierarchy=Secondary, State=Enable, Icon=Yes, Size=56`).
- Frame: full width up to `max-width: 327px` of parent stack, height 56px, `borderRadius: 16px`, border `1.5px solid --border/neutral/base` (`#1D1F23`), background transparent (white).
- Inner row: `gap: 8px`, `padding: 16px 20px`, items-center, justify-center.
- Label: "Continue with Google"
  - Style ref: `Text-md (l-24)/Medium` — Poppins Medium 500 / 16px / lineHeight 24px.
  - Color: `--text/neutral/base` (`#1D1F23`).
- Trailing icon: Google G logo (`imgImage1`) inside `24×24` box, actual glyph rendered at `16×16` centered.
- Action: tap → trigger Google Sign-In flow (same path as the Google entry point on the welcome screen). On success, proceed into post-auth UAC.

## Interactive elements
- **Back button**: state default. Action = `navigation.goBack()` → return to email input.
- **Continue with Google button**: state = Enable (Secondary). Action = launch native Google Sign-In SDK. Disabled when SDK in flight (show spinner / disable per existing button pattern). On error, surface inline error per project's standard error toast.
- **Password path is intentionally absent**: there is no "Continue" / "Enter password" CTA on this screen — per AC, password-based sign-in is blocked for Google-linked accounts.

## Text content (verbatim)
- Headline: `Google`
- Supporting: `This email is linked to a Google account. Please sign in with Google instead`
- CTA: `Continue with Google`
- No error / link / helper text.

## Design tokens referenced
- Color
  - `--background/neutral/subtlest` → `#FFFFFF`
  - `--text/neutral/base` → `#1D1F23`
  - `--border/neutral/base` → `#1D1F23`
- Typography
  - `Text-md (l-24)/Semibold` — Inter Semi Bold 600 / 16px / 24px (headline)
  - `Text-md (l-24)/Regular` — Poppins Regular 400 / 16px / 24px (supporting)
  - `Text-md (l-24)/Medium` — Poppins Medium 500 / 16px / 24px (CTA label)
- Spacing
  - `--body` = 24px (horizontal padding)
  - Outer stack gap = 24px
  - Body block paddingY = 12px, internal gap = 16px (between headline & paragraph)
  - Button paddingX = 20px, paddingY = 16px, gap = 8px
- Radii
  - Screen card: 18px
  - Button: 16px
- Components
  - `Hierarchy=Secondary, State=Enable, Icon=Yes, Size=56` (node `470:2282`) — M3 outlined button variant

## Notes / gotchas
- **No title in top bar** — designer chose to use the "Google" word inside the body as the de-facto heading rather than a top-bar title. Don't add one back without checking with Viet.
- **Secondary button (1.5px outlined)** is the only CTA — there is no fallback "Use a different email" link in this Figma frame. If product needs one (e.g. user mistyped email), escalate to PM; do NOT invent one unilaterally.
- **The supporting copy ends without a period** — `"...sign in with Google instead"` (verbatim from Figma). Preserve. Don't add punctuation.
- **Headline "Google" reads odd in isolation** — it is acting as a section/title for the account-conflict context. If a localization pass is done for `vi`, ask Viet for the Vietnamese equivalent (`"Tài khoản Google"`?) before guessing.
- **Tap target**: button is 56px tall — meets accessibility. Back button visual is 45×45; the M3 spec encourages 48dp — verify hitSlop matches Language screen and the rest of the UAC flow.
- **Google icon asset** is a remote PNG/SVG via `imgImage1`. In RN, prefer the existing Google brand icon asset already shipped with the Google Sign-In SDK or local assets, not a re-download.
