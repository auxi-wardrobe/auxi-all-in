# Figma Extraction — New Onboarding Flow

> READ-ONLY extraction artifact (Phase 1). No code written. Source of truth for the
> `figma-to-rn-workflow` implementation that follows.

- **Figma file:** "Auxi" — fileKey `0nXXMAR4Arf1ZfjtQvtBh0`
- **Section node:** `2849:8331` ("onboarding") — 4531×4402, contains 17 frames
- **URL:** https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-8331&m=dev
- **Extracted:** 2026-05-26 by mobile-dev
- **Frame canvas:** 414×896 (iPhone-ish). Body content column = 370–382 wide, left inset 16–22.

---

## 1. Screen inventory (17 frames → 8 distinct screen types)

The section holds 17 frames, but many are duplicates/branch variants of the same
template. Distinct **screen types** = 8. The flow is **3 numbered steps + intro/outro**.

| # | Frame name | node-id | Role | Notes |
|---|---|---|---|---|
| 1 | Welcome Home | `2849:8332` | Intro splash | "Welcome to auxi" + Get-started CTA. No header/back. |
| 2 | onboarding \| choose wardrobe | `2849:8339` | **Step 1/3** | Wardrobe gender: Womenswear / Menswear / Mixed (3 tiles). |
| 2b | onboarding \| choose wardrobe | `2850:13995` | Step 1/3 (dup) | Pixel-identical duplicate of `2849:8339`. Likely artboard copy. |
| 3 | onboarding \| menswear \| choose fit | `2849:8423` | **Step 2/3** | Fit: Slim / Regular / Relaxed. Has selected + disabled states baked in. |
| 3b | onboarding \| womenswear \| choose fit | `2849:8443` | Step 2/3 (branch) | Same template, womenswear copy variant + different headline. |
| 3c | onboarding \| mixed \| choose fit | `2849:8460` | Step 2/3 (branch) | Same template, mixed branch. |
| 4 | onboarding \| other options | `2849:9748` | **Step 3/3** (no pin) | Style picker, 5 tiles. Base state, nothing pinned. |
| 4-pin | onboarding \| other options | `2849:9883` | **Step 3/3** (pinned) | Same screen, 2 tiles pinned (numbered pin badges 1 & 2) + selected borders. Sticky bottom "(2/3) Next" bar. |
| 4w | onboarding \| other womenswear \| styles | `2849:9793`, `2849:9838` | Step 3/3 (branch dups) | Womenswear style-picker variants. |
| 5 | Loading onboarding | `2849:8477` | Processing | "You selected" chips + "Your MACGIE wardrobe **will be** ready" + loading rows. |
| 6 | completed onboarding | `2849:8498` | Done | Same as Loading but "**is** ready" + no loading rows; single CTA. |
| 7 | welcome screen | `2849:8510` | Outro quote | "One small step is enough." + bottom sheet "See my outfit" CTA. |
| — | notebox / pointerNote | `2849:8516` | Helper annotation | "Popup to ask user for accessing the location permission." Design note, NOT a screen. |

### Branch logic (inferred — confirm with CEO)
Step 1 wardrobe choice (Womenswear / Menswear / Mixed) drives which **Step 2 fit**
and **Step 3 styles** branch renders. The three Step-2 frames and the womenswear
Step-3 frames are the same template with branch-specific copy/imagery. **One RN
screen per step**, parameterised by the chosen wardrobe — not three separate screens.

---

## 2. Flow sequence

```
1. Welcome Home  ──[Get started — takes 1 min]──►
2. Step 1/3  Choose wardrobe (Womenswear | Menswear | Mixed)  ──[Continue]──►
3. Step 2/3  Choose fit (Slim | Regular | Relaxed)            ──[Continue]──►
4. Step 3/3  Choose styles (pick up to 2, pinned + numbered)  ──[(n/3) Next]──►
5. Loading   "Your MACGIE wardrobe will be ready" (Analyzing… / Building…)
6. Completed "Your MACGIE wardrobe is ready"                  ──[CTA]──►
7. Welcome   "One small step is enough."                      ──[See my outfit]──► Home
```

- **Back nav:** Steps 1–3 carry a `header` instance (h107) with a single back arrow
  top-left (45×45 tap target, glyph inset). Welcome Home, Loading, Completed and
  the outro quote screen have **no back** affordance.
- **Progress:** Steps 1–3 show a 3-segment progress bar (`Frame 2042`, three `Line`s)
  + "Step n/3" label above it. Loading/Completed have no progress bar.
- **Skip:** No skip affordance anywhere in this flow.
- **Location-permission popup:** the `notebox / pointerNote` annotates that a native
  location-permission prompt is expected somewhere in this flow (matches the existing
  `LocationPermissionScreen`). Placement not pinned in this Figma — OPEN QUESTION.

---

## 3. Per-screen specs

### 3.1 Welcome Home (`2849:8332`)
- bg `#fcfcfd` (background/primary/neutral_50), screen radius 18 (artboard only).
- Logo mark `Frame 2048` (image asset, ~156×76) centered, top 256.
- Title "Welcome to auxi" — Poppins **Bold 40 / 52**, letter-spacing −0.72, centered,
  color `#1d1f23`. Two visual lines ("Welcome to" / "auxi").
- Subtitle "Get outfit suggestion that work for your day." — Poppins **Regular 16 / 24**,
  centered, `#1d1f23`. (Copy has a grammar slip — "suggestion that work" — flag to CEO.)
- CTA: Primary button, text **"Get started — takes 1 min"**, 327×56, radius 16,
  bg `#1d1f23`, label `#f2efec`, Poppins Medium 16/24. Positioned ~bottom (50% + 322).

### 3.2 Step 1/3 — Choose wardrobe (`2849:8339`)
- Header (back only). Content column x22, top121, w370, vertical gap 4.
- "Step 1/3" — **Inter Regular 12/16**, color `#9e968e` (text/primary/bold_400).
- Progress bar `Frame 2042` (3 segments, image-rendered hairline; first segment active).
- Section title "What's your wardrobe like?" — **Inter SemiBold 16/24**, `#1d1f23`,
  center-aligned. Block is `text-center`.
- Section subtitle "No judgment. Just so we know what to work with." — **Inter Regular 12/16**.
- Title→grid gap = 32 (3XL token).
- **Tiles grid** (`Frame 2009`, gap 4):
  - Row 1: two tiles side-by-side (Womenswear, Menswear), each `aspect 3/4`, flex 1.
  - Row 2: single tile (Mixed), 183×244.
  - Tile: bg `#f2efec` (background/primary/subtle_50), radius **12** (border-radius/xl),
    contains a product image + bottom-center caption pill.
  - Caption pill: bg `rgba(18,18,18,0.75)` (color/neutral/black/Alpha300), radius 8,
    padX 12, h19; label Inter Regular **10/12** (Text-xxs), color `#fcfcfd`.
- CTA: **Disabled** primary "Continue" — bg `#262421` (border/primary/bold_600) @ 50%
  opacity, label `#f2efec`. (Disabled because nothing selected yet.)

### 3.3 Step 2/3 — Choose fit (`2849:8423` menswear; branches `2849:8443` w, `2849:8460` mixed)
- Same header + progress (2nd segment active) + title block layout as Step 1.
- "Step 2/3", title "How do you like things to fit?", subtitle "Think about the pieces
  you reach for without thinking." (Inter SemiBold 16 / Inter Regular 12.)
- **Womenswear branch** title differs: "Which fit makes you feel most confident?" /
  subtitle "This will be Auxi's starting point. You can switch up your style anytime."
- Tiles: Slim Fit, Regular Fit, Relaxed Fit (2 + 1 layout), 3/4 ratio, radius 12, bg `#f2efec`.
- **States baked into this frame (important — these are the tile states to implement):**
  - **Unselected** (Slim, Relaxed): tile `opacity 0.5`, caption pill bg `#262421`
    (border/primary/bold_600) or `rgba(39,42,50,0.9)`.
  - **Selected** (Regular): full opacity + **4px solid border `#262421`** around the
    Media, caption pill bg `rgba(18,18,18,0.75)`.
- CTA: **Enabled** primary "Continue" (bg `#1d1f23`, label white). Confirms enabled
  state once a fit is chosen.

### 3.4 Step 3/3 — Choose styles (`2849:9748` base; `2849:9883` pinned; womenswear `2849:9793`)
- Header + progress (3rd segment active). Content full-width container px16, top121, h588.
- "Step 3/3", title "Which of these feels most like you?", subtitle "Pick up to two.
  Your taste is rarely just one thing." (Inter SemiBold 16 / Inter Regular 12.)
- **6 style tiles**, 3/4 ratio, radius 12, bg `#f2efec`, 2-per-row + 1 trailing.
  Captions seen: Minimal, Classic, Casual, Soft, Bold (+ more in womenswear branch).
- **Multi-select, max 2** (per copy). Selection visuals:
  - Selected tile: **4px solid border `#1d1f23`** (border/neutral/base).
  - **Pin badge** top-right of selected tile: 34×34 container, `Rectangle 105` vector
    (rounded badge, looks like a teardrop/pin), with order number ("1", "2") inside,
    Inter Regular 12/16, label `#f2efec`. Number = selection order.
- **Sticky bottom bar** (`Frame 2129` / `2849:9932`): translucent
  `rgba(255,255,255,0.6)` + **backdrop-blur 2px**, h157, anchored bottom.
  Contains a **Secondary** button: 1.5px border `#1d1f23`, transparent fill, radius 16,
  label "(2/3) Next" — the "2" is the live count, "/3)" is the max — Poppins Medium 16,
  color `#1d1f23`, + trailing chevron icon (24, `Path 3391` = chevron-right rotated).
  NOTE: the in-flow non-sticky `button group` (`2849:9925`) is `hidden=true` — the
  sticky blurred bar is the real CTA.

### 3.5 Loading onboarding (`2849:8477`)
- bg `#eee6df` (color/primary/100). NO header.
- Content block left54, top231, w306, gap 16.
- "You selected" — Poppins Regular 16/24, black.
- **Selected chips** (`Frame 2089`, wrap, gap 8): chip bg `#5b5550` (background/primary/bold_500),
  radius **6** (border-radius/sm), padX12 padY8, h32, label Inter Regular 12/16 color
  `#eee6df`. Sample chips: Womenswear, Classic Fit, Minmal *(sic)*, Street style.
- Helper "Don't worry you can change later in you profile setting" — Inter Regular 12/16, black.
  *(Copy typo "in you profile" — flag to CEO.)*
- Big headline "Your MACGIE wardrobe will be ready." — Poppins **Bold 32/40**, ls −0.64
  (H2/Bold), black. *("MACGIE" reads like a placeholder/codename — confirm intended copy.)*
- Footer line "The more you use Auxi, the better it gets." — Poppins Regular 16/24, black.
- **Loading rows** (`Frame 2121`, top611): two rows, each centered text + 24×24 spinner
  icon (`streamline-ultimate:loading`). Text Poppins Regular 16/24 color `#7a7f89`
  (text/neutral/subtle_200): "Analyzing your style…" and "Building your wardrobe…".
- **Button group** (bottom): primary "Next" with trailing chevron — **disabled @ 50%**
  (bg `#1d1f23`, label `#eee6df`) + a **Text button "Retake"** (no fill, radius 100,
  label `#1d1f23`). Next is disabled while loading.

### 3.6 Completed onboarding (`2849:8498`)
- Identical layout to Loading EXCEPT:
  - Headline "Your MACGIE wardrobe **is** ready." (present tense).
  - NO loading rows (`Frame 2121` absent).
  - Button group present (CTA now enabled). bg `#eee6df`.

### 3.7 Welcome screen / outro (`2849:8510`)
- bg `#eee6df` (color/primary/100). NO header.
- Quote ""One small step is enough."" — Poppins **Bold 40**, ls −0.72, black,
  left-ish (left calc(50%−148)), line-height ~35 with 16 gaps between lines.
- **Bottom sheet** (`Frame 2033/2512`): bg `#fcfcfd`, top corners radius 16, h169,
  padding 24, anchored bottom (overshoots viewport bottom by −58).
  - Hidden helper text (`2849:8514`, hidden=true): "Light layers keep things comfortable,
    and neutral tones make this easy to wear and match." (not rendered — context only.)
  - CTA: **Text button** "See my outfit" — no fill, radius 100, label `#1d1f23`,
    Poppins Medium 16/24, + leading/trailing eye-or-view icon (24, two `Vector` glyphs).

---

## 4. Tokens used vs `auxi/src/theme/theme.ts`

### 4.1 Colors

| Figma var | Hex | In theme.ts? | Mapping / action |
|---|---|---|---|
| background/primary/neutral_50 | `#fcfcfd` | ❌ | NEW. Onboarding screen bg. Closest existing = `uacBackgroundNeutralSubtlest`/`uacBackgroundNeutral50` = `#fcfcfd` — **same hex, reuse it** (rename-alias, don't add dupe). |
| text/neutral/base | `#1d1f23` | ✅ | = `uacBackgroundBase`/`uacBorderBase`/`uacTextBase` (`#1d1f23`). Reuse `uacTextBase`. |
| text/primary/base | `#f2efec` | ✅ | = `uacTextPrimaryBase` (`#f2efec`). Reuse. |
| border/primary/bold_600 | `#262421` | ✅ | = `figmaCtaLabel` (`#262421`). Reuse. (Used for disabled CTA bg + selected-tile border on Step 2.) |
| background/primary/subtle_50 | `#f2efec` | ✅ | = `figmaBackground`/`figmaCardSurface` (`#f2efec`). Reuse. Tile bg. |
| color/neutral/black/Alpha300 | `#121212bf` (rgba(18,18,18,0.75)) | ✅ | = `figmaCardTag` (`rgba(18,18,18,0.75)`). Reuse. Caption pill bg. |
| color/primary/100 | `#eee6df` | ✅ | = `figmaCaptionPillBg`/`figmaFooterActivePill`/`figmaListDivider` (`#eee6df`). Reuse. Loading/outro screen bg. |
| color/neutral/50 | `#fcfcfd` | ❌→ | same as neutral_50 above; reuse `#fcfcfd` alias. Caption pill label color. |
| text/primary/bold_400 | `#9e968e` | ❌ | **NEW token needed.** "Step n/3" label + muted greige. No theme equivalent. Propose `figmaOnboardingStepLabel` / `colorPrimaryBold400`. |
| border/neutral/base | `#1d1f23` | ✅ | = `uacBorderBase`. Reuse. Selected-tile 4px border on Step 3. |
| background/primary/bold_500 | `#5b5550` | ❌ | **NEW token needed.** Selected-chip bg (Loading/Completed). No equivalent. Propose `figmaChipBg` / `colorPrimaryBold500`. |
| text/primary/subtle_100 | `#eee6df` | ✅ | = `#eee6df` family (figmaCaptionPillBg etc). Reuse. Chip label + disabled-CTA label on cream bg. |
| text/neutral/subtle_200 | `#7a7f89` | ✅ | = `uacBorderBold200`/`uacTextSubtle200` (`#7a7f89`). Reuse. Loading-row text. |
| color/neutral/white/Alpha200 | `#ffffff99` (rgba(255,255,255,0.6)) | ❌ | **NEW token needed.** Step 3 sticky-bar translucent bg. Propose `figmaOnboardingStickyBarBg`. (Also needs backdrop-blur 2 — RN: BlurView or low-fi solid fallback.) |
| background/primary/bold_700 | `#070707` | ✅ | = `figmaTextDark` (`#070707`). Reuse (appears in step-3 var set). |
| background/overlay/dark/10 | `#8271371a` | ❌ | NEW but appears unused on rendered layers; likely a hidden-group artifact. SKIP unless surfaced. |
| icon/neutral/base | `#1d1f23` | ✅ | = `uacTextBase`. Reuse. Back-arrow/chevron tint. |
| icon/primary/base | `#f2efec` | ✅ | = `uacTextPrimaryBase`. Reuse. Disabled-CTA chevron tint on dark. |
| rgba(39,42,50,0.9) | — | ❌ | One-off on a Step-2 caption pill (`#272A32` @ 90%). `figmaText`/`figmaAction` = `#272A32` exists. Likely a design inconsistency vs the `rgba(18,18,18,0.75)` pill used elsewhere — **flag: which pill color is canonical?** |

**Drift summary:** 4 genuinely NEW colors to add (`#9e968e`, `#5b5550`,
`rgba(255,255,255,0.6)`, + reuse-alias `#fcfcfd`). Everything else maps to existing
tokens (mostly the `uac*` and `figma*` families). One inconsistency (caption pill
`0.75` vs `0.9`) to resolve.

### 4.2 Typography

Onboarding uses **TWO families**, split by role:
- **Poppins** — headings (H1 40/52 ls −0.72, H2 32/40 ls −0.64) and all **button labels**
  (Medium 16/24) + intro/loading body (Regular 16/24).
- **Inter** — in-step **content**: "Step n/3" (Regular 12/16), section titles
  (SemiBold 16/24), subtitles (Regular 12/16), tile caption pills (Regular 10/12),
  chips (Regular 12/16), pin numbers (Regular 12/16).

theme.ts status:
- Poppins H1 40/52 → ✅ `uacH1Bold` (Poppins-Bold 40/52). letter-spacing −0.72 NOT in alias — add or apply inline.
- Poppins H2 32/40 ls −0.64 → ✅ `poppinsTimeLg` (Poppins-Bold 32/40 ls −0.64). Reuse.
- Poppins Medium 16/24 (buttons) → ✅ `uacBodyMdMedium`/`poppinsButton` (Poppins-Medium 16/24). Reuse.
- Poppins Regular 16/24 (body) → ✅ `uacBodyMdRegular`/`poppinsBody` (Poppins-Regular 16/24). Reuse.
- Inter SemiBold 16/24 (section title) → ⚠️ `uacBodyMdSemibold` exists but is **Inter-SemiBold 16/24** — MATCHES. Reuse.
- Inter Regular 12/16 (Step label, subtitle, chip) → ✅ `uacBodyXsRegular` (Inter-Regular 12/16). Reuse.
- Inter Regular 10/12 (Text-xxs, caption pill) → ❌ **NEW.** No 10/12 Inter alias exists.
  Propose `interCaptionXxs` (Inter-Regular 10, lineHeight 12).
- Inter Medium 12/16 → `uacBodyXsMedium` exists if needed (not seen rendered).

**Typography drift summary:** 1 NEW alias needed (`interCaptionXxs` 10/12). All other
roles map to existing `uac*`/`poppins*` aliases. Confirm fonts Poppins + Inter are both
bundled (Inter is used by the UAC flow, Poppins broadly — both should be present; verify
in `react-native.config.js` / `assets/fonts`).

### 4.3 Spacing / radius

| Figma | px | theme.ts | Action |
|---|---|---|---|
| dimension/4 (S) | 4 | `spacing.xs`=4 | reuse |
| dimension/8 | 8 | `spacing.s`=8 / `uacDimension8` | reuse |
| dimension/12 (ML) | 12 | `uacDimension12`=12 | reuse |
| dimension/16 (XL) | 16 | `spacing.m`=16 / `uacDimension16` | reuse |
| 3XL | 32 | `spacing.xl`=32 | reuse |
| body padding | 24 | `uacBodyPadding`=24 | reuse |
| border-radius/xl | 12 | `figmaTile`=12 | reuse (tile radius) |
| border-radius/sm | 6 | ❌ (closest `s`=4, `m`=8) | **NEW radius needed** for chips: add `chip:6`. |
| button radius | 16 | `borderRadius.l`=16 / `uacButtonCta`=16 | reuse |
| pill/sheet radius | 16 | `uacPanel`=16 | reuse |
| text-button radius | 100 | `round`=9999 / `uacRadioPill`=100 | reuse (`uacRadioPill`). |
| screen radius | 18 | `uacScreen`=18 | reuse (artboard chrome only; not a real RN screen prop). |
| header height | 107 | `uacHeaderHeight`=107 | reuse |
| button height | 56 | `uacButtonHeight`=56 | reuse |

**Spacing/radius drift:** 1 NEW radius (`6` for chips). Everything else maps.

---

## 5. Components / variants

- **Button** (`470:2206` primary / `470:2294` disabled / `821:1267` secondary-icon /
  `472:2050` & `472:2051` text-button). Variants seen across the flow:
  - Primary/Enable/56 — bg `#1d1f23`, label `#f2efec`, radius 16. ("Get started", "Continue", "See my outfit"… wait no, that's text).
  - Primary/Disable/56 — bg `#262421` @ 50% opacity. (Step 1 Continue, Loading Next.)
  - Secondary/Enable/Icon/56 — 1.5px border `#1d1f23`, transparent, trailing chevron. (Step 3 "(n/3) Next".)
  - Text button/Enable/56 — no fill, radius 100. ("Retake", "See my outfit").
  - → Maps to existing `auxi/src/components/primitives` button primitive if one exists;
    otherwise this is the canonical onboarding button. **Implement all 4 variants + states.**
- **header** (`864:1313`) — h107, back arrow only (45×45), top inset 45. Shared across steps 1–3.
- **chip** (`1783:11593`, state=selected size=S) — selected-style chip, bg `#5b5550`,
  radius 6. Used in Loading/Completed "You selected" cluster.
- **button group** (`821:1347`) — wrapper that lays out primary + secondary/text buttons,
  gap 12, padX 16, w361.
- **Image 3:4 tile** — recurring 3/4 card primitive: bg `#f2efec`, radius 12, centered
  product image, bottom-center caption pill. States: default / selected (4px border) /
  disabled (opacity 0.5) / pinned (border + numbered pin badge). Maps conceptually to the
  existing `OnboardingSelectionCard.tsx` primitive — **review whether to extend it**.
- **pin** (`2849:9901`) — 34×34 numbered badge (vector `Rectangle 105` + order number).

---

## 6. Icons / SVG audit

Existing icons live in `auxi/src/assets/images/*.svg` (re-exported via
`src/assets/icons/index.ts`). Onboarding icon needs:

| Icon (Figma) | node | Exists in auxi? | Action |
|---|---|---|---|
| Back arrow (header `Back` 45×45) | `864:1315` (`imgBack`) | Partial — `icon_chevron_left.svg` exists | Verify the Figma back glyph matches `icon_chevron_left`; if it's a distinct arrow, export `icon_onboarding_back.svg`. |
| Chevron-right (Next button trailing, `Path 3391`) | various | ✅ `icon_chevron_right.svg` / `icon_arrow_right.svg` | Reuse one; confirm which matches the thin chevron. |
| Loading spinner (`streamline-ultimate:loading`, 24×24) | `2849:8491` | ❌ NONE | **NEW SVG** — export `icon_loading.svg` (currentColor, viewBox 0 0 24 24). Will need RN rotation animation. |
| Pin badge shape (`Rectangle 105`) | `2849:9902` | ❌ NONE | **NEW SVG** — export `icon_pin_badge.svg` (the rounded teardrop/pin container) OR render as styled View + number. Recommend View+Text over SVG (number is dynamic). Confirm with CEO/design whether badge is a fixed shape. |
| "See my outfit" leading icon (two `Vector` glyphs, eye/view) | `2849:8515` | ❌ NONE | **NEW SVG** — export `icon_see_outfit.svg` (currentColor). Looks like an eye / view-grid glyph. |
| Logo mark (`Frame 2048`, ~156×76) | `2849:8336` | ? raster image asset, not SVG | This is the auxi wordmark/logo. Check if an existing logo asset covers it; else export. Likely PNG/raster in Figma. |

**Icon SVG export convention:** all new icons → `currentColor` fill, explicit `viewBox`,
filename `icon_<name>.svg`, register in `src/assets/icons/index.ts`.

---

## 6b. Tile image-fill audit (added 2026-05-26 — CEO directive: tiles must show EXACT Figma art)

**Truth check:** EVERY selection tile in Steps 1-3 has a distinct, real raster
flat-lay image fill in Figma — NONE are placeholder rectangles. The earlier
"centered product image" note understated this. Each "Image 3:4" component holds
a hidden `Group` of named garment vectors (`SYS_*`) PLUS a visible flattened
raster (`image NN` on Step 1, `Media` on Steps 2-3) which is what renders. The
raster fills are exportable PNGs via `get_design_context` asset URLs.

| Tile | Step | Figma node | Figma shows | Asset saved (`src/assets/images/onboarding/`) |
|---|---|---|---|---|
| Womenswear | 1 | `2849:8361` (`image 18`) | white shirt + black trousers + bag + heels | `wardrobe-womenswear.png` (1024×1536) |
| Menswear | 1 | `2849:8370` (`image 16`) | navy blazer + tan trousers + loafers + shirt | `wardrobe-menswear.png` |
| Mixed | 1 | `2849:8381` (`image 17`) | denim jacket + tee + cargo + sneakers + cap | `wardrobe-mixed.png` |
| Men · Slim | 2 | `2849:8437` Media | dark turtleneck + slim black jeans + boots | `fit-men-slim.png` (366×488) |
| Men · Regular | 2 | `2849:8438` Media | blue shirt + tan trousers (selected, 4px border) | `fit-men-regular.png` |
| Men · Relaxed | 2 | `2849:8440` Media | cream sweater + loose light jeans | `fit-men-relaxed.png` |
| Women · Slim | 2 | `2849:8451` Media | women slim flat-lay | `fit-women-slim.png` |
| Women · Regular | 2 | `2849:8452` Media | women regular flat-lay | `fit-women-regular.png` |
| Women · Relaxed | 2 | `2849:8454` Media | women relaxed flat-lay | `fit-women-relaxed.png` |
| Mixed · Slim/Reg/Relax | 2 | `2849:8468/8469/8471` | mixed flat-lays (Figma label slip = "common") | `fit-mixed-{slim,regular,relaxed}.png` |
| Minimal | 3 | `2849:9763` Media | white tee + light jeans + sneakers | `style-men-minimal.png` (600×900) |
| Casual | 3 | `2849:9772` Media | black tee + cap + jeans + sneakers | `style-men-casual.png` |
| Soft | 3 | `2849:9776` Media | tan sweater + tan trousers + espadrilles | `style-men-soft.png` |
| Bold | 3 | `2849:9781` Media | graphic tee + leather jacket + black + boots | `style-men-bold.png` |
| Formal | 3 | `2849:9767` Media (Figma label "Classic") | white shirt + grey trousers + brown shoes | `style-men-formal.png` |

**UPDATE 2026-05-27 (mobile-dev) — Step 3 style art is now PER-WARDROBE.**
The original ship had ONE style set (menswear) for all wardrobes — a
Womenswear/Mixed user wrongly saw men's outfits. Extracted the missing
Womenswear (frame `2849:9793`) + Mixed (frame `2849:9838`, Figma-named "other
womenswear" but sits at the mixed-row position = unisex/utility blend) sets and
re-keyed art by wardrobe, mirroring the Step-2 `fit` pattern. Tiles in visual
order [Minimal, Classic→`Formal`, Casual, Soft, Bold]:

| Wardrobe | Style | Figma tile node (Media raster) | Asset (600×900, alpha) |
|---|---|---|---|
| Womenswear | Minimal | `2849:9807` | `style-women-minimal.png` |
| Womenswear | Formal (label "Classic") | `2849:9811` | `style-women-formal.png` |
| Womenswear | Casual | `2849:9816` | `style-women-casual.png` |
| Womenswear | Soft | `2849:9820` | `style-women-soft.png` |
| Womenswear | Bold | `2849:9825` | `style-women-bold.png` |
| Mixed | Minimal | `2849:9852` | `style-mixed-minimal.png` |
| Mixed | Formal (label "Classic") | `2849:9856` | `style-mixed-formal.png` |
| Mixed | Casual | `2849:9861` | `style-mixed-casual.png` |
| Mixed | Soft | `2849:9865` | `style-mixed-soft.png` |
| Mixed | Bold | `2849:9870` | `style-mixed-bold.png` |

Existing menswear set renamed `style-{X}.png` → `style-men-{X}.png`. All 18
style+wardrobe rasters downsized 1024×1536 → 600×900 (tile displays ~180pt, 600px
is ample @3x; alpha preserved — garments sit on a transparent ground so the tile
cream surface shows as inset margin). Dir `src/assets/images/onboarding/` 15M → 11M.
`styleTileArt(value)` → `styleTileArt(wardrobe, value)` (config.ts), wired in
OnboardingStylesScreen via the route's already-threaded `wardrobe_direction`.

**LABEL RECONCILIATION (flag for qa-ui + CEO):** Figma Step-3 base shows
**Minimal / Classic / Casual / Soft / Bold**. The backend `StyleTag` enum
(`v05Api.ts`, authoritative wire vocabulary) is **Minimal / Casual / Soft /
Bold / Formal** — it has `Formal` where Figma drew "Classic", and no "Classic".
Mapping used: each config value → its visually-matching Figma flat-lay; the
`Formal` option reuses Figma's "Classic" tile (white shirt + tailored trousers
+ dress shoes — closest visual to "Formal"). Asset renamed `style-classic.png`
→ `style-formal.png` to match the config value. CEO to confirm "Classic" vs
"Formal" is intended.

**Option-value → asset mapping** lives in `src/onboarding/config.ts`
(`TILE_ART` + `wardrobeTileArt` / `fitTileArt` / `styleTileArt` resolvers).
Wired into `OnboardingSelectionFigure` (existing primitive, extended with
`inset` + `resizeMode` props) on all three v2 screens. Image specs: 3:4 tiles,
`resizeMode="contain"`, inset ~9.5% V / 10% H so the cream `figmaCardSurface`
shows as margin per Figma "Image 3:4". Selected (4px border) / dimmed (0.5
opacity) / pin-badge states preserved on the card, drawn over the image.

---

## 7. Cross-check against existing auxi onboarding

CLAUDE.md notes an **onboarding redesign in progress** (PreferenceSeed → FitPreference →
OutfitApproval → OnboardingConfirmation) but the entry still points at legacy
`GenderPreference → StylePreference`. Existing screens found:
`AppWelcomeScreen`, `LocationPermissionScreen`, `GenderPreferenceScreen`,
`StylePreferenceScreen`, `StylePickerScreen`, `OutfitCanvasScreen`.

**This Figma flow maps roughly to:**
- Welcome Home → `AppWelcomeScreen` (redesign).
- Step 1 wardrobe → `GenderPreferenceScreen` data (gender/wardrobe = Women/Men/Mixed).
- Step 2 fit → fit-preference (new — no exact existing screen; closest is the redesign's `FitPreference`).
- Step 3 styles → `StylePreferenceScreen` / `StylePickerScreen` (style_direction, pick-2).
- Loading + Completed + Outro → new confirmation screens (`OnboardingConfirmation`-ish).

⚠️ **Do NOT delete legacy screens.** Per CLAUDE.md the swap-vs-keep decision is a pending
**product decision** — escalate before wiring this flow as the live entry point.

⚠️ **`src/onboarding/config.ts` does NOT currently exist** despite the CLAUDE.md
convention. Implementation must CREATE it and put all copy/artwork there (gender labels,
fit labels, style labels, step headlines, chip text, loading-row text, quote) — no inline
strings. There is an `OnboardingSelectionCard.tsx` primitive to reuse/extend.

---

## 8. New backend fields / data needs

No new endpoints obviously required — this is preference capture (gender/wardrobe, fit,
style_direction ×2) which the existing onboarding already persists via
`AuthContext.completeOnboarding`. BUT confirm:
- Does the backend accept **wardrobe = "Mixed"** as a gender/wardrobe value? Legacy
  `GenderPreference` may only support binary. **Escalate to tech-lead/backend-dev.**
- Does it accept **two** style_direction values (pick-up-to-2)? Multi-select styles may
  need a list field, not a single enum. **Escalate.**
- "Fit" (Slim/Regular/Relaxed) — is there a field for this today? If not, it's a
  **new preference field → backend change → tech-lead.** Check `docs_agent/` for the
  onboarding/preferences contract before writing the client.

---

## 9. Open questions for the designer (CEO) / tech-lead

1. **"MACGIE wardrobe"** — placeholder/codename or real copy? Appears in Loading +
   Completed headlines. Likely meant to be dynamic ("Your wardrobe…") — confirm.
2. **Copy typos:** "Get outfit suggestion that work for your day" (subject/verb),
   "in you profile setting", "Minmal" chip, "Building your wardrobe…"" (stray quote).
   Confirm final copy (will live in `config.ts`).
3. **Caption-pill color inconsistency:** most tiles use `rgba(18,18,18,0.75)`; one
   Step-2 disabled tile uses `rgba(39,42,50,0.9)`. Which is canonical?
4. **Pin badge shape** — fixed SVG, or styled View+number? (Number is the selection
   order, so dynamic.) Confirm visual + max count (copy says "up to two").
5. **Branch behaviour** — is Step 2/Step 3 truly one screen parameterised by wardrobe
   choice (Women/Men/Mixed), or are the 3 frames intentionally distinct flows?
6. **Location permission** — where in the flow does the native prompt fire? The
   `pointerNote` annotation references it but no frame pins the placement.
7. **Backend contract** — Mixed wardrobe value, two style picks, and a new "fit" field:
   does the current `/api` preferences contract support these? (See §8 — tech-lead.)
8. **Loading screen mechanics** — is "Loading" a real async wait (recommendation
   pre-warm?) with Next disabled until done, then auto-advance to Completed? Or a timed
   splash? Confirm the gating logic.
9. **Step 1 duplicate frames** (`2849:8339` vs `2850:13995`) — identical; confirm one is
   the canonical artboard (ignore the dup).
10. **Welcome Home logo** — is there an existing logo asset to reuse, or export from Figma?
11. **letter-spacing on H1** (−0.72) is not in the `uacH1Bold` alias — add to alias or
    apply inline? (Consistency call.)

---

## 10. Summary of theme.ts changes the impl will need (for `figma-theme-sync`)

NEW tokens (4 colors, 1 type alias, 1 radius):
- `colors`: `#9e968e` (step label / primary bold_400), `#5b5550` (chip bg / primary bold_500),
  `rgba(255,255,255,0.6)` (sticky-bar bg). Plus reuse-alias for `#fcfcfd` (neutral_50)
  if not treating `uacBackgroundNeutral50` as the canonical name.
- `typography.aliases`: `interCaptionXxs` = Inter-Regular 10 / lineHeight 12.
- `borderRadius`: `chip` = 6.

REUSE (no change): `#1d1f23`, `#f2efec`, `#262421`, `#eee6df`, `#7a7f89`, all spacing,
button/panel/round radii, Poppins H1/H2/Medium/Regular aliases, Inter SemiBold/Regular aliases.

→ When implementing, run `figma-theme-sync` to diff and add ONLY the genuinely-new tokens;
do not duplicate existing hexes under new names.
