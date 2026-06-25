# Figma Extraction — Home outfit grid layouts (variable item count)

- **Figma file**: `0nXXMAR4Arf1ZfjtQvtBh0` (Auxi)
- **Component source-of-truth**: `Grid card layouts` component set (variants `2 / 3 / 5 / 6 / >6`) + `swipe card` instance (used by the "4 items" / Home-1/3 frame).
- **Extracted**: 2026-06-14 by mobile-dev (recon only, no code changes).
- **Frame canvas size**: every frame is **414 × 896** (header 107h at top, footer 84h at y=812).
- **Status of this artifact**: pending `qa-ui` review-extraction Pass 1.

> NOTE on mapping: the CEO listed `node 2850:9125` as the "4 items" frame.
> That frame is actually named **"Home 1/3"** and contains a **`swipe card`**
> instance (a 3-page horizontal carousel of full grid layouts), NOT a static
> 4-item grid. Its default page renders a 2×2 (4-item) grid, so the spec below
> treats the **4-item layout = 2×2** as confirmed, but the carousel wrapper is
> a discrepancy to resolve (see Open Questions Q1).

---

## Shared tokens (all frames)

From `get_variable_defs` on the frames:

| Figma var | Value | auxi theme token (existing) |
|---|---|---|
| `background/primary/subtle_50` | `#f2efec` | `theme.colors.figmaCardSurface` ✅ |
| `color/primary/100-#EFE9E3` | `#eee6df` | `theme.colors.figmaCaptionPillBg` ✅ |
| `color/primary/200-#DED5CC` | `#e0d2c4` | `theme.colors.figmaInsightPillBg` ✅ |
| `color/neutral/800-#1D1F23` | `#1d1f23` | `theme.colors.uacTextBase` ✅ |
| `color/neutral/50-#FCFCFD` | `#fcfcfd` | (rarity badge text) — `uacBackgroundNeutral50` ✅ |
| `color/neutral/black/Alpha300` | `#121212bf` (75%) | rarity-badge bg — **no exact token** (see Q4) |
| `background/overlay/light/30` | `#ffffff4d` (white 30%) | pin-badge bg — **no exact token** (see Q4) |
| `border-radius/md` | `8` | pin badge radius |
| `border-radius/xl` | `12` | card radius → `theme.borderRadius.figmaTile` ✅ |
| `dimension/12 - 0_75 rem` | `12` | grid container horizontal padding + row vgap |
| `body/sm` | 14 / lh16 / Inter 400 | caption pill text |
| `body/xxs` | 10 / lh12 / Inter 400 | rarity ("common") + pin label text |

**Spacing scale present in design**: 4, 8, 12 (gap=4 between tiles; container px=12, py=8; outer block vgap=12).

### Card primitive (every tile, all counts)
- `aspect-[3/4]` (w/h = 0.75) OR explicit `w/h` for fixed-size slots.
- `bg = #f2efec` (figmaCardSurface), `border-radius/xl = 12`, `overflow: hidden`.
- **Pin badge** (top-right): `right: 9, top: 8`, **size 34×34**, `border-radius/md = 8`
  (rounded square, NOT a circle), bg `rgba(255,255,255,0.30)`, shadow `4 4 5.3 rgba(7,7,7,0.05)`,
  inner icon 17×17. (Variant `pinned` swaps to white bg + "Tap to unpin" label pill.)
- **Rarity badge** ("common"): bottom-center, `bottom: 8`, h19, px12 py0, `border-radius 8`,
  bg `rgba(18,18,18,0.75)`, text 10px `#fcfcfd` centered.

### Grid container (the `Grid card layouts` component)
- `flex-col`, `gap: 12` (between the caption-row block and the grid block), `px: 12, py: 8`, `w: 414`.
- **Caption row** (top): horizontal, gap 4 →
  - caption pill: bg `#eee6df`, `px12 py8`, `radius 54`, text "Clean. Ready for today" 14px.
  - insight pill: bg `#e0d2c4`, `h40`, `px12 py8`, `radius 23`, `carbon:idea` icon 16×16.
- **Grid body**: `flex-col`, **gap 4** (row gap). Each row is `flex-row`, **gap 4** (column gap).

> KEY: the grid body uses **gap 4** for BOTH row and column gaps. The **12** is
> only the container horizontal inset + the caption↔grid vertical gap. Content
> width therefore = 414 − 2×12 = **390**.

---

## Per-count layout specs

### Case: 2 items — `node 3230:35149` (grid instance `3230:35901`, variant "2")

**Layout rule**: Item 0 is **FULL WIDTH** (aspect 3:4, w = full 390). Item 1 is a
**fixed small card 127.3 × 169.733** that drops to the NEXT row, left-aligned
(in a vertically-stacked, items-start column). Footer is **dimmed**.

Frame tree:
```
Grid card layouts (px12 py8, gap12)
└─ caption row (pill + insight pill)
└─ grid body (flex-col, items-start)         ← single column wrapper
   └─ col (flex-col, gap4, items-center)
      ├─ Image 3:4  — FULL WIDTH, aspect 3:4, radius12
      └─ Image 3:4  — 127.3 × 169.733 (fixed), radius12
```

| Property | Value |
|---|---|
| Outer container px / py | 12 / 8 |
| Content width | 390 (414 − 24) |
| Item 0 | full width (390), aspect 3:4 → ~520h |
| Item 1 | fixed 127.3 × 169.733 (3:4), left-aligned, on its own row |
| Inner gap (between item0 and item1) | 4 |
| Card radius | 12 |
| Footer | **dimmed** — footer instance `3230:35156` renders the nav at reduced opacity (inner nav `opacity-85`, blur backing `opacity-80`). CEO note says "50%". Visually the 2-item footer reads dimmer than the others. See Q3 — confirm exact target opacity. |

---

### Case: 3 items — `node 2850:9613` (grid instance `3227:18826`, variant "3")

**Layout rule**: 2 equal columns, 2 rows. Row 1 = 2 real items. Row 2 = 1 real
item (left) + 1 **opacity-0 placeholder** (right) to hold the column. So the lone
3rd item is **left-aligned**, NOT centered.

Frame tree:
```
grid body (flex-col, gap4, items-start)
├─ row (flex-row, gap4): [Image flex-1] [Image flex-1]
└─ row (flex-row, gap4): [Image flex-1] [Image flex-1 opacity-0]
```

| Property | Value |
|---|---|
| Columns | 2, each `flex-1 min-w-0` |
| Each tile | aspect 3:4, half width = (390−4)/2 = **193** |
| Row gap / col gap | 4 / 4 |
| Row 2, col 2 | real placeholder cell with `opacity-0` (item3 stays LEFT) |

---

### Case: 4 items — `node 2850:9125` ("Home 1/3" → `swipe card` `3788:10956`, default page)

**Layout rule**: clean **2×2 grid**, all four tiles `flex-1` aspect 3:4. Below the
grid this frame ALSO shows `Remix · dots · Show another` controls
(`buttons under card` instance `3788:9511`) and a sticky **"Wear this"** CTA.

Frame tree (one carousel page):
```
grid body (flex-col, gap4, items-start)
├─ row (flex-row, gap4): [Image flex-1] [Image flex-1]
└─ row (flex-row, gap4): [Image flex-1] [Image flex-1]
```

| Property | Value |
|---|---|
| Columns × rows | 2 × 2, all `flex-1` |
| Each tile | aspect 3:4, half width = 193 |
| Row gap / col gap | 4 / 4 |
| Extra chrome below grid | "Remix ✂ / page-dots / Show another" row + "Wear this ♥" CTA |
| Carousel | `swipe card` holds 3 pages (left −414 / center 0 / right +414) — horizontal swipe between outfit variants |

---

### Case: 5 items — `node 2850:9580` (grid instance `3227:18976`, variant "5")

**Layout rule**: HERO + STACK row, then a 3-col bottom row with the 3rd cell
`opacity-0`. Row 1 is `justify-end`: a big hero card on the LEFT (258.5 × 343.5)
+ a right column of **2 stacked small cards** (127.3 × 169.733 each, gap 4). Row 2
= 3 columns (`flex-1`), col 3 is an `opacity-0` placeholder.

Frame tree:
```
grid body (flex-col, gap4, items-center)
├─ row (flex-row, gap4, justify-end)
│  ├─ hero  258.5 × 343.5 (fixed)
│  └─ stack col (flex-col, gap4, self-stretch, justify-center)
│     ├─ small 127.3 × 169.733
│     └─ small 127.3 × 169.733
└─ row (flex-row, gap4, justify-center)
   ├─ Image flex-1 (aspect 3:4)
   ├─ Image flex-1 (aspect 3:4)
   └─ small 127.3 × 169.733  ← opacity-0 placeholder
```

| Property | Value |
|---|---|
| Hero | 258.5 × 343.5 (≈ 66% of 390) |
| Stack cards | 127.3 × 169.733 ×2, internal gap 4 |
| Hero row gap | 4 (hero ↔ stack) |
| Bottom row | 3× `flex-1`, last is `opacity-0` |
| Row gap | 4 |
| Math | 258.5 + 4 + 127.3 = 389.8 ≈ 390 ✓ |

---

### Case: 6 items — `node 2850:9508` (grid instance `3227:19147`, variant "6")

**Layout rule**: identical hero+stack row as 5-item, but the bottom row's 3rd
cell is now a **visible** fixed small card (127.3 × 169.733), so all 3 bottom
tiles render.

Frame tree:
```
grid body (flex-col, gap4, items-center)
├─ row (flex-row, gap4, justify-end): hero 258.5×343.5 + stack[ small, small ]
└─ row (flex-row, gap4, justify-center): [flex-1] [flex-1] [small 127.3×169.733 visible]
```

| Property | Value |
|---|---|
| Top row | same as 5-item (hero + 2-stack) |
| Bottom row | item3 `flex-1`, item4 `flex-1`, item5 fixed 127.3×169.733 (visible) |
| Gaps | 4 / 4 |

> Note: bottom row mixes 2 `flex-1` tiles + 1 fixed-width tile. The fixed tile is
> narrower than the flex tiles, so the bottom row is NOT 3 equal columns — it's
> 2 wide + 1 narrow. (Visible in `frame_6items` screenshot.)

---

### Case: >6 items (scrollable) — `node 2850:9542` (grid instance `3227:19318`, variant ">6")

**Layout rule**: same hero+stack top row as 5/6, then **multiple** 3-col rows
(each `[flex-1] [flex-1] [fixed 127.3 small]`) stacked until all items render. The
grid (759h) **exceeds the 896 frame past the footer** → content scrolls. Shown
with 9 items = hero(1) + stack(2) + 2 rows × 3 = 9. No truncation, no "+N" badge.

Frame tree:
```
grid body (flex-col, gap4, items-center)
├─ row: hero + stack[ small, small ]
├─ row: [flex-1] [flex-1] [small fixed]
├─ row: [flex-1] [flex-1] [small fixed]
└─ … repeat 3-col rows for every additional 3 items
```

| Property | Value |
|---|---|
| Top row | hero 258.5×343.5 + 2-stack (same as 5/6) |
| Each extra row | 3 cols: 2× `flex-1` + 1× fixed 127.3 small |
| Rows | `ceil(restCount / 3)` after the hero row |
| Overflow | grid scrolls under/over footer (frame grid h=759 > viewport) |
| Gaps | 4 / 4 |

---

## Spacing table (consolidated)

| Count | Layout shape | Full-width item? | Tile sizing | Outer px / py | Item gap (r/c) |
|---|---|---|---|---|---|
| 2 | full + small-drop | **YES (item0 full 390)** | item1 = 127.3×169.733 fixed | 12 / 8 | 4 / — |
| 3 | 2×2, R2C2 invisible | no | each = 193 (flex-1, 3:4) | 12 / 8 | 4 / 4 |
| 4 | 2×2 (in swipe-card) | no | each = 193 (flex-1, 3:4) | 12 / 8 | 4 / 4 |
| 5 | hero + 2-stack, R2 of 3 (C3 invisible) | no | hero 258.5×343.5; small 127.3×169.733; bottom flex-1 | 12 / 8 | 4 / 4 |
| 6 | hero + 2-stack, R2 of 3 (all visible) | no | hero + small + bottom (2 flex + 1 fixed) | 12 / 8 | 4 / 4 |
| >6 | hero + 2-stack, N×(3-col) rows, scroll | no | hero + small + rows of (2 flex + 1 fixed) | 12 / 8 | 4 / 4 |

**Constant for every count**: outer horizontal inset **12** (not 16), tile gap
**4**, card radius **12**, card bg `#f2efec`, pin badge **34×34 r8**, rarity badge
bottom-center.

---

## Icons needed

| Icon | Size | Status |
|---|---|---|
| `carbon:idea` (insight bulb) | 16×16 | Already on Home insight pill (verify exact asset; currently rendered in caption row). |
| pin glyph | 17×17 inside 34×34 badge | App uses `icon_home_pin.svg` (rendered at 24×24). Figma inner glyph is 17×17 in a 34 badge — see Q5. |
| `mynaui:grid` (footer toggle) | 24×24 | Footer toggle — already implemented (`HomeViewToggleFooter`). |

No NEW svg exports strictly required for the grid layout work itself (tiles are
photos, not vectors). Pin/insight assets already exist; sizes need reconciling.

---

## Variants / states

- **Pin badge**: `Default` (translucent white) and `pinned` (white bg + "Tap to
  unpin" label). Current app uses an active/inactive color flip + ring instead of
  the label pill — see Q5.
- **swipe card** (4-item frame): 3 carousel pages (prev/current/next). Already
  realized by the app's outfit pager (`OptionSheet` cells in a horizontal FlatList).
- **Footer**: `grid` variant; 2-item frame uses a dimmed footer.

---

## Open questions for CEO / tech-lead

- **Q1 (mapping)**: Node `2850:9125` is "Home 1/3" = a `swipe card` carousel, not
  a static 4-item grid. Confirm: the **4-item layout = 2×2** (as the carousel's
  default page shows), and the carousel/CTA chrome is out of scope for THIS grid
  task (already handled by the existing outfit pager)?
- **Q2 (2-item rule)**: Confirm item0 is truly full-width and item1 is the small
  127.3px card on the next row, left-aligned (per Figma). Current app renders
  2-item as two equal half-width cards (wrong). This is the headline change.
- **Q3 (2-item footer opacity)**: CEO note says "footer 50% opacity". Figma's
  2-item footer instance shows `opacity-85` on the nav row + `opacity-80` on the
  blur backing. Which is authoritative — 50%, or the 80–85% in the file?
- **Q4 (overlay tokens)**: pin-badge bg `rgba(255,255,255,0.30)` and rarity-badge
  bg `rgba(18,18,18,0.75)` have no exact `theme.ts` token. Add
  `figmaPinBadgeOverlay` + `figmaRarityBadgeBg`? (No literal hex in components.)
- **Q5 (pin badge fidelity)**: Figma pin badge = 34×34 rounded-square (r8), glyph
  17×17, translucent-white bg, with a `pinned` label variant. App currently uses
  28×28 circle (r14), 24×24 glyph, color-flip + ring, no label. Match Figma, or
  keep the current app treatment? (Affects testID-bearing pin button.)
- **Q6 (bottom-row asymmetry, 6 / >6)**: bottom rows are 2×`flex-1` + 1×fixed-127
  (narrow), so the 3rd tile is intentionally narrower than the other two. Confirm
  this asymmetry is intended (vs 3 equal columns).
- **Q7 (rarity "common" badge)**: every Figma tile shows a "common" rarity badge.
  The app does not render rarity on Home tiles today. In scope for this redo, or
  decorative-only in Figma?

## New backend fields (vs current API client)

- **Rarity** ("common" badge) — shown on every Figma tile. Not currently consumed
  on Home. If in scope, check whether `src/services/recommendation.ts` /
  item payload exposes a `rarity` field; if not → backend contract gap, escalate
  to tech-lead before rendering it. (Pending Q7.)
- Everything else (item image, id, pin state) is covered by the current contract.

---

## Header & Footer spec

- **Extracted**: 2026-06-14 by mobile-dev (recon only, no code changes) — APPENDED
  to fold in the CEO's two new Header/Footer references.
- **New Figma nodes**:
  - `3230:35155` — `header` instance (414 × 107, at y=0 of the Home frame).
    Main component `1769:10369`.
  - `3230:35156` — `footer` instance (414 × 84, at y=812 of the Home frame).
    Main component `2464:17348`.
  - `3227:26929` — `notebox / pointerNote` annotation "#3" (the CANONICAL doc note
    on the Home frame): **"Header and Footer (sticky)"**.

### CANONICAL note (resolves the footer-opacity open question)

Annotation `3227:26929` text, verbatim:

> **Header and Footer (sticky)**
> **Note:** background **90% opacity** and using **blur effect is 8px**
> Behavior: **sticky**
> Scroll content moves underneath sticky UI

**This supersedes** the earlier Q3 ("50% vs 80–85%") AND the brief's "4px". The
designer's authoritative spec for BOTH header and footer chrome is:
**translucent fill at 90% opacity + 8px backdrop blur, sticky, content scrolls
underneath.** (See "Footer translucency reconciliation" below — the instance's
internal layers use different per-layer numbers; the NOTE is the source of truth.)

### FOOTER spec — `3230:35156` (main `2464:17348`)

Frame tree (from `get_design_context`):
```
footer  (414×84, backdrop-blur 4px, overflow hidden)   data-node-id 2464:17348
├─ blur backing  (430×100, centered)                   3227:13480
│     bg = background/neutral/subtlest (#ffffff), opacity-80, backdrop-blur 7.5px
├─ nav row  (414×84, flex-col, items-center, pt6, opacity-85)  2464:17508
│  └─ active-pill stack  (grid)                         3227:10181
│     ├─ active capsule  (116×56, radius 14)            2464:17314
│     │     bg = background/primary/subtle_100 (#e0d2c4)
│     └─ button cluster  (flex-row, gap 12, ml4 mt4)    3227:11091
│        ├─ grid button  (48×48, radius 11)             2464:17303
│        │     bg = #ffffff, shadow 0 1 1 rgba(0,0,0,0.15)
│        │     └─ mynaui:grid icon 24×24 (ml12 mt12.5)  2464:17304
│        └─ alt button   (48×48, Group32 image)         2464:17306
```

| Property | Figma value |
|---|---|
| Footer total height | **84** (frame). Active pill row sits with **pt 6** inside. |
| Width | 414 (full) |
| Horizontal padding | none on the bar itself; the pill cluster is **centered** |
| Background fill | `background/neutral/subtlest` = **`#ffffff`** |
| Background opacity (NOTE) | **90%** ← canonical (instance backing layer shows 80%) |
| Backdrop blur (NOTE) | **8px** ← canonical (instance: wrapper 4px + backing 7.5px) |
| Top hairline / border | **none** — no stroke on the bar or backing layer. Separation comes purely from the translucent fill + blur over scrolling content. |
| Active capsule | 116 × 56, radius **14**, bg `#e0d2c4` (background/primary/subtle_100) |
| Nav button (each) | 48 × 48, radius **11**, bg `#ffffff`, shadow `0 1 1 rgba(0,0,0,0.15)` |
| Button cluster gap | **12** |
| Icon | `mynaui:grid` **24×24**, color `icon/primary/bold_700` = `#070707` |
| Behavior | **sticky**; content scrolls underneath |

> **Footer token note**: the active capsule in THIS instance is `#e0d2c4`
> (background/primary/subtle_100). The current app token `figmaFooterActivePill`
> is **`#eee6df`** (subtle_200). Mismatch — see Q9.

#### Footer translucency reconciliation (3230:35156 vs the note)
- Instance internals: wrapper `backdrop-blur 4px`; backing layer `opacity 80%` +
  `backdrop-blur 7.5px`; nav row `opacity 85%`.
- Canonical note (`3227:26929`): **90% opacity + 8px blur**.
- **Decision needed (Q8)**: implement to the NOTE (90% / 8px) as the single source
  of truth, treating the per-layer instance numbers as the designer's WIP. Default
  recommendation: follow the note.

### HEADER spec — `3230:35155` (main `1769:10369`)

Frame tree (from `get_design_context`):
```
header  (414×107, backdrop-blur 4px)                   data-node-id 1769:10369
├─ background  (414×108, centered, opacity-90)         3227:25189
│     bg = background/neutral/subtlest (#ffffff)
└─ content bar  (414×107, flex-col, items-center, justify-end, padding 12, bottom 0)  3227:19826
   └─ row  (flex-row, items-center, justify-between, w-full)  3227:19827
      ├─ menu button  (grid; 44×44 surface + icon)     3227:19828
      │     surface 44×44 (Rectangle105, white card)
      │     menu icon 24×24 (ml10 mt10)   "Icons name=menu"  3227:19830
      ├─ weather block  (flex-row, gap 7, items-center)  3227:19831
      │  ├─ weather glyph  35×32                        3227:19832
      │  └─ text col  (flex-col, items-start)           3227:19833
      │     ├─ "32°C"  → "32" Inter SemiBold 12/16 + "°C" 7.74px, color #1d1f23  3227:19834
      │     └─ "Monday" Inter Regular 12/16, color text/neutral/subtle_100 #40444d  3227:19835
      └─ right button  (grid; 44×44 surface + icon 24×24)  3227:19836
            icon = heart (Vector), 24×24 (ml11 mt10)    3227:19838
```

| Property | Figma value |
|---|---|
| Header total height | **107** |
| Width | 414 (full) |
| Padding | **12** all sides (content bar), content bottom-aligned (`justify-end`) |
| Row layout | flex-row, **space-between**, items-center, full width |
| Background fill | `background/neutral/subtlest` = **`#ffffff`** |
| Background opacity | instance shows **90%** (matches the canonical note) |
| Backdrop blur | wrapper **4px** (instance); **8px** per canonical note → use 8 (Q8) |
| Top hairline / border | **none** |
| Left: menu button | 44×44 white card surface, **menu icon 24×24** centered (~ml10 mt10) |
| Center: weather | icon **35×32** + 7px gap + text col; **"32°C"** (12px int + 7.74px °C, SemiBold #1d1f23), **"Monday"** (Inter Regular 12/16, #40444d) |
| Right: action button | 44×44 white card surface, **heart icon 24×24** centered (~ml11 mt10) |
| Behavior | **sticky**; content scrolls underneath |

Tokens (header `get_variable_defs`):
| Figma var | Value | auxi theme token |
|---|---|---|
| `background/neutral/subtlest` | `#ffffff` | `theme.colors.figmaSurface` / `white` ✅ |
| `text/neutral/base` | `#1d1f23` | `theme.colors.uacTextBase` ✅ (temp text) |
| `text/neutral/subtle_100` | `#40444d` | **no exact token** — Q10 (day-name "Monday") |
| `icon/primary/bold_700` | `#070707` | `theme.colors.figmaTextDark` ✅ (footer icons) |
| `icon/neutral/base` | `#1d1f23` | `theme.colors.uacTextBase` ✅ (header icons) |
| `font-family/body` | `Inter` | body font ✅ |
| `body/xs` | 12 / lh16 / Inter, SemiBold(600)+Regular(400) | header temp + day |
| `background/overlay/dark/10` | `#8271371a` (~10%) | menu/right button card shadow base — Q10 |

### How the current code renders Header & Footer today

- **Header** — `auxi/src/screens/HomeScreen.tsx:1308-1353` (JSX) + styles
  `auxi/src/screens/HomeScreen.tsx:2104-2127`:
  - `<SafeAreaView>` root → `<View style={styles.header}>` row
    (`flexDirection:'row'`, `space-between`, **paddingHorizontal: 22**,
    paddingTop 8, paddingBottom 10). **No fixed height**, **no background fill,
    no opacity, no blur** — the header is opaque-on-`figmaBackground`, NOT
    translucent/sticky. It is the FIRST child of the column, NOT absolutely
    positioned, so **content does NOT scroll underneath** it (diverges from the
    "sticky + scroll-underneath" note).
  - Left: `<TopIconButton>` (from `components/primitives/FigmaPrimitives`,
    `home-menu-button`) with `IconHomeMenu` 24×24.
  - Center: `<WeatherWidget>` (`components/features/WeatherWidget.tsx`) — icon
    34px (Figma 35×32), "32°C" Poppins(!) 16px (Figma Inter SemiBold 12),
    "Monday" Poppins 12 (Figma Inter Regular 12). See divergences.
  - Right: `<TouchableOpacity testID=home-heart-toggle[-saved]>` — `heartButton`
    is **45×45, radius 14, white bg** (Figma right button = 44×44 white card).
- **Footer** — `<HomeViewToggleFooter testID="home-footer-view-toggle">` mounted
  at `auxi/src/screens/HomeScreen.tsx:1552-1556`; component =
  `auxi/src/components/features/HomeViewToggleFooter.tsx`:
  - `HOME_VIEW_TOGGLE_FOOTER_HEIGHT = 98` (line 27) — Figma footer is **84**.
    Divergence: code reserves 98, Figma 84.
  - `translucentSurface` = `figmaSurface` (#fff) at **opacity 0.85** (lines
    104-108). Figma/note = **#fff @ 90%**. No blur (comment lines 18-20
    explicitly notes `@react-native-community/blur` is not installed → uses the
    opacity-only fallback).
  - `activeCapsule` = 158×56 radius 14, bg `figmaFooterActivePill` **#eee6df**.
    Figma capsule = **116×56 radius 14, #e0d2c4**. Divergence (size + color).
  - Two tabs (grid + collage), each 66×48 radius 13, white active cell. Figma
    nav buttons = **48×48 radius 11** with shadow. Divergence.
  - It is a normal sibling rendered below the ScrollView (not absolute/sticky),
    so it does NOT overlay scrolling content.

### Divergences from Figma (summary)

| Element | Figma (canonical) | Current code | Action |
|---|---|---|---|
| Header bg/opacity | #fff @ **90%** | none (opaque on bg) | add translucent fill |
| Header blur | **8px** (note) | none | blur dep OR opacity fallback (Q8) |
| Header sticky | **sticky**, scroll underneath | static first child | restructure to overlay (Q11) |
| Header height | **107** | unset (content-driven) | set min height 107 |
| Header padding | **12** | paddingH **22**, pT8/pB10 | reconcile to 12 (Q12) |
| Temp/day font | **Inter** 12/7.74 | **Poppins** 16/12 | switch family + sizes (Q13) |
| Right/menu button | 44×44 white card | 45×45 / TopIconButton | minor size reconcile |
| Footer bg opacity | **90%** | **85%** | bump to 0.90 |
| Footer blur | **8px** | none | blur dep OR fallback (Q8) |
| Footer height | **84** | **98** | reconcile (Q14) |
| Footer active capsule | 116×56 #e0d2c4 | 158×56 #eee6df | size + color fix (Q9) |
| Footer nav button | 48×48 r11 +shadow | 66×48 r13 | size/radius fix |
| Footer sticky overlay | scroll underneath | static sibling | restructure (Q11) |

### Footer blur — is it implemented anywhere in auxi?

**No blur library is installed** (`grep -i blur package.json` → nothing; no
`@react-native-community/blur`, no `expo-blur`, no `expo` at all). Deps present:
`react-native-svg`, `react-native-svg-transformer`, `react-native-gesture-handler`.

Existing convention (already used elsewhere) is to **approximate `backdrop-blur`
with a near-opaque translucent RGBA fill, no real blur**:
- `theme.ts:107` `figmaItemDetailHeaderBg: rgba(255,255,255,0.9)` — comment:
  "approximates Figma backdrop-blur 7.5 without a blur dependency (qa-ui safe default #5)".
- `theme.ts:63` `figmaOnboardingStickyBarBg: rgba(255,255,255,0.6)` — "(backdrop-blur 2)".
- `HomeViewToggleFooter.tsx:18-20`, `ItemDetailScreen.tsx:739-740`,
  `OnboardingStylesScreen.tsx:24-25` all document the same blur-less fallback.

So a real 8px blur would require adding `@react-native-community/blur` (native
dependency — pod install + iOS/Android linking; escalate, not a code-only task).
The established blur-less fallback at **90% opacity** already matches the note's
opacity exactly; only the *blur* itself is missing. See Q8.

### Open questions — Header & Footer (append to list above)

- **Q8 (blur strategy)**: Note says **8px blur + 90% opacity**. No blur lib in
  the app; existing convention = opacity-only fallback. Add
  `@react-native-community/blur` (native dep, escalate) for a true 8px blur, OR
  ship the documented 90%-opacity fallback (no blur)? Default rec: fallback,
  matching `figmaItemDetailHeaderBg`.
- **Q9 (footer active-pill token)**: Figma capsule = **#e0d2c4** (subtle_100),
  116×56. Current `figmaFooterActivePill` = **#eee6df** (subtle_200), 158×56.
  Which is authoritative — update token + size to match this footer instance?
- **Q10 (header tokens)**: `text/neutral/subtle_100` **#40444d** (day name) and
  `background/overlay/dark/10` **#8271371a** (button card shadow) have no exact
  theme token. Add `figmaTextSubtle` / a button-shadow token?
- **Q11 (sticky behavior)**: Note says header & footer are **sticky** with
  content scrolling underneath. Today both are static (header = first child,
  footer = sibling below the ScrollView). Restructure to absolute/overlay so the
  outfit grid scrolls under translucent chrome? This is a layout change, not just
  styling — confirm scope.
- **Q12 (header padding)**: Figma header padding = **12**; code uses
  paddingH **22** / pT8 / pB10. Reconcile to 12 all-round (will shift the menu /
  heart buttons outward)?
- **Q13 (weather typography)**: WeatherWidget renders temp/day in **Poppins**
  (16 / 12). Figma uses **Inter** SemiBold **12** (+ 7.74px °C) and Inter Regular
  **12** for the day. Switch to Inter + Figma sizes?
- **Q14 (footer height)**: code reserves **98** (`HOME_VIEW_TOGGLE_FOOTER_HEIGHT`),
  Figma footer = **84**. The constant feeds HomeScreen snap-paging math — changing
  it affects sheet-height reservation. Confirm 84 and re-verify the paging math.

### New backend fields — Header & Footer

None — header (weather, day) is local/weather-service driven; footer is a pure
view toggle. No new backend contract fields introduced by these two frames.
