# Figma extraction — See-on-me redesign (chat-transcript → stepped flow)

> Source of truth: Figma `Macgie` file `0nXXMAR4Arf1ZfjtQvtBh0`, section
> `See this on me - 1.1` node `4814:11694`. All frames 390×844.
>
> **Environment note:** the Figma MCP (`get_metadata`/`get_design_context`/
> `get_variable_defs`/`download_assets`) is NOT reachable in this headless cloud
> session (no gemini CLI bridge, MCP tools not exposed as callable functions).
> This extraction is therefore transcribed from the plan spec
> (`plans/260714-0516-see-on-me-redesign/spec.md`), which was authored from a
> live Figma read by the spec owner, cross-checked against the existing
> implementation under `auxi/src/screens/see-this-on-me/`. Pixel-level card
> layout for the two capture steps is inferred from the reuse map + existing
> copy; exact frame geometry + the two thumb glyph paths must be confirmed /
> re-exported in an interactive session with Figma MCP (see Open questions).

## Frame → screen map

| Figma frame | node | Screen | Reuse target |
|---|---|---|---|
| step 1 - ask to upload selfie | 4814:11695 | Step 1/3 selfie card | `StepSelfie` + `StomStepLayout` |
| step 2 - ask to upload body | 4814:11710 | Step 2/3 full-body card (optional) | `StepFullBody` + `StomStepLayout` |
| Loading step 3 | 4814:11737 | Body-shape generation loading (3 rows) | `StomLoadingScreen` + `MacgieLoader` |
| step 3 - choose a body fit | 4814:12741 | Body-fit picker (Next disabled) | `StepBodyShape` |
| step 3 - ... (selected) | 4814:13267 | Middle tile selected, Next enabled | `StepBodyShape` selected state |
| step 3 - ... - expanded | 4814:11783 | Expand bottom sheet | `BodyShapeCarousel` |
| loading to see result | 4814:13137 | Outfit render loading (4 rows) | `StomLoadingScreen` |
| success AI | 4814:11877 | Result + thumbs feedback | `OutfitPreview` + feedback row |

`Favourite collection` (4814:11887) — out of scope, ignored.

## Layout (per screen, structure)

Shared chrome (Figma `Frame 2086`): top app-bar `StomHeader` (centered title,
back chevron) → BELOW it the "Step n/3" muted label + 3-segment progress bar
(lifted from `OnboardingStepHeader`). Body content. Sticky footer: CTA(s) +
privacy caption.

- **Step 1/3 selfie** — VERTICAL: progress header (step 1 filled), prompt
  headline (`seeThisOnMe.step1.prompt`), hero card w/ FaceId outline glyph +
  captured selfie preview when present, footer CTA "Take photo" (outline pill,
  camera trailing), privacy caption (`privacyShort`). Inline error surface on
  photo rejection.
- **Step 2/3 full body (optional)** — progress header (step 2), prompt
  (`seeThisOnMe.step2.prompt`), hero card w/ BodyOutline glyph + preview,
  footer row: "Skip this step" (text) + "Take photo" (outline). privacy caption.
- **Loading step 3 (shapes)** — MacgieLoader mascot + headline
  (`loadingShapes.title`) + 3 staggered check rows (`loadingShapes.rows`) +
  footer supporting text (`loading.footer`) + quit CTA (`quit.cta`), gated ≥7s.
- **Body-fit picker** — progress header (step 3), row of 3 tap tiles (generated
  photos), selected tile → 2px accent border, bottom **Next** pill disabled
  until a shape is selected. Tapping a tile opens the expand sheet.
- **Expand sheet** — `BodyShapeCarousel`: swipeable pages, dots, opt-in
  checkbox, Retake / Use this photo. "Use this photo" now SELECTS + closes
  (does not render).
- **Loading to see result (render)** — same loading shell, headline
  (`loadingResult.title`) + 4 staggered rows (`loadingResult.rows`) + quit gate.
- **Success** — `OutfitPreview` 9:16 image + AI disclosure + Back-to-home;
  two 32×32 white rounded-8 thumb buttons (4px gap, shadow 0 1 1 rgba0,0,0,.15)
  overlaid bottom-center on the image (nodes 4814:13242 up / 4814:13237 down).

## Tokens used (mapped to `theme.ts`, no new tokens needed)

- `background/primary/subtle_50 #f2efec` → `theme.colors.figmaBackground` (screen bg)
- `text/neutral/base #1d1f23` → `theme.colors.uacTextBase`
- `background/neutral/subtlest #ffffff` → `theme.colors.white` / `figmaSurface`
- step label `#9e968e` → `theme.colors.figmaOnboardingStepLabel`
- empty segment `#eee6df` → `theme.colors.figmaCaptionPillBg`
- Poppins body md / xs → `theme.typography.aliases.poppinsBody*` / `uacBodyXsRegular`
- accent (selected border / filled) → `theme.colors.figmaAction`
- check row done → `theme.colors.figmaAction` (green check via `Icons.CheckCircle`)
- thumb button shadow → `theme.ds.shadow.headerIcon` (0 1 1 rgba(0,0,0,.15) equivalent)

No off-token literals identified. `auxi-lint-tokens.sh` must stay clean.

## Icons

| Icon | Size | Status |
|---|---|---|
| ChevronLeft (back) | 20×20 | exists |
| Camera (CTA trailing) | 20×20 | exists |
| FaceId (selfie glyph) | — | exists |
| BodyOutline (full-body glyph) | — | exists |
| CheckCircle (loading row done) | 24×24 | exists |
| Loading (spinner) | 24×24 | exists |
| Plus (checkbox / skip) | 14–16 | exists |
| **ThumbUp** (feedback) | 24×24 | **NEW** — Figma 4814:13244 |
| **ThumbDown** (feedback) | 24×24 | **NEW** — Figma 4814:13239 |

New glyphs registered as `Icons.ThumbUp` / `Icons.ThumbDown`, `currentColor`
convention, `viewBox 0 0 24 24`. (Hand-authored standard glyphs this session —
Figma export unreachable; flag re-export as follow-up.)

## Variants / states

- **Next pill (body-fit)**: default (disabled, no selection) / enabled (selection).
- **Body-fit tile**: default / selected (2px `figmaAction` border).
- **Quit CTA (loading)**: disabled (<7s) / enabled (≥7s).
- **Thumb button**: idle / selected (single-choice up XOR down; selected fills/tints).
- **PillButton** pressed / loading / disabled — covered by primitive.
- **Loading row**: hidden (unrevealed) / revealed (green check). Reduce-motion:
  all rows revealed at once, CTA still gated to 7s.

## Open questions for CEO / tech-lead

- Exact capture-step card geometry (hero illustration vs plain prompt card) not
  resolvable headless — implemented as a clean on-token onboarding-style card
  using existing prompt copy + outline glyph. Confirm against Figma
  4814:11695 / 4814:11710 in an interactive session (visual verification pending).
- Header title copy: existing `seeThisOnMe.title` = "Self visualization"; Figma
  section labels the bar "See on me". Left unchanged (copy rename out of scope) —
  confirm whether to retitle.
- Thumb glyphs hand-authored (standard up/down) — re-export exact paths from
  Figma 4814:13244 / 4814:13239 when MCP is available.

## New backend fields (vs current API client)

- `POST /api/tryon/feedback` `{ job_id, result_url, vote: "up"|"down" }` → `{ ok: true }`
  — NOT in any current `auxi/src/services/*.ts`. New `tryOnFeedbackService.ts`
  ships against this contract; endpoint is a backend follow-up (fire-and-forget,
  errors swallowed). No other new fields — capture/shapes/render/select all
  covered by current `bodyService` / `bodyShapeService` / `tryOnService`.
</content>
