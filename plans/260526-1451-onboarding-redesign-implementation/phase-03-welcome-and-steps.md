# Phase 3 — Welcome + Step Screens (1/2/3)

**Priority:** P1 · **Status:** pending · **Effort:** ~6h · **Blocks:** Phase 4,5
**Owner:** mobile-dev (figma-to-rn-workflow skill)

## Context links
- Extraction §3.1-3.4 (Welcome, Step1/2/3 specs)
- Existing screens to redesign/replace: `AppWelcomeScreen.tsx`,
  `GenderPreferenceScreen.tsx`, `StylePreferenceScreen.tsx`, `StylePickerScreen.tsx`
- Reusable primitives: `OnboardingSelectionCard.tsx`, `FigmaPrimitives.tsx`
  (`PillButton` variants filled/outline/text, `TopIconButton`, `BottomSheetSurface`)

## Overview
Implement the 4 interactive picker screens per Figma. Uses `figma-to-rn-workflow`
Phase 0 gate (verify extraction + qa-ui PASS) then Phases 1-7. Reuse the existing
`OnboardingSelectionCard` (3:4 tile + caption pill) — extend for pin badge.

## Key insights (re-verified)
- `OnboardingSelectionCard.tsx` already does tile bg + 4px selected border
  (cardSelected:71-73) + dimmed opacity (cardDimmed:74-76) + caption pill. BUT its
  hardcoded `#DEDEDE` bg (line 65), `rgba(39,42,50,*)` pills, and Manrope 8px label
  do NOT match the new Figma (bg `#f2efec`, Inter 10/12, pill `rgba(18,18,18,0.75)`).
  → **Extend the card** (props for bg/pill/label-font) OR fork an
  `OnboardingTileV2`. DRY favors extending; KISS favors a focused V2 if props
  balloon. Decide at impl; do not break legacy callers (StylePreferenceScreen uses it).
- `PillButton` (FigmaPrimitives.tsx:92) already has filled/outline/text/disabled
  → covers Welcome CTA (filled), Step-3 sticky "(n/3) Next" (outline+icon), and
  the text buttons. Reuse; pass trailing chevron via children/icon prop (verify
  PillButton supports a trailing icon — if not, small extension).
- Step-2 wire mapping ALREADY correct in `StylePreferenceScreen.tsx:57-61`
  (`Slim Fit`/`Classic Fit`/`Relaxed Fit`). New screen reuses that mapping from
  config.ts; only the LABEL changes per D2.
- Step-3 pin-badge multi-select (max 2, ordered) ≈ existing rank logic in
  `StylePickerScreen.tsx:168-178` (togglePick + ranked array). Reuse the logic,
  restyle to tiles+pins.

## Per-screen
### Welcome (redesign `AppWelcomeScreen.tsx`)
- Swap hardcoded `'#fcfcfd'` (line 49) → `theme.colors.uacBackgroundNeutral50`.
- Title `uacH1Bold` + inline `letterSpacing:-0.72` (D11/extraction §4.2). Subtitle
  `poppinsBody`. CTA `PillButton` filled, label from config (D4 fixes copy).
- No header/back. testID: `onboarding-welcome-cta`.

### Step1 Wardrobe (NEW `OnboardingWardrobeScreen`, replaces GenderPreference UI)
- Header (TopIconButton back) + "Step 1/3" (`uacBodyXsRegular`,
  `figmaOnboardingStepLabel`) + 3-segment progress bar + title block (Inter
  SemiBold/Regular). Tiles 2+1 (Womenswear/Menswear / Mixed) from config.
- Selecting a tile enables the "Continue" `PillButton` (disabled until pick).
  Unlike legacy (tap=navigate), new flow requires explicit Continue (Figma).
- testIDs: `onboarding-wardrobe-tile-<value>`, `onboarding-wardrobe-continue`.

### Step2 Fit (NEW `OnboardingFitScreen`)
- Same header/progress (seg 2). Title/subtitle per wardrobe branch (config, D8).
- 3 tiles (2+1) with selected (4px border) / unselected (opacity 0.5) states.
- Continue → `navigate('OnboardingStyles', {wardrobe_direction, fit_preference})`.
- testIDs: `onboarding-fit-tile-<wireslug>`, `onboarding-fit-continue`.

### Step3 Styles (NEW `OnboardingStylesScreen`)
- Header/progress (seg 3). Title/subtitle (config). 5-6 style tiles, multi-select
  MAX 2 with numbered pin badges (D6). Sticky bottom bar (`figmaOnboardingStickyBarBg`
  + backdrop-blur: use `@react-native-community/blur` BlurView if already a dep,
  else low-fi solid `rgba(255,255,255,0.6)` fallback — verify dep in impl).
- "(n/3) Next" outline button shows live count; enabled at ≥2 (per Figma "up to two"
  the cap is 2 → label reads "(2/2) Next" once full — confirm vs Figma "/3)" via D7).
- This screen OWNS the `/generate` mutation (Phase 5 wires it). On pending →
  render Loading (Phase 4). testIDs: `onboarding-style-tile-<slug>`,
  `onboarding-style-pin-<n>`, `onboarding-style-next`.

## Related code files
- MODIFY `AppWelcomeScreen.tsx` (token swap + copy from config).
- CREATE `OnboardingWardrobeScreen.tsx`, `OnboardingFitScreen.tsx`,
  `OnboardingStylesScreen.tsx` (new screens; legacy kept for fallback).
- MODIFY/EXTEND `OnboardingSelectionCard.tsx` OR create `OnboardingTileV2.tsx` (+ pin badge).
- READ-only: `FigmaPrimitives.tsx`, `config.ts`, `v05Api.ts`.

## Implementation steps
1. figma-to-rn Phase 0: confirm extraction artifact + qa-ui PASS (from Phase 0).
2. Welcome token/copy swap.
3. Build tile primitive (extend or V2) with default/selected/disabled/pinned states.
4. Step1 → Step2 → Step3 screens, consuming config + threading params.
5. Every interactive element gets `testID` + icon-only gets `accessibilityLabel`
   (auxi rule). Pin badge: testID `onboarding-style-pin-<n>`, a11y "Pinned #n".
6. `./scripts/auxi-lint-tokens.sh` — NO hex/font drift (exit Phase 3 clean).
7. `npx tsc --noEmit` + `yarn lint` (baseline: 4 errors in _HomeScreen only).

## Todo
- [ ] Welcome redesigned (token + config copy)
- [ ] Tile primitive with 4 states + pin badge
- [ ] Step1 Wardrobe screen + progress bar + Continue gate
- [ ] Step2 Fit screen (branch copy, wire mapping)
- [ ] Step3 Styles screen (max-2 pins, sticky bar)
- [ ] All testIDs + a11yLabels present
- [ ] auxi-lint-tokens.sh clean
- [ ] tsc + lint clean

## Success criteria
- 4 screens render per Figma; states (selected/dimmed/pinned/disabled) correct.
- Params thread Step1→2→3 carrying wire values.
- `auxi-lint-tokens.sh` clean; tsc passes; no new lint errors.

## Risks
| Risk | L×I | Mitigation |
|---|---|---|
| Style-tile artwork assets not supplied by CEO | M×M | Use `figmaCardSurface` bg placeholder; wire art when delivered. Non-blocking for structure/QA-of-flow. |
| Extending OnboardingSelectionCard breaks legacy StylePreference | M×H | Add OPTIONAL props (default = current look) OR fork V2. Run legacy flow (flag OFF) in Phase 6. |
| BlurView not a dependency | M×L | Check package.json; fallback to solid translucent bg — visually acceptable, note for qa-ui. |
| Progress bar hairline rendering (Figma image-rendered) | L×L | Reimplement as 3 Views with bg color — simpler than image. |

## File ownership
All `auxi/src/**` here — single owner (mobile-dev). No overlap with Phase 4
(different screen files) except the shared tile primitive — build it FIRST, then
Phase 4 can reuse read-only.
