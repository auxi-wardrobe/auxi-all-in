# Extracted: AU-310 — Outfit Recommendation Cards (Layout + Loading)

> Figma file `0nXXMAR4Arf1ZfjtQvtBh0`
> Nodes: `2850:11205` (Home — loading, 4-card 2×2 variant) · `2850:9580` (outfit
> with 5 items → instance `3227:18976` "Grid card layouts" property1="5").
> Tools used: get_metadata, get_design_context, get_variable_defs, get_screenshot.
> Pairs with `figma-to-rn-workflow`. Scope: `auxi/` only · JS-only · RN `Animated`.

---

## Frame — Home / loading (2850:11205)

- Device frame: **414 × 896**.
- `header` instance 414×107 · `footer` instance 414×84 (grid↔collage toggle, grid active).
- Content `Frame 2034` y=115, 414×781.
  - **"Generating" pill** (`Frame 2104`) 382×40 at x=16 — text "Generating" (91×24) +
    `streamline-ultimate:loading` spinner 24×24. Inner `Frame 2036` 147×40.
  - **Card grid** (`Frame 2009`) 382×508 at x=16, y=52 — the 4-card 2×2 variant:
    - Row 1 (`Frame 2007`) 382×252: two `Image 3:4` instances **189×252**, x=0 and x=193.
    - Row 2 (`Frame 2008`) 382×252: same.
  - **Control row** (`Frame 2103`) 382×32 at y=572 — left `✂ Remix` (104w, scissors
    `streamline-sharp:cut-remix` 24 + "Remix" 48) · right `Show (1/3)` (140w).
    *(Loading state shows a counter, not pager dots.)*
  - **CTA row** (`Frame 2035`) 382×56 at y=616 — `Button` 327w centred (a 2nd 160w
    Button is `hidden=true`). "Wear this" + heart.

### Loading skeleton — design context (Frame 2009 / 2850:11213)

```
VERTICAL flex, gap 4, items-start
  Row (HORIZONTAL flex, gap 4, w-full)
    Image 3:4 — aspect[3/4], flex[1 0 0], rounded var(--border-radius/xl)=12, gradient bg
    Image 3:4 — (same)
  Row (HORIZONTAL flex, gap 4, w-full)
    Image 3:4 ×2 — (same)
```

- **Skeleton fill in Figma** = `linear-gradient(230.17deg, rgb(242,239,236) 26.8%,
  rgb(213,204,195) 84%)` — a soft warm-taupe diagonal gradient (spec's "Option A
  ambient shimmer" look).
- **Card radius** = `border-radius/xl` = **12** ✓ (= `theme.borderRadii? → borderRadius.figmaTile`).
- **Gap** = 4 both axes (193−189=4) ✓.
- **Page padding** = 16 (Frame 2009 x=16) ✓.
- **Card aspect** = 189×252 = exactly 3:4 ✓.

> **LOCKED DECISION override:** brief + plan lock the skeleton to **Option B
> opacity-breathing (0.92→1, ~1700ms, ease-in-out) on a SOLID surface** — NOT the
> Figma gradient — because `react-native-linear-gradient` is a forbidden new native
> dep (JS-only constraint). So the skeleton surface = solid `figmaCardSurface`
> (#f2efec = `background/primary/subtle_50`, the lighter gradient stop / the loaded
> tile bg). The warmer stop (#d5ccc3) is not introduced — breathing carries the
> "alive" feel instead of the gradient. This is a deliberate, signed-off deviation.

---

## Frame — outfit with 5 items (2850:9580 → 3227:18976 "Grid card layouts", property1="5")

```
VERTICAL flex, gap 12, px 12 py 8 (component-internal; on-screen page padding is 16)
  caption row (HORIZONTAL gap 4): caption pill (color/primary/100 #efe9e3, radius 54,
    px12 py8, "Clean. Ready for today") + insight pill (color/primary/200 #e0d2c4,
    40×40, radius 23, carbon:idea 16 icon)            → already built: OutfitCardCaption
  grid (VERTICAL gap 4):
    top section (HORIZONTAL gap 4, justify-end):
      HERO Image 3:4 — 258.5 × 343.5, radius 12, bg background/primary/subtle_50 #f2efec
        + pin (top-right, 34px hit / 32 surface / 17 icon)
        + "common" rarity tag (bottom-center, bg rgba(18,18,18,0.75), radius 8, 57×19,
           text 10/12 #fcfcfd)
      right column (VERTICAL gap 4, self-stretch → matches hero height):
        small Image 3:4 — 127.3 × 169.733  (pin + tag)
        small Image 3:4 — 127.3 × 169.733  (pin + tag)
    bottom row (HORIZONTAL gap 4, justify-center):
      small Image 3:4 — aspect[3/4] flex[1 0 0]  (pin + tag)
      small Image 3:4 — aspect[3/4] flex[1 0 0]  (pin + tag)
      small Image 3:4 — flex[1 0 0] **opacity-0** (the empty 3rd slot for the 5-item case;
        present in DOM to balance the 2 visible smalls → left-justify of the 2 reals)
  control row (HORIZONTAL space-between): Remix (text btn, icon 16) · pager (3 dots) ·
    "Show another" (text btn, swipe icon, opacity-50 = disabled at edge)  → OutfitActionRow
  CTA (HORIZONTAL justify-center): "Wear this" — Secondary/outline, 1.5px border
    border/neutral/base #1d1f23, radius 16, px20 py16, Poppins Medium 16/24
    label color border/primary/bold_600 #262421, trailing heart 24       → PillButton
```

**Geometry cross-check (5-item):** hero 258.5w ≈ 2·colW+gap where colW≈127.3 and gap=4
(127.3·2+4 = 258.6 ✓); hero 343.5h ≈ 2·smallH+gap (169.733·2+4 = 343.47 ✓). Confirms
the brief's **hero family** formula: `colW=(contentW-2·gap)/3`, `smallH=colW·4/3`,
`heroW=2·colW+gap`, `heroH=2·smallH+gap`.

---

## Tokens used (mapped to auxi/src/theme/theme.ts)

| Figma var | Value | theme.ts path | Status |
|---|---|---|---|
| `background/primary/subtle_50` | #f2efec | `colors.figmaCardSurface` | exists ✓ |
| `border-radius/xl` | 12 | `borderRadius.figmaTile` | exists ✓ |
| `border-radius/xs` | 4 | (use literal `GRID_GAP=4` — spacing.xs) | exists ✓ |
| caption pill `color/primary/100` | #efe9e3/#eee6df | `colors.figmaCaptionPillBg` | exists ✓ (OutfitCardCaption) |
| insight pill `color/primary/200` | #e0d2c4 | `colors.figmaInsightPillBg` | exists ✓ |
| rarity tag `color/neutral/black/Alpha300` | rgba(18,18,18,0.75) | `colors.figmaCardTag` | exists ✓ |
| tag text `color/neutral/50` | #fcfcfd→#FFFFFF | `colors.white` | exists ✓ (current cardTag uses white) |
| CTA border `border/neutral/base` | #1d1f23 | `colors.uacBorderBase` | exists ✓ |
| CTA label `border/primary/bold_600` | #262421 | `colors.figmaCtaLabel` | exists ✓ |
| Remix/Show text `text/neutral/base` | #1d1f23 | `colors.uacTextBase` | exists ✓ |
| skeleton surface | #f2efec (solid, per locked decision) | `colors.figmaCardSurface` | exists ✓ |
| "Generating" / footer text | #1d1f23 | `colors.uacTextBase` / `figmaAction` | exists ✓ |

**Fonts:** body = Poppins; rarity tag = Inter-Regular 10/12 (current code already uses
Inter-Regular 10/12 for `cardTagText`). No new font alias needed.

### Theme additions
**NONE.** Every value maps to an existing token. The skeleton reuses
`figmaCardSurface`; gradient stop #d5ccc3 is intentionally NOT added (locked to
opacity-breathing on solid surface). No new hex/font literals introduced.

---

## Icons needed

- **pin** (top-right tile badge) — already rendered today via `IconHomePin`
  (`assets/images/icon_home_pin.svg`), 24×24. Reused as-is (no export).
- **carbon:idea** (insight pill) — already in `OutfitCardCaption`. Out of scope here.
- **cut-remix / swipe** — already in `OutfitActionRow` (`icon_remix.svg`, `icon_swipe.svg`).
- **streamline-ultimate:loading** spinner (Generating pill) — current loading footer
  uses RN `ActivityIndicator`; keep ActivityIndicator (no SVG export; matches the
  "spinner" intent and avoids a new asset). Not a tile icon.

**No new SVGs to export.** All tile/chrome icons already exist in the repo.

---

## Variants / states to implement

- **Count layouts:** 1 (defensive) · 2 · 3 · 4 · 5 · 6 · >6 (7+ scrolling). Driven by a
  pure descriptor (`outfit-card-layouts.ts`).
- **Skeleton:** mirrors the descriptor per count → identical slots → zero layout shift.
- **Content reveal:** opacity 0→1 + translateY 8→0, 300ms, Easing.out; stagger by
  revealGroup (hero=0, supporting=1, accessory=2) × 45ms.
- **Image fade-in:** per-card opacity 0→1 over ~200ms on `Image.onLoad`; fixed slot
  dims before load; fallback tile for missing `resolveItemImage`.
- **Skeleton breathing:** one shared Animated.Value 0.92↔1, ~1700ms,
  Easing.inOut(ease), applied to all cells.
- **Reduced motion** (`AccessibilityInfo.isReduceMotionEnabled` + change subscription):
  reveal = opacity-only (no translateY); skeleton holds static 1.0 (no breathing);
  image fade still allowed (opacity only).
- **Pin state** per tile (active ring + badge) — preserved from current code.

---

## Open questions for CEO / tech-lead

- **Skeleton gradient vs solid:** Figma loading frame uses a warm-taupe diagonal
  gradient; we ship a SOLID `figmaCardSurface` with opacity-breathing instead
  (locked decision — no `react-native-linear-gradient`, JS-only). Flag for CEO sign-off
  on the visual delta. Moving-shimmer (Option A) would later require the gradient lib.
- **1-item floor:** neither spec nor Figma frames cover a 1-item outfit. Defensive
  single full-width hero implemented; confirm V05 min item count.
- Otherwise spec self-contained — counts 2/3/4/5/6/>6 all confirmed against real frames
  (`au310-count-*.png`) and the 5-item design context.

## New backend fields (vs current API client)

None — all fields covered by current contract. AU-310 is pure presentation; items +
`reasoning_human` caption already flow through `buildViaV05` → `normalizeOutfits` →
`OutfitCardCaption`. No `services/*.ts` change.
