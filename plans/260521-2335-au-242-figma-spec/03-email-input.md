# Screen: Email input

**Node**: `2849:10143`
**Dimensions**: 414×896 (iPhone canvas, frame rounded 18px)
**Purpose**: User enters their email to begin sign-up / sign-in via the email path (after tapping "Continue with Email" on Welcome).
**Maps to AC scenario**: "User chose email path → enters email → proceeds to password creation (new user) or password sign-in (existing user)"

## Layout
- Container: 414×896 frame; background `--background/neutral/subtlest` (`white`)
- Body region: bottom-anchored flex column, top-padding 112px, bottom-padding 12px, horizontal-padding `--body` (24px), gap 0
- Body wraps a 360px-wide `List Item: 0 Density` content card
- The on-screen iOS software keyboard (320.16px tall, gray `#d1d3d9` with blur 60px) is rendered inside the frame at the bottom — in RN this is the actual keyboard, not a drawn asset; ignore the keyboard art for implementation but respect the 320px reserved space when picking input position
- Frame radius: 16/18px

## Header / Top bar
- Height 107px, full-width (414px)
- Contents at y=45px: a 370px-wide inner row, justify-between, vertical-center
  - Leading: back chevron icon (asset `imgBack1`), 45×45 hit area
  - Trailing: 47×47 "feedback" slot (empty in frame — likely an "?" / support icon placeholder)
- No title text in header
- System status bar overlaps the top 45px

## Body sections (top-to-bottom)

### 1. Label "What is your email"
- Component: section title text
- Text: "What is your email"
- Style ref: `Text-md (l-24)/Semibold` — Inter SemiBold, 16px, lineHeight 24px, weight 600
- Color: `--text/neutral/base` (`#1d1f23`)
- Width: 360px (full content), left-aligned within the centered card
- Spacing: container `py-12` (12px vertical), then 16px gap to input row

### 2. Email input row (textfield + secondary back/affordance)
- Row layout: horizontal flex, gap 16px, items-center, full-width
- **Text field** (M3 Text field, node id ref `1752:24683`)
  - Container: h=56px, flex-1, rounded `4px` top corners on outer wrapper but inner box rounded `8px`
  - Border: `1px solid --border/neutral/bold_200` (`#7a7f89`)
  - Inner state-layer padding: `pl-16, py-4` (top-left rounded 4/4)
  - Content area: h=48px, vertically centered
  - Placeholder text (label-text container):
    - "youremail@mail.com"
    - Style: `static/body-large` — Poppins Regular, 16px, lineHeight 24px, letterSpacing 0
    - Color: `--text/neutral/subtle_200` (`#7a7f89`)
  - State in this frame = **Empty / Idle** (border visible, no value yet, no error)
- **Back / submit chevron asset `imgBack`** — 56×57 box, rotated 180° (so chevron points right → acts as "next/submit" arrow)
  - This is the inline submit affordance for the email row (NOT the header back). Tap = advance to password creation.
  - Convert in RN to a circular icon button to the right of the input.

## Interactive elements
- **Header back button** (top-left chevron): state default = Enable; action = pop to Welcome (`2849:10085`)
- **Email TextField**: state default = empty (idle); becomes filled-with-value when user types; error state shown if backend returns invalid email per AC
- **Inline submit chevron** (right of input): state default = Enable; action = submit email → backend check → navigate to password screen
- **Feedback slot** (top-right, empty in frame): TBD — if present in AC, it's a support/help link

## Text content (verbatim)
- Section label: "What is your email"
- Placeholder: "youremail@mail.com"
- (No CTA button label — submit is the inline chevron)
- (No supporting text or error text shown in idle state)

## Design tokens referenced
- Colors: `--background/neutral/subtlest` (`white`), `--text/neutral/base` (`#1d1f23`), `--text/neutral/subtle_200` (`#7a7f89`), `--border/neutral/bold_200` (`#7a7f89`), `--white` (`white`)
- Typography: `Text-md (l-24)/Semibold` (Inter SemiBold 16/24), `static/body-large` (Poppins Regular 16/24)
- Spacing: `--body` (24px), `--s` (0px), `--line-height/none` (0px)
- Dimensions: container width 360 / 414, input height 56, content height 48, header height 107, keyboard region 320.16
- Radius: 8px (input box), 4px (top corners of input wrapper), 16/18px (frame)

## Notes / gotchas
- The chevron asset on the input row is rotated 180° in Figma — semantically it's a "submit/next" arrow. Don't accidentally render it as a back arrow. Use a separate icon (e.g. `arrow-forward` from icon set) in RN.
- The keyboard is drawn into the Figma frame as a static asset (`AlphabeticKeyboard` group). Do NOT replicate this in code — the real iOS keyboard renders on focus. Use `KeyboardAvoidingView` so the input stays visible above the keyboard.
- The label "What is your email" reuses Inter SemiBold via `Text-md (l-24)/Semibold` — note the `font-family/body` token actually resolves to Inter for SemiBold but Poppins for the input placeholder (`static/body-large` references Poppins). Two different font families in one screen — match exactly.
- The header has a "feedback" slot (47×47) trailing — empty in this frame; likely populated in other screens (or hidden when not needed). Confirm with Viet.
- There's no top-level title (e.g. "Sign up" or "Sign in") — header is bare. The branching logic (new vs existing user) happens server-side after email submit.
- No "Continue" button at the bottom — the inline chevron is the only submit affordance. This breaks from the typical M3 pattern; do not add a CTA button.
- The body's `bottom-0` + `pt-112` plus the keyboard art produces an artificial "above the keyboard" layout — in RN, layout the input naturally and rely on `KeyboardAvoidingView` + safe-area.
