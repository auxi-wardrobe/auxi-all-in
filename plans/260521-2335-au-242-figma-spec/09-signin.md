# Screen: Sign-in (returning user, "welcomeback")

**Node**: `2849:10462`
**Dimensions**: 414×896 (iPhone Plus / 8 Plus frame, design canvas)
**Purpose**: Returning user enters password against a pre-filled (locked) email to sign in.
**Maps to AC scenario**: AU-242 — "Returning user sign-in: app shows the email already on record (read-only), prompts only for password; provides Forgot password? link and submit affordance."

## Layout

- **Container**: `bg: var(--background/neutral/subtlest, white)`, `border-radius: 18px`, `overflow: clip`, full-frame 414×896
- **Status bar / Safe area**: implied by 112px top padding (`pt-[112px]`) on the body wrapper
- **Body wrapper** (`2849:10463`): vertical flex, items-center, `pb: 12px`, `pt: 112px`, `px: 24px` (= `var(--body)`), absolute bottom anchored, height 896, width 414
- **Header overlay** (`2849:10490`): absolute top, height 107px, full width — contains back button + feedback slot
- **Keyboard overlay** (`2849:10491`): absolute bottom — iOS alphabetic keyboard (decoration only; mock of system keyboard, NOT to be implemented as a real component)

## Header / Top bar

- Presence: **yes** — absolute top 107px container
- **Back** icon: 45×45, positioned in `Top bar` slot at left (inside `370px` row, centered horizontally on screen)
- **Trailing slot** (`feedback`, `I2849:10490;1688:13461`): 47×47 empty placeholder on the right
- No title text in header

## Body sections (top-to-bottom)

### 1. Section heading "Enter password to signin"
- Component: plain `<Text>`
- Text verbatim: `Enter password to signin`
- Style ref: `Text-md (l-24)/Semibold` → font-family `var(--font-family/body)` (Inter Semi Bold), weight 600, size 16, line-height 24, color `var(--text/neutral/base, #1d1f23)`
- Width: 360 (matches inner list container)
- Spacing: 12px top/bottom (body py), 16px gap to next item

### 2. Email field (read-only / pre-filled, disabled visual)
- Component: M3 Text field — filled variant, **read-only / disabled** state
  - data-node-id: `2849:10468` (outer), instance ref `1752:24683`
- Container: height 56, `border-radius: 8px`, `bg: var(--color/neutral/100-#f2f4f7, #f2f4f7)` (filled, no border)
- Inner state-layer: `padding: 4px 16px`, content centered vertically, no trailing icon
- Text verbatim (label / display value): `donut@macgie.com`
- Display style: `static/body-large` → Poppins Regular 16/24, color `var(--text/neutral/subtle_100, #40444d)` (subtle = visually disabled)
- Spacing: 16px gap below to next row

### 3. Password field + adjacent Back button (row)
Row container: `flex gap-16 items-center` — width 360.
- **Password field** (`2849:10476`, instance `1752:24683`)
  - Container: height 56, flex 1, `border-radius: 8px`, **border `1px solid var(--border/neutral/bold_200, #7a7f89)`** (outlined variant)
  - State-layer: `pl: 16, py: 4`
  - Display value verbatim: `Qeb3#vnbb` (masked-style sample; actual implementation should mask with dots/asterisks)
  - Style: `static/body-large` Poppins Regular 16/24, color `var(--text/neutral/base, #1d1f23)`
  - **Trailing icon**: 48×48 slot, icon 24×24 — eye toggle (show/hide password); asset `imgGroup`
- **Back button** at end of row (`2849:10483` / `2849:10484`): 56×57 icon, **rotated 180°** → this is actually a **forward / submit arrow** ("Continue / Sign in" action) styled as a circular icon button. Component ref: `Type=Round, Size=Small, Width=Default, State=Enabled` (`348:16292`).
  - **Critical**: NOT a back button despite the asset name — its 180° rotation + position next to password field + AC context means it's the submit affordance.

### 4. "Forgot your password?" link
- Container (`2849:10487`): width **327** (narrower than fields — centered text block)
- Component: plain text link
- Text verbatim: `Forgot your password?`
- Style ref: `Text-xs/Regular` → Inter Regular 12/16, color `var(--text/info/base, #1465b4)` (info-blue link)
- Alignment: `text-center`, full-width within 327 block
- **Position**: BELOW the password field row (after the 16px gap inside body) — answers Special Attention #1.
- No underline in spec — color alone signals link.

### 5. Keyboard (decorative)
- Alphabetic iOS keyboard mock at bottom 414×320.16 (`2849:10493`)
- Not implementation scope — RN uses real `TextInput` keyboard.

## Interactive elements

| Element | States | Action per AC |
|---|---|---|
| Email field | read-only / disabled | non-editable; reflects prefilled email from prior step |
| Password field | empty, focused, filled, error, password-visible-toggle | secureTextEntry by default; eye icon toggles visibility |
| Eye icon (trailing) | hide (default), show | toggles `secureTextEntry` |
| Submit arrow (circular, right of password) | enabled (when password non-empty), disabled, loading | submits credentials → on success navigate to authenticated home; on failure show inline error under password field |
| "Forgot your password?" link | enabled, pressed | navigates to Forgot password — request email screen (Screen 10, node 2849:10535) |
| Header back | enabled | pops navigation (returns to email entry / welcome screen) |

## Text content (verbatim)

- Heading: `Enter password to signin`
- Email value (sample): `donut@macgie.com`
- Password value (sample): `Qeb3#vnbb`
- Link: `Forgot your password?`
- No error text in this static design — AC implies inline error on wrong password (text TBD by content owner)
- No submit button label — submit is an icon-only circular button

## Design tokens referenced

- `--background/neutral/subtlest` → `#ffffff`
- `--color/neutral/100-#f2f4f7` → `#f2f4f7` (filled field background)
- `--border/neutral/bold_200` → `#7a7f89` (outlined field border)
- `--text/neutral/base` → `#1d1f23` (primary text)
- `--text/neutral/subtle_100` → `#40444d` (read-only/subtle text)
- `--text/info/base` → `#1465b4` (link)
- `--body` → `24px` (horizontal padding)
- Typography tokens: `Text-md (l-24)/Semibold`, `static/body-large`, `Text-xs/Regular`
- Font families: `font-family/body` (Inter for headings/Semibold) and Poppins (Regular for input text + UI body)

## Notes / gotchas

- **The "back" asset rotated 180° next to password is the submit/continue button** — engineering should NOT render two back arrows. Use a forward chevron / arrow icon for the M3 Round Small icon button.
- Email field is the **filled** M3 variant (gray bg, no border) = disabled visual; password field is the **outlined** variant (border, transparent bg) = enabled.
- Forgot password link sits BELOW the password row, NOT inline-right of the field. It is centered, width 327. (Confirms Special Attention #1.)
- Keyboard graphic is decoration only — don't implement.
- Designer mixes Inter (heading) + Poppins (body) — repo `auxi/src/theme` likely already has these family tokens; verify before implementing.
- No "Sign in" text CTA exists — the submit is icon-only.
