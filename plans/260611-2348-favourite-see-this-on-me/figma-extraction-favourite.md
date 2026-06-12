# Figma extraction — Favourite (Love Collection) screen

- **Figma file**: `0nXXMAR4Arf1ZfjtQvtBh0`
- **Board (See this on me / Favourite)**: section `2852:22266`
- **Primary frame**: `Favourite collection` `3230:35028` (414 × 1612, two stacked date groups)
- **Empty state** + **Remove dialog**: `Remove` frame `3539:23335` (414 × 896) — its dimmed canvas shows the empty state; its `noti` shows the confirm dialog
- Screenshots pulled: `3230:35028` (collection), `3539:23335` (empty + remove dialog)

Ticket: AU-226 Workstream 4. Service-contract fixes (Workstream 2) + i18n/tokens
(Workstream 6) covered in the same pass. "See this on me" try-on flow (Workstream 5)
is OUT OF SCOPE — the "Self visualization" link is a no-op stub here.

---

## Frame tree (Favourite collection `3230:35028`)

```
Favourite collection 414×1612
├── Frame 2130 (scroll content, 414×1610) auto-V
│   ├── Frame 2034 (date group #1, 414×805)
│   │   ├── Frame 2030 (date group body) auto-V gap 12 padX 16, items center
│   │   │   ├── Text "6 May"           Inter Regular 12/16, #1d1f23, center, w-full   [3230:35032]
│   │   │   ├── Frame 2104 (caption row) auto-H gap 4 items center                    [3230:35033]
│   │   │   │   ├── Frame 2036 caption pill  bg color/primary/100 #eee6df, padX12 padY8, radius 4
│   │   │   │   │   └── Text "Clean. Ready for today" Poppins Regular 16/24 #1d1f23
│   │   │   │   └── Frame 2037 idea pill     bg color/primary/200 #e0d2c4, 40h, padX12 padY8, radius 4
│   │   │   │       └── carbon:idea 16×16 (icon_idea.svg)
│   │   │   └── Frame 2009 (grid) auto-V gap 4
│   │   │       ├── Frame 2007 row1 auto-H gap 4 → Image3:4 ×2 (189×252 each)
│   │   │       └── Frame 2008 row2 auto-H gap 4 → Image3:4 ×2
│   │   └── Frame 2031 (action row) auto-H gap 24 items center                        [3230:35046]
│   │       ├── Button (icon) ⊖ remove   icon/danger/base #c0392b, 24×24 in 56×56     [3230:35048]
│   │       └── Button (text) "Self visualization" Poppins Medium 16/24 #1d1f23,
│   │             56h, rounded 100 + sparkle 24×24 (icon_remix.svg)                   [3230:35049]
│   └── Frame 2035 (date group #2, 414×805) — identical structure, "3 May"
├── header (instance) 414×107 — back chevron + centered "Favourite"                  [3230:35070]
└── footer (instance) 414×84 — grid/collage toggle                                   [3230:35071]
```

### Per-tile (`Image 3:4`, e.g. `3230:35041`)
- aspect 3/4, flex 1 (fills row), bg `background/primary/subtle_50` #f2efec, radius `border-radius/xs` = 4
- Media `<img>` cover, same radius
- Rarity tag overlay: absolute, centered horizontally, bottom 7px, bg `color/neutral/black/Alpha300`
  rgba(18,18,18,0.75), radius 8, h 15, w 59, padX 12; label Inter Regular **8px** /12, #fcfcfd,
  text **"common"** (Figma hardcodes "common" on every tile — FIX: render conditionally from
  `is_common_item`; screenshot also shows "uncommon" on some tiles).

### Header (`3230:35070`)
- 107h, white@90% bar (Figma backdrop-blur 7.5 → near-opaque token, no blur dep), pad 12
- Row space-between: back 44×44 tap target w/ chevron-left 24×24 · centered title "Favourite"
  Inter Medium 14/20 #1d1f23 · invisible 44×44 spacer (opacity 0) right to keep title centered

### Action row (`3230:35046`)
- auto-H, gap 24, items center
- ⊖ remove icon button: icons 24×24 inside 56×56 state-layer, stroke `icon/danger/base` #c0392b
- "Self visualization" text button: Content 56h, px 20, rounded 100, gap 8; label Poppins Medium
  16/24 #1d1f23 + sparkle 24×24. NOTE: Figma label literally reads `Self visualization"` (stray
  curly quote) — clean copy used in i18n. STUB ONLY (Workstream 5).

### Remove dialog (`3539:23380`, bottom-sheet)
- Basic Dialog: bg white, padX 16 padY 24, gap 16, rounded-top 16
  - Headline "Remove from your favourite" Inter SemiBold 14/20 #1d1f23
  - Body "Are you sure to remove this outfit from your favourite list" Inter Regular 14/20 #1d1f23
- Button group: row gap 12
  - "Yes 🗑" text button — Poppins Medium 16/24, `color/danger/400` #c0392b + trash 24×24
  - "Cancel" secondary — 1.5px border `border/neutral/base` #1d1f23, 56h, rounded 16,
    Poppins Medium 16/24 #1d1f23
- IMPL NOTE: per task we REUSE `components/settings/SettingsDialog.tsx` (danger variant). That is a
  CENTERED modal card, not a bottom-sheet — functional match, copy/danger preserved, structural
  delta (centered vs bottom-sheet) documented for qa-ui. Cancel→primaryVariant=danger ("Yes").

### Empty state (dimmed bg of `3539:23335`)
- Centered green heart glyph + caption "Tap 'Wear this' button to add an outfit"
- Footer grid/collage toggle still shown.
- Green heart hue not exposed as a variable in the favourite frame's `get_variable_defs`; the home
  heart icon (`icon_home_heart_filled.svg`) is the closest existing asset. OPEN Q below.

---

## Tokens used (Figma var → theme.ts)

| Figma variable | Value | theme.ts mapping | Status |
|---|---|---|---|
| background/primary/subtle_50 | #f2efec | `figmaBackground` / `figmaCardSurface` | exists |
| color/primary/100 (#EFE9E3) | #eee6df | `figmaCaptionPillBg` | exists |
| color/primary/200 (#DED5CC) | #e0d2c4 | `figmaInsightPillBg` | exists |
| color/neutral/black/Alpha300 | rgba(18,18,18,0.75) | `figmaCardTag` | exists |
| color/neutral/50 (#FCFCFD) | #fcfcfd | `white` (tag text — close enough; #fcfcfd≈white) | exists* |
| text/neutral/base | #1d1f23 | `uacTextBase` / `figmaItemDetailRowText` | exists |
| icon/danger/base / color/danger/400 | #c0392b | `figmaItemDetailDanger` (#c0392b) | exists |
| border/neutral/base | #1d1f23 | `uacBorderBase` | exists |
| border-radius/xs | 4 | `borderRadius.s` (4) | exists |
| border-radius/2xl | 16 | `borderRadius.l` (16) | exists |
| body/xs Inter Reg 12/16 | — | `typography.aliases.uacBodyXsRegular` | exists |
| body/md Poppins Reg 16/24 | — | `typography.aliases.poppinsBody` | exists |
| body/md Poppins Med 16/24 | — | `typography.aliases.poppinsButton` (Poppins-Medium 16/24) | exists |
| body/sm Inter Reg 14/20 | — | `typography.aliases.interBodySm` | exists |
| body/sm Inter SemiBold 14/20 | — | `typography.aliases.interSemiboldSm` (16/20) | NEAR — see note |
| header title Inter Medium 14/20 | — | `typography.aliases.interMediumSm` (14/20) | exists |
| rarity tag Inter Reg 8px/12 | — | NO 8px alias; HomeScreen uses literal 10px Inter | NEW token? |

Notes:
- `*` #fcfcfd vs #ffffff is a sub-perceptual delta; reuse `white`. No new token needed.
- `interSemiboldSm` is Inter-SemiBold **16**/20; the dialog headline is **14**/20. Since the dialog is
  reused `SettingsDialog` (its own `interSemiboldSm` title style), we accept the existing component's
  title styling rather than fork it. Documented delta.
- Rarity tag is 8px Inter. HomeScreen's `cardTagText` uses literal `'Inter-Regular'` 10px (a legacy
  inline pattern, not a theme alias). For the NEW favourite tile I reuse `interCaptionXxs`
  (Inter-Regular 10/12) — matches HomeScreen's rendered tag, NOT Figma's 8px. 8px is below the app's
  smallest type token and HomeScreen already ships 10px for the identical tag. Chose consistency with
  the live Home tile over a one-off 8px token. Documented for qa-ui / CEO.

**No new theme tokens required.** Every color/spacing/radius/type resolves to an existing alias.

---

## Icons (all already present under `src/assets/images/`, exported via `assets/icons/index.ts`)

| Figma node | Asset | Size on screen | Fill |
|---|---|---|---|
| carbon:idea (caption) | `icon_idea.svg` (currentColor, viewBox 0 0 16 16) | 24×24 (matches OutfitCardCaption) | `uacTextBase` |
| ⊖ remove | `icon_minus_circle.svg` (currentColor, 0 0 24 24) | 24×24 | `figmaItemDetailDanger` #c0392b |
| sparkle (Self visualization) | `icon_remix.svg` (currentColor, 0 0 12 12) | 24×24 | `uacTextBase` |
| back chevron | `icon_chevron_left.svg` (legacy baked #272A32 stroke) | 24×24 | n/a |
| green heart (empty) | `icon_home_heart_filled.svg` (existing) | ~24–28 | green (success) — OPEN Q |
| grid / collage toggle | reused via `HomeViewToggleFooter` (icon_grid / icon_grid_alt) | 24×24 | — |
| trash (dialog "Yes") | reused via `SettingsDialog` danger variant — no per-icon needed | — | — |

**No new SVGs to export.** All vectors map to existing assets.

---

## Variants / states
- Tile rarity tag: `is_common_item === true` → "common"; otherwise hidden (Figma shows "uncommon"
  on non-common tiles in the screenshot, but backend `WardrobeItem.to_dict` only exposes
  `is_common_item` boolean — render the badge ONLY for common items, matching HomeScreen behaviour
  which already only knows common/non-common). See OPEN Q.
- Grid ↔ collage toggle: reuse `HomeViewToggleFooter` (`grid` | `collage`). Collage layout for
  favourites is not separately specced — toggle switches the per-outfit tile arrangement; default
  `grid`. Faithful-but-minimal (mirrors the Home footer's documented "alt view" caveat).
- Remove confirm: default + busy (in-flight delete) states via `SettingsDialog` `isBusy`.
- Empty vs loaded vs loading: `useQuery` states → spinner / empty / list.
- Action row buttons: pressed handled by `TouchableOpacity` activeOpacity (reused primitives).

---

## Component reuse plan (primitives-first)
- Header: `TopIconButton` (back) + local title Text (matches ItemDetail header pattern).
- Caption + idea pill: **reuse `OutfitCardCaption`** (exact Frame 2104 match).
- Tile grid: extract Home grid tile look into a small `favourite/FavouriteOutfitCard.tsx`
  (mirrors HomeScreen `card`/`cardImage`/`cardTag` styles + `resolveItemImage`), FIXING the rarity
  tag to be conditional on `is_common_item`/`isSystem`.
- Date grouping: `favourite/group-by-date.ts` pure helper.
- Empty state: `favourite/EmptyState.tsx`.
- Grid/collage footer: **reuse `HomeViewToggleFooter`**.
- Remove confirm: **reuse `SettingsDialog`** (danger variant).
- Self-visualization link: `PillButton`/`TopIconButton`-style text row, no-op stub.

---

## Open questions for CEO / tech-lead
- **Rarity badge for non-common items**: Figma renders a per-tile badge that reads "common" on every
  tile (and "uncommon" in the rendered screenshot). Backend only gives `is_common_item: bool`. Plan:
  show the badge "common" ONLY when `is_common_item` is true; hide it for user items (matches Home).
  Confirm we should NOT invent an "uncommon" label for user items.
- **Empty-state heart color**: the green heart hue is not a published variable on this frame. Using
  the existing `icon_home_heart_filled.svg` tinted with `theme.colors.success` (#388E3C). Confirm
  the green tone, or provide the exact token.
- **Collage view for favourites**: footer toggles grid↔collage but only the grid arrangement is
  specced for the favourite card. Collage currently re-flows the same tiles; confirm intended
  collage layout (or treat as the Home footer's documented pending-alt-view).
- **Remove dialog shape**: task mandates reusing `SettingsDialog` (centered card). Figma draws a
  bottom-sheet. Shipping the centered reuse per instruction; flag if CEO wants the bottom-sheet.

## New backend fields (vs current API client)
None — `GET /api/favorites` (`{count,total,favorites:[{id,outfit_items,outfit_context,
outfit_thumbnail_url,created_at,updated_at}]}`) and `DELETE /api/favorites/{id}` (`{message}`) are
both live and fully cover the screen. `outfit_items[]` reuses the existing `Item` shape
(`image_url`, `image_png`, `category`, `is_common_item`). No field requires a backend change.
