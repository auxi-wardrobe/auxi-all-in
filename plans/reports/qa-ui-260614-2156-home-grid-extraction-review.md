# qa-ui review-extraction — Home grid layouts (Pass 1, pre-code)

- **Mode**: review-extraction (Pass 1 ONLY — artifact vs Figma, no code, no sim).
- **Artifact**: `plans/260614-2156-home-grid-layouts/figma-extraction-home-grid-layouts.md`
- **Figma file**: `0nXXMAR4Arf1ZfjtQvtBh0`
- **Reviewed**: 2026-06-14 by qa-ui
- **Figma MCP pre-flight**: OK (`get_metadata` / `get_design_context` / `get_variable_defs` all responding).

## VERDICT: **PASS (with one alignment correction)**

The artifact is an exceptionally faithful extraction. Every grid frame mapping,
tile dimension (258.5×343.5 hero, 127.3×169.733 small, 193 flex tiles), gap (4/4),
outer inset (12/8), radius (12/8), the 2-item full-width-then-drop rule, the
opacity-0 placeholder rule for 3 and 5, the 6/>6 "2×flex + 1×fixed-127" bottom
row, the >6 scroll/repeat behavior, AND the full header/footer spec (height
107/84, pad 12, active pill 116×56 #e0d2c4, nav 48×48 r11, weather Inter 12 +
7.74 °C, canonical note 90%/8px/sticky) — all verified frame-by-frame and match
Figma.

**One factual misread** found (item-1 alignment in the 2-item case). It is a
LOW-severity wording/layout-intent error, not a structural gap, so this PASSES
the gate — but mobile-dev MUST apply the correction below before implementing,
because it changes the rendered position of the small card.

---

## Corrections table (claim → Figma actual)

| # | Sev | Artifact claim | Figma actual | Where |
|---|-----|----------------|--------------|-------|
| C1 | LOW | 2-item: item1 (127.3 small) is **left-aligned**, in an **`items-start`** column (frame tree L70-76; table L84 "left-aligned, on its own row") | The image-holding column `3230:35286` is **`flex-col gap-4 items-center justify-center`** → item1 is **CENTERED**, not left-aligned. (Item0 full-width fills the row so it looks left-flush; item1 at 127.3 is horizontally centered under it.) | grid body inner col `3230:35286` |

Note: the artifact's OUTER wrapper claim (`3230:35285` = `items-start`) is correct,
but the actual tile column nested inside it (`3230:35286`) is `items-center` — the
artifact conflated the two and labelled the visible result "left-aligned". The 3/5
"lone-tile left-align via opacity-0 placeholder" claims are a DIFFERENT mechanism
and are 100% correct (see verified list).

---

## Verified correct (no change needed)

**Grid frame mappings** (all confirmed via `get_metadata`):
- 2 → frame `3230:35149` "outfit with 2 items", grid `3230:35901` (variant "2") ✓
- 3 → frame `2850:9613`, grid `3227:18826` (variant "3") ✓
- 4 → frame `2850:9125` "Home 1/3" = `swipe card` `3788:10956` + `buttons under card` `3788:9511` ✓ (artifact's mapping caveat L9-14 + Q1 are accurate)
- 5 → frame `2850:9580`, grid `3227:18976` (variant "5") ✓
- 6 → frame `2850:9508`, grid `3227:19147` (variant "6") ✓
- >6 → frame `2850:9542` "outfit with >6 items", grid `3227:19318` (variant ">6"), grid h=**759.1** > 896 viewport → scroll ✓

**Frame canvas**: every frame 414×896, header 107 @ y0, footer 84 @ y812 ✓

**Shared tokens** (via `get_variable_defs` on `3230:35901` + `3230:35155`):
- `background/primary/subtle_50` #f2efec ✓ · `color/primary/100` #eee6df ✓ · `color/primary/200` #e0d2c4 ✓
- `color/neutral/800` #1d1f23 ✓ · `color/neutral/50` #fcfcfd ✓
- `color/neutral/black/Alpha300` #121212bf (75%) ✓ · `background/overlay/light/30` #ffffff4d (30%) ✓
- `border-radius/md` 8 ✓ · `border-radius/xl` 12 ✓ · `dimension/12` 12 ✓
- `body/sm` 14/lh16 Inter400 ✓ · `body/xxs` 10/lh12 Inter400 ✓
- Header: `background/neutral/subtlest` #ffffff ✓ · `background/overlay/dark/10` #8271371a ✓ · `icon/primary/bold_700` #070707 ✓ · `text/neutral/base` #1d1f23 ✓ · `text/neutral/subtle_100` #40444d ✓ · `body/xs` 12/lh16 ✓

**Card primitive** (every tile): aspect 3/4, bg #f2efec, radius 12, overflow hidden;
pin badge **34×34 r8** translucent-white (#ffffff4d) shadow `4 4 5.3 rgba(7,7,7,0.05)`
glyph 17×17; rarity "common" badge bottom-8 center h19 px12 r8 rgba(18,18,18,0.75)
10px #fcfcfd — ALL verified across 2/3/5/6/>6. ✓

**Grid container**: `flex-col gap-12 px-12 py-8 w-414`; caption row gap-4 (pill #eee6df
px12 py8 r54 14px + insight pill #e0d2c4 h40 px12 py8 r23 + carbon:idea 16×16);
grid body gap-4 row & col; content width 390 = 414−24. ✓

**Per-count layout rules — all verified exactly:**
- **2**: item0 `aspect-3/4 w-full` (390), item1 fixed 127.3×169.733 dropped to next row, gap4. ✓ (only alignment is C1.)
- **3**: 2 rows × 2 `flex-[1_0_0]`; R2C2 = real cell `opacity-0` (`3227:17346`), body `items-start` → lone tile left. ✓
- **4**: 2×2 all `flex-1 aspect-3/4` (swipe-card default page). ✓
- **5**: R1 `justify-end` hero 258.5×343.5 + stack(2× 127.3×169.733 gap4 justify-center); R2 `justify-center` 2× flex-1 + 1× 127.3 `opacity-0` (`3227:17755`); body `items-center`; math 258.5+4+127.3=389.8. ✓
- **6**: same top row; R2 = 2× flex-1 + 1× 127.3 **visible** (`3227:17633`, no opacity-0) → intended 2-wide+1-narrow asymmetry. ✓
- **>6**: top row + N×(2 flex-1 + 1 fixed-127) rows, all visible, no truncation/+N badge; 9 items = hero+2stack+2×3. ✓

**Footer** (`3230:35156` → `2464:17348`): h84 `backdrop-blur-4`; backing 430×100 opacity-80 blur-7.5 #ffffff; nav row opacity-85 pt6; active capsule 116×56 r14 #e0d2c4; nav button 48×48 r11 #ffffff shadow `0 1 1 rgba(0,0,0,0.15)`; cluster gap12; mynaui:grid 24×24. ✓

**Header** (`3230:35155` → `1769:10369`): h107 `backdrop-blur-4`; bg 414×108 opacity-90 #ffffff; content bar h107 `items-center justify-end p-12`; row space-between; menu/right 44×44 surface + icon 24×24; weather glyph 35×32 gap7; "32" Inter SemiBold 12/16 #1d1f23 + "°C" 7.74; "Monday" Inter Regular 12/16 #40444d. ✓

**Canonical note** (`3227:26929`): note "#3" title "Header and Footer (sticky)",
body verbatim "background 90% opacity and using blur effect is 8px / Behavior:
sticky / Scroll content moves underneath sticky UI". Matches artifact quote. ✓
(Correctly supersedes the brief's "4px" and the per-layer instance numbers.)

---

## Review-extraction checklist

- [x] Frame tree matches Figma `get_metadata` (no missing/hidden/invented node) — **1 alignment mislabel (C1), structure otherwise exact**
- [x] Token list complete — every fill/stroke/pad/font resolves to a captured variable
- [x] Icon enumeration complete — carbon:idea 16, pin glyph 17-in-34, mynaui:grid 24, weather 35×32, menu/heart 24 all listed (sizes flagged for reconcile in Q5/Q13)
- [x] Variant/state coverage — Pin Default/pinned, swipe-card 3 pages, footer grid, opacity-0 placeholders all listed
- [x] "Open questions" non-empty — Q1-Q14 cover every genuine ambiguity (mapping, 2-item rule, footer opacity/blur strategy, token gaps, sticky restructure, weather font, footer height paging math)
- [x] "New backend fields" accurate — rarity flagged as the only potential contract gap (pending Q7); correctly says to check `src/services/recommendation.ts` before rendering

## Notes for mobile-dev (carry into figma-to-rn-workflow Phase 1)

1. **Apply C1**: 2-item small card is **centered**, not left-aligned. Use the
   inner column `items-center justify-center` (Figma `3230:35286`), not `items-start`.
2. Open questions Q1-Q14 are legitimately CEO/tech-lead decisions (esp. Q2 the
   headline 2-item rule change, Q8 blur strategy = native dep, Q11 sticky
   restructure, Q14 footer-height paging math). These are **ESCALATE-class** but
   the artifact already routes them correctly — they do not block the extraction
   gate, they block implementation choices. Surface via pm before coding the
   header/footer + 2-item changes.
3. No token literals required: every value maps to an existing or proposed
   `theme.ts` token (Q4/Q9/Q10 propose the 4 missing ones). Keep `auxi-lint-tokens.sh` clean.

---

**Status:** DONE_WITH_CONCERNS
**Summary:** PASS — extraction is faithful frame-by-frame; one LOW correction (C1: 2-item small card is centered, not left-aligned) to apply before coding.
**Concerns/Blockers:** C1 must be fixed in implementation. Open questions Q1/Q2/Q8/Q11/Q14 are ESCALATE-class implementation decisions (already routed in the artifact) — pm should surface to CEO/tech-lead before mobile-dev codes the 2-item rule change, sticky header/footer restructure, blur strategy, and footer-height paging math.
