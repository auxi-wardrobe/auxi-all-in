# Screen: Verified Successfully (Terminal Success)

**Node**: `2849:10099`
**Dimensions**: 414×896
**Purpose**: Terminal success screen confirming the user has successfully verified their account. Provides a single CTA to continue into the post-UAC app surface.
**Maps to AC scenario**: AU-242 — "Given the user has completed verification (either email OTP after sign-up OR password reset confirmation), when verification succeeds, then the app displays a confirmation screen with a single 'Continue' action that resumes the user's intended flow." This is the **convergence point** for two distinct upstream flows.

## Layout
- Container: full screen 414×896, `borderRadius: 18px`, background `--background/primary/neutral_50` (`#FCFCFD`).
- Hero stack (`2852:23278`): column auto-layout, `gap: 24px`, items-center, vertically centered (translate -50%, top = `calc(50% - 64.5px)`), `left: 13px`, `width: 387px`.
  - Inside: illustration block on top, then text stack.
- Button: absolute, `top: 775px`, `left: 43.5px`, `width: 327px`, height 56px.
- Status bar / Safe area: no explicit header — entire screen is "feature" content. Safe area must still be respected at top/bottom in implementation (~44px top, ~34px bottom on iOS).

## Header / Top bar
- **NONE.** This is a terminal screen — no back button, no top bar, no title.
- Back navigation is intentionally disabled (terminal success). On Android hardware back, project should treat it as a no-op or route to home — escalate to PM if unclear.

## Body sections (top-to-bottom)

### 1. Illustration
- Component: image asset (`2852:23273` → inner `2852:23274`).
- Frame: `154×122` outer box; inner illustration `imgGroup42` rendered at `129.665×90.12px`, top-offset 16px, horizontally centered.
- Asset: appears to be a celebratory / check-mark / confetti illustration (Group42). Treat as a single SVG/PNG export — do not try to reconstruct vector parts.
- Spacing below: 24px gap (outer hero stack) to text block.

### 2. Headline — "Verified!"
- Component: text node (`2849:10101`).
- Text: "Verified!"
- Style ref: `H4/Bold` — Poppins Bold 700 / 24px / lineHeight 32px / tracking 0px.
- Color: `--text/neutral/base` (`#1D1F23`).
- Width: full (387px), center-aligned.
- Spacing below: 3px to supporting text (inner column gap on `2849:10100`).

### 3. Supporting message
- Component: text node (`2849:10102`).
- Text: "You have successfully verified account."
- Style ref: `Text-md (l-24)/Regular` — Poppins Regular 400 / 16px / lineHeight 24px.
- Color: `--text/neutral/base` (`#1D1F23`).
- Width: full (387px), center-aligned.

### 4. CTA — Continue (Primary, filled)
- Component: `Button` (`Hierarchy=Primary, State=Enable, Icon=No, Size=56`) — node `470:2206`.
- Frame: width 327px, height 56px, `borderRadius: 16px`, background `--background/neutral/base` (`#1D1F23`), no border, no icon.
- Label: "Continue"
  - Style ref: `Text-md (l-24)/Medium` — Poppins Medium 500 / 16px / lineHeight 24px.
  - Color: `--text/primary/base` (`#F2EFEC`) — off-white on near-black.
- Position: absolute, anchored near bottom (`top: 775px` ≈ 65px from bottom — leaves room above iOS home indicator).
- Action: tap → resume user's intended post-UAC route:
  - If reached from **sign-up email verification**: advance to onboarding / home (per AU-242 happy path).
  - If reached from **password reset**: route to login or directly into home if session is restored.
  - Implementation must read the source flow from navigation state / a route param (e.g. `source: 'signup' | 'password-reset'`) to branch correctly.

## Interactive elements
- **Continue button**: state = Enable (Primary). Action = navigate to post-verification destination. No disabled state in this frame.
- **No other interactive elements** — no back, no skip, no secondary CTA.
- Tapping outside the button is a no-op.

## Text content (verbatim)
- Headline: `Verified!`
- Supporting: `You have successfully verified account.`
- CTA: `Continue`
- No error / link / helper text.

## Design tokens referenced
- Color
  - `--background/primary/neutral_50` → `#FCFCFD` (screen background — slightly warmer/off-white than the `--background/neutral/subtlest` used on form screens)
  - `--text/neutral/base` → `#1D1F23` (headline + supporting)
  - `--background/neutral/base` → `#1D1F23` (button fill)
  - `--text/primary/base` → `#F2EFEC` (button label, off-white)
- Typography
  - `H4/Bold` — Poppins Bold 700 / 24px / 32px (headline)
  - `Text-md (l-24)/Regular` — Poppins Regular 400 / 16px / 24px (supporting)
  - `Text-md (l-24)/Medium` — Poppins Medium 500 / 16px / 24px (button label)
- Spacing
  - Hero stack gap = 24px (illustration → text)
  - Text stack gap = 3px (headline → supporting) — note the unusual tight gap
  - Button width = 327px, height = 56px
  - Button position: bottom anchored, ~65px from bottom edge
- Radii
  - Screen card: 18px
  - Button: 16px
- Components
  - `Hierarchy=Primary, State=Enable, Icon=No, Size=56` (node `470:2206`) — M3 filled button variant

## Notes / gotchas
- **CONVERGENCE SCREEN**: This same screen (`2849:10099`) is the terminal success for both:
  1. **Email verification after sign-up** (post-OTP).
  2. **Password reset confirmation** (after new password is committed).

  Implementation must accept a `source` route param (or read from navigation stack) to determine where "Continue" routes:
  - Sign-up source → onboarding next-step / home.
  - Password reset source → login screen pre-filled with email, OR directly home if session is already established.

  Do **not** render two near-identical screens; reuse this component with branching on the CTA handler. Confirm routing decision with Viet + PM before wiring.

- **Background color is slightly different from other UAC screens**: `#FCFCFD` (`--background/primary/neutral_50`) here vs `#FFFFFF` (`--background/neutral/subtlest`) on the form screens. This is intentional — terminal/celebratory screens use the warmer "primary" surface. Preserve this.

- **Headline-to-supporting gap is only 3px** — unusually tight. This is deliberate (the supporting text reads as a subtitle, not a separate paragraph). Don't auto-correct to a larger gap like 8/12/16px.

- **Supporting copy is grammatically slightly off**: "You have successfully verified **account**" is missing the article "your". Verbatim from Figma. Open question for Viet/PM: ship as-is or correct to "your account"? Flag in open questions; do not silently rewrite.

- **No top bar means no back/dismiss path** — this is correct for a terminal success but ensure:
  - iOS swipe-back gesture is disabled on this screen (`gestureEnabled: false` or `headerBackVisible: false`).
  - Android hardware back triggers the Continue action (or no-op + toast).

- **Illustration asset (`imgGroup42`)** is the only visual hero. Export from Figma as SVG (preferred) or 3x PNG. Place in `auxi/src/assets/` per the project's existing asset convention.

- **Button is absolutely positioned** at `top: 775px` in a 896-tall frame — i.e. anchored ~65px above the bottom of the design canvas, NOT respecting iOS home indicator. Implementation should anchor with `bottom: insets.bottom + 24px` (or similar) using safe-area insets, not a hardcoded 775px.

- **Single CTA, no secondary action**: do not add a "Skip" or "Maybe later" — would break the AC contract.

- **i18n**: both strings ("Verified!" and "You have successfully verified account.") need Vietnamese translations. Coordinate with Viet for `vi` copy before shipping.
