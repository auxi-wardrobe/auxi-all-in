# Screen: Reset password — set new password

**Node**: `2849:10570`
**Dimensions**: 414×896
**Purpose**: After clicking the email reset link, user lands here to set a new password with live validation against three rules.
**Maps to AC scenario**: AU-242 — "User opens reset link, enters new password meeting strength requirements, and submits to complete the reset."

## Layout

- **Container**: `bg: var(--background/neutral/subtlest, white)`, `border-radius: 18px`, full-frame 414×896
- **Body wrapper** (`2849:10571`): vertical flex, items-center, `pt: 112px`, `pb: 12px`, `px: 24px`, width 414, height 896
- **Header overlay** (`2849:10604`): absolute top, height 107px
- **Keyboard overlay** (`2849:10605`): absolute bottom, full alphabetic iOS keyboard mock (height ≈ 320px) — decorative
- **No primary CTA visible** in the static frame — submit is the inline circular icon button next to the password field (same pattern as Screen 9)

## Header / Top bar

- Presence: **yes** — back at left (45×45)
- Trailing slot: empty 47×47 placeholder (`feedback`)
- No title text

## Body sections (top-to-bottom)

### 1. Heading + subhead block (`2849:10574`)
- Layout: `flex-col gap-4`, full width (360 inner)
- **Heading** (`2849:10575`): verbatim `Reset your password`
  - Style: `Text-md (l-24)/Semibold` — Inter Semi Bold 16/24, color `#1d1f23`
- **Supporting text** (`2849:10576`): verbatim `Set your new password below`
  - Style: `Text-md (l-24)/Regular` — Poppins Regular 16/24, color `#1d1f23`

### 2. New-password field + adjacent submit icon button (row)
Row container (`2849:10579`): `flex gap-16 items-center`, width 360.
- **Password field** (`2849:10580`, instance `1752:24683`)
  - Container: height 56, flex 1, `border-radius: 8px`, **border `1px solid var(--border/neutral/bold_200, #7a7f89)`** (outlined variant)
  - State-layer: `pl: 16, py: 4, gap: 4` between text + trailing icon
  - Display value verbatim: `Qeb3#vnbb` (sample)
  - Text style: `static/body-large` Poppins Regular 16/24, color `var(--text/neutral/base, #1d1f23)`
  - **Trailing icon**: 48×48 slot, 24×24 eye icon (toggle visibility) — asset `imgGroup` (identical to Screen 9 eye toggle)
- **Submit icon button** at end of row (`2849:10587`/`2849:10588`): 56×57 icon, **rotated 180°** (M3 Round Small `348:16292`) — same forward-arrow submit pattern as Screen 9.

### 3. Password requirements checklist (`2849:10591`)
- Container: `flex-col gap-8`, width **327** (narrower than the field row, NOT 360)
- Three checklist rows, each `flex gap-10 items-center justify-center` (text + icon centered horizontally within the 327 block)

| # | Icon | Text verbatim | Node |
|---|------|--------------|------|
| 1 | 12×12 bullet/check (`imgFrame2114`) | `At least 8 characters` | `2849:10592` |
| 2 | 12×12 bullet/check (`imgFrame2114`) | `Contains a lowercase letter` | `2849:10596` |
| 3 | 12×12 bullet/check (`imgFrame2114`) | `Contains a number` | `2849:10600` |

- Text style for all 3: `Text-xs/Regular` — Inter Regular 12/16, color `var(--text/neutral/subtle_100, #40444d)`
- All three icons reuse the same `imgFrame2114` asset → in the static frame they appear identical (single state); at runtime the icon must swap to indicate pass/fail (e.g. empty circle → checkmark green).

### 4. Keyboard (decorative)
- Full iOS alphabetic keyboard at bottom (`2849:10607`), 414×320.16 — same mock as Screen 9.
- Implementation: don't render; rely on system keyboard.

## Interactive elements

| Element | States | Action per AC |
|---|---|---|
| Password field | empty / focused / valid (all 3 rules pass) / invalid (any rule fails) / visible / hidden | secureTextEntry by default; eye icon toggles |
| Eye icon (trailing) | hide / show | toggles password visibility |
| Submit icon button (right of field) | disabled (until all 3 rules pass), enabled, pressed, loading | submits new password → on success navigate to authenticated home OR sign-in confirmation; on failure show inline error |
| Requirements checklist | pending (gray bullet) / met (green check) per item, live-updated as user types | visual reinforcement; not interactive itself |
| Header back | enabled | navigate back (Screen 11 if reached from in-app flow, or exit reset flow if deep-linked from email) |

## Text content (verbatim)

- Heading: `Reset your password`
- Subhead: `Set your new password below`
- Password sample: `Qeb3#vnbb`
- Rule 1: `At least 8 characters`
- Rule 2: `Contains a lowercase letter`
- Rule 3: `Contains a number`

## Design tokens referenced

- `--background/neutral/subtlest` → `#ffffff`
- `--border/neutral/bold_200` → `#7a7f89` (outlined field border)
- `--text/neutral/base` → `#1d1f23`
- `--text/neutral/subtle_100` → `#40444d` (checklist text)
- `--body` → `24px`
- `--dimension/4---0_25-rem` → `4px`
- Typography tokens: `Text-md (l-24)/Semibold`, `Text-md (l-24)/Regular`, `Text-xs/Regular`, `static/body-large`

## Notes / gotchas

- **Special Attention #3 resolved**: Password requirements list has **3 rules** here. Compared to a typical signup screen (likely also Inter Regular 12/16, same subtle color), the rules text **must be confirmed against the signup spec**:
  - This screen lists: 8 chars + lowercase + number.
  - **Common signup variants** add: uppercase, special character. If signup demands uppercase / special-char, this reset screen is MORE PERMISSIVE than signup, which is a security regression.
  - **Action**: cross-reference Screen 08 (signup) spec — if rule list differs, raise with Viet to align (either tighten reset to match signup, or loosen signup to match reset).
- No uppercase / no special-character / no "matches confirm-password" rule shown — implementation should NOT silently add rules.
- No "Confirm password" field — single password input. If product wants double-entry confirmation, that's a separate ask.
- Submit pattern matches Screen 9 exactly (round icon button rotated 180° next to field) — reuse the same component.
- Requirements checklist sits at width 327 (NOT 360) — slightly inset from the field row. This is intentional centering.
- Checklist icon is a single asset for all 3 in the static frame — at runtime each row's icon must reflect that row's individual pass/fail state, independent of the others.
