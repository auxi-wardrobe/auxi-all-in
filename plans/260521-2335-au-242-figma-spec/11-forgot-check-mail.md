# Screen: Forgot password — check mail confirmation

**Node**: `2849:10552`
**Dimensions**: 414×896
**Purpose**: Confirm to the user that a reset link has been dispatched; show the email it was sent to + spam-folder hint; offer a path back to login.
**Maps to AC scenario**: AU-242 — "After requesting reset, user sees confirmation with destination email and instructions to check inbox/spam, with affordance to return to login."

## Layout

- **Container**: `bg: var(--background/neutral/subtlest, white)`, `border-radius: 18px`, full-frame 414×896
- **Body wrapper** (`2849:10553`): vertical flex, items-center, `pt: 112px`, `pb: 12px`, `px: 24px`, width 414, height 896
- **Header overlay** (`2849:10568`): absolute top, height 107px
- **Primary CTA** (`Button` instance referenced inline at bottom): absolute, `top: 775, left: 43.5, width: 327`
- **No keyboard graphic** — pure confirmation screen, no inputs requiring focus

## Header / Top bar

- Presence: **yes** — back button at left (45×45)
- Trailing slot: empty 47×47 placeholder (`feedback`)
- No title text

## Body sections (top-to-bottom)

### 1. Heading + subhead block (`2849:10556`)
- Layout: `flex-col gap-4`, width 100% (360 inner)
- **Heading** (`2849:10557`): verbatim `Reset your password`
  - Style: `Text-md (l-24)/Semibold` — Inter Semi Bold 16/24, color `#1d1f23`
- **Supporting text** (`2849:10558`): verbatim `We've sent  a password reset link to:` (note the **double space** between "sent" and "a" — kept verbatim from Figma; fix in copy QA)
  - Style: `Text-md (l-24)/Regular` — Poppins Regular 16/24, color `#1d1f23`
  - `whitespace-pre-wrap` is set → preserves the double space

### 2. Email display field (read-only, filled M3)
- Component: M3 Text field (`1752:24683`), filled variant
- Container (`2849:10560`): height 56, `border-radius: 8px`, `bg: #f2f4f7`
- Display value verbatim: `donut@macgie.com`
- Style: Poppins Regular 16/24, color `var(--text/neutral/subtle_100, #40444d)`
- Width: full row (360 inner)
- Acts as a **non-interactive readout** of the destination email — visually identical to a text field but should be treated as a static display in implementation (no focus, no edit).

### 3. Spam-folder hint
- Container (`2849:10567`): full-width 360, no extra padding
- Text verbatim: `if you don't see the email, check your spam folder.`
- Style: `Text-md (l-24)/Regular` — Poppins Regular 16/24, color `#1d1f23`
- Lowercase first letter is **as-designed** (kept verbatim) — flag in copy QA.

### 4. Primary CTA — "Back to Login"
- Position: absolute `top: 775, left: 43.5, width: 327, height: 56`
- Component ref: `Hierarchy=Primary, State=Enable, Icon=No, Size=56` (`470:2206`) — note: **no icon** variant (differs from Screen 10's CTA which has trailing arrow)
- Container: `bg: var(--background/neutral/base, #1d1f23)`, `border-radius: 16px`, h 56, centered text
- Label verbatim: **`Back to Login`** (Title Case)
- Label style: Poppins Medium 16/24, color `var(--text/primary/base, #f2efec)`

## Interactive elements

| Element | States | Action per AC |
|---|---|---|
| Email readout field | static / non-interactive | display destination email only |
| "Back to Login" CTA | enabled, pressed | navigate back to the sign-in entry (likely the email-entry step OR the welcomeback Screen 9) — confirm target with PM |
| Header back | enabled | navigates back to Screen 10 (request email) |

## Text content (verbatim)

- Heading: `Reset your password`
- Subhead: `We've sent  a password reset link to:` (double-space preserved)
- Email value (sample): `donut@macgie.com`
- Hint: `if you don't see the email, check your spam folder.` (lowercase initial)
- CTA: `Back to Login`

## Design tokens referenced

- `--background/neutral/subtlest` → `#ffffff`
- `--background/neutral/base` → `#1d1f23` (CTA)
- `--color/neutral/100-#f2f4f7` → `#f2f4f7` (email readout bg)
- `--text/neutral/base` → `#1d1f23`
- `--text/neutral/subtle_100` → `#40444d`
- `--text/primary/base` → `#f2efec`
- `--body` → `24px`
- `--dimension/4---0_25-rem` → `4px`
- Typography tokens: `Text-md (l-24)/Semibold`, `Text-md (l-24)/Regular`, `Text-md (l-24)/Medium`

## Notes / gotchas

- **Special Attention #2 resolved**: The CTA is **"Back to Login"** — NOT "Open mail app". Figma is the source of truth, so go with `Back to Login`. If Linear AC mentions "Open mail app" as an alternative, escalate to PM Viet to reconcile (one option: add a secondary text link "Open mail app" below the primary CTA in a future revision, but it's NOT in this Figma).
- The destination email is shown in a text-field-styled container — it's NOT an input. Implementation must render this as a static styled box, not a real `<TextInput>`, to prevent focus/keyboard appearing.
- Two copy quirks to flag for QA before merge: (a) double space `"We've sent  a"`, (b) lowercase `"if you don't see"`.
- Subhead heading text "Reset your password" is **identical** to Screen 10 and Screen 12 — confirms a 3-screen reset funnel with consistent header.
- CTA variant differs from Screen 10: this is the **no-icon** primary button (component `470:2206`), Screen 10's is the **with-icon** primary button (component `470:2264`).
