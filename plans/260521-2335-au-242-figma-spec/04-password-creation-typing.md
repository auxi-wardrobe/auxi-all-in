# Screen: Password creation — typing state

**Node**: `2849:10296`
**Dimensions**: 414×896 (iPhone canvas, frame rounded 18px)
**Purpose**: After confirming email, new user creates a password. This frame shows the **typing** state — password field is focused but empty/incomplete; criteria checks shown as inactive bullets.
**Maps to AC scenario**: "User creates password → sees real-time validation criteria → button enabled when all met"

## Layout
- Container: 414×896 frame; background `--background/neutral/subtlest` (`white`)
- Body: bottom-anchored flex column, pt-112, pb-12, px-24 (`--body`), gap 0
- Inner card width 360px, vertically stacked
- Keyboard art at bottom (320.16px) — same as email screen, ignore for RN
- Frame radius 16/18px

## Header / Top bar
- Same as email screen: height 107px, back chevron at top-left (45×45, asset `imgBack1`), empty 47×47 feedback slot top-right, no title

## Body sections (top-to-bottom)

### 1. Label "What is your email"
- Same as email screen label
- Text: "What is your email"
- Style ref: `Text-md (l-24)/Semibold` — Inter SemiBold 16/24
- Color: `--text/neutral/base` (`#1d1f23`)
- Width: full (360)

### 2. Email field (filled / read-only style)
- Component: M3 TextField but in disabled-looking state
- Container: h=56, rounded 8px, **no border**, **filled background** `--color/neutral/100-#f2f4f7` (`#f2f4f7`)
- Padding `px-16, py-4`
- Value text: "donut@macgie.com"
  - Style: `static/body-large` — Poppins Regular 16/24
  - Color: `--text/neutral/subtle_100` (`#40444d`) (slightly darker than placeholder, indicates filled-but-locked)
- No placeholder, no trailing icon, no inline submit chevron
- Width: full (360), text width auto (41px in frame, but should flex)
- State = **filled / read-only** (user already entered this in previous step; not editable here visually — though tapping back goes to email screen)

### 3. Password input row (active typing state)
- Row layout: horizontal flex, gap 16px, items-center, full-width
- **Text field — password input** (state = **focused / empty / typing**)
  - Container: h=56, rounded 8px
  - Border: `1px solid --border/neutral/bold_200` (`#7a7f89`)
  - Inner state-layer padding `pl-16, py-4`, gap 4px (because of trailing icon)
  - Content area: h=48px, vertically centered
  - Placeholder text:
    - "create a password"
    - Style: `static/body-large` — Poppins Regular 16/24
    - Color: `--text/neutral/subtle_200` (`#7a7f89`)
  - **Trailing icon**: eye-toggle (show/hide password)
    - 48×48 hit area, inner 40×40 circular state-layer, 24px icon (`imgGroup` — eye SVG)
    - Default state = closed-eye (password hidden); tap toggles to reveal
- **Submit chevron** to the right of input (same as email screen): 56×57, rotated 180°, asset `imgBack`
  - Tap = submit password → next step (verify email)
  - **In typing state** the chevron is presumably disabled or low-emphasis (criteria not yet met) — though Figma doesn't visually distinguish here. Implementation should disable until criteria pass.

### 4. Password criteria checklist (inactive / pending state)
- Container: vertical flex, width 327px, gap 8px
- Each row: horizontal flex, gap 10px, items-center, justify-center, full-width
- Per-row layout: 12×12 status icon + text label (flex-1)

Three rows, all in **pending / unfilled** state in this frame:
- Row 1: bullet icon (`imgFrame2114` — empty circle / hollow dot) + "At least 8 characters"
- Row 2: same icon + "Contains a lowercase letter"
- Row 3: same icon + "Contains a number"

Text style: `Text-xs/Regular` — Inter Regular 12px lineHeight 16px weight 400
Color: `--text/neutral/subtle_200` (`#7a7f89`) — **muted gray, indicates criteria not yet met**

## Interactive elements
- **Header back**: pop to email screen (`2849:10143`)
- **Email field**: tap → behavior TBD (probably no-op; user must use back to edit email)
- **Password TextField**: state = focused/empty in this frame; transitions to "filled with value" as user types; criteria icons flip from hollow → check as conditions pass (see screen `2849:10379` for valid state)
- **Eye toggle** (trailing icon on password field): state default = hidden; tap toggles password visibility
- **Submit chevron**: state default in this frame = enabled-looking but per AC should be **disabled until all 3 criteria pass**

## Text content (verbatim)
- Section label: "What is your email"
- Email value (read-only): "donut@macgie.com"
- Password placeholder: "create a password"
- Criteria 1: "At least 8 characters"
- Criteria 2: "Contains a lowercase letter"
- Criteria 3: "Contains a number"

## Design tokens referenced
- Colors: `--background/neutral/subtlest` (`white`), `--color/neutral/100-#f2f4f7` (`#f2f4f7`), `--text/neutral/base` (`#1d1f23`), `--text/neutral/subtle_100` (`#40444d`), `--text/neutral/subtle_200` (`#7a7f89`), `--border/neutral/bold_200` (`#7a7f89`), `--white` (`white`)
- Typography: `Text-md (l-24)/Semibold` (Inter SemiBold 16/24), `Text-md (l-24)/Regular` (Poppins Regular 16/24 — for password placeholder), `Text-xs/Regular` (Inter Regular 12/16), `static/body-large` (Poppins Regular 16/24)
- Spacing: `--body` (24px), `--s` (0px), `--line-height/none` (0px)
- Dimensions: input 56/48, criteria icon 12, eye icon 24, eye state-layer 40, eye hit-area 48
- Radius: 8px (text fields), 100px (eye state-layer pill), 16/18px (frame)

## Notes / gotchas
- This frame is the **typing / empty / pending-criteria** state. Compare against `2849:10379` (valid state) — diff is:
  - Criteria icons: hollow → checked
  - Criteria text color: `subtle_200` (gray) → `subtle_100` (darker gray, but NOT green/success — odd choice, may be a Figma oversight or intentional minimal style)
  - Password value: empty placeholder → filled "Qeb3#vnbb" (sample masked value)
  - All three criteria text colors shift in the valid state (see notes in 05)
- The "What is your email" label is reused literally on the password screen — confirmed in Figma. This appears to be **a mistake or placeholder in the Figma source** (the label should probably read "Create a password" or similar on this screen). Flag to Viet before implementing — implement what's specified but call this out.
- Criteria checklist is exactly 3 items: 8 chars, lowercase, number. **AC may require additional rules** (uppercase, special char) — check AU-242 server-side validation and align.
- Password field is the only field where the trailing icon is the eye toggle; the submit chevron lives **outside** the text field as a sibling. Don't try to put both inside the text field's trailing slot.
- Criteria icon `imgFrame2114` is reused for all 3 rows in the pending state — same hollow-bullet asset. In the valid state (next frame), all three use the same asset too — meaning the "check vs hollow" diff is encoded only in the asset URL between frames. We'll need to verify whether the check-state asset is a different SVG (likely yes — see 05).
- Read-only filled email uses `text/neutral/subtle_100` (`#40444d`) — not the same as the empty placeholder color (`#7a7f89`). Two distinct shades of gray to convey "filled but locked" vs "empty placeholder".
- The submit chevron's enabled/disabled state isn't visually distinct in this frame — implement defensively: disable until all criteria met.
