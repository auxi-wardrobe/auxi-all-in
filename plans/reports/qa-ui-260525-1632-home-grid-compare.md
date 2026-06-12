# qa-ui Compare — Home Grid View (AU-253) vs Figma

> Mode: Compare (post-code). Pass 2 (code vs Figma spec) complete. Pass 3 SKIPPED — no booted sim (Metro up, but app not installed on any booted device; per dispatch, no build churn).
> Date: 2026-05-25 · Reviewer: qa-ui
> Figma truth: file `0nXXMAR4Arf1ZfjtQvtBh0`, section `2849:11340`, canonical frame `Home 1/3` `2850:9125`.
> Figma MCP tools used: `get_variable_defs` (2849:11340), `get_design_context` (2850:9125 — full canonical frame incl. footer/CTA/pager), `get_metadata` (2464:17348), `get_screenshot` (2850:9125).
> Code audited (branch `feat/au-253-home-grid-view`, uncommitted): HomeScreen.tsx, OutfitCardCaption.tsx, OutfitActionRow.tsx, HomeViewToggleFooter.tsx, theme.ts, 4 new SVGs.

## Verdict: PASS-WITH-DELTAS

The implementation is a faithful, token-clean translation of the Figma Grid View. All 6 added tokens match Figma hex exactly, no raw hex leaked into the new component files, the caption row / CTA / adaptive grid / pager / "Show another" disabled state all match spec, and the Remix omission is correct per CEO scope. Two real fidelity deltas (1 MED, 1 MED) and several LOW nits/known-deltas remain. None are blockers; route the two MEDs to mobile-dev.

---

## Findings

### HIGH
None.

### MED

**M1 — Footer active pill geometry wrong (shape + size).**
- Figma `2464:17314`: active pill is a single **158w × 56h, radius 14** cream (`background/primary/subtle_200 #eee6df`) capsule sitting at `left-128` **behind the entire 2-tab cluster** (cluster is 149w, centered). Tab 1 then has its own white 66×48 inner cell (`2464:17303`) layered on top; tab 2's cell is transparent (`opacity-0`). The screenshot confirms one wide cream capsule spanning both tabs, white cell over the active (grid) tab.
- Code (`HomeViewToggleFooter.tsx` `activePill`): renders a **56×56, radius 14** pill that is positioned `left:0` and flips to `right:0` on toggle (`activePillRight`). This is a per-tab square that slides, not the wide 158w capsule behind both tabs.
- Impact: the active-tab affordance reads differently — Figma is a static wide cream bed with a white chip over the selected tab; code is a single small pill that jumps tab-to-tab. Visual mismatch on the most prominent NEW surface of this ticket.
- Fix: render the cream 158w capsule as a static background behind the cluster, then a white inner cell (66×48, radius 13) over the active tab, matching `2464:17303` vs `2464:17307` (opacity-0 inactive). Route → mobile-dev.

**M2 — "Show another" label font family is Inter, Figma is Poppins.**
- Figma `Text-xs/Regular` resolves to `font-family/body = Poppins` (confirmed by `get_variable_defs`; the `'Inter:Regular'` string in design-context is the MCP literal-font fallback, exactly as the extraction artifact Q4 + Pass-1 established Poppins as authoritative).
- Code (`OutfitActionRow.tsx` `showAnotherText`): `...theme.typography.aliases.uacBodyXsRegular` → `fontFamily: 'Inter-Regular'` (theme.ts:171). Wrong family for a body-text label.
- Note: this is the same Inter-vs-Poppins drift the artifact flagged; the new code re-introduced it by reaching for the `uac*` Inter alias instead of a Poppins 12/16 alias. There is no Poppins 12/16 alias in theme.ts today — `poppinsBody` is 16/24.
- Fix: add a Poppins 12/16 alias (e.g. `poppinsXs`) and use it for the "Show another" label (and any other `Text-xs/Regular` body labels), or override `fontFamily: 'Poppins-Regular'` inline. Route → mobile-dev. (Tie-in: the "common" tile tag in HomeScreen.tsx:1705 also hardcodes `Inter-Regular` for `Text-xxs/Regular` which Figma also maps to Poppins — same class of drift, pre-existing, worth folding into the same fix.)

### LOW

**L1 — Pager dots: active-dot styling is an interpretation, not spec-derived.**
- Figma renders the 3 dots as a single flat image (`imgFrame2036`, node `2850:9144`) with **no per-dot active/inactive color encoded** — artifact Q2 explicitly left this open. Code renders active = `uacTextBase #1d1f23` (dark), inactive = `figmaInsightPillBg #e0d2c4` (muted). This is a reasonable, documented resolution and matches the dispatch's stated intent ("active dark / inactive muted"). No change needed, but flag that it is a design decision the code made, not a value read from Figma — confirm with CEO that dark/muted is the intended treatment.

**L2 — Dot inactive color reuses the insight-pill token.**
- Inactive dot uses `figmaInsightPillBg #e0d2c4` (the caption insight-pill bg). Semantically odd to drive a pager dot off a pill-background token; if the designer later picks a distinct muted-dot color this will need its own token. Cosmetic; current hex reads acceptably muted. No action now.

**L3 — Caption is stubbed (expected, in scope guard).**
- `OutfitCardCaption` renders `DEFAULT_CAPTION = 'Clean. Ready for today'` because the Outfit/V05Outfit contract has no `caption`/`insight` field. The *rendering* fidelity is correct: pill bg `#eee6df`, text `uacTextBase`, `poppinsBody` (Poppins 16/24 = Figma `Text-md/Regular` ✓), padX 12 / padY 8 / radius 4 / gap 4 all match Frame 2104. Default copy matches the Figma sample string verbatim. Data wiring is a known backend gap (escalated), not a fidelity defect.

**L4 — Footer blur is translucent-View fallback (known delta).**
- `@react-native-community/blur` not installed; `HomeViewToggleFooter` uses a `figmaSurface` View at opacity 0.85. Figma is `backdrop-blur 3.25px` + opacity 0.85. Documented in code + artifact Q5. Acceptable known delta, not a fail.

**L5 — CTA "Wear this" trailing heart is fine; header right heart maps to Figma "feedback" slot.**
- CTA: outline, radius 16, border `uacBorderBase #1d1f23`, label `figmaCtaLabel #262421`, heart 24×24, `poppinsButton` (Poppins Medium 16/24) — all match `2850:9151`. ✓
- Header right icon: Figma slot is "feedback" (heart glyph 16×14 in a 47×47 cell); current build maps it to the favourite-heart toggle (24×24). Functional reinterpretation noted in the artifact (header is REUSED, pre-existing). Out of scope for this ticket; no change.

**L6 — Plain Tooltip first-run hint not implemented (known follow-up).**
- Tooltip tokens (`figmaTooltipBg #322f35`, `figmaTooltipText #f5eff7`) were correctly added to theme.ts ahead of the feature, but no tooltip is rendered. Per scope guard, this is a known follow-up, not a fail.

---

## Point-by-point verification (dispatch checklist)

| # | Check | Result |
|---|---|---|
| 1 | 6 tokens match Figma hex; no raw hex in 3 new files | PASS — `figmaCaptionPillBg #eee6df`, `figmaInsightPillBg #e0d2c4`, `figmaCtaLabel #262421`, `figmaFooterActivePill #eee6df`, `figmaTooltipBg #322f35`, `figmaTooltipText #f5eff7` all = `get_variable_defs`. `borderRadius.figmaTile = 12` added. `grep -E '#[0-9a-fA-F]{3,8}'` on the 3 new files = none. |
| 2 | Caption row (Frame 2104) | PASS — caption pill `#eee6df`, insight pill `#e0d2c4` 40×40, idea icon 16×16 currentColor, padX 12 / padY 8 / radius 4 / gap 4. |
| 3 | Adaptive grid (3/4/5/6/>6), 4-default = Home 1/3 | PASS — `pickLayout` count→shape mapping matches: 3=twoRowOneLarge (2-top + 1-bottom-left), 4=twoByTwo (even 2×2, = canonical `Home 1/3`), 5/6/>6=heroStackPlusRows. Tile radius 12, 4px gaps, 3:4 aspect intent (height capped on small screens by design, documented C4/2026-05-18). |
| 4 | Action row: 3 dots (active/inactive), "Show another" + swipe, disabled@tail, NO Remix | PASS (with L1) — 3 dots, dark/muted; "Show another" + `icon_swipe.svg`; `showAnotherDisabled = sheetIndex >= total-1` → opacity 0.5; Remix correctly omitted. |
| 5 | CTA: "Wear this" outline, radius 16, border + label per spec, heart 24×24 | PASS — see L5. |
| 6 | Footer: toggle bar, active pill, grid tabs, 414×98 sizing | PASS-WITH-DELTA — bar 98h, 2 grid tabs 66×48 radius 13, `icon_grid` + `icon_grid_alt` 24×24. Active pill geometry wrong → **M1**. |
| 7 | Poppins body (not Inter) per artifact | FAIL on "Show another" → **M2**; caption + CTA correctly Poppins. |

## Asset check
`icon_idea.svg` (16 viewBox, currentColor fill ✓), `icon_swipe.svg` (16, currentColor ✓), `icon_grid.svg` (24, currentColor stroke ✓), `icon_grid_alt.svg` (24, currentColor stroke ✓). All four normalized correctly.

## Routing
- **M1 (footer pill geometry)** → mobile-dev. Pure layout fix in `HomeViewToggleFooter.tsx`.
- **M2 (Show another / common-tag font)** → mobile-dev. Token-class drift (Inter where Figma = Poppins body). Add a Poppins `Text-xs/Text-xxs` alias to theme.ts rather than per-screen literals; fold in the pre-existing `cardTagText` Inter literal.
- **L1** → confirm dark/muted active-dot treatment with CEO (Q2 was open in extraction).

## Pass 3
NOT RUN. No booted iOS simulator (`xcrun simctl list devices booted` = none; app not installed on any booted device). Metro is up but irrelevant without an installed app on a booted sim. Did not build/boot per project memory (fragile sim setup, no build churn). Re-run Pass 3 when a live build is on a booted sim.

## Unresolved questions
- Q2 (carry-over): active-dot styling — confirm dark/muted is intended (code chose it; Figma encodes nothing).
- M2 scope: is adding a `poppinsXs` alias + fixing the pre-existing `cardTagText` Inter literal in-scope for AU-253 or a separate token-hygiene follow-up?
