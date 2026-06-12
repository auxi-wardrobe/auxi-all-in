# Figma Extraction — Home | Grid View (rewritten)

> Extraction artifact (design-only). No RN code produced in this task.
> Produced per `figma-design-extraction` skill. Input to `figma-to-rn-workflow`.

## Source

- File: `0nXXMAR4Arf1ZfjtQvtBh0` (Auxi)
- Section node: **`2849:11340`** — "Home | Grid View", under page `2849:8205` (✅ Hifi (RFD) 1.1)
- URL: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-11340&m=dev
- Template author note: Kenechukwu Nwafor (designer). CEO is our authoritative designer.
- MCP tools used: `get_metadata` (2849:11340), `get_design_context` (2850:9125 — 4-item frame; 2849:11988 — Plain Tooltip), `get_variable_defs` (2849:11340), `get_screenshot` (2849:11340).
- **Tool surface check: PASS.** All required read tools available under `mcp__plugin_figma_figma__*` (get_metadata / get_design_context / get_variable_defs / get_screenshot / search_design_system). NOTE: skill doc references the `mcp__claude_ai_Figma__*` namespace; the live namespace in this session is `mcp__plugin_figma_figma__*`. Same tools, different prefix — no failure.

---

## Section overview

Every device frame is **414 × 896**. Structure is identical across all variant frames:

```
Frame (414×896, radius 18, bg background/neutral/subtlest = #ffffff)
├── header   INSTANCE  414×107  @ (0,0)            [shared component]
├── Frame 2034          414×781  @ (0,115)          [content]
│   └── Frame 2030       414× (content height)       [inner column, padX = body/24]
│       ├── Frame 2104   382×40   title row          (px 16 inside Frame 2127/2125)
│       ├── Frame 2009/2106/2125  image grid         (adaptive — see layout tables)
│       ├── Frame 2105   382×32   pagination/action row
│       └── Frame 2035   382×56   primary CTA (full-width Button + hidden 160.5w variant)
├── footer   INSTANCE  414×98   @ (0,798)           [shared component, grid-view tabs]
└── (3/3 frame only) Plain Tooltip INSTANCE 200×40 @ (141,167)  [first-run swipe hint]
```

Frames present in the section (device frames + annotation frames):

| Frame name | Node id | Item-count variant |
|---|---|---|
| Home 1/3 | `2850:9125` | 4 items (even 2×2) — canonical, fully design-context'd |
| Home 2/3 | `2850:9250` | 4 items but hero+stack arrangement (5-item-style top, 2 below) |
| Home for option 3/3 | `2849:11960` | 4 items (2×2) + **Plain Tooltip** swipe hint |
| outfit with 3 items | `2850:9613` | 3 items (2-top + 1-bottom-left) |
| outfit with 5 items | `2850:9580` | 5 items (1 hero + 2 stacked, then 2 below) |
| outfit with 6 items | `2850:9508` | 6 items (1 hero + 2 stacked, then 3 below) |
| outfit with >6 items | `2850:9542` | 9 items (1 hero + 2 stacked, then two rows of 3) |
| Home 1/3 (dup, >6) | `2852:20899` | 9 items — duplicate of >6 layout |
| note (sticky) | `2850:11913`, `2850:12005` | designer annotations (NOT shippable) |
| Arrow / Label | `2852:20456`, `2850:11986`, `2850:11996` | annotations (NOT shippable) |

---

## Confirmed design intents (sticky notes)

1. **Carousel of 3 options** — sticky `2850:11913`: "User need to swipe left/right to see other options - rotate within 3 options". The 3 ellipse dots in Frame 2105 = a 3-option pager. Frame names `Home 1/3`, `Home 2/3`, `Home for option 3/3`.
2. **Adaptive grid** — sticky `2850:12005`: "We have layouts to present 3-4-5-6 and >6 items in an outfit." See layout tables below.
3. **Plain Tooltip** on the 3/3 frame = first-run swipe hint ("Pair with a denim jacket for extra comfort."). UX hint, not a permanent element.

---

## Adaptive grid layouts — exact dimensions per item-count

Content frame inner width is **382** (414 − 16 left − 16 right). Image gap is **4px** everywhere (horizontal + vertical). All images are **3:4 aspect**, radius `border-radius/xl = 12`.

Column split logic for hero layouts: large column **253w** + 4px gap + small column **125w** = 382. (253 + 4 + 125 = 382. ✓)
Two-up rows: **189w** + 4px gap + **189w** = 382. (189 + 4 + 189 = 382. ✓)

### 3 items — `2850:9613` (Frame 2009 = 382×508)
| Item | Frame | x | y | w | h |
|---|---|---|---|---|---|
| 1 | Frame 2007 (row1) | 0 | 0 | 189 | 252 |
| 2 | Frame 2007 (row1) | 193 | 0 | 189 | 252 |
| 3 | Frame 2008 (row2) | 0 | 256 | 189 | 252 |
Row2 has a single left-aligned 189w card; right half is empty.

### 4 items — `2850:9125` "Home 1/3" (Frame 2009 = 382×508), even 2×2
| Item | Frame | x | y | w | h |
|---|---|---|---|---|---|
| 1 | Frame 2007 (row1) | 0 | 0 | 189 | 252 |
| 2 | Frame 2007 (row1) | 193 | 0 | 189 | 252 |
| 3 | Frame 2008 (row2) | 0 | 0 (@y256) | 189 | 252 |
| 4 | Frame 2008 (row2) | 193 | 0 (@y256) | 189 | 252 |
Note: `Home 2/3` (`2850:9250`) is also 4 items but uses the **hero+stack** top row (253 hero + two 125×166.7 stacked) then a 2×125 bottom row (Frame 2106 = 382×510). So the SAME count can render in two arrangements — the arrangement is a **design exploration**, not strictly count-driven (see open question Q1).

### 5 items — `2850:9580` (Frame 2009 = 382×510)
| Item | Container | x | y | w | h |
|---|---|---|---|---|---|
| 1 (hero) | Frame 2007 | 0 | 0 | 253 | 339 |
| 2 (stack-top) | Frame 2127 | 257 | ~0.83 | 125 | 166.67 |
| 3 (stack-bot) | Frame 2127 | 257 | 171.5 | 125 | 166.67 |
| 4 | Frame 2008 (row2) | 0 | 343 | 125 | 167 |
| 5 | Frame 2008 (row2) | 129 | 343 | 125 | 167 |
Row2 here uses **125w** cards (not 189) — left-aligned, two cards, trailing empty.

### 6 items — `2850:9508` (Frame 2009 = 382×509.2)
| Item | Container | x | y | w | h |
|---|---|---|---|---|---|
| 1 (hero) | Frame 2007 | 0 | 0 | 253 | 339 |
| 2 (stack-top) | Frame 2127 | 257 | ~0.83 | 125 | 166.67 |
| 3 (stack-bot) | Frame 2127 | 257 | 171.5 | 125 | 166.67 |
| 4 | Frame 2008 (row2) | 0 | 343 | 124.67 | 166.22 |
| 5 | Frame 2008 (row2) | 128.67 | 343 | 124.67 | 166.22 |
| 6 | Frame 2008 (row2) | 257.33 | 343 | 124.67 | 166.22 |
Row2 = 3 equal ~124.67w cards (382 − 2×4gap = 374 / 3 = 124.67). ✓

### >6 items (9 shown) — `2850:9542` (Frame 2009 = 382×679.4)
| Item | Container | x | y | w | h |
|---|---|---|---|---|---|
| 1 (hero) | Frame 2007 | 0 | 0 | 253 | 339 |
| 2 (stack-top) | Frame 2127 | 257 | ~0.83 | 125 | 166.67 |
| 3 (stack-bot) | Frame 2127 | 257 | 171.5 | 125 | 166.67 |
| 4–6 | Frame 2008 (row2) | 0 / 128.67 / 257.33 | 343 | 124.67 | 166.22 |
| 7–9 | Frame 2009 (row3) | 0 / 128.67 / 257.33 | 513.2 | 124.67 | 166.22 |
Rows of 3 repeat for additional items. No "+N" overflow badge — all items render (frame shows all 9). For >6 the CTA detaches into `Frame 2126` (366w, centered) so the grid can grow.

**Layout consolidation (3 shapes cover all counts):**
- `twoUp` rows of 189w (counts 3, 4-even)
- `heroStack` top (253 hero + 2×125 stacked) + bottom rows (counts 5, 6, >6, and the 4-item `Home 2/3` exploration)
- bottom rows are 2×125 (count 5) or 3×124.67 (count 6, >6)

---

## Title row (`Frame 2104`, 382×40)

```
Frame 2104  HORIZONTAL, gap 4, align center, w-full
├── Frame 2036 (caption pill)  HUG, h-40, padX 12, padY 8, radius 4
│   bg = color/primary/100 (#eee6df)
│   └── TEXT caption — Text-md (l-24)/Regular, color/neutral/800 (#1d1f23)
│       e.g. "Clean. Ready for today" / "Feels polished without trying too hard"
└── Frame 2037 (insight icon pill)  40×40, padX 12, padY 8, radius 4
    bg = color/primary/200 (#e0d2c4)
    └── carbon:idea icon 16×16  (the "why this outfit" insight affordance)
```

The caption pill HUGs the text width; the icon pill is a fixed 40×40 square. Gap 4 between them.

---

## Pagination / action row (`Frame 2105`, 382×32)

```
Frame 2105  HORIZONTAL, space-between, align center, w-full
├── Button (left)   ~83w, h-32, "Remix" label + scissors icon 16×16
│                    text style Text-xs/Regular (12/16), color text/neutral/base (#1d1f23)
│                    pill radius 100, padX 12, gap 8 (icon-text button, Size=32)
├── Frame 2124 (dots) 94w → Frame 2036 52w → 3 × Ellipse 4×4 @ x 12/24/36, y 14
│                    3 dots = the 3-option pager
└── Button (right)  ~127w, h-32, "Show another" label + swipe icon 16×16
                     SHOWN DISABLED on the 1/3 frame (opacity 0.5) — see note
```

- Left button label = **"Remix"** (with scissors/`Vector` icon). NOT "Wear this ♡" as the task hypothesised.
- Right button label = **"Show another"** (with `swipe` icon). The 1/3 frame renders it at **opacity 0.5 (disabled)** — design context shows variant `State=Disable`. Likely "no previous option to go back / forward at edge" state.
- Dots: 3 ellipses, 4×4, equal spacing. No active/inactive color delta is encoded as a variable in the design-context output (all three rendered the same fill). The active-dot styling is NOT explicitly specified — **open question Q2**.

---

## Primary CTA (`Frame 2035`, 382×56 — `Frame 2126` 366w on >6/5/6 frames)

```
Frame 2035  HORIZONTAL, gap 8, justify center
├── Button (hidden) 160.5×56  hidden="true"  → secondary/half-width variant, NOT rendered
└── Button (visible) 327×56   "Wear this" + heart icon 24×24
    variant: Secondary, State=Enable, Icon=Yes, Size=56 (node 470:2282)
    Content: border 1.5px border/neutral/base (#1d1f23), radius 16, overflow clip
    State-layer: padX 20, padY 16, gap 8
    label "Wear this" — Text-md (l-24)/Medium, color border/primary/bold_600 (#262421)
    trailing heart icon 24×24 (outline)
```

The hidden 160.5w Button is a half-width secondary variant the designer parked but did not place (kept for a future two-button row). Do NOT render it.

---

## header (INSTANCE, 414×107) — shared component `1769:10370`

Contents (from design context on `2850:9152`):
- **Left**: hamburger/menu icon button (`menu` 24×24 inside a 45×45 tap target, `Rectangle 106` bg). Node `1769:10371` "Back".
- **Center**: weather cluster —
  - "Monday" (weekday) — Text-xs/Regular (12/16), color text/neutral/subtle_100 (#40444d)
  - "32" + "°C" — Text-md/Semibold (16/24) base + small "°C" (10.32px), color text/neutral/base (#1d1f23)
  - weather glyph (sun/cloud `weather(s)` 35×32, vector group — Ellipse4/5 + Mask group + Union)
- **Right**: feedback icon button — heart/`Vector` icon 16×14 inside 47×47 tap target. Node `1769:10375` "feedback".

**Reuse status: ALREADY IMPLEMENTED** in `auxi/src/screens/HomeScreen.tsx` as the inline `<View style={styles.header}>` using `TopIconButton` + `IconHomeMenu` + `WeatherWidget` + heart toggle. The current build renders the SAME three-zone header (menu / weather / heart). The Figma "feedback" icon on the right currently maps to the favourite-heart toggle in the build. Minor: Figma weekday + weather widget already covered by `WeatherWidget`.

---

## footer (INSTANCE, 414×98) — shared component `2464:17348`

Contents (from design context on `2850:9152` Footer):
- backdrop-blur (3.25px) translucent bar, bg background/neutral/subtlest (#ffffff) at opacity 0.85.
- A rounded pill (158w, radius 14, bg background/primary/subtle_200 #eee6df) behind the active tab.
- **Two tabs**, each `mynaui:grid` icon 24×24 in a 66×48 cell (radius 13):
  - Tab 1 (active): bg background/neutral/subtlest (#ffffff), grid icon — this is the **grid view** (current screen).
  - Tab 2 (inactive): transparent bg (opacity 0), grid icon variant.
- This is a **view-toggle bottom bar** (grid-view ↔ an alternate view), NOT the app's main tab navigator.

**Reuse status: NOT IMPLEMENTED on current HomeScreen.** The current build has no footer view-toggle bar. This is **NEW**. The two tab glyphs are both `mynaui:grid` variants (grid vs. an alternate layout toggle). The second view it toggles to is **not defined in this section** — **open question Q3**.

---

## Token table (Figma variable → value → theme.ts status)

| Figma variable | Value | Used for | theme.ts status |
|---|---|---|---|
| `background/neutral/subtlest` | `#ffffff` | screen bg, footer bg, active tab | = `white`/`figmaSurface` |
| `background/primary/subtle_50` | `#f2efec` | image tile bg | = `figmaCardSurface` / `figmaBackground` ✓ |
| `background/primary/subtle_200` | `#eee6df` | footer active-pill bg | **MISSING** (≈ same hex as `color/primary/100`) |
| `color/primary/100-#EFE9E3` | `#eee6df` | caption pill bg (Frame 2036) | **MISSING** |
| `color/primary/200-#DED5CC` | `#e0d2c4` | insight icon pill bg (Frame 2037) | **MISSING** |
| `color/neutral/800-#1D1F23` | `#1d1f23` | caption text, weather temp | present as hex under `uacTextBase`/`uacBorderBase` (different name) |
| `text/neutral/base` | `#1d1f23` | "Remix" label, weather temp | = `uacTextBase` (`#1d1f23`) |
| `text/neutral/subtle_100` | `#40444d` | weekday "Monday" | = `uacTextSubtle100` ✓ |
| `border/neutral/base` | `#1d1f23` | CTA outline 1.5px | = `uacBorderBase` ✓ |
| `border/primary/bold_600` | `#262421` | CTA label "Wear this" | **MISSING** (near-black variant) |
| `color/neutral/black/Alpha300` | `#121212bf` (rgba(18,18,18,0.75)) | "common" tile tag bg | = `figmaCardTag` ✓ |
| `color/neutral/50-#FCFCFD` | `#fcfcfd` | "common" tag text | = `uacBackgroundNeutralSubtlest` (#fcfcfd) |
| `background/neutral/subtle_300` | `#f2f4f7` | inactive footer tab bg | = `uacColorNeutral100` (#f2f4f7) |
| `Schemes/Inverse Surface` | `#322f35` | Plain Tooltip bg | **MISSING** |
| `Schemes/Inverse On Surface` | `#f5eff7` | Plain Tooltip text | **MISSING** |
| `icon/neutral/base` | `#1d1f23` | carbon:idea, menu icons | = `uacTextBase` hex |
| `border-radius/xs` | `4` | caption + icon pill radius | = `spacing.xs` / `borderRadius.s` (4) ✓ |
| `border-radius/xl` | `12` | image tile radius | **no named 12 radius** (have s4/m8/l16) → add `radius.md=12` |
| `border-radius` (CTA) | `16` | CTA Content radius | = `borderRadius.l` (16) / `uacButtonCta` ✓ |
| `dimension/12 - 0.75rem` | `12` | Frame 2030→2127 column gap, caption pill padX | = `spacing.uacDimension*`/12 |
| `body` | `24` | Frame 2126 inner pad / column padX | = `spacing.l` / `uacBodyPadding` (24) ✓ |
| `ML` | `12` | "common" tag padX | 12 |
| image grid gap | `4` (one-off, not a named var) | gaps between tiles | = `spacing.xs` (4) ✓ |

### Typography styles (Figma text styles → theme.ts)

| Figma text style | family / weight / size / line-height | theme.ts alias |
|---|---|---|
| `Text-md (l-24)/Regular` | Poppins Regular 16 / 24, ls 0 | = `poppinsBody` ✓ |
| `Text-md (l-24)/Medium` | Poppins Medium 16 / 24, ls 0 | = `poppinsButton` ✓ |
| `Text-md (l-24)/Semibold` | Poppins SemiBold 16 / 24 | ≈ `uacBodyMdSemibold` (Inter) — **family mismatch**: Figma weather temp uses Inter SemiBold in code, but style def says Poppins/`font-family/body`. Confirm. |
| `Text-xs/Regular` | Poppins(body) Regular 12 / 16 | = `uacBodyXsRegular` (Inter) — **family mismatch** (Inter vs Poppins, see Q4) |
| `Text-xxs/Regular` | body 10 / 12 | "common" tag — no exact alias (Inter 10/12 in code) |

> Caveat: `get_design_context` rendered several `font-family/body` references as `'Inter:...'` in the Tailwind output (header weekday, weather, "Remix", "common" tag) while the variable collection defines `font-family/body = Poppins`. The text-STYLE definitions all point to `font-family/body`. The "Inter" strings are the MCP's literal-font fallback. **Treat `font-family/body` = Poppins as authoritative** (matches `poppinsBody`/`poppinsButton` already in theme). Flagged as Q4.

---

## Component inventory (reused vs new)

| Component | Figma node | Status in auxi |
|---|---|---|
| header (menu/weather/feedback) | `1769:10370` | **REUSED** — inline header in HomeScreen + `WeatherWidget` + `TopIconButton` + `IconHomeMenu` |
| footer (grid-view toggle tabs) | `2464:17348` | **NEW** — no footer toggle bar on current HomeScreen |
| Button "Remix" (Text btn, icon, size 32) | `2403:13607` | partial — current has "Edit context +" text button; "Remix" + scissors is **NEW label/icon** |
| Button "Show another" (disabled variant) | `2403:13611` | partial — `PillButton` exists; disabled+swipe-icon variant **NEW** |
| Button "Wear this" (Secondary, size 56, heart) | `470:2282` | **REUSED** — `PillButton variant="outline"` with `IconHomeHeartOutline`, label "Wear this" already shipped |
| Image 3:4 tile (with pin + "common" tag) | `1682:11858` (pin), `2595:10076` (tag) | **REUSED** — `GarmentPreview` + pin badge + `cardTag`; current tag text "common items", Figma says "common" |
| Plain Tooltip (swipe hint) | `1994:5270` / `2849:11988` | **NEW** — no first-run tooltip on current HomeScreen |
| 3-dot pager | `Frame 2124` ellipses | partial — current uses a text "1/3" counter, Figma uses **3 dots** (Q2) |

---

## Icons audit (per-icon)

Filename convention in this repo: icons live in **`auxi/src/assets/images/`** (NOT `assets/icons/` — that dir holds only `index.ts`). Pattern `icon_<name>.svg`.

| Icon | Figma size | Purpose | Exists? | Action |
|---|---|---|---|---|
| `carbon:idea` (lightbulb) | 16×16 | insight / "why this outfit" affordance | **NO** | EXPORT → `icon_idea.svg` (currentColor, 16 viewBox) |
| scissors (Remix) | 16×16 | "Remix" left button | **NO** | EXPORT → `icon_remix.svg` (currentColor) |
| `swipe` | 16×16 | "Show another" right button | **NO** | EXPORT → `icon_swipe.svg` (currentColor) |
| `mynaui:grid` | 24×24 | footer view-toggle tabs (×2) | **NO** | EXPORT → `icon_grid.svg` (+ alt variant) |
| heart outline | 24×24 (CTA) / 16×14 (header feedback) | CTA trailing + header right | **YES** `icon_home_heart_outline.svg` | reuse |
| heart filled | 24×24 | saved state | **YES** `icon_home_heart_filled.svg` | reuse |
| menu (hamburger) | 24×24 | header left | **YES** `icon_home_menu.svg` | reuse |
| pin | 17×17 (badge) | tile pin badge | **YES** `icon_home_pin.svg` | reuse |

`carbon:idea` confirmed as the insight/why-this-outfit affordance (it sits in the title row next to the caption, in a distinct `color/primary/200` pill). 4 NEW SVGs to export (idea, remix/scissors, swipe, grid). Run `figma-icons-sync` when implementing — normalise to `currentColor` + correct `viewBox`.

---

## Effects

- **footer**: backdrop blur 3.25px (outer) + 2px (inner bar), bar opacity 0.85. RN needs `@react-native-community/blur` BlurView — confirm it's installed before promising the blur (otherwise approximate with a translucent View). Flagged Q5.
- **Plain Tooltip**: no shadow in the rendered context (flat `#322f35` rounded-4 box). M3 spec tooltips can have elevation; here none encoded.
- No drop shadows on cards, pills, or CTA in the variable/context output. Tile pin badge uses `Rectangle 105` (a soft circle bg behind the pin glyph) — replicate with a semi-opaque circular View, already done in current build (`styles.pinBadge`).

---

## Deltas vs current `auxi/src/screens/HomeScreen.tsx`

Current HomeScreen already implements a swipe-paged adaptive grid (baseline node `1666:9723`). Deltas to align to the rewritten `2849:11340`:

1. **Title row caption pill is NEW.** Current screen has no caption text pill ("Clean. Ready for today"). Figma puts a `color/primary/100` HUG pill + `color/primary/200` insight-icon pill at the top of each card. Current build has no equivalent. → ADD title row (`Frame 2104`).
2. **`carbon:idea` insight icon is NEW** (no current equivalent). → EXPORT + ADD.
3. **Pager: dots vs counter.** Current uses a text counter `"1/3"` (`home-sheet-counter`). Figma uses **3 ellipse dots**. → switch to dots (confirm active-dot style, Q2).
4. **Left button label.** Current pagination row has no left button; bottom cluster has "Edit context +" (text). Figma left button = **"Remix" + scissors** in the pager row. NOTE: legacy generated code in design-context shows "Remix" — but **MEMORY says Remix was killed (2026-05-11), replaced by "Try Another"/AU-252 batch refresh.** The Figma template still carries the old "Remix" label. → **DO NOT ship "Remix"; reconcile label with current product (Try Another) — Q1/Q6.**
5. **Right button "Show another" + swipe icon + disabled state.** Current "Show another" logic exists via swipe; Figma surfaces it as an explicit pager button with a disabled state. → ADD button affordance + swipe icon + opacity-0.5 disabled state.
6. **"Wear this" CTA already matches** (outline, radius 16, trailing heart, h56). ✓ Keep. Figma uses border `#1d1f23` + label color `#262421`; current uses `figmaAction #272A32` — **slight color delta** (Q7).
7. **Footer view-toggle bar is NEW.** Current screen has no bottom view-toggle. → ADD (or confirm out-of-scope, Q3).
8. **"common" tile tag**: current text = "common items"; Figma = "common". Minor copy delta. Tag bg/positioning already matches (`figmaCardTag`, bottom-center). → align copy.
9. **Plain Tooltip first-run hint is NEW.** → optional UX add (Q8 — is it shippable or just an annotation?).
10. **Grid arrangement for 4 items**: current build renders 4-even as 2×2 (`twoByTwo`). Figma has BOTH a 2×2 (`Home 1/3`) AND a hero+stack 4-item (`Home 2/3`). Current `pickLayout` is count-driven; the Figma `Home 2/3` 4-item hero variant is an exploration. → confirm which 4-item arrangement is canonical (Q1).
11. **Token gaps**: `color/primary/100 #eee6df`, `color/primary/200 #e0d2c4`, `border/primary/bold_600 #262421`, `background/primary/subtle_200 #eee6df`, tooltip `#322f35`/`#f5eff7`, named `radius.md = 12`. → add to theme.ts via `figma-theme-sync` before coding (don't hardcode).

---

## Open questions for CEO / tech-lead

- **Q1 (layout authority):** The section has TWO 4-item arrangements — `Home 1/3` (even 2×2) and `Home 2/3` (hero 253 + 2×125 stack, then 2×125). Which is canonical for 4 items? Is `Home 2/3` an exploration or a real second state? Current build uses 2×2 for 4.
- **Q2 (pager dots):** Active vs inactive dot styling is not encoded as a variable — all 3 ellipses render identical fill in the design context. What's the active-dot treatment (color? size? fill vs outline)? Current build uses a "1/3" text counter instead of dots — keep dots or counter?
- **Q3 (footer toggle):** The footer toggles between two `mynaui:grid` views. The second (alternate) view is not in this section. What does tab 2 switch to? Is the footer in-scope for this rewrite or a later ticket?
- **Q4 (font family):** `font-family/body` = Poppins per the variable collection, but the MCP rendered several labels as "Inter" (weekday, weather temp, Remix, common tag). Confirm Poppins is authoritative for ALL body text (matches existing `poppinsBody`/`poppinsButton`). Weather temp `Text-md/Semibold` — Poppins SemiBold or Inter SemiBold?
- **Q5 (footer blur):** Footer uses backdrop blur (3.25px). Is `@react-native-community/blur` available, or approximate with a translucent View? (Affects fidelity.)
- **Q6 (Remix vs Try Another):** Figma template carries the legacy "Remix" left-button label. Per project memory, Remix was killed 2026-05-11 in favour of "Try Another"/AU-252 batch refresh. Confirm the shipped label (almost certainly NOT "Remix").
- **Q7 (CTA color):** Figma CTA border = `border/neutral/base #1d1f23`, label = `border/primary/bold_600 #262421`. Current build uses `figmaAction #272A32` for both. Adopt the exact Figma tokens or keep `#272A32`?
- **Q8 (Plain Tooltip):** Is the swipe-hint tooltip a shippable first-run coachmark, or just a designer annotation? If shippable, what's the dismiss/trigger logic (first session only)?
- **Q9 (icon set):** OK to export 4 NEW SVGs (idea, remix/scissors, swipe, grid) into `auxi/src/assets/images/` with `icon_*.svg` + currentColor? (`assets/icons/` is empty except index.ts — confirm images/ is the right home.)

## New backend fields (vs current API client)

- The caption text ("Clean. Ready for today" / "Feels polished without trying too hard") — is this a backend-provided outfit caption/insight string, or client-side copy? The current `Outfit`/`V05Outfit` shape (`recommendationService.ts` / `v05Api.ts`) has no `caption` / `insight` / `why` field. If the caption + `carbon:idea` insight are meant to be AI-generated per outfit, that is a **NEW backend field** (`outfit.caption` / `outfit.insight`). → escalate to tech-lead before wiring; do not invent the endpoint field.
- The "common"/rarity tag on tiles maps to existing `item.isSystem` (source `common_essential`) — already covered by the current contract. No new field needed for the tag.
- Pagination "rotate within 3 options" maps to the existing `listOutfits` batch (count: 3 in `buildViaV05`). No new field.
- Everything else (items, image_url, category, pin) is covered by the current `Item`/`Outfit` contract.

---

## qa-ui review-extraction (Pass 1)

> Reviewer: qa-ui · 2026-05-25 · review-extraction mode (Pass 1 ONLY — no code, no sim).
> Source verified against live Figma `0nXXMAR4Arf1ZfjtQvtBh0`, section `2849:11340`.
> Tools used: `get_metadata` (2849:11340), `get_variable_defs` (2849:11340), `get_design_context` (2850:9141 pager row, 2850:9151 CTA, 2849:11988 Plain Tooltip). theme.ts/asset cross-check via grep (read-only on src).

### Verdict: **PASS (with minor corrections)**

The artifact is an accurate, faithful read of the section. Frame tree, tokens, button labels, adaptive layouts, component inventory, and icon enumeration all match live Figma. The 6 claimed token gaps are all real. mobile-dev may proceed to `figma-to-rn-workflow` Phase 1 after applying the 3 minor corrections below. None block coding; all are nits or confirmations.

### Verified accurate

1. **Token table — ALL 6 gaps confirmed real.** `get_variable_defs` resolves: `color/primary/100`=`#eee6df` ✓, `color/primary/200`=`#e0d2c4` ✓, `border/primary/bold_600`=`#262421` ✓, `background/primary/subtle_200`=`#eee6df` ✓, `Schemes/Inverse Surface`=`#322f35` ✓, `Schemes/Inverse On Surface`=`#f5eff7` ✓, `border-radius/xl`=`12` ✓. Grep of `auxi/src/theme/theme.ts` confirms all five hex values are ABSENT and `borderRadius` has only `s:4/m:8/l:16` (no tile-radius 12 — `uacButtonText:12` is a different role). Token-gap section is correct; route to `figma-theme-sync` before coding stands.
2. **Button labels — confirmed exact strings.** design-context on `2850:9141`: left text node = **"Remix"**, right text node = **"Show another"** rendered at `opacity-50` (disabled). CTA `2850:9151` = **"Wear this"** + heart, border `#1d1f23`, label color `#262421`, radius 16, Poppins Medium. The artifact correctly flags that Figma literally says "Remix" and correctly escalates the Remix-vs-Try-Another conflict (Q6) rather than blindly transcribing it. Good catch — this is exactly the pre-code gate working.
3. **5 adaptive layouts — all dimensions match metadata.** 3-item `2850:9613` (2-top 189w + 1-bottom-left), 4-item `2850:9125` (even 2×2), 5-item `2850:9580` (hero 253 + 2×125 stack + 2×125 row), 6-item `2850:9508` (+ 3×124.67 row), >6 `2850:9542` (+ second 3-row). All x/y/w/h verified against `get_metadata`. The CTA detaching into `Frame 2126` (366w) on 5/6/>6 frames is correct.
4. **"Two 4-count layouts" ambiguity — legitimately flagged (Q1).** Metadata confirms `Home 1/3` (`2850:9125`) = 2×2 even, vs `Home 2/3` (`2850:9250`) = heroStack via `Frame 2106`. The ambiguity is real and correctly escalated, not invented.
5. **Component inventory — reuse-vs-new classification sound.** header (414×107) REUSED, footer (414×98) NEW, "Wear this" CTA REUSED, "Remix"/"Show another" buttons NEW label/icon, Plain Tooltip NEW, 3-dot pager (vs current "1/3" counter) flagged. Verified `icon_idea/remix/swipe/grid` absent from `src/assets/images/` — 4 NEW SVG exports confirmed needed. heart/menu/pin confirmed present.
6. **font-family/body = Poppins is authoritative** — `get_variable_defs` explicitly returns `"font-family/body":"Poppins"`. The "Inter" strings in design-context are MCP literal-font fallback, exactly as the artifact's Q4 caveat states. Correct.
7. **Completeness — no missed frames/states.** All 12 section children accounted for (9 device frames incl. the `2852:20899` >6 duplicate, 2 sticky notes, 3 Arrow/Label annotations). Both sticky-note intents transcribed verbatim. No hidden layer rendered as real; the hidden 160.5w Button correctly marked do-not-render.

### Minor corrections (apply during impl — non-blocking)

- **C1 (icon name).** The left "Remix" button icon is named **`mix`** in the Figma component (`Icons name="mix"`), not "scissors". The glyph reads scissors-like but the export source is `mix`. Cosmetic — export as `icon_remix.svg` is fine, just don't search Figma for "scissors".
- **C2 (tooltip font).** Plain Tooltip text style is M3 `static/body-small` (12/16), which design-context renders as `'Inter:Regular'`. Unlike body copy, this is an **M3 system style**, not `font-family/body`, so the Poppins-authoritative rule (Q4) does NOT automatically apply to the tooltip. Confirm with CEO whether the tooltip stays M3/Inter or is normalized to Poppins. Currently the artifact lists tooltip under the generic Q4 family caveat — call it out separately.
- **C3 (3-item bottom-row width).** Artifact's 3-item table lists item 3 as 189w in `Frame 2008`. Metadata confirms `2850:9627` = 189×252 at x=0, right half empty. ✓ correct — no change, just confirming the lone-card width is 189 (full two-up width), not a 125 hero-stack remnant.

### Open questions — all legitimate, none invented

Q1–Q9 and the "New backend fields" section are all grounded in real Figma ambiguity or real contract gaps. Q6 (Remix killed → Try Another, per project memory 2026-05-11) and the `outfit.caption`/`insight` new-backend-field escalation are the two that genuinely need CEO/tech-lead decision before wiring — correctly routed, not guessed. The "Open questions" section is non-empty and substantive, satisfying the pre-code gate requirement.

### Routing

- **PASS** → mobile-dev proceeds to `figma-to-rn-workflow` Phase 1.
- Before coding: run `figma-theme-sync` (6 token gaps) + `figma-icons-sync` (4 SVGs: idea, remix/mix, swipe, grid) per the artifact's own recommendations.
- **ESCALATE to pm → CEO/tech-lead** (do not resolve in code): Q6 (Remix vs Try Another label — Figma literally says "Remix" but project decision killed it) and the `outfit.caption`/`outfit.insight` NEW backend field. These two gate visible behavior/contract; coding the rest can proceed in parallel.
