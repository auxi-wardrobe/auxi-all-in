# Phase 1 — Theme Tokens + Icons

**Priority:** P1 · **Status:** pending · **Effort:** ~3h · **Blocks:** Phase 3,4
**Owner:** mobile-dev

## Context links
- Extraction §4 (tokens) + §6 (icons) + §10 (theme summary)
- Theme file: `auxi/src/theme/theme.ts` (253 lines — verified)
- Icons index: `auxi/src/assets/icons/index.ts`

## Overview
Add ONLY the genuinely-new tokens (4 colors, 1 type alias, 1 radius) + export 1-3
new SVG icons. Everything else maps to existing `uac*`/`figma*` tokens. DRY: do not
duplicate existing hexes under new names.

## Key insights (re-verified against theme.ts)
- `#fcfcfd` ALREADY exists twice: `uacBackgroundNeutralSubtlest` and
  `uacBackgroundNeutral50` (theme.ts:54-55). **Reuse — do NOT add.** Note:
  `AppWelcomeScreen.tsx:49` currently hardcodes `'#fcfcfd'` with a "no matching
  token" comment that is now stale — Phase 3 swaps it to the alias.
- `#262421` = `figmaCtaLabel` (theme.ts:23). `#eee6df` = `figmaCaptionPillBg`
  (theme.ts:21). `#7a7f89` = `uacBorderBold200`/`uacTextSubtle200` (theme.ts:58,61).
  `#1d1f23` = `uacTextBase`/`uacBorderBase` (theme.ts:57,59). `#f2efec` =
  `uacTextPrimaryBase` (theme.ts:62). All REUSE.
- Typography: `uacH1Bold` (theme.ts:181) is Poppins-Bold 40/52 but lacks the
  `-0.72` letterSpacing. `poppinsTimeLg` (theme.ts:156) = Poppins-Bold 32/40 ls
  -0.64 (matches H2). `poppinsButton` (148), `poppinsBody` (142),
  `uacBodyMdSemibold` (191, Inter-SemiBold 16/24), `uacBodyXsRegular` (213,
  Inter-Regular 12/16) all REUSE.
- **Inter-Regular 10/12 has NO alias** → add `interCaptionXxs`.
- `borderRadius` has no `6` (theme.ts:236-250) → add `chip: 6`.

## NEW tokens to add (exact)
`theme.ts` → `colors`:
- `figmaOnboardingStepLabel: '#9e968e'` — "Step n/3" label / primary bold_400.
- `figmaChipBg: '#5b5550'` — selected chip bg (Loading/Completed). primary bold_500.
- `figmaOnboardingStickyBarBg: 'rgba(255, 255, 255, 0.6)'` — Step-3 sticky bar.

`theme.ts` → `typography.aliases`:
- `interCaptionXxs: { fontFamily: 'Inter-Regular', fontSize: 10, lineHeight: 12 }`.

`theme.ts` → `borderRadius`:
- `chip: 6`.

## Icons (re-verified against assets)
Existing SVGs present: `icon_chevron_left`, `icon_chevron_right`, `icon_arrow_right`,
`icon_home_pin`. (`ls` confirmed.) Needs:
| Icon | Status | Action |
|---|---|---|
| Back arrow (header) | reuse `icon_chevron_left.svg` | Verify glyph matches Figma `864:1315`; if distinct, export `icon_onboarding_back.svg`. |
| Chevron-right (Next trailing) | reuse `icon_chevron_right.svg` | Confirm thin-chevron match. |
| Loading spinner 24×24 | **MISSING** | Export `icon_loading.svg` (currentColor, viewBox 0 0 24 24). Rotation via RN `Animated`. |
| Pin badge | per D6 | If View+number (recommended) → NO svg. If SVG → export `icon_pin_badge.svg`. |
| "See my outfit" eye/view | **MISSING** | Export `icon_see_outfit.svg` (currentColor). |
| Logo (Welcome) | reuse `assets/images/logo.png` | Already used by `AppWelcomeScreen.tsx:21`. Confirm sizing; no new asset unless CEO wants the Figma wordmark. |

## Related code files
- MODIFY `auxi/src/theme/theme.ts` (add 3 colors + 1 alias + 1 radius).
- CREATE `auxi/src/assets/images/icon_loading.svg`, `icon_see_outfit.svg`
  (+ conditionally `icon_onboarding_back.svg`, `icon_pin_badge.svg`).
- MODIFY `auxi/src/assets/icons/index.ts` (register new icons in `Icons` + named exports).

## Implementation steps
1. Add the 3 colors + `interCaptionXxs` + `chip:6` to theme.ts.
2. Export new SVGs from Figma with `currentColor` fill + explicit viewBox.
3. Register icons in `index.ts` (both `Icons` object and named re-exports).
4. `npx tsc --noEmit` — must pass.
5. Optional: run `figma-theme-sync` to confirm no other drift was missed.

## Todo
- [ ] Add `figmaOnboardingStepLabel`, `figmaChipBg`, `figmaOnboardingStickyBarBg`
- [ ] Add `interCaptionXxs` alias
- [ ] Add `chip: 6` radius
- [ ] Export + register `icon_loading.svg`, `icon_see_outfit.svg`
- [ ] Verify back-arrow + chevron-right reuse (or export new)
- [ ] tsc clean

## Success criteria
- Exactly 3 new colors, 1 alias, 1 radius added; no duplicate hexes.
- New icons render as RN components (currentColor tint works).
- `npx tsc --noEmit` passes.

## Risks
| Risk | L×I | Mitigation |
|---|---|---|
| Dup token added (e.g. another `#fcfcfd`) | M×L | Grep theme.ts for the hex before adding; reuse alias. |
| Inter-Regular 10 renders blurry on Android | L×L | RN handles 10px fine; verify on sim in Phase 6. |
| Back glyph mismatch → wrong icon | L×M | Compare Figma `864:1315` vs `icon_chevron_left` in qa-ui Pass2. |
