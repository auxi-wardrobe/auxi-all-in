# qa-ui Compare — AU-362 Outfit Temperature (Pass 2 + Pass 3)

- **Date:** 2026-06-18 · **Branch/commit:** duc2820/au-362-... @ 4dfb4082 · **Mode:** Compare (code-vs-Figma + sim)
- **Figma:** `0nXXMAR4Arf1ZfjtQvtBh0` node 3906-8765 — frames Home/weather (3906:8538), sheet (3906:11465), override (3906:12787)
- **Pass 1 artifact:** `plans/260618-1957-au-362-temperature-adjustment/figma-extraction-temperature-sheet.md`
- **MCP pre-flight:** `mcp-doctor.sh` exit 0 (iPhone 16 Pro booted, WDA :8100, mobile-mcp 0.0.56). Figma MCP available.
- **Sim screenshots (4, within budget):**
  - `auxi/docs/qa-findings/screenshots/2026-06-18/qa-ui-temp-sheet.png` (sheet default)
  - `qa-ui-temp-override.png` (override-active Home)
  - Figma refs: `figma-sheet.png`, `figma-override.png`, `figma-home-weather.png` (same dir)

## Pass 2 — code vs Figma

**Sheet (`TemperatureOverrideSheet.tsx`)**
- Title "Outfit Temperature" / subtitle copy → match Figma verbatim (en-EN.json:396-397). ✓
- 5 radio rows in order: Use current weather (XX°C) default · 28–40 · 10-25 · 0-7 · -10-0 → match (en-EN.json:398-402, buckets config). ✓
- Radio at row right edge; selected = dark filled dot (inner #070707 `figmaTextDark`, ring `figmaTextDark`), unselected = hollow tan ring (`figmaDotInactive` #c6bcb1) → matches Figma. ✓
- Row dividers = hairline `uacColorNeutral100` (#f2f4f7) → matches `border/neutral/subtle_300`. ✓
- Apply = full-width filled PillButton (dark `ds.color.ink` #1d1f23), Cancel = centered text button below → matches. ✓
- Sheet surface white `figmaSurface`, radius `borderRadius.l` (16) → matches `border-radius/2xl`. ✓
- Scrim = `figmaOverlayScrim` rgba(38,36,33,0.7) on Modal overlay → matches dark dim. ✓
- Apply disabled+loading while `isApplying`; backdrop/Cancel guarded during apply → correct state coverage. ✓
- Typography: title `uacBodyMdSemibold` (Inter SemiBold 16), rows `interBodyMd` (Inter 16/24), subtitle `interBodySm` (Inter 14/20), Cancel `uacBodyMdMedium` → match extraction. ✓

**Override header (`TemperatureOverrideIndicator.tsx` + HomeScreen swap)**
- Weather widget → indicator swap driven by single-source `useTemperatureOverride` (header + request layer can't disagree). ✓
- Person glyph `Icons.User` + selected bucket label + chevron (rotated ChevronRight 90°) → matches Figma structure (D4: label = selected bucket, not the "10-35" mock — intentional, not flagged). ✓
- Label typography `interSemiboldXs` = identical token the WeatherWidget uses for temp → header parity preserved on swap. ✓

**Lightbulb pill (`OutfitCardCaption.tsx`)**
- Idle: `figmaInsightPillBg` (#e0d2c4) + dark glyph. Active: `figmaChipBg` (#5b5550) + white glyph → matches Figma `degree selected` darker pill. ✓
- Pill is pressable only on Home (onPressInsight); stays non-interactive insight indicator elsewhere (Favourites) → correct. ✓

**Tokens / hex lint**
- `grep` for hex/rgba in both new components → 0 matches. No raw hex. All colors/fonts/radii/spacing resolve to existing theme tokens. No `theme.ts` drift (consistent with extraction §3 "no new tokens"). ✓

## Pass 3 — sim (RAN)

Walked weather → sheet open → select → Apply → override Home on iPhone 16 Pro.
- **Sheet** renders pixel-faithful to `figma-sheet.png`: title/subtitle, 5 rows w/ right-edge radios, default "Use current weather (31°C)" selected (live temp interpolated), dividers, dark full-width Apply, Cancel below, scrim behind. ✓
- **Radio toggle**: tapping a row moves the dark filled dot to it and hollows the rest — single-select confirmed. ✓
- **Apply → override**: header swapped to `person icon + "-10 - 0°C" + chevron`; lightbulb pill rendered active (darker fill, light glyph beside "Easy lines." caption); a temperature-adjusted recommendation was re-fetched. Matches `figma-override.png` (allowing for D4 label). ✓

## Findings

| # | Sev | Finding |
|---|-----|---------|
| 1 | minor | Sheet uses fixed `width: min(screenWidth-16, 414)` with 8px side margins (card-style sheet), whereas Figma renders the sheet edge-to-edge (full bleed, top-rounded only). Matches the house `ContextChipsModal` pattern, so it's a deliberate system convention, not a defect — noting for cross-screen awareness only. |

No blocker/major findings. The single minor is a pre-existing house-sheet convention (not introduced by this feature) and the extraction explicitly cloned `ContextChipsModal`.

## Intentional decisions confirmed (NOT flagged)
- D1 bucket→rep-temp midpoints ✓ · D4 reuse `Icons.User` + selected-bucket label (not Figma "10-35" mock) ✓.

## Unresolved Qs
- None blocking. (Extraction §9 already flagged `temperature_apply_clicked` present-tense naming + `10-25` midpoint lossiness for CEO — out of qa-ui visual scope.)

---

**Verdict:** PASS (Pass 3 RAN — all 3 states verified on sim)
**Status:** DONE — Sheet, override header, and active lightbulb pill are faithful to Figma on tokens/typography/spacing/state; no raw hex; 1 minor (pre-existing house-sheet width convention).
