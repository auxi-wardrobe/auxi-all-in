# Figma Extraction — "See this on me" / Self visualization try-on flow

- **Figma file**: `0nXXMAR4Arf1ZfjtQvtBh0`
- **Section node**: `2852:22266` "See this on me" (2783 × 2057)
- **Plan**: 260611-2348-favourite-see-this-on-me (Workstream 5)
- **Screen entry points**: FavouriteScreen "Self visualization" link; Home "See this on me" CTA
- **Extracted**: 2026-06-12 by mobile-dev

## Child frame node-ids (the screens to implement)

| Figma node | Name | Maps to |
|---|---|---|
| `3395:8480` | "ask to upload photo 1" | **Step 1/3 · Selfie** (StepSelfie) |
| `3395:9006` | "ask to upload photo 2" | **Step 2/3 · Full body** (StepFullBody) |
| `3395:9248` | "choose a body fit" | **Step 3/3 · Body shape** (StepBodyShape, collapsed) |
| `3398:17745` | "choose a body fit - detail" + child `noti` `3398:17798` | **Body-shape picker expanded** (full-screen carousel modal) |
| `3398:17581` | "success AI" | **Your outfit preview** (OutfitPreview) |
| `3395:8500` | header instance | shared centered-title header ("Self visualization") |
| `3539:23335` | "Remove" | (out of scope — FavouriteScreen remove dialog, already built) |
| `3230:35028` | "Favourite collection" | (out of scope — FavouriteScreen, already built) |

## Layout model (IMPORTANT — conversational/chat, not page swaps)

Steps 1–3 are NOT three separate full screens that replace each other. The Figma
frames are **cumulative chat transcripts**: each step appends a left-aligned
"assistant" prompt bubble (greige pill + outline icon) and, once the user takes a
photo, a right-aligned user photo thumbnail. By "choose a body fit" (step 3) the
screen shows: selfie prompt → selfie thumb → fullbody prompt → fullbody thumb →
bodyshape prompt → 3 silhouette options inline.

Implementation: a single scrolling transcript (`SeeThisOnMeScreen`) that renders
the accumulated bubbles per the `step` state machine
(`selfie → fullBody → bodyShape → generating → preview`). Step components render
the incremental bubble + the bottom action bar for the *current* step.

### Header (`3395:8500`, all step frames + preview)
- Height 107, white bg @90% opacity with backdrop-blur 7.5 (approx w/o blur dep
  → `figmaItemDetailHeaderBg` rgba(255,255,255,0.9), same pattern as FavouriteScreen).
- Back chevron in a 44×44 tappable slot (left). Centered title. Opacity-0 44×44
  trailing spacer to keep title optically centered.
- Title text: **"Self visualization"** (Figma literally renders `Self visualization”`
  with a stray smart-quote — treat as "Self visualization", matches
  `favourite.self_visualization` copy). The expanded body-shape modal header reads
  **"See this on me"**.
- Title style: Inter SemiBold 14/20, color text/neutral/base #1d1f23
  → `theme.typography.aliases.interMediumSm` is 14/20 Inter Medium; closest existing
  is `uacBodyMdSemibold` (Inter SemiBold 16/24) — wrong size. Use `interMediumSm`
  (14/20) for size/line-height parity; weight delta (Medium vs SemiBold) is a minor
  nit, FavouriteScreen already ships `interMediumSm` for the same header. NO new token.
- Preview header (`3398:17581`) swaps back-chevron for a hamburger/menu glyph (left)
  + a download glyph (right). We keep the chevron-back for nav consistency and omit
  the download action for v1 (note as open Q).

### Step 1/3 · Selfie (`3395:8480`)
- Prompt bubble `3398:17737` (382 wide, ~68 tall): greige pill, padX 12 padY 14,
  radius ~16. Text 257 wide + 44×44 face-id icon on the right.
  - Copy: "1/3 - Start with a selfie photo. No need to be perfect, you can change it later."
  - Icon: `hugeicons:face-id` (outline). **NOT in assets** → fallback to existing
    `Icons.User` (closest) OR omit. See asset gap below.
- Bottom button group `3516:19610` (h145): single full-width outline **"Take photo"**
  pill (h56, radius 100) with a small camera glyph trailing the label.
- Footer caption centered: "Your photos are always kept private" — Inter xs 12/16,
  muted. → `uacBodyXsRegular` (Inter 12/16). Color muted greige
  `figmaOnboardingStepLabel` (#9e968e).

### Step 2/3 · Full body (`3395:9006`)
- Adds: selfie thumbnail bubble (right-aligned 96×127 3:4, radius ~12) above a second
  prompt bubble.
  - Copy: "2/3 - Add a full-body photo. Optional, but it helps Macgie understand
    proportions and styling better." (Macgie = the assistant persona; keep as-is.)
  - Icon: `ion:body-outline`. **NOT in assets** → fallback `Icons.Body`.
- Bottom button group `3516:19584` (h145): **two** controls in a row —
  "Skip this step" (text + plus glyph, left) and "Take photo" (outline pill, right).
- Same privacy footer.

### Step 3/3 · Body shape (`3395:9248`)
- Adds: fullbody thumbnail bubble (right) + bodyshape prompt bubble.
  - Copy: "3/3 - Choose the shape that feels most like you. Tap to expand"
- Then 3 silhouette option tiles inline (`Frame 2009` → `Frame 2007`, three
  124.67 × 166.22 3:4 image instances, gap ~4). Tapping any opens the expanded
  full-screen picker modal.
- Footer (`3395:9271`): sticky bottom band w/ privacy caption (no buttons in the
  collapsed state — selection happens in the expanded modal).

### Body-shape picker expanded (`3398:17745` → `noti` `3398:17798`)
- Full-screen sheet over a dim scrim (`Rectangle 346` 414×897). Header "See this on me".
- `Basic Dialog` `3398:17800`: "Choose the shape that feels most like you." headline
  (Inter SemiBold 14/20, centered) + a large 3:4 silhouette image `3398:17855`
  (382 × 509) + a 3-dot pagination indicator `Frame 2124` (active dark, inactive
  greige — `figmaChipBg` / `figmaDotInactive`, same as AU-303 pager).
- Button group `3516:18764` (h108): **Retake** (text, left) + **Use this photo**
  (filled dark pill, right).

### Your outfit preview (`3398:17581`)
- Header "Self visualization" (menu+download glyphs in Figma; we use chevron-back).
- `Frame 2167` `3398:17689`: full-bleed rendered try-on image `3398:17635`
  390 × 520 (3:4-ish, 12px side inset), radius ~16.
- Button group `3516:19701` (h164):
  - `3539:21391` filled-outline pill **"Back to home"** (327 wide, h56).
    NOTE: Figma button is outline-style (white bg, dark border) here, not filled.
  - Row `3516:19705`: 44×44 **checkbox** `3516:19706` + caption "Use this photo for
    future outfit previews" (Inter xxs 10/12 muted).

## Tokens used (all resolve to existing `theme.ts` — NO new tokens needed)

| Figma var | Value | theme.ts token |
|---|---|---|
| background/primary/subtle_50 | #f2efec | `colors.figmaBackground` |
| color/primary/100 (#eee6df) | greige | `colors.figmaCaptionPillBg` (prompt-bubble bg) |
| text/neutral/base | #1d1f23 | `colors.uacTextBase` |
| text/primary/bold_400 | #9e968e | `colors.figmaOnboardingStepLabel` (privacy footer + caption) |
| background/primary/bold_600 | #262421 | `colors.figmaButton` / `figmaAction` (filled pill, active dot) |
| icon/primary/subtle_300 | #c6bcb1 | `colors.figmaDotInactive` (inactive pager dot) |
| header bg neutral/subtlest @90% | rgba(255,255,255,0.9) | `colors.figmaItemDetailHeaderBg` |
| card/tile surface | #f2efec | `colors.figmaCardSurface` |
| dimension/16,12,8,4 | 16/12/8/4 | `spacing.m / uacDimension12 / s / xs` |
| border-radius/2xl (16), xl (12), 100 | 16/12/100 | `borderRadius.l / figmaTile / round` |
| body/sm Inter 14/20 | — | `typography.aliases.interMediumSm` / `interBodySm` |
| body/xs, xxs Inter 12/16, 10/12 | — | `typography.aliases.uacBodyXsRegular` / `interCaptionXxs` |
| Button label Poppins Med 16/24 | — | `typography.aliases.poppinsButton` (via PillButton) |

## Icons needed

| Figma icon | Size | In assets? | Decision |
|---|---|---|---|
| `hugeicons:face-id` (selfie prompt) | 44×44 | NO | Fallback `Icons.User` (or omit). ASSET GAP. |
| `ion:body-outline` (fullbody prompt) | 44×44 | NO | Fallback `Icons.Body`. ASSET GAP. |
| `healthicons:body-outline` (step3 prompt) | 24×24 | NO | Fallback `Icons.Body`. ASSET GAP. |
| camera glyph (Take photo trailing) | ~20 | YES | `Icons.Camera`. |
| plus glyph (Skip this step) | ~16 | YES | `Icons.Plus`. |
| back chevron (header) | 20 | YES | `Icons.ChevronLeft`. |
| body silhouettes (picker carousel) | 124×166 | NO (photo instances, not vectors) | Per task: NO SVG assets → use a simple labeled shape option set (pear/hourglass/rectangle/triangle/oval). ASSET GAP — silhouette artwork not exported by design as reusable vectors. |
| checkbox (preview opt-in) | 44×44 | NO dedicated svg | Build a simple square + check using `Icons.Plus`/inline, or a bordered box w/ checkmark via View. |
| download glyph (preview header) | ~24 | NO | OMITTED v1 (open Q). |

## Components — reuse vs new

- **REUSE**: `PillButton` (filled/outline/text), `TopIconButton` (header back),
  `Icons.*`, header pattern from FavouriteScreen, theme tokens, `track()` analytics,
  `bodyService.uploadBody/getBodies`, `tryOnService.generateTryOn`.
- **REUSE w/ caveat**: `OnboardingStepHeader` — task asked to reuse for the
  1/3·2/3·3/3 progress bar, BUT the Figma header on these frames is a *centered-title*
  header with NO 3-segment progress bar; the step indicator is the "1/3 -" / "2/3 -" /
  "3/3 -" textual prefix inside each chat bubble. Following Figma (CEO is designer),
  I use a simple centered-title header and put the step count in the bubble copy.
  → DIVERGENCE from task wording, justified by the design. (Open Q.)
- **NEW**: `SeeThisOnMeScreen` (container + step state machine),
  `StepSelfie`, `StepFullBody`, `StepBodyShape` (+ expanded carousel modal),
  `OutfitPreview`, `use-image-picker` hook (extracted from BodyScreen).

## State machine

`selfie → fullBody → bodyShape → generating → preview`
- Selfie REQUIRED (Take photo → store `selfieUri`, advance).
- Full body OPTIONAL (Take photo → `fullBodyUri`, advance; Skip → advance).
- Body shape: select a shape (`selectedShape`), Use this photo → advance to generating.
- Generating: upload chosen body photo (fullBody ?? selfie) → `body_id`; then
  `tryOnService.generateTryOn`. ~10-20s loader. On error → error+retry, `try_on_failed`.
- Preview: render `composite_url`, opt-in checkbox (local), Back to home → Home.

## Exact generate call wired

```ts
const body = await bodyService.uploadBody(fullBodyUri ? fullBodyAsset : selfieAsset);
const res = await tryOnService.generateTryOn({
  body_id: body.id,
  wardrobe_item_ids: outfit.itemIds,
  gemini_opt_in: true,            // backend rejects anything else with 400
  prompt_params: { body_shape: selectedShape },
});
const url = res.composite_url ?? (res.composite_png ? `data:image/png;base64,${res.composite_png}` : null);
```

## Analytics

- `try_on_started` { outfit_hash, item_count }
- `try_on_step_completed` { step: 'selfie'|'fullBody'|'bodyShape', skipped? }
- `try_on_completed` { outfit_hash, provider }
- `try_on_failed` { outfit_hash, error_kind }

## testIDs

`stom-step-1`, `stom-step-2`, `stom-step-3` (step containers),
`stom-take-photo`, `stom-skip`, `stom-shape-option-<shape>`, `stom-shape-use`,
`stom-shape-retake`, `stom-generate`, `stom-retry`, `stom-preview-image`,
`stom-optin`, `stom-back-home`, `stom-back` (header).

## Open questions for CEO / tech-lead

1. **Header**: design shows a centered-title header (no 3-segment progress bar) +
   "1/3 / 2/3 / 3/3" text prefix in the bubbles. Task asked to reuse
   `OnboardingStepHeader` (which renders a progress bar, no title). I followed Figma
   (title header + textual step prefix). Confirm this is the intended treatment.
2. **Prompt-bubble icons** (`hugeicons:face-id`, `ion:body-outline`,
   `healthicons:body-outline`) and **body-shape silhouettes** are NOT in
   `src/assets/icons/`. Per task instruction I used existing-icon fallbacks
   (`Icons.User` / `Icons.Body`) for prompts and a labeled shape option set for
   the picker. Need the real SVGs exported (figma-icons-sync) for fidelity.
3. **Preview header download glyph** (save image to camera roll) — omitted for v1.
   Want it wired? (would need a save-to-gallery dependency.)
4. **"Use this photo for future outfit previews" opt-in** — no backend preference
   endpoint exists. Stored in local state only for v1; intent left as a `// TODO`.
   Confirm a BE pref endpoint is out of scope for this ticket.
5. **Body-shape `prompt_params.body_shape`** — sent to `/tryon/highres`. Confirm the
   backend accepts/ignores an arbitrary `body_shape` string in `prompt_params`
   (the field is a free-form `Record<string, unknown>` client-side).

## New backend fields (vs current API client)

None — all calls use the existing `bodyService.uploadBody`, `bodyService.getBodies`,
and `tryOnService.generateTryOn` contracts. `prompt_params.body_shape` rides inside
the already-supported free-form `prompt_params` map (see Open Q5 — needs BE confirm
it isn't rejected, but no NEW field/endpoint is required client-side).
</content>
