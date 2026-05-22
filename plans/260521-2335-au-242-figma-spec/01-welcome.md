# Screen: Welcome

**Node**: `2849:10085`
**Dimensions**: 414×896 (iPhone canvas, frame rounded 18px)
**Purpose**: Entry point for AU-242 UAC. User picks an auth path (Google, Apple, Email) or changes language.
**Maps to AC scenario**: "Unauthenticated user opens app → sees Welcome screen with sign-in options"

## Layout
- Container: absolute-positioned children on a 414×896 frame (Figma absolute layout — convert to RN flex column with safe areas)
- Background: `--background/primary/neutral_50` (`#fcfcfd`)
- Status bar: visible (iOS default), light content over near-white background
- Safe area: top inset under "English" button at y≈45px; bottom inset under footer text

## Header / Top bar
- No back button (root screen)
- No title
- Trailing action: language switcher "English" text-button with caret-down icon (top-right, top≈45px from frame top)

## Body sections (top-to-bottom)

### 1. Logo / Brand mark
- Position: x≈center, y≈188px, size 129.665×90.12
- Asset: `imgGroup42` (Macgie/Auxi wordmark/logo SVG)
- No text

### 2. Headline
- Position: y≈347px, width 382px, centered
- Text: "Welcome to\nMacgie" (two lines, `<br>` between "to" and "Macgie")
- Style ref: `H1/Bold` — Poppins Bold, 40px, lineHeight 52px, letterSpacing `-0.72px`
- Color: `--text/neutral/base` (`#1d1f23`)
- Alignment: center

### 3. Action stack (Buttons)
Container: y≈546px, x≈45px, width 327px, vertical flex, gap `--dimension/16` (16px), align-start

#### 3a. Sub-group of social buttons (gap 12px)
- **Button — Continue with Google** (Secondary, size 56, icon=yes)
  - Border `1.5px solid --border/neutral/base` (`#1d1f23`)
  - Background transparent
  - Rounded 16px
  - Padding `20px / 16px` (horizontal/vertical) inside content
  - Gap between label and icon: 8px
  - Label: "Continue with Google" — Poppins Medium, 16px, lineHeight 24px, color `--text/neutral/base`
  - Trailing icon: Google "G" image (`imgImage1`), 24px box, 16px image inside
- **Button — Continue with Apple** (Primary, size 56, icon=yes)
  - Background `--background/neutral/base` (`#1d1f23`)
  - Height 56px, gap `--dimension/8` (8px), padding-x 20px
  - Rounded 16px
  - Label: "Continue with Apple" — Poppins Medium, 16px, lineHeight 24px, color `--text/primary/base` (`#f2efec`)
  - Trailing icon: Apple logo vector (`imgVector`), 24px box

#### 3b. Divider
- Component: `Horizontal/Full-width` (M3 Divider)
- Full-width, height 0 (1px stroke top inset)
- Image asset `imgDivider`

#### 3c. Continue with Email button (Secondary, size 56, icon=yes)
- Same shape as Google button: border `1.5px solid --border/neutral/base`, rounded 16px, padding 20/16, gap 8
- Label: "Continue with Email"
- Trailing icon: envelope vector (`imgVector1`), 24px box

### 4. Legal footer text
- Full-width, left-aligned, width 327px
- Text: "By continuing, you agree to our Terms of Service and Privacy Policy"
- Style ref: `Text-xs/Regular` — Inter Regular, 12px, lineHeight 16px, weight 400
- Color: `--text/neutral/base` (`#1d1f23`)
- (No interactive link styling in this frame — likely whole strings link to Terms / Privacy per AC)

## Interactive elements
- **English** (top-right, `Hierarchy=Text button, State=Enable, Icon=Yes, Size=44`)
  - Inter Medium 12px / line 16
  - Trailing caret icon
  - Action per AC: opens language picker
- **Continue with Google**
  - State default = Enable; action = launch Google OAuth flow
- **Continue with Apple**
  - State default = Enable; action = launch Apple Sign-In (iOS only — Android falls back to email per AC)
- **Continue with Email**
  - State default = Enable; action = navigate to Email input screen (node `2849:10143`)
- **Terms of Service / Privacy Policy** — link spans inside legal text (no separate component; copy is the link target)

## Text content (verbatim)
- Headline: "Welcome to\nMacgie"
- Legal: "By continuing, you agree to our Terms of Service and Privacy Policy"
- CTA 1: "Continue with Google"
- CTA 2: "Continue with Apple"
- CTA 3: "Continue with Email"
- Lang button: "English"

## Design tokens referenced
- Colors: `--background/primary/neutral_50` (`#fcfcfd`), `--background/neutral/base` (`#1d1f23`), `--border/neutral/base` (`#1d1f23`), `--text/neutral/base` (`#1d1f23`), `--text/primary/base` (`#f2efec`)
- Typography: `H1/Bold` (Poppins Bold 40/52, letterSpacing -0.72), `Text-md (l-24)/Medium` (Poppins Medium 16/24), `Text-xs/Regular` (Inter Regular 12/16), `Text-xs/Medium` (Inter Medium 12/16)
- Spacing/dimension: `--dimension/16---1-rem` (16px), `--dimension/8---0_5-rem` (8px)
- Font families: `font-family/heading` → Poppins; `font-family/body` → Poppins (Medium) + Inter (Regular/Medium)
- Radius: 16px (buttons), 12px (text button), 18px (frame)

## Notes / gotchas
- Brand says "Macgie" in this frame — confirm with Viet whether this is intentional or should be "Auxi" in shipped build (AU-242 names the product as Auxi but design file uses Macgie).
- The legal text wraps "Terms of Service" and "Privacy Policy" but they are not styled as separate link nodes in Figma; treat the whole sentence as having two tappable substrings (need design-token-agnostic implementation in RN, likely separate `<Text>` children).
- Apple button uses Poppins font family in this frame (Poppins:Medium), but the typography token references `font-family/body` — `body` resolves to Poppins/Inter depending on weight. Stick with the token, not the literal `Poppins`.
- "English" button position is absolute at top-right; convert to header trailing slot in RN.
- No back button on this screen — verify RN navigation: this is the auth stack root.
- Apple-only on iOS — Android variant of this screen should hide the Apple button (not in this batch).
