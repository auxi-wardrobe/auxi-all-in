# Extracted: Outfit Canvas / Remix editor (AU-285)

- Figma fileKey: `0nXXMAR4Arf1ZfjtQvtBh0`
- Section "Cavas" node `2852-16581`; frame **"remix"** node `2852-16582` (414 × 896)
- Target RN file: `auxi/src/screens/OutfitCanvasScreen.tsx`
- Scope: **VISUAL FIDELITY ONLY** — drag/PanResponder/undo/redo/layer logic is approved, not touched.

---

## Frame tree (remix `2852:16582`, 414×896)

```
remix 414×896
├── header 2852:16583  (414×107)
│   └── Frame 2001 2852:16584 (x22 y45, 370×45)   ← top-bar row
│       ├── Top bar 2852:16585 (45×45)            ← back chevron container
│       ├── Rectangle 105 2852:16589  HIDDEN
│       ├── icons 2852:16590         HIDDEN
│       └── Button 2852:16591        HIDDEN
│   ├── lets-icons:back 2852:16592 (x89 y46, 45×45)  ← UNDO icon
│   └── lets-icons:back 2852:16594 (x184 y46, 45×45) ← REDO icon
├── Frame 2034 2852:16596 (y115, 414×781)          ← body
│   ├── Frame 2030 2852:16597 (414×664)
│   │   ├── Frame 2007 2852:16598 (414×552)        ← canvas card
│   │   │   └── Image 3:4 2852:16599 (414×552, aspect 3/4)
│   │   │       ├── Frame 2094 2852:16600          ← VERTICAL grid lines (28 lines, 16px step)
│   │   │       ├── Frame 2095 2852:16629          ← HORIZONTAL grid lines (rotated, 16px step)
│   │   │       └── Media ×4 2852:16666..16669     ← clothing item images (jacket/tee/jeans/shoes)
│   │   ├── Frame 2010 2852:16670 (y568, 64×48)    ← add-item row
│   │   │   ├── Group 35 2852:16671  HIDDEN         ← 5-icon editing toolbar (pill, hidden in this frame)
│   │   │   └── Group 36 2852:16690 (16,0 48×48)    ← circular "+" add button (VISIBLE)
│   │   └── Frame 2101 2852:16693 (y632, 270×32)   ← tag chips row
│   │       ├── chip 2852:16694  "Low Energy" + ×
│   │       ├── chip 2852:16698  "Calm" + ×
│   │       └── chip 2852:16702  (+ add chip, icon only)
│   └── Frame 2092 2852:16705 (y693, 413×56)        ← Save button row
│       └── Button 2852:16706 (x28, 327×56)         ← Save CTA (outlined)
```

---

## Tokens used (Figma var → theme.ts mapping)

| Figma variable | Value | theme.ts path | Status |
|---|---|---|---|
| `background/primary/subtle_50` | `#f2efec` | `figmaBackground` / `figmaCardSurface` | exists |
| `background/primary/subtle_100` | `#e0d2c4` | `figmaInsightPillBg` | exists (`color/primary/200`, same hex) |
| `text/primary/bold_700` | `#070707` | `figmaTextDark` | exists |
| `border/neutral/base` | `#1d1f23` | `uacBorderBase` | exists |
| `border/primary/bold_600` | `#262421` | `figmaCtaLabel` | exists |
| `border-radius/sm` | `6` | `borderRadius.chip` | exists |
| `border-radius/xl` | `12` | `borderRadius.figmaTile` | exists |
| (Save radius) | `16` | `borderRadius.l` | exists |
| body/xs (Inter Regular 12/16) | — | `typography.aliases.uacBodyXsRegular` | exists |
| body/md (Poppins Medium 16/24) | — | `typography.aliases.poppinsButton` | exists |
| **canvas grid line** | `#e9e0d8` | `figmaCanvasGridLine` | **NEW — added** |

Grid line color sampled from the rendered PNG (dominant line pixel `(233,224,216)` = `#e9e0d8`;
intersection antialias trends toward `#e0d2c4` = subtle_100). Canvas bg sampled `(242,239,236)` = `#f2efec`.

---

## Canvas grid style (suspected-gap #1 — CONFIRMED)

- Figma uses a **square LINE grid (graph-paper)**, NOT dots.
- 28 vertical `<line>` nodes + ~33 horizontal `<line>` nodes, **16px spacing** (`Line` x at 0,16,32,…).
- Lines are hairline (width ≈ 0, i.e. 1px stroke), color `#e9e0d8` on `#f2efec` bg.
- Canvas card: aspect 3:4, `cornerRadius 12` (`border-radius/xl`), `overflow: clip`, bg `#f2efec`.
- **Code today**: `Circle` dot pattern, 20px step, `#C8CAD0` on `#F7F5F0` literal bg → REPLACE with
  line grid 16px step, token bg + token line.

## Toolbar (suspected-gap #2 — RESOLVED: design hides it)

- The 5-icon editing toolbar (`Group 35` `2852:16671`) is `hidden="true"` in this frame.
- The only control visible below the canvas is the circular **"+" add button** (`Group 36`).
- **Judgment call**: the drag/layer/duplicate/swap/delete logic is approved & working, and Maestro
  flows likely select its testIDs. Per task constraint "DO NOT delete working functionality unless
  the design clearly omits it — if unsure, keep it and flag." The design *hides* (not *deletes*) the
  toolbar — it is presumably shown contextually on item-selection. **Decision: KEEP the toolbar but
  gate it to show only when an item is selected** (`selectedId != null`), matching the hidden-by-default
  intent without destroying functionality. Add button stays always-visible & restyled circular.
  Flagged for CEO review below.

## Save button (suspected-gap #3 — CONFIRMED: outlined, not dark-filled)

- Figma: `1.5px` solid border `#1d1f23` (`border/neutral/base`), radius `16`, height `56`,
  **transparent fill**, label "Save" Poppins Medium 16/24 color `#262421` (`border/primary/bold_600`).
- Width: 327 (frame is full-width with 28px side insets ≈ horizontal padding ~28).
- NOTE: this Button instance carries `opacity-50` in Figma (it's the "State=Disable, Size=56"
  secondary-button variant the designer dropped in as the visual). The CTA is functional in app,
  so implement at **full opacity** for the enabled state; pressed state = light fill tint. (Open Q.)
- **Code today**: dark filled `figmaButton` (#272A32) + white Archivo text → REPLACE with outlined.

## Tag chips (suspected-gap #4 — CONFIRMED)

- Filled chips ("Low Energy", "Calm"): bg `#e0d2c4` (`background/primary/subtle_100`), radius `6`
  (`border-radius/sm`, NOT pill/round), text `#070707` Inter Regular 12/16, `gap 4` between label and
  the rotated-45° "×" vector (~14px). Padding `8 / 12`. Height `32`. Row `gap 10`, `paddingLeft 16`.
- Add chip: bg `#f2efec` (`background/primary/subtle_50`), same radius/height, icon-only "+" (~14px).
- **Default copy**: design shows **"Low Energy", "Calm"** → update mock default tags from `['Happy']`.
- **Code today**: bg `figmaSurfaceSoft` (#F3F5F9), `borderRadius.round` pill, Manrope 13px → REPLACE.

## "+" add-item button (suspected-gap #5 — CONFIRMED)

- `Group 36` 48×48, circular, bordered "+" sitting below the canvas (row `Frame 2010`,
  `paddingLeft 16`, left-aligned). Rendered as a vector in Figma.
- **Code today**: the "+" is inside the toolbar as `canvas-tool-add` (44×44 square). Add a dedicated
  circular 48×48 bordered add button below the canvas (`canvas-add-item`), keep `canvas-tool-add`
  testID on the toolbar variant for Maestro continuity OR move it — see open Qs.

## Header

- Back chevron (left) + Undo + Redo icons. Matches current code (`canvas-header-back/undo/redo`).
  Icons are `lets-icons:back` style (≈24–28px). Current code uses 24/28px — close enough, keep.

---

## Icons needed

All canvas icons already exist under `auxi/src/assets/images/canvas-icons/`:
`icon_canvas_add/undo/redo/layer_up/layer_down/duplicate/swap/delete/back/replace.svg`.
**No new icons to export.** The chip "×" is a rotated vector — reuse a small "×" glyph (existing
`Text ×`) or `icon_canvas_add` rotated; keep the lightweight Text "×" to avoid a new asset.

---

## Variants / states

- Save: default (outlined), pressed (light fill tint), (disabled — not in app scope, CTA always enabled).
- Add-item "+" button: default, pressed.
- Add chip "+": default, pressed.
- Tag chip "×": default, pressed (hitSlop).
- Toolbar buttons: default, pressed, disabled (when no selection) — unchanged logic.
- Selected canvas item: dashed highlight (keep; not specified in Figma static frame).

---

## Open questions for CEO / tech-lead

- **Toolbar visibility**: design frame hides the 5-icon editing toolbar (`Group 35`), showing only the
  circular "+" add button. I am KEEPING the toolbar (approved functionality + Maestro testIDs) but
  gating it to appear only when an item is selected. Confirm: (a) keep gated-on-selection [my pick],
  (b) keep always-visible, or (c) remove entirely (would drop layer/duplicate/swap/delete UI).
- **Save opacity**: the Figma Save instance is the `State=Disable` secondary-button variant at 50%
  opacity. I render the enabled CTA at full opacity (outlined). Confirm intended enabled-state look.
- **Selected-item highlight**: not shown in the static Figma frame (no item is selected). I keep the
  existing dashed-green highlight. Confirm desired selection affordance / color.
- **"+" add button testID**: I add `canvas-add-item` for the new circular button and keep the toolbar's
  `canvas-tool-add` for parity. If Maestro only needs one, tech-lead/qa-ui to confirm which to retain.

## New backend fields (vs current API client)

None — this is visual-only. The canvas still uses the mock `test_jeans` image and in-memory state;
no API client touched. Real wardrobe-image wiring + outfit persistence (`handleSave` TODO) remains a
separate backend task, out of scope.
