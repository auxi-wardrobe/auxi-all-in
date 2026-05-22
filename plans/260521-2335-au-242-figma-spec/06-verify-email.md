# Screen: Verify email

**Node**: `2849:10276`
**Dimensions**: 414×896 (iPhone canvas, frame rounded 18px)
**Purpose**: After password creation, user is shown a "we sent you a verification email" state. App polls for verification while user opens email app, clicks magic link, or waits for resend countdown.
**Maps to AC scenario**: "User submitted email + password → backend sends verification email → app shows waiting screen → user verifies via email link → app auto-advances when verified"

## Layout
- Container: 414×896 frame; background `--background/neutral/subtlest` (`white`)
- Body region: bottom-anchored flex column, pt-227 (more top padding than email/password screens — content sits lower), pb-12, px-24 (`--body`), centered horizontally
- Inner stack: vertical flex, full-width, gap `--dimension/24---1_5-rem` (24px)
- Three logical groups, top-to-bottom: hero/body-text block → button stack → polling-status row
- **No keyboard region** — text-only screen
- Frame radius 16/18px

## Header / Top bar
- **No standard header in this frame** (no 107px header strip rendered)
- Single absolute-positioned text button "Logout" at top-right (x ≈ 87.5% − 8.25, y ≈ 50% − 377 — roughly y=71 from top), h=44
- No back button on this screen (auth is post-creation; only forward or logout)

## Body sections (top-to-bottom)

### 1. Brand mark / illustration
- Container 154×122, centered
- Asset `imgGroup42` — same Macgie/Auxi wordmark used on Welcome screen (90.12×129.665, positioned with 16px top offset inside container)

### 2. Title
- Text: "Verify your email"
- Style ref: `H4/Bold` — Poppins Bold, 24px, lineHeight 32px, letterSpacing 0
- Color: `--text/neutral/base` (`#1d1f23`)
- Alignment: center

### 3. Supporting body text (3 lines, separate text nodes)
Each is a centered, full-width text block — three separate nodes stacked with the 16px gap from the parent Body's `py-12`. Effectively the layout produces:

- Line A: "We sent a verification email to"
  - Style: `Text-md (l-24)/Regular` — Poppins Regular 16/24
  - Color: `--text/neutral/base`
- Line B: "Youremai@abc.com"
  - Style: `Text-md (l-24)/Semibold` — Inter SemiBold 16/24, weight 600
  - Color: `--text/neutral/base`
  - This is dynamic — bound to the email user just signed up with
- Line C: "Click the link in the email to verify account."
  - Style: `Text-md (l-24)/Regular` — Poppins Regular 16/24
  - Color: `--text/neutral/base`

### 4. Button stack
- Container: vertical flex, gap 12px, full-width, items-center
- **Button 1 — "Open email app"** (Primary, size 56, icon=no, state=Enable)
  - Background `--background/neutral/base` (`#1d1f23`)
  - Rounded 16px, h=56
  - Label: "Open email app" — Poppins Medium 16/24, color `--text/primary/base` (`#f2efec`)
  - Action: deep-link to the OS mail app (iOS: `message://`; Android: implicit intent)
- **Button 2 — "Resend verification email (00s)"** (Secondary, size 56, icon=no, state=**Disable**)
  - Border `1.5px solid --border/neutral/base` (`#1d1f23`), rounded 16px, **opacity 50%**
  - Label: "Resend verification email (00s)" — Poppins Medium 16/24, color `--text/neutral/base` (`#1d1f23`)
  - State = disabled because countdown is showing "00s" (cooldown active or just-after-send). Becomes enabled when timer reaches 0.

### 5. Polling-status row
- Container: horizontal flex, gap 12px, justify-center, items-start, full-width
- **Text label**: "Waiting for email to be verified"
  - Style: `Text-md (l-24)/Regular` — Poppins Regular 16/24
  - Color: `--text/neutral/subtle_200` (`#7a7f89`)
  - Whitespace nowrap
- **Spinner**: 24×24 icon (`imgStreamlineUltimateLoading` — Streamline "loading" SVG)
  - Should rotate continuously in implementation (animated)

## Interactive elements
- **Logout** (top-right text button): state default = Enable; action = clear auth state, return to Welcome
- **Open email app** (Primary): state default = Enable; action = open OS mail app via deep link
- **Resend verification email (00s)**: state default in this frame = **Disable** (opacity 50%); countdown text updates per second; becomes Enable when timer = 0 and tap triggers a new send (then countdown restarts)
- **Polling status** is **not interactive** — purely informational; app polls backend for verification status in background

## Text content (verbatim)
- Title: "Verify your email"
- Body line A: "We sent a verification email to"
- Body line B (dynamic email): "Youremai@abc.com"
- Body line C: "Click the link in the email to verify account."
- CTA 1: "Open email app"
- CTA 2: "Resend verification email (00s)"
- Status: "Waiting for email to be verified"
- Logout: "Logout"

## Design tokens referenced
- Colors: `--background/neutral/subtlest` (`white`), `--background/neutral/base` (`#1d1f23`), `--border/neutral/base` (`#1d1f23`), `--text/neutral/base` (`#1d1f23`), `--text/neutral/subtle_200` (`#7a7f89`), `--text/primary/base` (`#f2efec`)
- Typography: `H4/Bold` (Poppins Bold 24/32), `Text-md (l-24)/Regular` (Poppins Regular 16/24), `Text-md (l-24)/Semibold` (Inter SemiBold 16/24), `Text-md (l-24)/Medium` (Poppins Medium 16/24 — buttons), `Text-xs/Medium` (Inter Medium 12/16 — Logout button)
- Spacing: `--body` (24px), `--dimension/24---1_5-rem` (24px)
- Radius: 16px (buttons), 12px (text button — Logout), 18px (frame)
- Opacity: 50% on disabled Secondary button

## Notes / gotchas
- The example email "Youremai@abc.com" is **misspelled in Figma** ("Youremai" missing final "l"). This is a designer placeholder — implementation binds to the real email entered. Don't preserve the typo.
- Countdown format is `(00s)` — implementation must format as `(NN s)` or `(N s)` depending on locale + length. Confirm whether `(00s)` vs `(0s)` vs `(00 s)` is the canonical style with Viet.
- Disabled Secondary button uses **opacity 0.5 + same border + same text color** as the enabled variant. There's no separate disabled token — purely opacity-driven. Reference component `Hierarchy=Secondary, State=Disable, Icon=No, Size=56` (node `1727:17468`).
- The Logout button is `Hierarchy=Text button, State=Enable, Icon=No, Size=44` (node `1774:6683`) — Inter Medium 12, color `--text/neutral/base`, hit area h=44, px-16, rounded 12. No icon visible (Icon=No).
- No header back button — confirms this is a post-account-creation state where the only escape is Logout. Match this in RN navigation: don't show a back arrow.
- The status spinner needs to be animated in RN — use `react-native-reanimated` or `Animated` rotate, not a static SVG.
- Three separate text nodes (body A / B / C) are rendered as three flex children with the body container's `gap` controlled implicitly via the `py-12` on the parent `Body`. In implementation, render them as separate `<Text>` elements with vertical spacing, NOT a single multi-line `<Text>` with `\n` — because line B has a distinct font weight (SemiBold) and we want clean per-line styling.
- The brand mark at the top is identical to Welcome's logo (same `imgGroup42` URL conceptually — different cache key but same Figma asset). Reuse the same RN asset.
- AC likely requires automatic navigation away from this screen once verification completes (polling success). The screen itself only shows the waiting state — the next screen is out of this batch (likely "onboarding" or "home").
