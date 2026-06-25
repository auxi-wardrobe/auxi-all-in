# qa-ui Compare — Pass 2 (code-vs-Figma) — Home grid + header + footer

- **Mode**: Compare, **Pass 2 ONLY** (code-vs-Figma; no sim, no app run).
- **Focus**: PADDING & spacing (CEO request) + grid dims + header/footer.
- **Reviewed**: 2026-06-15 by qa-ui.
- **Files audited**:
  - `auxi/src/screens/HomeScreen.tsx`
  - `auxi/src/components/features/WeatherWidget.tsx`
  - `auxi/src/components/features/HomeViewToggleFooter.tsx`
- **Source of truth**: `plans/260614-2156-home-grid-layouts/figma-extraction-home-grid-layouts.md`
  + prior review `plans/reports/qa-ui-260614-2156-home-grid-extraction-review.md` (note C1).
- **Out of scope (CEO decisions, NOT failed)**: no real blur (90% opaque fallback),
  header not sticky, pin badge treatment unchanged, rarity badge absent.

## VERDICT: **PASS**

Every padding/spacing/dimension value in the brief matches Figma or the
authoritative extraction artifact. The headline 2-item alignment follows the
C1 correction (centered), not the artifact's superseded "left-aligned" text.
No spacing discrepancies. One non-blocking observation on hero sizing.

---

## Padding & spacing (CEO focus) — verified

| Property | Code (file:line) | Figma/artifact | Result |
|---|---|---|---|
| Outer horizontal inset `SHEET_PADDING` | 12 (HomeScreen:87; `optionSheet.paddingHorizontal` :2326) | 12 (`dimension/12`) | ✅ |
| Grid vertical inset `SHEET_PADDING_V` → `gridWrap.paddingVertical` | 8 (:92, :2345) | py 8 | ✅ |
| Tile gap `GRID_GAP` (row + col) | 4 (:83; `cardRow.gap`/`gridWrap.gap`/`heroRow.gap`/`heroStackCol.gap`) | 4 / 4 | ✅ |
| optionSheet block gap | 12 (:2334) | 12 inter-block rhythm | ✅ |
| Header padding H/T/B `styles.header` | 12 / 12 / 12 (:2167-2169) | 12 all sides (3227:19826) | ✅ |
| Footer cluster gap `tabCluster.gap` | `uacDimension12`=12 (Footer:115) | 12 | ✅ |
| Weather row gap | 7 (WeatherWidget:56) | 7 | ✅ |

## Grid dimensions — verified

| Property | Code | Figma | Result |
|---|---|---|---|
| `SMALL_CARD_WIDTH/HEIGHT` (`cardFixedSmall`) | 127.3 × 169.733 (:95-96, :2411-2414) | 127.3 × 169.733 | ✅ |
| `CARD_ASPECT` | 0.75 (:97) | 3:4 = 0.75 | ✅ |
| Card radius | 12 (`card.borderRadius` :2422; `cardFull`/tiles) | border-radius/xl 12 | ✅ |
| Hero 258.5×343.5 | flex 2 : 1 ratio (`heroCol`/`heroStackCol` :2444-2450) | 258.5×343.5 hero + 127.3 stack | ✅ (approx, see OBS-1) |
| pin badge | 34×34 r `m`(8), top8 right9, shadow 4/4/5.3 (:2464-2480) | 34×34 r8, top8 right9, shadow 4 4 5.3 rgba(7,7,7,0.05) | ✅ |

## Per-count layout shapes — verified (`pickLayout` :1657-1697)

| Count | Code branch | Figma rule | Result |
|---|---|---|---|
| 1-2 | `fullPlusSmall` — full + small drop, `gridWrapCenter` (centered) | item0 full 390 + item1 127.3 centered next row | ✅ (C1 applied) |
| 3 | `twoRowOneLarge` — R2C2 `cardCellHidden` opacity-0, `gridWrapStart` | 2×2, lone 3rd LEFT via opacity-0 placeholder | ✅ |
| 4 | `twoByTwo` — static 2×2 flex-1 | 2×2 all flex-1 | ✅ |
| 5/6/>6 | `heroStackPlusRows` — hero+2stack, rows `[flex-1][flex-1][fixed-127]`, opacity-0 pad, scroll for >6 | hero 258.5×343.5 + 2-stack; bottom [flex][flex][fixed127]; 5→C3 opacity-0; 6→visible; >6 scroll | ✅ |

## Weather typography — verified

| Property | Code | Figma | Result |
|---|---|---|---|
| temp | `interSemiboldXs` = Inter-SemiBold 12/16 (theme:265-269), color `uacTextBase` #1d1f23 | Inter SemiBold 12/16 #1d1f23 | ✅ |
| °C unit | fontSize 8, lineHeight 16 (WeatherWidget:65-68) | 8px (artifact); Figma instance 7.74 | ✅ (8 ≈ 7.74, brief value honored) |
| day | `uacBodyXsRegular` = Inter-Regular 12/16 (theme:254-258), color `uacTextSubtle100` #40444d | Inter Regular 12/16 #40444d | ✅ |
| icon size | 35 (WeatherWidget:38) | 35 (×32) | ✅ |

## Footer — verified (`HomeViewToggleFooter.tsx`)

| Property | Code | Figma/note | Result |
|---|---|---|---|
| bar height | 84 (`HOME_VIEW_TOGGLE_FOOTER_HEIGHT` :28) | 84 | ✅ |
| bg | `figmaItemDetailHeaderBg` = #fff @90% (:109; theme:107) | #fff @90% (canonical note) | ✅ |
| blur | none (opacity fallback :18-21) | 8px note | OUT OF SCOPE (CEO: no native dep) |
| active capsule | 116×56 r14 `figmaInsightPillBg` #e0d2c4 (:121-127) | 116×56 r14 #e0d2c4 | ✅ |
| nav buttons | 48×48 r11 (`tab` :128-134) | 48×48 r11 | ✅ |
| active cell shadow | 0/1/1 rgba(0,0,0,0.15) (`activeCell` :141-145) | 0 1 1 rgba(0,0,0,0.15) | ✅ |
| cluster gap / width | gap 12, width 108 (:115-117) | gap 12 | ✅ |

## Discrepancies

**None** affecting padding/spacing/dimensions. All brief values verified
against Figma or the authoritative artifact/C1 correction.

### Observations (non-blocking)

- **OBS-1 (hero sizing, INFO)**: Hero + stack use flex ratio `2 : 1`
  (`heroCol` flex 2 / `heroStackCol` flex 1) rather than literal px
  258.5 / 127.3. On the 390 content frame this resolves to ~256 hero +
  ~127 stack — within ~1-2pt of Figma. On non-390 device widths the hero
  is NOT pixel-locked to 258.5. Documented intentional approximation
  (HomeScreen.tsx:2435-2439); verified equivalently by the prior extraction
  review. No change unless CEO wants pixel-locked hero widths across all
  device widths.

- **OBS-2 (artifact vs C1, RESOLVED)**: The extraction artifact text
  (L84, L223) labels the 2-item small card "left-aligned". The qa-ui C1
  correction superseded this to **centered**. The code correctly implements
  centered (`gridWrapCenter` :2349-2352, comments :1635-1636/:1850-1851).
  Not a defect — flagging that the artifact body text is stale on this point.

## Items NOT verifiable in Pass 2 (deferred to Pass 3, sim)

- Rendered visual centering of the 2-item small card at runtime.
- Hero/stack effective px on the actual sim device width.
- Footer translucency/contrast over scrolling content.
- (All require a sim screenshot — Pass 3, separate dispatch, ≤4 surfaces.)

---

**Status:** DONE
**Summary:** PASS — all padding (outer inset 12, grid py 8, gap 4, header pad 12), grid dims (127.3×169.733, aspect 0.75), 2-item centered (C1), weather Inter 12/16, and footer (84/116×56/48×48/gap12) match Figma. No discrepancies.
**Concerns/Blockers:** None blocking. OBS-1 (hero is flex-ratio, not pixel-locked 258.5) is intentional/documented — confirm with CEO only if pixel-exact hero width across device widths is required. Runtime visual checks deferred to Pass 3 (sim).
