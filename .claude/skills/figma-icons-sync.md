---
name: figma-icons-sync
description: Audit Figma vector nodes used on a screen, export missing SVG icons into auxi/src/assets/icons/, enforce naming + currentColor convention. Use when mobile-dev finds a Figma icon not yet in the asset folder, or before starting a screen that introduces new icons.
---

# Figma SVG icon pipeline

## Why this exists

Recurring qa-ui finding: back button renders literal `'<'` text glyph at
fontSize 22 instead of `IconChevronLeft.svg`. Same for selected check (`'x'`),
chevron-right, kebab menu. Reason: lazy fallback to text when icon export
not done. Pipeline removes the excuse.

## When to invoke

- Before starting a screen that has any Figma vector node
- When mobile-dev sees a Figma node that "looks like an icon"
- When qa-ui finding flags missing SVG asset

## Naming convention

```
auxi/src/assets/icons/icon_<lowercase_with_underscores>.svg
```

Examples:
- `icon_chevron_left.svg`
- `icon_heart.svg`
- `icon_heart_filled.svg`  ← variant suffix
- `icon_kebab.svg`
- `icon_close.svg`

## Procedure

### Step 1 — Enumerate Figma vectors on the screen

```
mcp__claude_ai_Figma__get_metadata (nodeId: <screen frame nodeId>)
```

Walk children, find every node with type `VECTOR`, `BOOLEAN_OPERATION`, or
`COMPONENT` whose name suggests icon (e.g., contains "icon", "ic_", "chevron",
"heart", "close", "arrow").

For each, capture:
- Figma node name → maps to filename (lowercase, underscored, prefix `icon_`)
- Rendered size (width × height in Figma)
- Fill color: variable reference (good) vs literal hex (needs flagging)

### Step 2 — Inventory existing icons

```
ls auxi/src/assets/icons/*.svg
```

For each Figma icon, check if `icon_<name>.svg` already exists.

### Step 3 — Categorise

| Figma icon | Existing? | Action |
|---|---|---|
| `icon_chevron_left` | yes | reuse — verify size matches Figma |
| `icon_heart_filled` | no | export from Figma → save → audit fill |
| `icon_close` | no | export → save → audit fill |

### Step 4 — Export missing SVGs

Get the SVG via `get_screenshot` with `format: svg`:

```
mcp__claude_ai_Figma__get_screenshot (nodeId: <vector nodeId>, format: svg)
```

Save to `auxi/src/assets/icons/icon_<name>.svg`.

### Step 5 — Audit & normalise SVG content

Open each new SVG. Verify / fix:

- [ ] Has `<svg ... viewBox="0 0 W H">` (W/H match Figma render size)
- [ ] Fills use `fill="currentColor"` — NOT literal hex
- [ ] No baked-in `width=` / `height=` on `<svg>` tag (prop-overridable from JSX)
- [ ] No `style=` attributes with hardcoded color
- [ ] Strokes use `stroke="currentColor"` (if applicable)

If the exported SVG has literal hex fills (Figma sometimes bakes them):

```bash
# Replace literal hex fill with currentColor
sed -i '' -E 's/fill="#[0-9a-fA-F]{3,8}"/fill="currentColor"/g' \
  auxi/src/assets/icons/icon_<name>.svg
```

Then visually verify the icon still looks right (the tool may have missed a
multi-color icon — those need manual review).

### Step 6 — Usage example for the handoff

Show mobile-dev the correct JSX:

```tsx
import IconChevronLeft from '../assets/icons/icon_chevron_left.svg';

// In JSX — size and color via props, not in the SVG file
<IconChevronLeft
  width={24}
  height={24}
  fill={theme.colors.figmaTextPrimary}
/>
```

Never:
```tsx
<Image source={require('../assets/icons/icon_chevron_left.svg')} />   // ✗ won't theme
<Text style={{ fontSize: 22 }}>{'<'}</Text>                            // ✗ literal glyph
```

## Output contract

End-of-turn line:
`Icons: N enumerated · M reused · K exported · L flagged for review`

## Do NOT

- Don't ship multi-color icons via simple sed-replace — they need designer
  confirmation on which fills should theme vs stay branded.
- Don't accept Figma SVG without a `viewBox` — RN will render badly without it.
- Don't `<Image>` an SVG — color won't pass through. Always use
  `react-native-svg-transformer` component import.
- Don't keep both `icon_x.svg` and `IconX.svg` — pick the snake_case version
  (`icon_x.svg`) and delete the other.
