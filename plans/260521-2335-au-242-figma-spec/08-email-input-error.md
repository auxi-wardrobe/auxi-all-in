# Screen: Email Input — Error State

**Node**: `2849:10205`
**Dimensions**: 414×896
**Purpose**: Email input screen showing inline validation error when the user submits / blurs with an invalid email format. Keyboard remains visible.
**Maps to AC scenario**: AU-242 — "Given the user types an invalid email format, when they attempt to continue, then the field must display an inline error message and the submit affordance must remain in an actionable but error-flagged state until the email is valid."

## Layout
- Container: column auto-layout, `padding: 112px 24px 12px 24px`, gap = 0 (`--line-heigh/none`), centered items, anchored to bottom, full screen 414×896, `borderRadius: 16px`.
- Inner stack (`2849:10207`): width `360px`, column, gap = 0 (z-stacked), items-center, justify-center.
- Body block (`2849:10208`): full width, column, gap = `16px`, paddingY = `12px`.
- Form row (`2849:10210`): row, gap = `16px`, items-center, full width — holds [text field] + [continue arrow button].
- Background: `--background/neutral/subtlest` (`#FFFFFF`).
- Status bar / Safe area: header zone reserves top `112px`. Keyboard occupies bottom region — leaves visible body height ≈ 449px (896 − 107 − 320 − safe paddings).

## Header / Top bar
- Top bar absolute, `height: 107px`, full width `414px`, top = 0.
- Inner row: `width: 370px`, centered, top = 45px, `justify-between`.
- Leading: **Back** icon button `45×45` (asset `imgBack1`). Action: `pop()` to previous step.
- Trailing: **feedback** slot `47×47` (empty placeholder).
- **No title text on this screen** — body headline carries the question.

## Body sections (top-to-bottom)

### 1. Headline — "What is your email"
- Component: text node (`2849:10209`).
- Text: "What is your email"
- Style ref: `Text-md (l-24)/Semibold` — Inter Semi Bold 600 / 16px / lineHeight 24px.
- Color: `--text/neutral/base` (`#1D1F23`).
- Width: full (360px), left-aligned.

### 2. Form row — Text field + Continue arrow
- Wrapper: row, gap 16px, items-center.

  #### 2a. Text field (M3 Outlined, error variant)
  - Component: `Text field` (node `1752:24683`) — M3 outlined text field.
  - Outer frame: flex-1, height 56px, `borderRadius: 8px` (top corners `4px` inside via state layer), border `1px solid --border/neutral/bold_200` (`#7A7F89`).
  - State-layer: `padding: 4px 0 4px 16px`, height 56px.
  - Content: column, justify-center, height 48px, paddingY 4px.
  - **Label / placeholder text**: "youremail@mail.com"
    - Style ref: `M3 static/body-large` — Poppins Regular 400 / 16px / lineHeight 24px / tracking 0px.
    - Color: `--text/neutral/subtle_200` (`#7A7F89`) — this is placeholder grey, indicating field is **empty**, error triggered on blur/submit with empty or malformed value.
  - **Supporting text** (error) — absolute, bottom `-20px`, height 20px, paddingX `16px`, paddingTop `4px`:
    - Text: "Please enter a valid email adress" *(sic — "adress" is the verbatim Figma typo, see notes)*
    - Style ref: `M3 body/small` — Roboto Regular 400 / 12px / lineHeight 16px / tracking 0.4px.
    - Color: `--text/danger/base` (`#BB251A`).
    - fontVariationSettings: `'wdth' 100`.

  #### 2b. Continue arrow button
  - Component: rotated-180 "Top bar" `Back` asset reused (`imgBack`) — visually it's a right-arrow (back glyph flipped) inside a `57×56` frame.
  - Asset: `imgBack` placed inside a 56×57 box, wrapped in `rotate-180`. This is the "submit / continue" affordance.
  - State: enabled in this frame (no separate disabled treatment shown). Stays tappable in error state so user can retry after edit.
  - Action: tap → re-validate email. If still invalid → keep error visible (no-op visually). If valid → advance to next UAC step.

### 3. Keyboard (iOS alphabetic, shift-active)
- Component: `AlphabeticKeyboard` mock, absolute bottom = -0.16px, width 414px, height ≈ 320.16px, background `#D1D3D9` with `backdrop-blur 60.02px`.
- Layout: 3 letter rows (QWERTY) at the top, then bottom row `[123] [space] [return]`, then emoji + dictation icons row, then iOS Home Indicator (5.52px tall pill).
- Shift key is in the **active** (filled) state (asset `imgShiftActive`) — capital letters showing.
- This is a design mock of the native iOS keyboard; do **not** implement it in RN. Use the OS keyboard via `TextInput` with `keyboardType="email-address"` and `autoCapitalize="none"`.

## Interactive elements
- **Back button** (top-left, header): state default. Action = `navigation.goBack()`.
- **Text field**: state = error (border may shift to danger color in normalized M3 variants, but this Figma frame keeps the neutral bold border + danger-colored supporting text). Behavior:
  - On focus: keyboard opens, label may animate up (per project's existing TextField behavior).
  - On blur with invalid value: show error supporting text.
  - On change: clear error if pattern becomes valid; show error if still invalid (debounce per existing pattern).
- **Continue arrow** (right of field): state default (enabled). Action = submit/validate. Disabled state not shown in this frame — implementation must add a disabled visual when field is empty (escalate to Viet if unclear).
- **Keyboard**: native; not part of the React Native code.

## Text content (verbatim)
- Headline: `What is your email`
- Placeholder: `youremail@mail.com`
- Error: `Please enter a valid email adress`
- No CTA label text (arrow button is icon-only).
- No helper / link text.

## Design tokens referenced
- Color
  - `--background/neutral/subtlest` → `#FFFFFF`
  - `--text/neutral/base` → `#1D1F23`
  - `--text/neutral/subtle_200` → `#7A7F89` (placeholder)
  - `--text/danger/base` → `#BB251A` (error supporting)
  - `--border/neutral/bold_200` → `#7A7F89` (field border, neutral — see note on M3 error border)
  - `--white` → `#FFFFFF` (keyboard frame)
  - System Background Light / Primary `#FFFFFF`
  - Label Color Light / Primary `#000000` (keyboard glyphs)
- Typography
  - `Text-md (l-24)/Semibold` — Inter Semi Bold 600 / 16px / 24px (headline)
  - `static/body-large` — Poppins Regular 400 / 16px / 24px (field placeholder)
  - `M3 body/small` — Roboto Regular 400 / 12px / 16px / tracking 0.4px (error supporting)
- Spacing
  - `--body` = 24px (horizontal padding)
  - Body paddingY = 12px, gap = 16px
  - Field paddingLeft = 16px, paddingY = 4px (state layer)
  - Supporting text offset bottom = -20px, paddingX = 16px, paddingTop = 4px
  - Form row gap = 16px
- Radii
  - Screen card: 18px
  - Text field: 8px (rounded corners 4px on top via state-layer)
  - Keyboard keys: 4.6px
- Components
  - `Text field` (node `1752:24683`) — M3 outlined text field
  - `HomeIndicator` (node `345:15612`) — iOS home indicator (visual mock only)

## Notes / gotchas
- **TYPO IN FIGMA**: "Please enter a valid email **adress**" — missing the second `d`. Verbatim source. Open question for Viet: ship as-is, or correct to "address"? Flag in the file's open-questions section; do **not** silently fix.
- **Border color in error state stays neutral grey** (`#7A7F89`) in this Figma frame, not the danger red. M3 standard is to switch the outline to error color too. Two options when implementing:
  1. Follow Figma verbatim (neutral border + red supporting text only).
  2. Apply the M3 norm (red border + red supporting text).
  Default to (1) — match Figma — but call out in PR for Viet to ack.
- **Continue arrow is a rotated back-icon asset, not a dedicated forward icon**. In RN, prefer a proper right-arrow icon from the existing icon set instead of a rotated import — preserves semantic correctness and avoids odd asset reuse. Confirm with Viet that the right-arrow glyph matches.
- **Disabled state for the arrow is not in this frame** — if the email field is empty on first render, decide whether the arrow is disabled or shows the same error. Likely disabled; check sibling email-input "empty" frame in the file (not in this batch).
- **Keyboard frame is a mock** — do not port. Use RN `TextInput` props: `keyboardType="email-address"`, `autoCapitalize="none"`, `autoCorrect={false}`, `textContentType="emailAddress"`.
- **Roboto for error text** is the M3 default static body-small. Project may already substitute Poppins/Inter; verify the supporting-text style in the design system before importing Roboto.
- **Tap targets**: field is 56px tall (good); arrow button 57×56 (good). Back button is 45×45 — same caveat as other UAC screens (use hitSlop for 48dp+).
- **Validation regex**: project should reuse existing email validator (likely in `auxi/src/utils/validation.ts` or similar); don't introduce a new regex here.
