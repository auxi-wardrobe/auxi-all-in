# Screen: Language Settings

**Node**: `2849:10108`
**Dimensions**: 414×896
**Purpose**: Allow user to pick app language (English / Tiếng Việt) via a radio-button list.
**Maps to AC scenario**: AU-242 — language switching is a prerequisite for first-run onboarding/UAC; user must be able to select language before/during sign-up so all subsequent UAC copy renders in the chosen language.

## Layout
- Container: column auto-layout, `padding: 112px 24px 12px 24px`, gap = 0 (`--line-heigh/none`), centered items, anchored to bottom, full screen 414×896, `borderRadius: 16px`.
- Inner list: column auto-layout, `width: 360px`, gap = 0 (isolation/z-stacked), `justify-center` + `items-center`.
- Body wrapper: column, `gap: 16px`, `paddingY: 12px`, full width of inner list, `z-index: 1`.
- Background: `--background/neutral/subtlest` (`#FFFFFF`).
- Status bar / Safe area: header zone reserves top `112px` (status bar + top bar combined region).

## Header / Top bar
- Top bar absolute, `height: 107px`, full width `414px`, top = 0.
- Inner row: `width: 370px`, centered horizontally, top = 45px, `justify-between`, `items-center`.
- Leading: **Back** icon button — `45×45` (asset `imgBack`). Action: `pop()` to previous screen (Settings root or wherever entered from).
- Trailing: **feedback** slot — `47×47` empty placeholder (no visible icon in this state).
- Title: "Language" — centered, `top: 68.5px`, `left: 206px` (translate -50%, -50%), `Inter Semi Bold 600 / 16px / lineHeight 24px`, color `--text/neutral/base` (`#1D1F23`), whitespace nowrap.

## Body sections (top-to-bottom)

### 1. List item — English (selected)
- Component: `List item 2` (M3 List baseline, density 0) with radio trailing.
- Frame: `height: 56px (min-h 56px)`, full width 360px, row state-layer with `gap: 16px`, `paddingY: 8px`, `items-center`.
- **Leading element**: `Icons` component `name="flag.eng"` `size="L"` — rendered at `24×20.903px` (flag aspect cropped from 32×28 base).
- **Content**: text "English" — `Poppins Regular 400 / 16px / lineHeight 24px`, color `--text/neutral/base` (`#1D1F23`), single line.
- **Trailing element**: `Radio buttons` component, `selected = true`, `state = "Enabled"`, container `48×48` (visual icon 24×24, state-layer padding 8px, container rounded-100px). Inner icon = filled radio.
- **Divider** below row: `Horizontal/Middle-inset` divider, full width, 1px (M3 outline-variant).
- Action: tap row → set app language to `en`, persist, re-render UAC stack with English copy. Radio toggles to filled state. Already-selected: no-op (idempotent).

### 2. List item — Tiếng Việt (unselected)
- Component: `List item 2` identical structure to English row.
- **Leading element**: `Icons` `name="flag-vn"` `size="L"` — `24×20.903px`.
- **Content**: text "Tiếng Việt" — `Noto Sans Regular 400 / 16px / lineHeight 24px` (font swapped to Noto Sans for diacritics support; fontVariationSettings `'CTGR' 0, 'wdth' 100`).
- **Trailing element**: `Radio buttons`, `selected = false`, `state = "Enabled"`. Container `48×48`, inner icon = unfilled radio outline (`imgIcon`).
- **Divider** below row: same `Horizontal/Middle-inset`.
- Action: tap row → set app language to `vi`, persist (e.g. `AsyncStorage` / i18n provider), re-render UAC stack with Vietnamese copy. Radio swaps to filled; previous selection swaps to unfilled.

## Interactive elements
- **Back button** (top-left): state default, action = `navigation.goBack()`. No disabled state shown.
- **English row**: state = selected. Action = re-select (no-op) on tap. Radio reflects current locale.
- **Tiếng Việt row**: state = unselected. Action = select → switch locale.
- **feedback** trailing slot in top bar: empty / no action in this variant.
- Only one row can be selected at a time (radio group semantics — single-select).

## Text content (verbatim)
- **Title (top bar)**: `Language`
- **Row 1**: `English`
- **Row 2**: `Tiếng Việt`
- No supporting/helper/error text on this screen.

## Design tokens referenced
- Color
  - `--background/neutral/subtlest` → `#FFFFFF`
  - `--text/neutral/base` → `#1D1F23`
  - `M3/sys/light/on-surface-variant` → `#49454F` (referenced via M3 list/divider source)
- Typography
  - `Text-md (l-24)/Semibold` — Inter Semi Bold 600, 16px / 24px (top bar title)
  - `Text-md (l-24)/Regular` — Poppins Regular 400, 16px / 24px (English row)
  - `Text-md (l-24)/Regular` — Noto Sans Regular 400, 16px / 24px (Vietnamese row, swapped family for diacritics)
- Spacing
  - `--body` = `24px` (horizontal padding)
  - List item gap = `16px`, list item paddingY = `8px`, body paddingY = `12px`
  - List item min-height = `56px` (M3 standard list item)
- Radii
  - Screen card: `18px`
  - Inner panel: `16px`
  - Radio container: `100px` (pill / circle)
- Components (Figma → M3 lineage)
  - `Radio buttons` (node `329:1207`) — M3 Radio Button
  - `Horizontal/Middle-inset` (node `483:1550`) — M3 Divider middle-inset

## Notes / gotchas
- **M3 list pattern**: this is a textbook M3 `List item` (density 0, baseline) with leading icon (flag), content text, trailing control (radio). Use Material 3 list semantics in RN — render via custom `<ListItem>` with `flexDirection: row`, fixed 56px minHeight, 16px gap.
- **Font family swap per locale**: English uses Poppins; Tiếng Việt uses Noto Sans. This is a deliberate designer decision for Vietnamese diacritic legibility — preserve when implementing, do not force one family across both. If the global app font already supports Vietnamese cleanly, escalate to Viet before unifying.
- **Radio state-layer is 48×48 but visual icon is 24×24**: tap target is the full 48×48 (M3 accessibility minimum 48dp). Implement with `hitSlop` or a `Pressable` wrapper of that size, not just the icon.
- **Divider is rendered below each list item, including the last one** — confirms full-bleed divider pattern (not a between-items separator). Acceptable; M3 middle-inset uses outline-variant ~12% opacity grey.
- **Persistence**: language choice must survive app restart. Use the existing i18n persistence layer in `auxi/` (likely `AsyncStorage` + `i18next`), not local screen state.
- **Top bar title alignment**: title is absolutely centered (`left: 206px` = ~50% of 414px width, with translate). Back button is `45×45` left-aligned with horizontal offset baked into the outer row (`left: ~22px` after centering 370px-wide row). Use the project's existing header component if it already mirrors this layout.
- **Designer is Viet (CEO)** — any deviation from this list pattern (e.g. switching to a segmented control or modal) must be cleared with him first.
