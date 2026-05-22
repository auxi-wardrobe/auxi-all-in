# Screen: Forgot password — request email

**Node**: `2849:10535`
**Dimensions**: 414×896
**Purpose**: User enters / confirms the email address to which a password-reset link will be sent.
**Maps to AC scenario**: AU-242 — "User taps 'Forgot your password?'; app collects the target email and dispatches a reset link via email."

## Layout

- **Container**: `bg: var(--background/neutral/subtlest, white)`, `border-radius: 18px`, full-frame 414×896
- **Body wrapper** (`2849:10536`): vertical flex, items-center, `pt: 112px`, `pb: 12px`, `px: 24px`, width 414, height 896
- **Header overlay** (`2849:10550`): absolute top, 107px high
- **Primary CTA** (`2849:10551`): absolute, anchored at `top: 775px`, `left: 43.5px`, `width: 327` (i.e. 21px from each side on a 414 canvas — visually screen-centered; this is the standard 24px-edge button slot ≈ 366px container, but designer used 43.5px = (414−327)/2)
- **No keyboard graphic** in this frame (cleaner than sign-in/reset screens — keyboard may or may not be visible at runtime depending on focus state).

## Header / Top bar

- Presence: **yes** — back button at left (45×45 asset, M3 Round Small)
- Trailing slot: empty 47×47 placeholder (`feedback`)
- No title text

## Body sections (top-to-bottom)

### 1. Heading + subhead block (`2849:10539`)
- Width: 100% of 360 inner container
- Layout: `flex-col gap-4` (`var(--dimension/4---0_25-rem, 4px)`)
- **Heading** (`2849:10540`): text verbatim `Reset your password`
  - Style: `Text-md (l-24)/Semibold` — Inter Semi Bold 16/24, color `var(--text/neutral/base, #1d1f23)`
- **Supporting text** (`2849:10541`): text verbatim `We'll send a password reseting to your email`
  - Style: `Text-md (l-24)/Regular` — Poppins Regular 16/24, color `var(--text/neutral/base, #1d1f23)`
  - **TYPO IN FIGMA**: "reseting" should likely be "reset link" — flag with copy/PM before ship.

### 2. Email field (pre-filled / editable — filled M3 variant)
- Component: M3 Text field (`1752:24683`)
- Container (`2849:10543`): height 56, `border-radius: 8px`, `bg: var(--color/neutral/100-#f2f4f7, #f2f4f7)` — **filled variant** (no border)
- Inner: `padding: 4px 16px`, no trailing icon
- Display value verbatim: `donut@macgie.com`
- Text style: `static/body-large` Poppins Regular 16/24, color `var(--text/neutral/subtle_100, #40444d)`
- Width: full row (360 inner)
- 16px gap below to nothing (CTA is absolutely positioned)
- **Behavior question** (open): is this field editable, or read-only echoing the email entered on the previous screen? Subtle color (`#40444d`) suggests read-only/disabled. Confirm with designer — see Open Questions.

### 3. Primary CTA — "Send reset password"
- Absolute position: `top: 775, left: 43.5, width: 327, height: 56`
- Component ref: `Hierarchy=Primary, State=Enable, Icon=Yes, Size=56` (`470:2264`)
- Container: `bg: var(--background/neutral/base, #1d1f23)`, `border-radius: 16px`, height 56, flex row centered, gap 8px between label + icon
- Label verbatim: `Send reset password`
- Label style: Poppins Medium 16/24, color `var(--text/primary/base, #f2efec)`
- Trailing icon: 24×24 (arrow → asset `imgVector`)

## Interactive elements

| Element | States | Action per AC |
|---|---|---|
| Email field | If editable: empty/focused/filled/error. If read-only: locked | If editable → user can change target email; validate format before enabling CTA |
| "Send reset password" CTA | enabled, disabled (invalid/empty email), pressed, loading | POST reset-password request → on success navigate to Screen 11 (check mail); on failure show inline error |
| Header back | enabled | pops back to sign-in (Screen 9) |

## Text content (verbatim)

- Heading: `Reset your password`
- Subhead: `We'll send a password reseting to your email` (typo flagged)
- Email value (sample): `donut@macgie.com`
- CTA: `Send reset password`
- No error/helper text shown in this static design

## Design tokens referenced

- `--background/neutral/subtlest` → `#ffffff`
- `--background/neutral/base` → `#1d1f23` (CTA bg)
- `--color/neutral/100-#f2f4f7` → `#f2f4f7` (field bg)
- `--text/neutral/base` → `#1d1f23`
- `--text/neutral/subtle_100` → `#40444d`
- `--text/primary/base` → `#f2efec` (button label, off-white)
- `--body` → `24px` (horizontal padding)
- `--dimension/4---0_25-rem` → `4px` (heading↔subhead gap)
- `--dimension/8---0_5-rem` → `8px` (button label↔icon gap)
- Typography tokens: `Text-md (l-24)/Semibold`, `Text-md (l-24)/Regular`, `Text-md (l-24)/Medium`

## Notes / gotchas

- This is the **only screen in the batch with a visible primary CTA button** — the sign-in screen uses a round icon button, the reset-new-password screen lacks a CTA in the static frame.
- CTA is absolutely positioned at `top: 775` — about 56+8+12 = ~76px above the home indicator on a 896-tall frame. Below the keyboard area when keyboard is closed.
- Copy typo: `"a password reseting"` — almost certainly meant `"a password reset link"`. Flag in PM/Linear before mobile implements.
- Email field's subtle color tone matches the read-only sign-in email field — implementation should pick one: either truly read-only (use the email from the previous screen + a small "edit" affordance) or editable with normal `base` text color when focused.
- No keyboard graphic in the Figma frame — keyboard appearance is implicit / runtime-only.
