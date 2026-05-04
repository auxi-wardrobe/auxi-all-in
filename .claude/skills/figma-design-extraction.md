---
name: figma-design-extraction
description: How to read a Figma file thoroughly and accurately via the Figma MCP — navigate the node tree, decode auto-layout, lift tokens/variables, enumerate variants, audit text and effect styles, and avoid common misreads. Use BEFORE figma-to-rn-workflow whenever the input is a Figma URL.
---

# Reading Figma Files Well

Before you can implement a Figma design faithfully, you have to read it
faithfully. Most "Figma → code" mistakes are not coding mistakes — they
are reading mistakes: missed a variant, missed a hidden layer, missed an
instance override, picked up an absolute value when the design uses a
token.

This skill is the muscle memory for extracting a design correctly. It is
strict on purpose.

## The Figma MCP toolbox

| Tool | Purpose |
|---|---|
| `mcp__claude_ai_Figma__get_metadata` | Whole-file or selection node tree (IDs, names, types, sizes, parent/child) |
| `mcp__claude_ai_Figma__get_design_context` | Component/instance specs: layout, properties, variant args, applied styles |
| `mcp__claude_ai_Figma__get_variable_defs` | Defined design variables — colors, numbers, strings, booleans — by collection |
| `mcp__claude_ai_Figma__get_screenshot` | Rendered PNG of a node — your visual reference |
| `mcp__claude_ai_Figma__search_design_system` | Locate library components by name or category |

Order of operations on a fresh URL:

```
1. get_metadata  → understand the structure
2. get_screenshot → understand the look
3. get_variable_defs → understand the system
4. get_design_context (per node) → understand the contract
5. search_design_system (per unfamiliar component) → understand reuse
```

Do not skip 1–3. Skipping 3 is how you end up hardcoding values that the
file has tokens for.

## Reading the node tree

Every Figma frame is a tree. Common node types:

| Type | Translates to |
|---|---|
| `FRAME` (auto-layout) | Flex container (`View` with flexbox props) |
| `FRAME` (no auto-layout) | Absolute-positioned container — usually a smell, ask before mirroring 1:1 |
| `GROUP` | Logical grouping — usually unwrap in code |
| `INSTANCE` | A library component used here — find the library, find its RN equivalent |
| `COMPONENT` / `COMPONENT_SET` | Source-of-truth for a reusable thing |
| `TEXT` | `<Text>`, with the style copied from the text style applied |
| `VECTOR` / `BOOLEAN_OPERATION` | Usually export as SVG icon |
| `RECTANGLE`, `ELLIPSE` | Backgrounds, dividers, dots — replicate with style |

Key fields you must capture per node:
- `id`, `name`, `type`
- `absoluteBoundingBox` (size + position)
- `layoutMode` (`HORIZONTAL` / `VERTICAL` / `NONE`)
- `primaryAxisAlignItems`, `counterAxisAlignItems`
- `itemSpacing`, padding (4 sides)
- `cornerRadius` (uniform or per-corner)
- `effects` (drop shadow, inner shadow, blur)
- `fills`, `strokes` (each may reference a variable)
- `characters` (for `TEXT`)
- `style` reference (`textStyleId`, `fillStyleId`, `effectStyleId`)
- `componentId` / `mainComponent` (for instances)

If `get_metadata` returns very dense JSON, summarize before coding:

```
Frame "HomeScreen" 390×844
└── Frame "Header" auto-V, padX 16, padY 12, gap 8
    ├── Text "Greeting" textStyle/heading-lg, fill color/text/primary
    └── Instance "Avatar" → component "Avatar/40"
└── Frame "Content" auto-V, padX 16, gap 24
    ├── Instance "Card/Recommendation" → component "Card/Recommendation"
    └── ...
```

That outline is what you implement against — not the screenshot alone.

## Auto-layout decoding (this is where most errors happen)

| Figma field | Value | RN equivalent |
|---|---|---|
| `layoutMode` | `HORIZONTAL` | `flexDirection: 'row'` |
| `layoutMode` | `VERTICAL` | `flexDirection: 'column'` (default) |
| `primaryAxisAlignItems` | `MIN` | `justifyContent: 'flex-start'` |
| `primaryAxisAlignItems` | `CENTER` | `justifyContent: 'center'` |
| `primaryAxisAlignItems` | `MAX` | `justifyContent: 'flex-end'` |
| `primaryAxisAlignItems` | `SPACE_BETWEEN` | `justifyContent: 'space-between'` |
| `counterAxisAlignItems` | `MIN`/`CENTER`/`MAX` | `alignItems: 'flex-start'`/`'center'`/`'flex-end'` |
| `itemSpacing` | number | `gap: <n>` (RN 0.71+) or margins |
| `paddingTop/Right/Bottom/Left` | numbers | `paddingTop`, `paddingRight`, etc. |
| `layoutSizingHorizontal` | `FIXED` | explicit `width` |
| `layoutSizingHorizontal` | `HUG` | width: undefined (content-driven) |
| `layoutSizingHorizontal` | `FILL` | `flex: 1` (within a row) or `alignSelf: 'stretch'` |
| `layoutSizingVertical` | similar | similar |

**Watch out**: a `FRAME` with `layoutMode: NONE` uses absolute positioning
in Figma. Mirroring that with `position: 'absolute'` in RN usually breaks
on different screen sizes. Look for the parent's intended layout instead.

## Variables / tokens — lift them, don't replicate values

`get_variable_defs` returns collections like:

```
color/
  primary           = #1A73E8
  text/primary      = #1F1F1F
  text/secondary    = #5F6368
  surface/raised    = #FAFAFA
spacing/
  4, 8, 12, 16, 24, 32
radius/
  sm = 6, md = 12, lg = 20
font/
  heading-lg = { family, weight, size 24, lineHeight 32 }
  body       = { family, weight, size 14, lineHeight 20 }
```

Every fill, stroke, padding, and font in a node either:
- **Resolves to a variable** — log it as `color/text/primary`, etc.
- **Is a one-off literal** — flag it. One-off literals are usually
  a designer's WIP or an oversight. Ask before encoding them.

When you implement, you map:
- `color/primary` → `theme.colors.primary` (add to `auxi/src/theme/theme.ts`
  if missing).
- `spacing/16` → `theme.spacing[16]` (or whatever the RN scale is).
- `font/heading-lg` → a `Text` style preset (`theme.text.headingLg` or
  similar).

If the Figma file uses Variables 2.0 (modes — light/dark, mobile/desktop),
record the mode. If only one mode is provided, ask which one is
authoritative before implementing.

## Text styles

For each `TEXT` node, capture:
- `characters` (the actual string — but UI strings should go through
  i18n in `src/translations/`, not hardcoded)
- `fontFamily`, `fontWeight`, `fontSize`, `lineHeightPx`,
  `letterSpacing`, `textCase`, `textDecoration`
- `fills` (color)
- `textAutoResize` (`NONE` / `HEIGHT` / `WIDTH_AND_HEIGHT`) — affects
  whether you need fixed height or content-driven

If the design uses a custom font, check it's bundled in the app
(`auxi/ios/...` and `auxi/android/...` font configs). If not, escalate —
this is not a code-only task.

## Effects (shadows / blur)

| Figma effect | RN |
|---|---|
| `DROP_SHADOW` | `shadowColor`, `shadowOffset`, `shadowOpacity`, `shadowRadius` (iOS) + `elevation` (Android) |
| `INNER_SHADOW` | Not supported natively — usually approximate with a layered View, ask first |
| `LAYER_BLUR` | `BlurView` from `@react-native-community/blur` (if installed) — check first |
| `BACKGROUND_BLUR` | `BlurView` over the layer — check first |

Don't pretend inner shadows or blur are free. They aren't.

## Variants and component sets

A component set (e.g., `Button`) often has variants like:

```
Button
├── size = sm | md | lg
├── kind = primary | secondary | ghost
└── state = default | pressed | disabled | loading
```

For each variant the design uses, you must implement the variant. For
each variant the design DEFINES but doesn't use on this screen, decide
with the user whether to implement preemptively (probably yes, since
the component will reappear).

Use `mcp__claude_ai_Figma__search_design_system` to find:
- Whether the project already has a shared `Button` component in
  `auxi/src/components/`. If yes, reuse and add the missing variant. If
  no, build it generically — don't bake "this screen's button" into the
  screen file.

## Instance overrides — the silent killer

A Figma `INSTANCE` can override its main component's properties locally
(text, color, visibility, layer overrides). When you read an instance:

1. Check `componentProperties` for the variant args used here.
2. Check `overrides` for ad-hoc property changes (icon swap, color tweak).
3. Check whether any child layer is **hidden** in this instance — Figma
   shows hidden layers in the metadata but greyed in the canvas. Hidden
   layers should NOT be rendered.

If you ignore overrides, your code looks like the main component's
default state, not the instance the designer placed on this screen.

## Hidden layers, locked layers, and developer ignore

Things to filter out:
- `visible: false` — don't render.
- Layers named with `[dev: ignore]` or similar conventions — check the
  project's convention with the designer before assuming.
- Comment / annotation layers (often `TEXT` nodes outside the main frame).

## Responsive notes

Auxi is iOS-first but ships Android too. If Figma shows only a single
390-wide frame:
- Confirm with the designer how the layout breathes at smaller (e.g.,
  iPhone SE 375) and larger (Plus / Max 428–430) widths.
- Default to flex-based layouts that absorb width changes — avoid fixed
  widths unless the spec demands them.

## Sanity checks before you call extraction "done"

- [ ] You read every immediate child of the target frame.
- [ ] You enumerated every variant of every component used.
- [ ] You logged every variable referenced.
- [ ] You exported every icon that's not already in
      `auxi/src/assets/icons/`.
- [ ] You know the text styles applied (fontFamily/Weight/Size/LineHeight).
- [ ] You know the effects (shadows, blurs) applied.
- [ ] You know the responsive intent (or asked).
- [ ] You called out one-off literal values that don't resolve to a
      variable.

If any of those are unclear, ASK before coding. Faster to ask the CEO
once than to ship the wrong thing.

## Output of this skill (what you produce)

A short markdown summary in the conversation that reads like a spec, not
a paraphrase. Example:

```markdown
## Extracted: HomeScreen / Recommendation card

### Frame
- Size: 358 × 220, cornerRadius 16
- Padding: 16 / 16 / 16 / 16
- Effect: DROP_SHADOW { x:0 y:2 blur:8 color: rgba(0,0,0,0.08) }

### Layout
- VERTICAL auto-layout, gap 12
- Children:
  1. Image 326×120, cornerRadius 12 (instance of "Card/Image")
  2. Text "Sunny day fit" — textStyle/heading-md, color/text/primary
  3. Frame "Tags" HORIZONTAL gap 8 (HUG)
     - Instance "Tag/Default" × 3 with override text

### Tokens used
- color/surface/raised, color/text/primary, color/text/secondary
- spacing/8, spacing/12, spacing/16
- radius/md (12), radius/lg (16)
- font/heading-md, font/body
- effect/shadow-card

### Icons needed
- icon_heart (24×24) — already exists
- icon_more (20×20) — NEW, export from Figma

### Variants to implement
- Card states: default, pressed (95% opacity ripple)
- Tag variants: default, selected
```

That note becomes the input to `figma-to-rn-workflow`.
