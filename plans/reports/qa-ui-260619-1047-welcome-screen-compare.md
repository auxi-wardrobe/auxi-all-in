# qa-ui Compare — Welcome screen (auth-stack root) vs Figma 2849:10085

- **Date**: 2026-06-19
- **Mode**: Compare (Pass 2 code-vs-Figma + Pass 3 sim screenshot). Re-run of prior BLOCKED audit (code now live on disk).
- **Figma**: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-10085 — node `2849:10085` "Welcome Home" (390×844)
- **Code**: `auxi/src/screens/auth/WelcomeScreen.tsx` + `auxi/src/components/macgie/MacgieLoader.tsx` (`asLogo` prop)
- **Spec**: `plans/260618-2108-welcome-screen-redesign/figma-extraction-welcome.md`
- **Screenshots**:
  - Sim (Pass 3): `auxi/docs/qa-findings/screenshots/2026-06-19/qa-ui-welcome.png`
  - Figma ref: `auxi/docs/qa-findings/screenshots/2026-06-19/figma-welcome-reference.png`

## Verdict: **PASS**

The redesign is a faithful, token-clean implementation of Figma 2849:10085.
All structural elements, tokens, glyphs, and the lively-Macgie hero are present
and correct. The only divergences are the 3 pre-approved/CEO-flagged deviations
(font family, 1px radius/gap rounding, non-tappable legal links) — none are
fidelity defects. No new issues found.

## Pre-flight

- `mcp-doctor.sh` exit 0 — sim booted (iPhone 16 Pro), WDA :8100, mobile-mcp healthy.
- Code on disk: `grep -c asLogo MacgieLoader.tsx` → 4; WelcomeScreen imports MacgieLoader (line 41), renders `<MacgieLoader variant="inline" size={126} asLogo testID="welcome-logo" />` (lines 285-290).
- Figma MCP (`get_metadata`/`get_design_context`/`get_variable_defs`) available.
- App opened logged-in → navigated drawer → Log out → reached Welcome (auth root). Fresh JS bundle confirmed (redesign renders live, no AsyncStorage redbox — build fix holds).

## Pass 2 + Pass 3 — per-element Compare table

| Element | Figma (2849:10085) | Live sim / code | Verdict |
|---|---|---|---|
| Hero logo | `macgie-animate-2` 103×126, no caption | `MacgieLoader asLogo size=126`; a11y `Image` "Macgie", 118×126; motion live (sway mid-tilt + pupil track captured in screenshot); no "Loading" caption | PASS |
| Logo motion | lively (±4° dwell sway, pupil track, ~9% bob) | `MacgieLoader` loops run regardless of `asLogo` (motion.ts tokens); reduce-motion parks at rest | PASS |
| Logo a11y | image, label "Macgie" | `accessibilityRole="image"`, label "Macgie", busy state dropped when `asLogo` (MacgieLoader.tsx:163-164) | PASS |
| Heading | "Welcome to Macgie" H1, 2 lines, centered | `t('…headline')` = "Welcome to\nMacgie", centered, `uacH1Bold` + ls −0.72 | PASS (font = known dev) |
| Subtitle | "Get dressed with more clarity, less pressure." centered | `t('…subtitle')` present, `uacBodyXsRegular`, centered | PASS |
| Layout | hero top group · action stack pinned bottom · legal below | `bodyContainer` space-between; `heroGroup` top, bottom group (action stack + legal) | PASS |
| Google btn | outlined, 327w, border base, label + G glyph trailing | outlined `uacBorderBase` 1.5px, 56h, `welcome-cta-google`, GoogleGlyph 24 | PASS |
| Apple btn | filled dark `#1d1f23`, label `#f2efec` + Apple glyph, iOS | filled `uacBackgroundBase`, light label `uacTextPrimaryBase`, iOS-gated, `welcome-cta-apple` | PASS |
| "or" divider | line · "or" · line (Inter 12) | `orDivider` line · `t('…or')` · line, `uacBodyXsRegular` | PASS |
| Email btn | outlined like Google, envelope glyph | outlined, EnvelopeGlyph 24, `welcome-cta-email` | PASS |
| Lang switcher | top-right "English" + caret | `welcome-lang-link` "English" + CaretDownGlyph, top-right | PASS |
| Legal footer | Terms / Privacy underlined links | single Text `welcome-legal-text` (non-tappable) | PASS (known dev #3) |
| bg color | #fcfcfd | `uacBackgroundNeutral50` | PASS |
| text/border | #1d1f23 | `uacTextBase`/`uacBorderBase`/`uacBackgroundBase` | PASS |
| Apple text | #f2efec | `uacTextPrimaryBase` | PASS |

## Token + i18n integrity

- `auxi-lint-tokens.sh` → no hex/font drift in WelcomeScreen or MacgieLoader.
- Figma vars (`get_variable_defs`) map 1:1 to `uac*` tokens used in code.
- i18n 3-locale parity (en-EN / vi-VN / fr-FR) confirmed for headline, subtitle, or, all CTAs, legal — no fallback / missing-key risk. en-EN copy matches Figma verbatim.

## Known deviations (NOT failed — pre-flagged to CEO)

1. **Font** — Figma H1 = Nunito Sans (not bundled) → Poppins H1 used. Visible: Figma headline has rounded terminals, live has Poppins geometry. Expected per spec line 29.
2. **Rounding** — outlined-button radius 17→16, hero gap 7→8 (on-token-grid). Imperceptible.
3. **Legal links** — Terms/Privacy plain text, not tappable (PM open Q). Underline styling also absent vs Figma — acceptable under the same open Q.

## Notes / non-blocking observations

- Subtitle wraps to 2 lines in Figma (390pt frame, 251px text box) but 1 line on the live 393pt screen. Natural responsive reflow, same copy/alignment — not a defect.
- Hero logo screenshot caught the sway mid-tilt (head rotated, pupils offset) — positive confirmation the lively motion is wired, not a frozen frame.

## Routing

- No HIGH/MEDIUM fidelity findings → nothing to route to mobile-dev.
- Deviation #3 (legal-link tappability + underline) remains a PM open question — flag to pm if CEO wants Figma-exact underlined links; would need testIDs + tracking per analytics rule.

## Unresolved questions

- Legal Terms/Privacy: ship as plain text (current) or linkify to match Figma underline? PM decision pending.
- Designer gate (step 6.5) still owns the Nunito-Sans-vs-Poppins taste call.
