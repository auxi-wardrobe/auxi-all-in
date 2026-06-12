# Wardrobe + Add-Item Flow — Figma rebuild report

Date: 2026-06-01 · Branch: `feat/au-310-outfit-cards-layout-loading` (auxi submodule)
Figma: Wardrobe `2850:16483` · Add-item flow `2852:19750` (file `0nXXMAR4Arf1ZfjtQvtBh0`)
Sim verified: iPhone 17 (iOS 26.5), bundle `com.auxi2026.app`, Metro Fast Refresh.

## Step 1 — Extraction (design tokens)

| Token | Value | Theme alias |
|---|---|---|
| App bg | `#f2efec` | `figmaBackground` |
| Tile / panel / divider beige | `#eee6df` | `figmaDetailSurface` / `figmaListDivider` |
| Chip unselected (tan) | `#e0d2c4` | `figmaInsightPillBg` |
| Chip selected (warm dark) | `#5b5550` | `figmaChipBg` |
| CTA / dark icon / text | `#1d1f23` | `uacBackgroundBase` |
| Badge overlay | `#121212` @75% | `rgba(18,18,18,0.75)` (whitelisted) |
| Header icon button bg | `#ffffff` | `figmaSurface` |
| Font | Inter (md16/24, sm14/20, xxs10/12) | `interBodyMd`/`interBodySm`/`interMediumSm`/`interCaptionXxs` (3 added) |
| Radii | tile 12, chip 20, sheet 24 | `borderRadius.figmaTile` / 20 / 24 |

Grid: 3 cols, 24px side padding, 4px gaps, 3:4 tiles. Chips wrap to 2 rows.
Add sheet rows: Search the database / Take a photo / Import from web (icon + title + desc + dividers).

## Step 2 — Related cluster walk

- `database view` (2850:16559) / `database selected` (2850:20024): wardrobe-style beige grid + "common" badges + bottom CTA "Add N item(s)" (grey → dark `#1d1f23` when ≥1 selected). **The shipped `DatabaseScreen.tsx` does NOT match this** (title "Database", scroll chips, white cards, "Add Item") — flagged follow-up.
- `remix (enable an item)` (2852:16707): Outfit Canvas editor (AU-285) — collage on grid paper, toolbar, tag chips, Save. Separate feature, out of scope.

## Step 3 — Code compare (before)

`WardrobeScreen.tsx` (821 LOC): 4-col grid (design=3), emoji icons, "common items" badge (design="common"), hardcoded hex tiles, 2 competing add UIs + dead commented search modal, "Import from Web" no-op, no analytics, no AI-loading screen, used `getImageUrl` not `resolveItemImage`. `PillButton` already had `loading`/`disabled`. `track(event, props)` in `services/analytics.ts`, no wardrobe events.

## Implementation (files changed)

- `screens/WardrobeScreen.tsx` — rebuilt: 3-col grid, `resolveItemImage` cutouts, "common" pill badge, design-order wrapped chips, white header icon squares (menu + plus), redesigned add bottom sheet (real icons + descriptions + dividers, radius 24), AI **"Preparing your item…"** overlay (node 2852:20021), Mixpanel events, removed legacy/catalog dead code.
- `components/features/CategoryTabs.tsx` — warm palette (tan/`#5b5550`), Inter, radius 20, paddingH 12, new opt-in `wrap` prop (Wardrobe/Database wrap; OutfitCanvas unchanged).
- `components/layout/Header.tsx` — added optional `leftIconStyle` (forwarded to left button; lets Wardrobe make menu icon white).
- `assets/images/icon_database.svg`, `icon_globe.svg` + `assets/icons/index.ts` — new `Icons.Database`/`Icons.Globe` (currentColor).
- `theme/theme.ts` — added `interBodyMd` / `interBodySm` / `interMediumSm` aliases.

Mixpanel events: `wardrobe_viewed`, `wardrobe_filter_changed`, `wardrobe_item_opened`, `add_item_opened`, `add_item_method_selected` (search_database|take_photo|import_web), `add_item_upload_started|_succeeded|_failed`.

Loading UI: header plus-button spinner while uploading · full-screen "Preparing" overlay (photo + spinner + 2 steps) · `PillButton.loading` on Database "Add Item".

## Verification (3 visual iterations + flow)

- tsc clean (touched files), eslint clean (touched files), token-lint **0 new** violations.
- it1 `sim-04/05/06`: 3-col grid + add sheet match. it2 `sim-07`: white header squares + chip radius. it3 `sim-08/09`: chips wrap.
- Side-by-side: `cmp-wardrobe-sbs.png`, `cmp-addsheet-sbs.png` (add sheet ≈ pixel match).
- Flow: Search→Database nav OK; Take a photo→Alert→library picker→upload→success toast→grid refresh OK (new item appears).

## Deferred / follow-ups

1. `DatabaseScreen.tsx` visual drift vs `clu1` design (out of scope here).
2. Custom camera-capture screen (cam2) — currently OS picker; full custom camera deferred.
3. ItemDetail attribute pickers (Energy/Material/Occasion/Date, HSV color, multi-select) — backend-field gated.
4. Header menu-icon square is white only on Wardrobe (opt-in); Home still uses default grey — confirm if Home should match.
5. One nature photo was added during the live upload test; delete from QA wardrobe if undesired.

## Unresolved questions

- Chip wrap break is 4+2 (sim) vs 5+1 (design) — pure width rounding on 402pt; acceptable or tighten chip metrics?
- Should the white header icon-button treatment roll out to Home/other screens (design system) or stay Wardrobe-only?
