# Figma Extraction — Wardrobe Item Detail (AU-311)

- **Figma file**: Auxi — `0nXXMAR4Arf1ZfjtQvtBh0`
- **Section node**: `2852:7175` "Item detail | Edit detail" (3339×3376)
- **Target screen**: the FIRST detail screen + its edit-mode bottom bar (Save/Cancel)
- **Device frame**: 414×896 (iPhone 11-ish width 414)
- **Screenshots**: `figma-section-overview.png`, `frame-detail-base.png`,
  `frame-detail-save.png`, `frame-more.png`, `frame-more-edit.png`

## Section contains 4 relevant screen-state frames (same screen, different states)

| Frame | id | State | Bottom bar |
|---|---|---|---|
| `detail` | 2852:14557 | READ, collapsed (image only) | Mix-with-this pill + [Trash][Less used] / [Change] |
| `detail item - more` | 2850:16678 | READ, expanded (full detail list) | same as above |
| `detail - save` | 2852:14647 | EDIT, collapsed (Name row + More/Edit) | **[Cancel] [Save]** |
| `detail item - more - edit` | 2852:16316 | EDIT, expanded (rows w/ pencils) | **[Cancel] [Save]** |

The CEO's "first screen" = the detail view (read mode). Ticket's hard ask:
in EDIT mode the bottom shifts to **Save + Cancel** — that is frames
`detail - save` / `more - edit`.

## Frame tree (read-expanded `detail item - more`, node 2850:16681)

```
SafeArea (white #ffffff)
├── Header (107h) — back chevron only (44×44 menu glyph, blur bg)
├── Image 3:4 (414×552) bg #f2efec, contain; "common" badge pill (rgba(18,18,18,0.75), radius 8) when catalog
└── BottomSheet "detail" — bg #ffffff, radius-top 16, padX 16, padTop 16, padBottom 32, gap 24
    ├── List (column, full width)
    │   ├── List item (h56): Label(left) ↔ Value(right) + Divider hairline
    │   │   rows: Name, Style, Eneegy*, Lable*, Color(•dot), Fit, Material*, Occasion*, Purchase Date*
    │   └── More/Less row (h44): "Less ⌃" (left, Inter Medium 12) / "Edit" (right, Inter Medium 12)
    └── Actions (column, gap 8, full width)
        ├── "Mix with this ⤬" — outline pill, flex:1, h56, radius16, border 1.5 #1d1f23, padX20/padY16
        └── Row (space-between):
            ├── left group (gap 4): [Trash icon btn 24] + "Less used ⊖" text-pill (h56, padX20, radius100, color #c0392b)
            └── "Change ↻" text-pill (h56, padX20, radius100, color #1d1f23)
```
\* Eneegy/Lable/Material/Occasion/Purchase Date are MOCK fields — see "New backend fields".

## Frame tree (edit-expanded `detail item - more - edit`, node 2852:16324)

Same as above EXCEPT:
- Each detail row value gets a trailing **edit pencil** icon (24×24, name="edit").
- "Edit" link is disabled/greyed (opacity 0.5) while editing.
- Actions block REPLACED by a single row (gap 16):
  - **Cancel** — Text button, flex:1, h56, radius 100, padX 20, transparent bg,
    label color `#1d1f23` (text/neutral/base), Poppins/Inter Medium 16/24.
  - **Save** — Primary button, flex:1, h56, radius **16**, bg `#1d1f23`
    (background/neutral/base), label color `#f2efec` (text/primary/base), 16/24.
- `detail - save` (collapsed edit) shows just the Name row + More/Edit + Cancel/Save.

## Tokens used (Figma var → theme.ts mapping)

| Figma var | Hex | theme.ts token | Status |
|---|---|---|---|
| background/neutral/subtlest | #ffffff | colors.white / figmaSurface | exists |
| background/primary/subtle_50 | #f2efec | colors.figmaBackground | exists |
| background/neutral/base | #1d1f23 | colors.uacBackgroundBase | exists |
| border/neutral/base | #1d1f23 | colors.uacBorderBase | exists |
| text/neutral/base | #1d1f23 | colors.uacTextBase | exists |
| text/primary/base | #f2efec | colors.uacTextPrimaryBase | exists |
| text/primary/bold_700 | #070707 | colors.figmaTextDark | exists |
| **text/danger/base** | **#c0392b** | colors.figmaItemDetailDanger (NEW) | **DRIFT** — see below |
| border/neutral/subtle_300 | #f2f4f7 | colors.uacColorNeutral100 (#f2f4f7) | exists |
| color/neutral/black/Alpha300 | rgba(18,18,18,0.75) | colors.figmaCardTag | exists |
| text/info/base (color dot) | #1465b4 | colors.uacTextInfoBase | exists |

### Spacing
- padX 16, padTop 16, padBottom 32, section gap 24 → spacing.m(16) / uacDimension24
- Actions inner gap 8, Cancel/Save row gap 16, left-group gap 4
- List item height 56 (uacListItemMinHeight), More/Less row height 44
- Button height 56 (uacButtonHeight), padX 20 (uacButtonPaddingX), padY 16

### Radii
- Sheet top radius 16 (uacPanel), Save button radius 16 (uacButtonCta),
  text/outline pills radius 100 (uacRadioPill), "common" badge radius 8

### Typography
- Row label: Inter Regular 14/20 (interBodySm) color #1d1f23
- Row value: Inter SemiBold 16/20 → closest alias `uacBodyMdSemibold` (Inter SemiBold 16/24) — line-height delta 24 vs 20, acceptable
- More/Less/Edit: Inter Medium 12/16 (uacBodyXsMedium) color #070707
- Button label: Poppins Medium 16/24 (uacBodyMdMedium / poppinsButton)
- "common" badge: Inter Regular 10/12 (interCaptionXxs) color #fcfcfd

## Token DRIFT flagged
- Figma `text/danger/base` = **#c0392b**. Current theme has `figmaRed = #CC4C3E`
  and `uacTextDangerBase = #bb251a`. Neither equals #c0392b. The "Less used"
  label + Trash icon in THIS design use #c0392b.
  → Per figma-theme-sync convention: add a new token
  `figmaItemDetailDanger = '#c0392b'` (text/danger/base) rather than reusing
  the off-by mismatched figmaRed/uacTextDangerBase. Asked CEO note below.

## Icons audit (auxi/src/assets/images/*.svg)

| Figma icon | size | Exists? | File | Action |
|---|---|---|---|---|
| back chevron | 24 | yes | icon_chevron_left.svg (Icons.ChevronLeft) | use |
| Mix/shuffle ⤬ | 24 | yes | icon_remix.svg (Icons via IconRemix?) | NOT in Icons map — add export |
| Trash 🗑 | 20 | yes | icon_trash.svg (Icons.Trash) | use |
| edit pencil ✏️ | 24 | **NO** | — | **NEW: icon_edit.svg** |
| Less used ⊖ (minus circle) | 24 | **NO** | — | **NEW: icon_minus_circle.svg** |
| Change ↻ (cycle) | 24 | **NO** | — | **NEW: icon_change.svg** |
| chevron up/down (More/Less) | 24 | partial | icon_chevron_left/right exist; up/down NO | use text caret or add |

Icons to export from Figma with currentColor + viewBox 0 0 24 24:
`icon_edit.svg`, `icon_minus_circle.svg`, `icon_change.svg`. The Mix icon
`icon_remix.svg` already exists — just add it to the `Icons` map.

## Variants / states to implement
- **Read mode** (default): Mix-with-this pill + Trash + Less used + Change.
  - Less used toggle: active state turns label/icon red (#c0392b) — current
    code already toggles `usage_frequency`.
  - Catalog (common) item: Trash hidden, demote via Less used only (AU-287
    rule, preserve).
- **Edit mode**: rows become editable (tap → picker), each editable row shows
  pencil; bottom bar = **[Cancel] [Save]**. Cancel discards drafts + exits;
  Save persists via `wardrobeService.updateWardrobeItemAttributes`.
- Pressed/disabled: TouchableOpacity activeOpacity ~0.85; Save disabled while
  `saving` (spinner acceptable).
- More/Less: expand/collapse the detail list (Fit/Color shown only when "More").

## RESOLVED — shipped in feat/au311-item-detail-edit-fidelity (AU-311 follow-up)

CEO approved a full read + edit fidelity pass. The earlier "OMIT mock fields"
default below is SUPERSEDED. What actually shipped:

### Edit mode: all 9 rows, 1:1 with Figma (frame 3508:8356)
Order + labels match the design exactly. Sample values in Figma are mock —
we render the item's REAL value (or "—" when none).

| # | Row | Source | Editable | testID |
|---|---|---|---|---|
| 1 | Name | `name` (in update contract) | YES — inline `TextInput` (new free-text path; enum Modal can't do text) | `item-detail-row-name` / input `item-detail-name-input` |
| 2 | Color | `dominant_color`/`colors`/`color_hex` | YES — color picker + dot | `item-detail-row-color` |
| 3 | Style | `formality_level` | YES — enum picker (shows real formality, not mock "Minimal, Relaxed") | `item-detail-row-style` |
| 4 | Energy | none | NO — read-only, "—" | `item-detail-row-energy` |
| 5 | **Label** | `category` | YES — category picker. Figma typo "Lable" → shipped correct **"Label"**. Replaces old "Type" row. | `item-detail-row-label` |
| 6 | Fit | `style_tags` `fit:` | YES — fit picker | `item-detail-row-fit` |
| 7 | Material | none | NO — read-only, "—" | `item-detail-row-material` |
| 8 | Occasion | `occasion: string[]` (read model only) | NO — read-only; joined array or "—" | `item-detail-row-occasion` |
| 9 | Purchase Date | `created_at` via `formatItemDate` (dd/mm/yyyy) | NO — read-only or "—" | `item-detail-row-purchase-date` |

### Read-only-pencil decision
Read-only rows (Energy, Material, Occasion, Purchase Date) **omit the edit
pencil entirely** and have **no tap target** (plain `View`, not
`TouchableOpacity`). Chosen over a greyed pencil because a missing pencil +
no press affordance reads cleaner as "not editable" and removes any
implication of tappability. They never open a picker and never fake-save
(hard project rule: no mock persistence). The Figma mock draws a pencil on
all 9 rows — that's design boilerplate, not a contract.

### Save button glyph
Save now carries the trailing send glyph: `Icons.Send` (`send_icon.svg`),
white, 18×20 (preserves the design's taller-than-wide arrow; raw viewBox
34×38). Normalised the SVG's baked `stroke="white"` → `currentColor` so the
`color` prop themes it. Cancel stays a text button. Existing
`handleSaveEdits`/`handleCancelEditing` + testIDs (`item-detail-save-btn`,
`item-detail-cancel-btn`) preserved. Name diff now also persists via
`payload.name`.

### i18n keys added (boilerplate.wardrobe.itemDetail)
`row_energy`, `row_label`, `row_material`, `row_occasion`,
`row_purchase_date`, `value_unset` ("—"), `name_edit_placeholder`.
Added to en-EN + vi-VN (both already had the block). **fr-FR.json was a
pre-existing auth-only stub with NO `wardrobe` namespace** — added a full,
consistent `wardrobe.itemDetail` block (translated) rather than an orphaned
6-key partial. Flagged for review.

### Tokens / icons
No NEW theme tokens needed — reused existing `figmaItemDetail*`,
`uacBodyMdSemibold`, `figmaItemDetailRowText`, `figmaTextMuted`,
`figmaTextDark`, `white`. No new hex/font literals (token-lint clean for the
diff). All icons already present in `Icons` map (Edit, Send, MinusCircle,
Remix) — no new icon export.

### Edit list scroll
9 rows × 56px can exceed short screens → wrapped the edit rows in a
`ScrollView` (`detailsScroll`, flexShrink) so the [Cancel][Save] bar always
stays visible.

## Open questions for CEO / tech-lead
1. **Danger red drift**: Figma `text/danger/base` = #c0392b, but app already
   ships `figmaRed #CC4C3E` (used by existing Less-used/cancel). Add a new
   #c0392b token for this screen, or keep the existing app red for
   consistency? — Defaulting to ADD `figmaItemDetailDanger #c0392b` to match
   Figma exactly (CEO is designer, fidelity wins). Confirm.
2. **Mock fields (Energy, Label, Material, Occasion, Purchase Date)** appear in
   Figma but have NO backend field. Scope: render them now (read-only "—"
   placeholder) or omit until BE supports them? — Defaulting to OMIT (keep the
   current screen's real fields: Type/Style/Color/Fit, plus add **Name** which
   IS in the contract). See "New backend fields".
3. **"Mix with this" / "Change"** buttons: backend anchor-recommendation isn't
   wired (current screen shows "Coming soon" alert for Add). Keep as
   coming-soon placeholders styled to Figma, or hide until BE ready? —
   Defaulting to KEEP the existing "Add"→coming-soon behavior but RESTYLE the
   bottom bar layout to Figma (Mix pill + Trash/Less used/Change row).

## New backend fields (vs current API client `WardrobeAttributeUpdate`)
Contract today supports: `category, name, description, colors, dominant_color,
color_hex, formality_level, style_tags`.
- **Name** — IN contract (`name`). Can wire as editable. (will add to detail rows)
- **Energy** — NOT in contract. Figma mock only. → omit (escalate if CEO wants it).
- **Lable/Label** — overlaps `category` (e.g. "T-Shirt"); ambiguous. → omit.
- **Material** — NOT in contract. → omit.
- **Occasion** — `occasion: string[]` exists on WardrobeItem read model but NOT
  in `WardrobeAttributeUpdate`. → omit edit; could show read-only later.
- **Purchase Date** — NOT in contract. → omit.

→ Net: This task ships the **bottom-bar Save/Cancel behavior + Figma-faithful
layout** for the fields the contract already supports. The extra Figma rows are
flagged as future BE work, NOT invented here (per no-invent-backend rule).
