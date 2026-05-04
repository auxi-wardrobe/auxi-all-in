---
name: figma-to-rn-workflow
description: Strict workflow for translating a Figma design into Auxi RN code. Use whenever the user provides a Figma URL or asks to implement a screen/component from design. Designer is the CEO — alignment, theme adherence, icon fidelity, and on-simulator verification are non-negotiable.
---

# Figma → React Native (Auxi) Workflow

The designer is the CEO. Your output gets reviewed against the Figma file
pixel-for-pixel. Treat every Figma URL as a contract: every spec in the
file should appear in the implementation, and every value should map to
either a theme token or a deliberate, justified addition.

## Phase 1 — Extract before you write any code

Use the Figma MCP tools systematically. Do NOT skip this and start typing
JSX from a screenshot.

```
mcp__claude_ai_Figma__get_metadata          # node tree, sizes, structure
mcp__claude_ai_Figma__get_design_context    # component specs, layout, variants
mcp__claude_ai_Figma__get_variable_defs     # design tokens (colors, spacing, type)
mcp__claude_ai_Figma__get_screenshot        # reference image for side-by-side
mcp__claude_ai_Figma__search_design_system  # locate reusable components
```

Produce a short extraction note in the conversation:

```
Frame: <frame name>
Size: 390 × 844 (iPhone 15)
Layers / nodes: <count>
Tokens used:
  - color/primary, color/text/primary, color/surface/raised
  - spacing/8, spacing/16, spacing/24
  - font/heading-lg, font/body
Icons:
  - icon_heart (24×24), icon_settings (20×20), icon_close (16×16)
States/variants:
  - default, pressed, disabled
```

If any value in Figma doesn't have a clear token (one-off color, weird
spacing like 13px), flag it now — don't silently invent one.

## Phase 2 — Map tokens to `theme.ts`

Open `auxi/src/theme/theme.ts`. For every token in the extraction note:

| Figma token | Theme path | Action |
|---|---|---|
| Already exists | use existing | nothing to do |
| Equivalent name, different value | check with the user | DON'T silently change |
| New token | add to `theme.ts` with the same semantic name | add first, use second |
| Off-token literal (e.g., #2A2D31 used once) | ask first | most likely the design system has it |

Example add:

```ts
// auxi/src/theme/theme.ts
export const theme = {
  colors: {
    // ...existing
    surface: {
      raised: '#FAFAFA',     // ← matches Figma var color/surface/raised
    },
  },
  spacing: { 4: 4, 8: 8, 12: 12, 16: 16, 24: 24, 32: 32 },
};
```

**Hard rule**: no literal hex values in screen/component files. If a value
isn't a theme token, it goes through `theme.ts` first.

## Phase 3 — Per-icon audit

For each icon used in the design:

1. Check if it exists: `auxi/src/assets/icons/icon_<name>.svg`.
   - Use Glob: `auxi/src/assets/icons/*.svg`.
2. If missing: export from Figma (SVG) and add the file. Naming:
   `icon_<lowercase_with_underscores>.svg`.
3. Open the SVG and verify:
   - `viewBox` is set (e.g., `0 0 24 24`).
   - `fill="currentColor"` on shapes that should theme — NOT a literal
     hex. (`react-native-svg` will let you pass `fill` prop in JSX.)
   - No baked-in `width`/`height` that would prevent prop overrides.
4. Use it via the SVG component import:

```tsx
import IconHeart from '../assets/icons/icon_heart.svg';

<IconHeart width={24} height={24} fill={theme.colors.accent} />
```

Never `<Image source={require('...svg')} />` — colors won't theme.

If Figma shows a 20×20 icon but the SVG file's viewBox is 24×24, the icon
will look "lighter" on screen — match the rendered size to Figma exactly.

## Phase 4 — Layout & alignment

Translate Figma's auto-layout / absolute positions into RN flexbox:

| Figma | RN |
|---|---|
| Auto-layout horizontal | `flexDirection: 'row'` |
| Auto-layout vertical | `flexDirection: 'column'` (default) |
| Spacing between items | `gap` (RN 0.71+) or explicit margin on children |
| Padding on container | `padding`, `paddingHorizontal`, `paddingVertical` |
| Align items center | `alignItems: 'center'` |
| Distribute space-between | `justifyContent: 'space-between'` |
| Hug contents | `alignSelf: 'flex-start'` or default |
| Fill container | `flex: 1` |

All numeric spacing values come from `theme.spacing.*`. If Figma has a
13px gap and your scale is 4/8/12/16, ask the designer (CEO) — don't
silently round to 12.

## Phase 5 — States & variants

Buttons, inputs, cards usually have multiple states in Figma:

- Default
- Pressed (`Pressable` `style={({ pressed }) => …}`)
- Disabled (`disabled` prop + visual)
- Loading (if applicable)

Implement every state present in the Figma variant set. Missing the
pressed state is the #1 review nit you'll get.

For text inputs, also: focused, error, with-helper-text.

## Phase 6 — Verify on simulator

This is non-negotiable for Figma tasks. Code-only verification is not
sufficient when the CEO is the reviewer.

```bash
cd auxi
yarn ios:sim
```

Then:

1. Navigate to the screen you implemented.
2. Take a simulator screenshot (`Cmd+S` in Simulator, or
   `xcrun simctl io booted screenshot ./screenshot.png`).
3. Open Figma (or the `get_screenshot` MCP output) side-by-side.
4. Walk a checklist:
   - [ ] Same colors? (especially text, surface, accent)
   - [ ] Same icon sizes?
   - [ ] Same spacing between elements?
   - [ ] Same font weight + size?
   - [ ] Same corner radii?
   - [ ] Same shadows / elevation?
   - [ ] Pressed state matches?
   - [ ] Disabled state matches?
   - [ ] Renders correctly in light AND dark mode (if the design covers both)?
5. Note any visible deltas in your hand-off, even minor ones. Don't hide
   discrepancies — the CEO will spot them.

If the simulator can't run in your current session, mark the task as
"code complete · visual verification pending" and explicitly hand it to
qa-mobile (or back to the user) for the visual pass. Do not claim
"matches Figma" without the side-by-side.

## Phase 7 — Hand-off

When done, your message includes:

```
Implemented: <screen/component name>
Files touched:
  - auxi/src/screens/MyScreen.tsx (new)
  - auxi/src/components/MyChip.tsx (new)
  - auxi/src/theme/theme.ts (+1 token: color/surface/raised)
  - auxi/src/assets/icons/icon_close.svg (new)
  - auxi/src/types/navigation.ts (registered MyScreen)
  - auxi/src/navigation/AppNavigator.tsx (registered MyScreen)

Theme deltas:
  - Added color/surface/raised = #FAFAFA (matches Figma var)

Icons added: icon_close (16×16, currentColor)

Verification:
  - tsc clean
  - lint baseline preserved
  - Simulator side-by-side: matches Figma except [list any deltas]

Open questions for CEO/designer:
  - Disabled state for primary CTA wasn't shown — assumed 40% opacity. Confirm?
```

That format makes review fast and avoids the "but I asked for X" loop.

## Anti-patterns

- Hex values lifted from Figma into JSX (`backgroundColor: '#FAFAFA'`).
- Using `<Image>` for SVG icons.
- Ignoring pressed/disabled states because they "weren't requested".
- Approximating spacing ("13px ≈ 12px, close enough").
- Saying "looks good" without a simulator screenshot.
- Adding new theme tokens without the same semantic name as the Figma var.
- Skipping the metadata pull and coding from a screenshot.
