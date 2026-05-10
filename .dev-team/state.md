# Dev Team State

## Design Spec

### Figma Source
- File key: `0nXXMAR4Arf1ZfjtQvtBh0`
- Node: `470:1122` — SECTION named "onboarding"
- Page: "Hifi-design (RFD)" (`470:1121`)
- Section overview screenshot: https://www.figma.com/api/mcp/asset/83fa70c8-9abd-47a9-b8ad-c9ec924b4ad4

---

### Flow Map — Onboarding Screens

The onboarding section contains **9 frames** arranged in a 2-row canvas layout. They represent a **multi-step sequential flow** plus **variant states** for some steps.

| # | Frame ID | Frame Name | Role in Flow |
|---|----------|------------|--------------|
| 1 | 909:7122 | Welcome Home | Entry / splash screen |
| 2 | 909:7154 | auxi-ask01 | Step 1/3 — Wardrobe type selection (default / unselected) |
| 3 | 1719:17384 | auxi-ask01 | Step 1/3 — Wardrobe type selection (Menswear SELECTED state) |
| 4 | 909:7193 | auxi-ask01-m | Step 2/3 — Fit preference, menswear variant (Classic Fit selected) |
| 5 | 909:7210 | auxi-ask01-w | Step 2/3 — Fit preference, womenswear variant (no selection, disabled CTA) |
| 6 | 909:7227 | auxi-ask01-u | Step 2/3 — Fit preference, unisex/neutral variant (Classic Fit selected) |
| 7 | 909:7130 | Welcome Home | Step 3/3 — Style taste picker (swipeable outfit cards) |
| 8 | 1727:19270 | flash-screen | Confirmation flash — "Your wardrobe is ready." |
| 9 | 1783:11535 | flash-screen | Closing flash — Motivational quote + "See my outfit" CTA |

**Canonical user journey:**
Screen 1 → Screen 2 (with 3 as its selected-state variant) → Screen 4/5/6 (gender-variant, same question) → Screen 7 → Screen 8 → Screen 9 → Home

---

### Cross-Cutting Tokens

#### Frame Dimensions
- All frames: **414 × 896 px** (matches iPhone 14 Pro / 390pt logical width at 1x; 414 is the Figma canvas width — likely targeting 390pt in implementation)
- `border-radius` on frames: `18px` (screen-level rounding, decorative in Figma)
- Safe-area: Status bar implied at top (header component starts at y=0; top content inset is `44px` from Figma's safe-area reference)

#### Typography
All fonts are **Poppins** (heading) and **Poppins / Inter** (body). The Figma variable defs show font family as `Poppins` for both heading and body; some nodes reference `Inter` — this appears to be a font-family inconsistency in the Figma file (see Open Questions).

| Token Name | Family | Size | Weight | Line Height | Letter Spacing |
|---|---|---|---|---|---|
| `H1/Bold` | Poppins | 40px | 700 | 52px | -0.72px |
| `H2/Bold` | Poppins | 32px | 700 | 40px | -0.64px |
| `Text-md/Semibold` | Poppins | 16px | 600 | 24px | 0px |
| `Text-md/Medium` | Poppins | 16px | 500 | 24px | 0px |
| `Text-md/Regular` | Poppins | 16px | 400 | 24px | 0px |
| `Text-xs/Regular` | Poppins/Inter | 12px | 400 | 16px | 0px |
| `Text-xxs/Regular` | Poppins/Inter | 10px | 400 | 12px | 0px |
| Image card label (Manrope) | Manrope | 8px | 500 | 24px | 0.15px |
| Step counter label | Inter | 12px | 400 | 16px | 0px |

Note: Image card bottom labels (`Slim Fit`, `Classic Fit`, `Menswear` etc.) use **Manrope Medium 8px** — a third font family. This is distinct from the Poppins design system and likely intentional for the micro-label treatment.

#### Colors
| Token | Value | Usage |
|---|---|---|
| `background/primary/neutral_50` | `#fcfcfd` | Default screen background (Screens 1, 2, 3, 6, 7) |
| `background/primary/subtle_50` | `#f2efec` | Image card backgrounds, Screen 1 logo area |
| `color/primary/100` | `#eee6df` | Flash screen backgrounds (Screens 8, 9) |
| `light surface` | `#f7f7f8` | Screen 5 (auxi-ask01-w) background — slightly cooler |
| `background/neutral/base` | `#1d1f23` | Primary CTA button fill (dark/black) |
| `background/primary/bold_600` | `#262421` | Disabled CTA button fill (dark warm brown) |
| `background/primary/bold_500` | `#5b5550` | Chips (flash screen), selected-state border ring |
| `text/neutral/base` | `#1d1f23` | Primary text (headings, body) |
| `text/primary/base` | `#f2efec` | Text on dark buttons |
| `text/neutral/subtle_600` | `#ffffff` | Text on enabled dark button (white) |
| `text/primary/bold_400` | `#9e968e` | Step counter "Step X/3" label |
| `text/primary/subtle_100` | `#eee6df` | Chip labels on flash screen |
| `color/neutral/50` | `#fcfcfd` | Image card label text |
| `color/neutral/black/Alpha300` | `rgba(18,18,18,0.75)` | Image card label pill background (default) |
| `rgba(39,42,50,0.9)` | — | Image card label pill background (alternate / darker — used in Screens 4, 6) |
| `border/primary/bold_500` | `#5b5550` | Selected card border ring (4px) |
| `border/neutral/base` | `#1d1f23` | Header component border (decorative, 1px) |

#### Spacing Scale (variables used)
| Token | Value |
|---|---|
| `S` | 4px |
| `M` | 8px |
| `ML` | 12px |
| `XL` | 16px |
| `3XL` | 32px |
| `body` | 24px |
| `dimension/4` | 4px |
| `dimension/12` | 12px |
| `dimension/16` | 16px |

#### Border Radius
| Token | Value | Usage |
|---|---|---|
| `border-radius/xl` | 12px | Image cards |
| `border-radius/sm` | 6px | Chips |
| Button CTA (primary) | 16px | Dark full-width button |
| Button CTA (text/ghost) | 100px (pill) | Skip / text buttons |
| Image card label pill | top-left 8px, top-right 8px | Pill label at card bottom |
| Header back button | — | 45×45px square tap target |

---

### Screen 1 — Welcome / Entry Screen

**Node ID:** `909:7122`
**Frame name:** `Welcome Home`
**Screenshot (embedded in get_design_context):** Light, centered, minimal.

#### Layout
- Background: `#fcfcfd`
- No header/back button — this is the first screen
- Centered single-column layout (absolute positioning in Figma)
- Content vertically centered around y≈467 (title), y≈571 (subtitle), y≈783 (button)

#### Elements (top to bottom)
1. **Logo / Brand Mark** (node `909:7126`)
   - Asset: `imgFrame2048` — SVG/PNG of the "auxi" wordmark-plus-knot logo
   - Dimensions: 155.976 × 76px (in Figma); absolute positioned at left=50%−78px, top=256px
   - Color: black on white background (logo itself is dark)

2. **Title** (node `909:7124`)
   - Copy: `"Welcome to\nauxi"` (two lines; "auxi" is lowercase)
   - Font: Poppins Bold 40px / lh 52px / ls -0.72px
   - Color: `#1d1f23`
   - Alignment: center
   - Width: 382px container, centered on screen
   - Top: 467px (centered on container)

3. **Subtitle** (node `909:7123`)
   - Copy: `"Get outfit suggestion\nthat work for your day."`
   - Font: Poppins Regular 16px / lh 24px / ls 0px
   - Color: `#1d1f23`
   - Alignment: center
   - Width: 382px container, centered
   - Top: 571px

4. **Primary CTA Button** (component `470:2206`)
   - Copy: `"Get started — takes 1 min"`
   - Background: `#1d1f23`
   - Text: `#f2efec` (cream white), Poppins Medium 16px / lh 24px
   - Width: 327px, Height: 56px
   - Border radius: 16px
   - Position: centered, top ≈ 783px (50% + 322px)
   - State shown: Enable (no disabled variant visible)

#### Interaction States
- No step indicator, no back button, no skip
- CTA is always enabled (user hasn't done anything yet)

---

### Screen 2 — Step 1/3: Wardrobe Type (Default / Unselected)

**Node ID:** `909:7154`
**Frame name:** `auxi-ask01`

#### Layout
- Background: `#fcfcfd`
- Header at top: 414×107px, contains back button (`<`) at y=44px
- Content starts at y=121, left=22px, width=370px
- Step indicator + progress bar: at top of content area
- Photo grid below: 2-up top row + 1 card bottom-left
- CTA button at bottom: centered, y ≈ 50% + 366px ≈ 814px

#### Elements (top to bottom)
1. **Header** (node `1717:17308`)
   - Height: 107px (includes status bar space)
   - Border: 1px `#1d1f23` (bottom border on header container — likely a Figma annotation artifact, verify in implementation)
   - Back button: 45×45px tap target, left side, top=44px

2. **Step Counter** (node `1783:11432`)
   - Copy: `"Step 1/3"`
   - Font: Inter Regular 12px / lh 16px
   - Color: `#9e968e` (muted warm gray)

3. **Progress Bar** (node `1783:11425`)
   - Visual: 3-segment segmented bar, width=370px
   - Active segment: 1/3 filled (leftmost segment is dark, other two are light)
   - Asset: rendered as an image in Figma (`imgFrame2042`)
   - Height: appears as a thin line (~6px visual height), absolute positioned at inset [-3px, 0, 0, 0]
   - Gap between step counter and bar: 12px

4. **Heading** (node `909:7158`)
   - Copy: `"What's your wardrobe like?"`
   - Font: Inter Semi Bold 16px / lh 24px / ls 0px (note: token says Poppins but node references Inter — see Open Questions)
   - Color: `#1d1f23`
   - Gap below step counter block: 32px (`3XL`)

5. **Sub-heading** (node `909:7159`)
   - Copy: `"No judgment. Just so we know what to work with."`
   - Font: Inter Regular 12px / lh 16px
   - Color: `#1d1f23`
   - Gap from heading: 0px (tight stack)

6. **Photo Grid** (node `909:7160`)
   - Gap from heading block: 32px (`3XL`)
   - Gap between cards: 4px

   **Row 1 — 2 equal cards side by side**
   - Each card: `flex: 1`, aspect ratio 3:4, rounded 12px
   - Background: `#f2efec`
   - **Card A — Womenswear** (node `909:7162`):
     - Assets: trousers (`SYS_BT_TRS_BLK_WID_01`), bag (`SYS_AC_BAG_BLK_SHO_01`), shirt (`SYS_L2_SHR_WHT_FEM_01`), heels (`SYS_SH_HEL_BLK_PNT_01`)
     - Label pill: "Womenswear", dark overlay `rgba(18,18,18,0.75)`, h=19px, bottom of card, borderRadius top 8px
     - Default state: no selection indicator
   - **Card B — Menswear** (node `909:7170`):
     - Assets: chinos (`SYS_BT_CHI_BGE_SLM_01`), shirt (`SYS_L2_SHR_WHT_SLM_01`), loafers (`SYS_SH_LOA_BLK_LEA_01`), blazer (`SYS_L3_BLZ_NVY_REG_01`)
     - Label pill: "Menswear"
     - Default state: no selection indicator

   **Row 2 — 1 card (bottom-left)**
   - **Card C — Mixed** (node `909:7179`): 183×244px (fixed size, not flex), rounded 12px
   - Assets: cargos (`SYS_BT_CRG_GRN_OVS_01`), high-top sneakers (`SYS_SH_SNK_BLK_HIG_01`), tee (`SYS_L2_TEE_BLK_OVS_01`), denim jacket (`SYS_L3_DNM_BLU_OVS_01`), cap (`SYS_AC_CAP_NVY_BAS_01`)
   - Label pill: "Mixed"

7. **Primary CTA Button**
   - Copy: `"Continue"`
   - State: **Disabled** — `background/primary/bold_600` (`#262421`), opacity 50%, text `#f2efec`
   - Same dimensions as Screen 1 button (327×56px, radius 16px)
   - Position: bottom, centered

#### Selection State (Screen 3 — node `1719:17384`)
This is the same screen with **Menswear selected**:
- Selected card gets: `border: 4px solid #5b5550`, no opacity change
- Unselected cards: `opacity: 0.5`
- CTA button switches to **Enabled** state: `background/neutral/base` `#1d1f23`, text `#ffffff`
- Missing step counter / progress bar on this variant (node `1719:17384`) — the container starts at y=126 with no step counter block above, suggesting this variant was sketched without the full header treatment. Treat screen 2 (909:7154) as canonical.

---

### Screen 4 — Step 2/3: Fit Preference (Menswear variant)

**Node ID:** `909:7193`
**Frame name:** `auxi-ask01-m`

#### Layout
Same structural template as Step 1: header → step counter → progress bar → heading/sub → photo grid → CTA.

#### Elements
1. **Step Counter**: `"Step 2/3"`, same style as above (#9e968e, Inter Regular 12px)
2. **Progress Bar**: 2/3 segments filled
3. **Heading**: `"How do you like things to fit?"`
4. **Sub-heading**: `"Think about the pieces you reach for without thinking"`
5. **Photo Grid**:
   - Same 2-up + 1 card layout
   - **Card A — Slim Fit** (unselected, `opacity: 0.5`): Shows a slim-fit model outfit
   - **Card B — Classic Fit** (selected, `border: 4px solid #5b5550`): Shows a model in blue shirt + chinos
   - **Card C — Relaxed Fit** (unselected, `opacity: 0.5`): Shows a relaxed knit outfit
   - Label font on selected card: Inter Regular 10px / lh 12px / `#fcfcfd` (xxs token)
   - Label font on unselected cards: Manrope Medium 8px / `white` / `rgba(39,42,50,0.9)` overlay
6. **CTA**: `"Continue"` — **Enabled** (dark `#1d1f23`, text white)

---

### Screen 5 — Step 2/3: Fit Preference (Womenswear variant)

**Node ID:** `909:7210`
**Frame name:** `auxi-ask01-w`

#### Differences from Screen 4
- Background: `#f7f7f8` (slightly cooler white — `light surface` token)
- No header component with back button; back button is a raw tap target (`inset: 5.02% 80.68% 89.96% 8.45%`)
- No step counter / progress bar visible in this frame (heading starts at y=133 directly)
- **Heading**: `"Which fit makes you feel most confident?"`
- **Sub-heading**: `"This will be Auxi's starting point. You can switch up your style anytime."`
- Photo content: womenswear fit photos — Slim Fit, Classic Fit (striped top + grey trousers), Relaxed Fit (denim shirt)
- All 3 cards: **no selection** (no border ring, no opacity dimming — all cards shown at full opacity)
- CTA: **Disabled** state (`#262421` at 50% opacity)
- No `Step X/3` label or progress bar — this appears to be an earlier or alternate design pass (see Open Questions)

---

### Screen 6 — Step 2/3: Fit Preference (Unisex/Neutral variant)

**Node ID:** `909:7227`
**Frame name:** `auxi-ask01-u`

#### Differences from Screen 4/5
- Background: `#fcfcfd`
- No header component with back button — same raw tap target approach as Screen 5
- No step counter / progress bar
- **Heading**: `"Which fit makes you feel most confident?"` (same as Screen 5)
- **Sub-heading**: `"This will be Auxi's starting point. You can switch up your style anytime."`
- **Card A — Slim Fit**: opacity 0.5, unselected
- **Card B — Classic Fit**: selected, `border: 4px solid #5b5550`
- **Card C — Relaxed Fit**: opacity 0.5, unselected
- CTA: **Enabled** dark button, text color `#eee6df` (primary/subtle_100 — slightly warm off-white instead of pure white)

---

### Screen 7 — Step 3/3: Style Taste Picker (Swipe Cards)

**Node ID:** `909:7130`
**Frame name:** `Welcome Home`

#### Layout
- Background: `#fcfcfd`
- Header: 414×107px with back button

#### Elements
1. **Step Counter**: `"Step 3/3"`, `#9e968e`, Inter Regular 12px
2. **Progress Bar**: 3/3 segments filled (all active)
3. **Heading**: `"Which of these feels most like you?"`
   - Font: Inter Semi Bold 16px / lh 24px
4. **Sub-heading**: `"Pick up to two. Your taste is rarely just one thing."`
   - Font: Inter Regular 12px / lh 16px
5. **Outfit Card (Swipeable)**: Single large card centered
   - Container: 336px wide, column layout
   - Card: 328×474px, bg `#f2efec`, rounded 16px
   - Contains layered outfit images: white tee (`tops_tshirt_white_regular_f3_w1`) + light blue jeans (`bottoms_jeans_lightblue_straight_f3_w3`) + white sneakers (`shoes_sneaker_white_low_f4_w3`)
   - Images positioned absolutely within card, overlapping (collage/flat-lay style)
6. **Pagination Dots** (node `1783:11473`)
   - Visual: 5 dots/segments in a row
   - Asset: `imgFrame2043` — rendered as image, centered below card
   - Width: full container minus 80px H padding (so within ~200px center area)
   - Dot 1 (active): dark/filled; Dots 2–5: light/outlined
   - Height: ~6px visual
7. **Button Group** (node `1783:11508`)
   - Contains 2 buttons stacked, gap 8px (`M`)
   - Total width: 361px, padded 16px H
   - Position: top ≈ 749px

   **Button A — "Love this"** (Secondary with icon, node `I1783:11508;821:1267`):
   - Style: outlined, `border: 1.5px solid #1d1f23`
   - No fill background
   - Text: `"Love this"` + heart icon, Poppins Medium 16px / lh 24px
   - Text color: `#262421`
   - Height: 56px (via padding 16px top/bottom), rounded 16px
   - Width: full flex (`max-w: 327px`)
   - Icon: heart SVG (`imgVector`), 16×14px

   **Button B — "Skip"** (Text button, node `I1783:11508;472:2051`):
   - No border, no background
   - Text: `"Skip"`, Poppins Medium 16px / lh 24px
   - Color: `#1d1f23`
   - Height: 56px (padding only), rounded 100px (pill)
   - Width: 327px

---

### Screen 8 — Flash: "Your wardrobe is ready."

**Node ID:** `1727:19270`
**Frame name:** `flash-screen`

#### Layout
- Background: `#eee6df` (color/primary/100 — warm beige)
- No header, no navigation
- Content block at: left=54px, top=302px (bottom-left aligned, not centered)
- No CTA button visible in this frame

#### Elements (top to bottom within content block)
1. **Preference Chips** (node `1783:11602`)
   - Chips shown: `"Womenswear"`, `"Classic Fit"`, `"Minmal"` [sic], `"Street style"`
   - Chip style: bg `#5b5550`, border-radius 6px, h=32px, px=12px, py=8px
   - Text: Inter Regular 12px / `#eee6df`
   - Chips wrap horizontally, gap 8px between
   - This is a **result summary** showing the user's choices back at them

2. **Heading** (node `1727:19377`)
   - Copy: `"Your wardrobe\nis ready."`
   - Font: Poppins Bold 32px / lh 40px / ls -0.64px (H2/Bold token)
   - Color: `#000000` (pure black, not the `#1d1f23` token)
   - No width constraint (whitespace-nowrap)
   - Gap from chips: `16px` (`XL` token)

3. **Body Copy** (node `1783:11555`)
   - Copy: `"56 pieces, chosen for you. The more you use Auxi, the better it gets."`
   - Font: Poppins Regular 16px / lh 24px
   - Color: `#000000`
   - Width: 311px

- Gap between heading and body: 0px (tight stack in content block)

---

### Screen 9 — Flash: Motivational Quote + "See my outfit"

**Node ID:** `1783:11535`
**Frame name:** `flash-screen`

#### Layout
- Background: `#eee6df`
- No header
- Quote block positioned at center-left (left=50%−148px, y=416px vertically centered)
- Bottom sheet: white panel anchored at bottom (bottom=−58px, appears to slide up)

#### Elements
1. **Quote Text** (node `1783:11541`)
   - Copy: `'" One small step\nis enough."'` (opening quote mark on its own line, then two text lines)
   - Font: Poppins Bold 40px / lh 35px (line-height is less than font-size — tight/condensed feel)
   - Note: line-height of 35px is unusual; the `mb-[16px]` between paragraphs creates vertical rhythm
   - Letter spacing: -0.72px (H1 token)
   - Color: `#000000`
   - Left-aligned, not centered

2. **Bottom Action Sheet** (node `1783:11542`)
   - Background: `#fcfcfd`
   - Width: 414px, Height: 169px
   - Border radius: top-left 16px, top-right 16px (rounded top corners only)
   - Position: bottom, offset -58px (appears partially hidden, slides up on animation)
   - Padding: 24px H, 24px V

   **CTA inside sheet** — `"See my outfit"` (Text button with icon, node `I1783:11545;472:2050`):
   - Text: `"See my outfit"` + arrow/pointing icon (`imgVector` + `imgVector1`)
   - Font: Poppins Medium 16px / lh 24px
   - Color: `#1d1f23`
   - No background, no border (text button)
   - Height: 56px (padded), rounded 100px
   - Icon: compound SVG icon (2 vectors), 24×24px hit area

---

### Component Inventory

#### Button Component (`470:2206` family)
| Variant | Fill | Text Color | Border | Opacity | Radius |
|---|---|---|---|---|---|
| Primary / Enable | `#1d1f23` | `#ffffff` | none | 1.0 | 16px |
| Primary / Disable | `#262421` | `#f2efec` | none | 0.5 | 16px |
| Secondary / Enable (outlined) | none | `#262421` | 1.5px `#1d1f23` | 1.0 | 16px |
| Text button / Enable | none | `#1d1f23` | none | 1.0 | 100px (pill) |
| Text button + icon / Enable | none | `#1d1f23` | none | 1.0 | 100px (pill) |

All buttons: height 56px, Poppins Medium 16px, horizontal padding 20–24px.

#### Progress Bar (Step Indicator)
- 3 segments, equal width, gap between segments
- Active: dark fill (`#1d1f23` or similar)
- Inactive: light warm beige fill (matching `#f2efec` or similar)
- Visual height: ~6px
- Total width: matches content container width (370px)
- In Figma: rendered as an asset image — implementer must build as a native component

#### Image Card (Selectable)
- Background: `#f2efec`
- Border radius: 12px (xl token)
- Default: no border, no opacity modifier
- Selected: 4px solid border `#5b5550`, full opacity
- Unselected (when another is selected): `opacity: 0.5`
- Label pill: bottom of card, centered, rounded-top corners (8px), h=19px
  - Default overlay: `rgba(18,18,18,0.75)` OR `rgba(39,42,50,0.9)` depending on screen
  - Text: 8–10px, white/cream
- Tap target: full card area

#### Back Button
- Size: 45×45px tap target
- Visual: `<` chevron icon (SVG asset)
- Position: top-left of header area, top=44px (below status bar)

#### Preference Chip (Screen 8 only)
- Height: 32px
- Padding: 12px H, 8px V
- Background: `#5b5550`
- Border radius: 6px
- Text: Inter Regular 12px, `#eee6df`

---

### Interaction / Animation Hints

No explicit prototype connections are visible from the Figma data alone. However the design strongly implies:
- **Forward navigation**: tap CTA to advance; each step screen uses the same template
- **Back navigation**: back button (`<`) in header
- **Step 3 card mechanic**: swipe left/right between outfit cards (the pagination dots confirm multiple cards exist); "Love this" = like, "Skip" = pass
- **Screen 8**: appears to be a transition/interstitial — no CTA, content is a summary. Likely auto-advances or has an implied tap-anywhere behavior
- **Screen 9 bottom sheet**: the `bottom: -58px` offset suggests a **slide-up animation** on entry — the sheet enters from below
- No explicit swipe-to-navigate between the step screens is indicated; navigation is tap-CTA only

---

### Designer Review

_(To be filled after implementation)_
