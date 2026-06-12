# AU-310 Research — Outfit Recommendation Cards: Layout + Loading Spec

**Ticket:** [AU-310 — \[Spec\] Outfit Recommendation (cards) Layout + Loading Spec (AI-Friendly)](https://linear.app/duncan-1/issue/AU-310/spec-outfit-recommendation-cards-layout-loading-spec-ai-friendly)
**Author:** Viet (vietdesign81@gmail.com — the CEO/designer) · **Assignee:** Minh Đức Nguyễn (you)
**Status:** Backlog · No priority · No labels · No comments · Created 2026-05-31
**Branch (Linear-suggested):** `duc2820/au-310-spec-outfit-recommendation-cards-layout-loading-spec-ai`
**Figma:**
- Spec/annotation frame — node `2849-11340` → `plans/reports/au310-figma-frame.png`
- **Design scroll (real screen) — node `2850-11205` ("Home - loading")** → `plans/reports/au310-design-scroll-2850-11205.png`
- File `0nXXMAR4Arf1ZfjtQvtBh0`

---

## 1. What this ticket actually is

Not a bug, not a feature request — it's a **design contract written AI-first** (YAML-ish blocks) so it can be handed straight to an implementer. Viet authored it; you're the assignee. It governs the **grid/card view of an outfit recommendation** on `HomeScreen` — how the outfit's individual items are laid out, how they load, and how they animate in.

Emotional target: **calm / intentional / emotionally lightweight / editorial-lite.**
Explicit anti-goals: ecommerce grid density, Pinterest masonry, aggressive animation, chaotic composition.

---

## 2. The spec, decoded

### Card system (4 types, all 3:4 portrait)
| Type | Width | Purpose |
|---|---|---|
| `standard` | 100% | primary standalone outfit item |
| `large` | 66.66% | hero item |
| `medium` | 50% | balanced grid |
| `small` | 33.33% | supporting / accessories |

**Global rules:** every card is `3:4` portrait; gap `4–6px`; edges align cleanly; no floating cards, uneven gutters, masonry, random heights, or stretched cards.

### Layouts by item count
- **2:** `standard` (full width) on top, one `small` centered below. Lots of calm empty space; primary focus = the standard card.
- **3:** `2×2` grid of 3 `medium` cards **+ 1 empty slot** (equal sizes, balanced).
- **4:** `2×2` grid of 4 `medium` cards, equal spacing both axes.
- **5:** top = `large` hero (left) + 2 `small` stacked (right); bottom row = 2 `small`.
- **6:** top = `large` (left) + 2 `small` (right); bottom row = 3 `small`.
- **7:** top = `large` (left) + 2 `small` (right); bottom = two rows of 3 `small`.

### Loading system
- **Skeleton must exactly match final layout** (same slots, spacing, hierarchy, radius). Goal: zero layout shift / no jump.
- Background = soft neutral surface; **avoid** high-contrast gray, hard edges, flashing.
- **Two animation options** (pick one): **A) soft ambient shimmer** `1.8–2.4s`, no sharp/fast gradients; **B) opacity breathing** `0.92→1`, `1.5–2s`, ease-in-out.

### Content reveal
- Per-card: `opacity 0→1` + `translateY 8px→0`, `250–400ms`, ease-out.
- **Reveal order:** hero → supporting → accessories, **stagger 30–60ms**.

### Image loading
- Reserve card dimensions before image loads; fade image in; **no white flash / pop-in / resize.**

### Performance & a11y
- Optimize for older iPhones / mid-range Android / RN rendering. Avoid heavy blur, large transforms, continuous layout recalc, excessive stagger chains.
- **Reduced motion:** disable translate + shimmer movement, opacity-only transitions.

---

## 3. Figma frame observations (node 2849-11340)

~10 phone mockups, each = one recommendation: **hero card + smaller supporting cards** in a calm grid, a **caption pill**, and an **action row** at the bottom. Cards are clearly 3:4 portrait on a near-white surface with generous spacing — matches the text spec.

**Two sticky-note annotations carry product intent beyond the layout spec:**
1. *"User need to swipe left/right to see other options — create within 3 options"* → the card grid is **one option** in a set; L/R swipe cycles options, **capped at 3**. This is the same gesture as **AU-303 two-axis swipe** (L/R = outfit-in-set, U/D = next set).
2. *"We have layouts to present 3, 4, 5, 6 … items in an outfit"* → confirms the count-driven layout table is the deliverable.

> Implication: AU-310 is the **per-option card layout + loading** contract; AU-303 is the **gesture/navigation** layer around it. They compose — this spec describes what each L/R page looks like.

---

## 3b. Design scroll (node 2850-11205, "Home - loading") — measured

The real screen for the **loading state**, on a 414pt iPhone frame. Metadata gives exact slot geometry (single source of truth for extraction):

```
Home - loading            414 × 896
├─ header (instance)      414 × 107
├─ content  y=115         414 × 781   (padding 16px → inner width 382)
│  ├─ "Generating" pill   382 × 40    text "Generating" + spinner (streamline-ultimate:loading)
│  ├─ card grid           382 × 508   (4-card 2×2 variant)
│  │  ├─ row 1  y=0       two Image-3:4 cards @ 189×252, x=0 and x=193
│  │  └─ row 2  y=256     two Image-3:4 cards @ 189×252, x=0 and x=193
│  ├─ control row y=572   382 × 32    left "✂ Remix" (104w) · right "Show (1/3)" (140w)
│  └─ CTA row    y=616    382 × 56    "Wear this ♡" button (327w, centered; 2nd 160w button hidden)
└─ footer (instance)      414 × 84    grid ↔ collage view toggle (grid active)
```

**Hard numbers (resolve the spec's ranges):**
- **Card = 189 × 252 = exactly 3:4** ✓
- **Gap = 4px** both axes (193 − 189) → spec's "4–6px" lands on **4**.
- **Screen padding = 16px**; grid block 382 × 508 (252 + 4 + 252).
- Vertical rhythm: grid → 12px → control row → 12px → CTA.

**Loading skeleton appearance (from render):** soft **warm-taupe gradient** cards, ~12px radius, on a neutral surface — i.e. the spec's **Option A "soft ambient shimmer,"** NOT high-contrast gray and NOT opacity-breathing. Skeletons already occupy the **exact final 2×2 slots** → zero layout shift, exactly as the spec requires.

**Chrome the YAML spec didn't mention but the screen shows:**
- A **"Generating" status pill** (spinner) shown during loading.
- A **"Remix"** affordance (scissors / `cut-remix` icon) → routes to the AU-285 Outfit Canvas Remix Editor (see `project_remix_feature` memory — this is the live Remix, not the killed auto-variation one).
- A **"Show (1/3)"** counter = current option index of the 3-option set (the AU-303 L/R swipe).
- A **"Wear this ♡"** primary CTA below the grid.
- The **grid ↔ collage** view toggle in the footer (grid active here).

> Note: this is metadata + screenshot only. Pull `get_design_context` on `2850-11205` (and the per-count layout nodes) during the `figma-design-extraction` step for exact color/gradient stops, font tokens, and the skeleton fill values before coding.

---

## 3c. Count-layout series — real frames (observed)

Screenshotted the actual count frames (saved as `plans/reports/au310-count-*.png`). The real designs **confirm the YAML hero-stack pattern** and clear up the spec's abstractions. All cards 3:4 portrait, 4px gap, 16px page padding, each card has a **pin icon** (top-right) + a **"common" rarity tag** (bottom-center dark pill).

| Count | Node | Real layout (observed) | vs YAML spec |
|---|---|---|---|
| **2** | `3230:35149` | full-width `standard` hero (dress) on top + **1 `small` below** | ✓ matches |
| **3** | `2850:9613` | row1 = 2 `medium` side-by-side; row2 = **1 `medium`, left** (bottom-right empty) | ✓ = spec's "2×2 + empty slot" |
| **4** | `3104:5907` | **2×2** of 4 `medium`, equal | ✓ matches (baseline; no separate "4 items" frame) |
| **5** | `2850:9580` | `large` hero left + 2 `small` stacked right; bottom row = 2 `small` | ✓ matches exactly |
| **6** | `2850:9508` | `large` hero left + 2 `small` right; bottom row = **3 `small`** | ✓ matches exactly |
| **>6** | `2850:9542` | `large` hero left + 2 `small` right, then **N rows of 3 `small`** (scrolls); no caption pill, controls below fold | spec's discrete "7" is really a **">6 scrolling catch-all"** |

**No dedicated "4 items" or "7 items" frame exists** — 4 is the baseline 2×2; 7+ collapses into ">6 items".

### Surrounding chrome (consistent across loaded frames)
- **Caption pill** top-left: e.g. "Clean. Ready for today" / "Feels polished without trying too hard" + insight bulb icon pill (already built: `OutfitCardCaption.tsx`).
- **Control row** below grid — and it **differs by state**:
  - **Loaded:** `✂ Remix` (left) · **• • • pagination dots** (center = 3 options) · `Show another ↗` (right).
  - **Loading:** `✂ Remix` (left) · `Show (1/3)` counter (right). *(no dots while generating)*
- **CTA:** `Wear this ♡` — outlined, full-width, 56px.
- **Footer:** grid ↔ collage view toggle (grid active).
- **4-card frame** (`3104:5907`) also shows the **edit-context bottom sheet** open — mood chips "Grounded / Light / Confident / Input" + shuffle icon = the Remix/refine entry.

### Full Figma inventory (3 sections on page "Hifi (RFD) 1.1")
- **Home | Grid View** (`2849:11340`) — count series + 1/3–3/3 rotation set + designer notes (`2850:11913` swipe-within-3-options, `2850:12005` "layouts for 3-4-5-6 and >6 items").
- **Edit context flow** (`2850:10085`) — the fully-expanded grids incl. the loading anchor `2850:11205`, loaded `2850:11059` ("after 2 packs"), `3104:5907`.
- **Pin a item flow** (`3140:5959`) — reuses the grid + a 2nd loading state `3171:9988` (one card has a pin overlay).
- Loading-state frames: `2850:11205`, `3171:9988`. Everything else is loaded.

---

## 4. Current implementation (auxi) — what exists today

Rendering lives **inline in `HomeScreen.tsx`** (~2,200 LOC); there is no standalone card component yet.

| Area | Current state | File |
|---|---|---|
| Result screen | `HomeScreen.tsx` — vertical paginated "sheets", `grid` ↔ `collage` toggle | `auxi/src/screens/HomeScreen.tsx` |
| Card tile | `GarmentPreview` (inline, stateless: image + tag) | `HomeScreen.tsx:1900–1921` |
| Layout variants | `twoRowOneLarge` (1–3), `twoByTwo` (4), `heroStackPlusRows` (5–7+) | `HomeScreen.tsx:74–165`, `:1520` |
| Aspect ratio | `0.75` (3:4) already enforced | `HomeScreen.tsx:74–165` |
| Radius / gap | radius `12`, gap `4px` | `HomeScreen.tsx:2086–2104` |
| Loading | **static placeholder tiles, no animation** | `HomeScreen.tsx:1873–1881`; loading flag `:794` |
| Image resolve | `resolveItemImage` → prefer `image_png` cutout, fallback `image_url`; **no fade-in** | `auxi/src/utils/url.ts` |
| Caption / actions | `OutfitCardCaption.tsx`, `OutfitActionRow.tsx` | `auxi/src/components/features/` |
| Collage/canvas | `CollageSheetCanvas.tsx`, `collage-seed-layout.ts`, `OutfitCanvasSurface.tsx` (4:3, drag-to-play) | `auxi/src/components/features/` |
| Theme tokens | `figmaCardSurface #f2efec`, `figmaTile 12` radius, spacing scale | `auxi/src/theme/theme.ts` |
| Animation libs | **only RN `Animated`** — no Reanimated / Moti / LayoutAnimation / shimmer lib | `auxi/package.json` |

---

## 5. Gap analysis (spec vs. code)

**Already aligned (✓):**
- 3:4 portrait cards, radius `12`, gap `4px`, neutral surface token — all present.
- Count-driven layouts exist for 4 and 5–7 (hero-stack matches spec's `large` + `small` right-stack + small rows almost exactly).
- PNG-cutout-first image resolution already in place.

**Gaps to close (✗):**
1. **3-card layout ALREADY matches** (real frame = 2 top + 1 bottom-left = current `twoRowOneLarge`). The YAML "2×2 + empty slot" is the same thing. No rework needed — was a false alarm.
2. **2-card layout differs.** Real design = **full-width hero + 1 small below**; current code (`twoRowOneLarge`, 1–2 items) = 2 equal cards side-by-side. Needs rework for the 2-item case.
3. **No skeleton matching final layout.** Current loading is a flat placeholder, not a per-slot skeleton mirroring the chosen count-layout. This is the biggest build item.
4. **No skeleton animation** (neither shimmer nor opacity-breathing).
5. **No staggered content reveal** (hero→supporting→accessories, 30–60ms).
6. **No image fade-in** (images pop in instantly).
7. **No reduced-motion branch** for animations.
8. **Animation toolkit decision needed** — RN `Animated` can do all of this, but Reanimated 3 / Moti would be cleaner for per-card stagger + shimmer. Adding a dep is an architecture call (no Reanimated currently installed).

---

## 6. How it connects to in-flight work

- **AU-303 two-axis swipe** (`home_swipe_two_axis_au303` memory; plan `plans/260531-1326-au-303-two-axis-swipe/`) — the L/R-between-options gesture the Figma annotation references. AU-310 defines what each swipe page *renders*; AU-303 defines the gesture. The "max 3 options" annotation is a constraint AU-303 should honor.
- **Home collage/canvas** (`plans/260529-1401-home-collage-canvas-play/`, `CollageSheetCanvas`) — separate `collage` view mode. AU-310 governs the **`grid`** mode, not collage. Worth confirming with Viet whether grid is now the primary/default and collage is secondary.
- **V05 engine** emits the items + `reasoning_human` caption already consumed by `OutfitCardCaption`. AU-310 doesn't change the data contract — it's pure presentation.

---

## 7. Open questions (for Viet / tech-lead before implementing)

1. ~~Shimmer vs. opacity-breathing~~ — **resolved by design scroll: Option A soft shimmer (warm-taupe gradient).** Confirm only if you want breathing as the reduced-motion fallback.
2. ~~Gap 4–6px~~ — **resolved: 4px** (measured on node 2850-11205). Padding 16px, card 189×252.
3. ~~2- and 3-card layouts diverge~~ — **resolved by real frames: 3-card already matches; only 2-card (full-width + small below) needs the rework.** All counts 2/3/4/5/6/>6 now confirmed visually.
4. **Item counts in practice** — design tops out at a **">6 items" scrolling catch-all** (no discrete 7+ layouts). What's the floor — does a **1-item** outfit happen? Neither spec nor frames cover 1. Confirm V05's min/max item count per outfit.
5. **Reanimated dependency** — OK to add Reanimated 3 (cleaner stagger/shimmer) or keep to RN `Animated` to avoid a new native dep?
6. **Grid vs. collage primacy** — is `grid` now the default recommendation view, with `collage` demoted? AU-310 only specs grid.
7. **"Within 3 options"** — is this a hard product cap on how many outfit variations a set can hold (relevant to AU-303 + V05 try-another pool)?

---

## 8. Suggested next step

This is a clean, self-contained UI spec assigned to you and authored by the CEO — i.e. **Figma-fidelity-critical** per project rules. The natural path:
`figma-design-extraction` (pull the 2849-11340 frame's tokens + per-count layout slots) → `qa-ui` review-extraction PASS → `figma-to-rn-workflow` to extract a real `OutfitCardGrid` + `OutfitCardSkeleton` out of `HomeScreen.tsx` → `auxi-lint-tokens.sh` → `qa-ui` Compare → `qa-mobile` smoke. No backend/contract changes required.

**Not started — research only. No code changed.**
