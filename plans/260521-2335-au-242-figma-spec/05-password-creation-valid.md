# Screen: Password creation — valid state

**Node**: `2849:10379`
**Dimensions**: 414×896 (iPhone canvas, frame rounded 18px)
**Purpose**: User has typed a password that passes all criteria — checklist is satisfied, password text shown in field, submit chevron should be enabled.
**Maps to AC scenario**: "User creates password → all 3 criteria pass → submit chevron enabled → advance to verify-email step"

## Layout
Identical to `04-password-creation-typing.md`. See that file for container/header/keyboard layout details. Only the diffs are listed below.

## Header / Top bar
Same as typing state. Back chevron + empty feedback slot.

## Body sections (top-to-bottom)

### 1. Label "What is your email"
Identical to typing state (same text, same Inter SemiBold 16/24, same `text/neutral/base` color).

### 2. Email field (filled / read-only)
Identical to typing state.
- Value: "donut@macgie.com"
- Filled bg `#f2f4f7`, no border, color `--text/neutral/subtle_100` (`#40444d`)

### 3. Password input row — **VALID FILLED STATE** (diff vs typing)
- Same container, border `1px solid --border/neutral/bold_200` (`#7a7f89`)
- Trailing eye icon, trailing submit chevron — unchanged
- **Diff**: Value text **shown literally** as "Qeb3#vnbb" (sample valid password)
  - Style: `static/body-large` — Poppins Regular 16/24
  - Color: **`--text/neutral/base` (`#1d1f23`)** (vs `subtle_200` placeholder in typing state)
  - Note: shown in **plaintext** in Figma because eye toggle is "open" (visible). The default real-world state would mask with bullets — only show plaintext when user taps eye to reveal.

### 4. Password criteria checklist — **ALL VALID STATE** (diff vs typing)
- Same 3 rows, same layout (gap 8px, w=327, per-row gap 10)
- **Diff**: text color of each row label is now `--text/neutral/subtle_100` (`#40444d`) instead of `subtle_200` (`#7a7f89`)
  - i.e. darker gray to indicate "satisfied"
  - **Status icons in Figma still reference the same `imgFrame2114` asset URL** as the typing state — but visually these should be filled/check variants. Either the asset URL changes server-side or the implementation must swap the icon source based on validation result. Treat as **check / filled bullet** when criterion met.
- Rows are still in the same order: "At least 8 characters", "Contains a lowercase letter", "Contains a number"

## Interactive elements
Same as typing state, with these changes:
- **Submit chevron**: state = **Enable** (all criteria met) → tap = submit → advance to Verify Email screen (`2849:10276`)
- **Eye toggle**: shown in **open / visible** state in this frame (password rendered plaintext); tap toggles back to masked

## Text content (verbatim)
- Section label: "What is your email"
- Email value: "donut@macgie.com"
- Password value (shown when eye open): "Qeb3#vnbb"
- Criteria 1: "At least 8 characters"
- Criteria 2: "Contains a lowercase letter"
- Criteria 3: "Contains a number"

## Design tokens referenced
Same as typing state, plus the diff that criteria text uses `--text/neutral/subtle_100` (`#40444d`) instead of `subtle_200` (`#7a7f89`). Password value uses `--text/neutral/base` (`#1d1f23`) instead of `subtle_200`.

## Diff summary vs `04-password-creation-typing.md`
| Element | Typing state (04) | Valid state (05) |
|---|---|---|
| Password value | placeholder "create a password" / color `subtle_200` | actual value "Qeb3#vnbb" / color `--text/neutral/base` |
| Eye toggle | closed (masked) | open (visible) |
| Criteria text color | `subtle_200` (gray) | `subtle_100` (darker gray) |
| Criteria icon | hollow bullet (`imgFrame2114`) | should be check (asset URL is same in Figma data — implementation must swap) |
| Submit chevron enablement | disabled (per AC) | enabled |

## Notes / gotchas
- **Critical**: Figma uses the same image asset name (`imgFrame2114`) for both pending and valid bullet icons. This is a Figma export artifact — in the actual Figma layers Viet most likely uses two different vector states. Confirm with Viet whether (a) the icon truly stays a hollow bullet and only the text color signals success, or (b) the bullet swaps to a check mark in the satisfied state. Implementation should default to (b) — swap to a check icon when criterion passes — but match design after confirmation.
- The "success" text color in this frame is `subtle_100` (darker gray) — not a typical green. This is intentional minimalist styling; do not introduce green tokens unless designer confirms.
- The "What is your email" label being reused on this screen is the same Figma quirk as in 04. Treat it as a single shared section label across email + password screens, but flag the mismatch for Viet.
- Password value "Qeb3#vnbb" is a sample — but note it contains a `#` (special character) and an uppercase `Q`, even though the criteria checklist only requires 8 chars + lowercase + number. So the password "Qeb3#vnbb" satisfies all visible criteria. Don't add hidden rules.
- The submit chevron in this frame is visually identical to the typing-state chevron — the **enabled/disabled** distinction is **not encoded** in the Figma asset. Implementation must drive enablement off the validation state, not the visual asset.
- Frame is `pass creation success` in Figma — designer's name for the valid/filled state, not a separate "success confirmation" screen.
