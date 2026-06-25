# Code Review — PR #74 `feat/home-grid-layout-by-count`

Date: 2026-06-15 · Reviewer: code-reviewer · Focus: CORRECTNESS only (visual fidelity = qa-ui Compare PASS, not re-audited)

## Scope
- Files (4): `src/screens/HomeScreen.tsx` (+206/-85 net region), `src/components/features/HomeViewToggleFooter.tsx`, `src/components/features/WeatherWidget.tsx`, `src/theme/theme.ts`
- Base: `origin/main` · Verified: `npx tsc --noEmit` clean (legacy `_HomeScreen.tsx` excluded), `yarn lint --quiet` clean on all 4 files (no new errors/warnings)

## Verdict: APPROVE-WITH-NITS
One HIGH height-math invariant violation that is currently masked by bottom padding on iPhone 16 (no visible clip today) but breaks the documented "nothing clips for any item count" guarantee and is fragile across devices. Everything else is correct. Not a merge blocker, but fix the HIGH before it bites a smaller device.

---

## Findings

### HIGH — new `gridWrap` vertical padding breaks the GRID_FIT_H "no-clip" invariant
`HomeScreen.tsx` adds `gridWrap { paddingVertical: SHEET_PADDING_V (8) }` (styles ~2345) = **16px total** that is NOT netted out of `GRID_FIT_H` / `computeHeroRowHeight`. The whole grid-fit derivation (constants block ~162-176, comment "total grid height ≤ GRID_AREA_H for any item count → nothing clips, no scroll needed") assumes the only chrome below the rows is `gridScrollContent.paddingBottom (GRID_CONTENT_PAD=16)`. The new 8px top + 8px bottom is unaccounted.

Computed (iPhone 16, 393×852, footer=84):
- `GRID_AREA_H=404`, `GRID_FIT_H=388`, `CARD_HEIGHT=192`
- 2-row scroll-content total = 8(top) + 388(rows) + 8(bottom) + 16(scroll padBottom) = **420** vs `gridScroll maxHeight: GRID_AREA_H = 404` → **16px overflow**.
- hero layouts (count 5/6/7/9/12): overflow **11-12px**.
- `gridScroll` has `scrollEnabled={false}` (line 2018) → overflow is **hard-clipped at the bottom**, exactly the C4/auto-fit regression the math was built to prevent.

Why no visible clip today / why qa-ui PASS missed it: the clipped 16px falls entirely within the **24px of pure bottom padding** below the last card row (gridScrollContent 16 + gridWrap bottom 8). So on iPhone 16 only invisible whitespace is cut — card pixels survive. Pre-PR baseline was exactly fit (2-row total 390 ≤ GRID_AREA_H 392).

Risk: the safety cushion is now ~8px (24px pad − 16px overflow), and the new 8px `paddingTop` shifts the whole grid DOWN, so the bottom is what loses. On a smaller device, a different measured `OPTION_ACTIONS_HEIGHT`, or any future +rest-row, the overflow eats real card edge. The invariant is now false.

Fix (one line, restores the invariant):
```
const GRID_FIT_H = GRID_AREA_H - GRID_CONTENT_PAD - SHEET_PADDING_V * 2;
```
This re-derives `CARD_HEIGHT` and `computeHeroRowHeight`'s `available` so rows shrink by the new padding and total content ≤ GRID_AREA_H again. (Alternatively drop the 8px gridWrap padding and apply the Figma py:8 elsewhere — but netting it into GRID_FIT_H is the smallest change.)

### LOW — `figmaFooterActivePill` token now orphaned by the footer
Footer switched the active capsule from `figmaFooterActivePill` to `figmaInsightPillBg`. The old token still exists in `theme.ts:30` and is no longer referenced anywhere (`grep` confirms only the definition). Harmless (shared palette token), but flag for cleanup if no other surface adopts it.

### NIT — redundant `renderTile` key on directly-rendered tiles
`renderTile` always sets a `key` on its returned element, but in `fullPlusSmall`/`twoRowOneLarge` it is called directly (not in a `.map`) where the key is ignored, and in `twoByTwo`/`heroStackPlusRows` the wrapping `<View>` already carries the row/cell key. No collision, no warning — purely cosmetic redundancy.

---

## Correctness checks that PASSED

1. **`pickLayout` count branches (0,1,2,3,4,5,6,7,8,9…)** — all safe. count 0 → `null` (renderLayout early-returns null, no draw). `filled = items.filter(Boolean)` then count guards mean every `filled[i]` access is in-bounds: fullPlusSmall uses `filled[0]` (count≥1) + `filled[1] ?? null`; twoRowOneLarge `filled[0..2]` (count===3); twoByTwo `filled[0..3]` (count===4); heroStackPlusRows `filled[0..2]` + `filled.slice(3)` (count≥5, rest≥2). No undefined access.
2. **count 1 (`small=null`)** — renders only the full tile, `layout.small ? … : null` guards the second renderTile. OK.
3. **`restRows` pad-to-3 with `null`** — `while (slice.length < 3) slice.push(null)`; null cells render as `cardCellHidden` (opacity 0), non-interactive, NO testID. Visible cols 0/1 stay left-aligned. Correct.
4. **React key uniqueness** — within a rest row, a given `itemIndex` is EITHER `rest-pad-…-{row}-{idx}` OR `rest-shell-…-{row}-{idx}` (never both); different prefixes + unique (row,idx). Hidden static cell in twoRowOneLarge has no key but is not in a map. No collisions.
5. **testID flat-index uniqueness** — fullPlusSmall 0,1 · twoRowOneLarge 0,1,2 · twoByTwo 0-3 (`row*2+idx`) · heroStackPlusRows hero 0, stack 1,2, rest `3+row*3+idx` → 3,4,5,… all unique & contiguous. `home-tile-{cellKey}-{idx}` + `home-tile-pin-…[-set]` preserved on every real tile. Placeholders correctly testID-less. Maestro selectors intact.
6. **">6 scroll" claim** — PR description says ">6 scrolls" but `gridScroll` is `scrollEnabled={false}` and `computeHeroRowHeight` SHRINKS rows so all N items fit in `GRID_FIT_H` (no scroll). This is the intended C4 design (dynamic shrink, not scroll) — the PR description wording is just imprecise; behavior is correct (modulo the HIGH overflow above). No truncation: every item gets a row; >6 packs into rows of 3.
7. **Footer 98→84 consumers** — two: `AVAILABLE_VIEWPORT` (line 142, reduction FREES 14px → taller sheet, opposite of CTA clip) and `moodBanner.bottom` (line 2656, tracks footer height, stays just above shorter footer). CTA reservation is separate (`WEAR_THIS_FOOTER_HEIGHT`, unchanged). CTA not clipped.
8. **activeCell shadow / removed `overflow:hidden` on `.tab`** — removing `.tab` overflow is REQUIRED so the new activeCell drop-shadow (0,1,1) isn't clipped to tab bounds. Parent `.bar` keeps `overflow:hidden` but the tiny shadow (~2px) sits well inside the 56px cluster in an 84px bar — no clip. z-order correct: activeCell rendered before icon → white bg+shadow under, icon on top.
9. **theme `interSemiboldXs` alias** — valid; `Inter-SemiBold` already bundled (used by pre-existing aliases theme.ts:233,240). `uacDimension12` correctly in `spacing` block. All color tokens (`uacTextBase`, `uacTextSubtle100`, `figmaItemDetailHeaderBg`, `figmaInsightPillBg`) exist.
10. **WeatherWidget** — `tempUnit` is a nested `<Text>` inside `temp`; RN inherits parent `Inter-SemiBold` + `uacTextBase` color, overrides only fontSize/lineHeight. Correct. `temp`/`day` set explicit color alongside the alias spread.
11. **Dead code / imports** — none. `cardShellFixed` still used by `HomeLoadingState` skeleton (line 2116). `poppinsButton`/`poppinsBody` still used by 10+ other screens. No broken imports.

---

## Recommended actions (priority order)
1. (HIGH) Subtract `SHEET_PADDING_V*2` from `GRID_FIT_H` to restore the no-clip invariant before merge to a non-iPhone-16 device matrix.
2. (LOW) Remove or repurpose orphaned `figmaFooterActivePill` token.
3. (NIT) Optional: drop redundant key in `renderTile` for direct (non-map) call sites — cosmetic only.

## Unresolved questions
- Is the device test matrix iPhone-16-only? If smaller phones (SE/13 mini) are in scope, the HIGH overflow cushion (~8px) is more likely to clip real card pixels — confirm before merge.
- PR description says ">6 scrolls" — confirm with author this is intended as "shrinks to fit" (current behavior) vs a real scroll requirement; if scroll is genuinely wanted for very large outfits, `scrollEnabled={false}` would need revisiting (and would re-open the AU-303 nested-scroll arbitration concern).
