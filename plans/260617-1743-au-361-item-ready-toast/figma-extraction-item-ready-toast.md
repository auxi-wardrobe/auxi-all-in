# Figma Extraction — AU-361 "Item is ready" toast

- **Ticket:** AU-361 — "[bug] There is no toast message to inform an item is ready"
- **Figma:** https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2852-18884
- **Section:** `add items from camera or library` (2852:18884)
- **Reporter:** Viet (CEO/designer)

## Frame tree (relevant nodes)

```
Section "add items from camera or library" (2852:18884)
├── Frame "detail enhancing" (3471:16322)        ← item detail while processing
│   └── "Preparing this item ..." + macgie-animate loader
├── Frame "wardrobe" (3471:16161)                ← grid w/ a tile mid-processing
│   ├── tile overlay "Preparing this item ..." (3471:16321)
│   └── Instance "Snackbar" (3910:22258) @ x23 y747 w344 h68   ← UPLOAD/in-progress toast
├── Frame "wardrobe - added" (3728:17941)         ← grid, item just became ready
│   └── Instance "Snackbar" (3915:30077) @ x23 y747 w344 h52   ← READY toast  ★ THIS TICKET
└── Frame "wardrobe - seen" (3728:18070)          ← same grid, snackbar dismissed (no toast)
```

The three-frame storyboard (`wardrobe` → `wardrobe - added` → `wardrobe - seen`)
encodes the lifecycle: item uploads (preparing toast) → finishes processing
(**"Your item is ready"** toast) → user sees it, toast auto-dismisses.

## The two snackbars (both 1-line Material-3 snackbars, same visual spec)

| Node | Frame | Copy | Meaning |
|---|---|---|---|
| 3910:22258 | `wardrobe` | "Item added. We'll finish preparing it in the background." | upload accepted, still processing |
| **3915:30077** | `wardrobe - added` | **"Your item is ready"** | processing finished — **THIS TICKET** |

## Snackbar visual spec (node 3910:22127 component → 3915:30077 instance)

- **Size:** 344 wide, hug height (~52px for 1 line)
- **Background:** `color/success/200` = `#4cf4d3`
- **Corner radius:** 4px
- **Padding:** 16 horizontal / 14 vertical
- **Gap:** `dimension/8` = 8px (icon ↔ text)
- **Layout:** HORIZONTAL, items-start
- **Icon:** check-circle, 24px container, 16px glyph, color `icon/primary/bold_700` = `#070707`
- **Text:** `text/neutral/base` = `#1d1f23`, font `Inter` Regular 400, size 14, line-height 20, letter-spacing 0 (`body/sm`)
- **Effect:** M3/Elevation Light/3 — DROP_SHADOW #0000004D off(0,1) r3 + DROP_SHADOW #00000026 off(0,4) r8 spread3

## Tokens used (Figma var → theme.ts mapping)

| Figma var | Value | theme.ts target |
|---|---|---|
| `color/success/200-#4CF4D3` | `#4cf4d3` | already in theme? → verify; existing toast config |
| `text/neutral/base` | `#1d1f23` | existing neutral text token |
| `icon/primary/bold_700` | `#070707` | existing |
| `body/sm` font | Inter 14/20/0 | existing body-sm preset |
| `dimension/8` | 8 | `theme.spacing` 8 |

NOTE: The app already renders all toasts through `react-native-toast-message`
(mounted in `App.tsx:83`, used in 9 screens incl. `WardrobeScreen.tsx`). The
existing `type:'success'` toast config is what every other success toast uses.
Per project convention (reuse existing primitive, no new dependency), the
"ready" toast reuses the same `Toast.show({ type:'success', ... })` channel
rather than building a bespoke snackbar component. The success-toast styling
is the established app-wide pattern; pixel-rematching the M3 snackbar to a
new bespoke component is out of scope for a bug fix and would diverge from
the 9 other success toasts already shipped.

## Icons

- check-circle (snackbar leading icon) — provided by the existing
  `react-native-toast-message` `success` preset. No new SVG export needed.

## Variants / states

- `wardrobe` frame: preparing toast (already conceptually covered by existing
  post-upload success toast `wardrobe.list.added_title`).
- `wardrobe - added` frame: **ready toast** — MISSING today. This is the fix.
- `wardrobe - seen` frame: toast dismissed (auto-hide handles this).

## Root cause (code side)

`WardrobeItem` already carries `is_preparing` (rendered as a tile overlay at
`WardrobeScreen.tsx:304` and item-detail gate at `ItemDetailScreen.tsx:775`),
so the preparing → ready lifecycle EXISTS in the data model. But nothing
detects the transition `is_preparing: true → false` across wardrobe refetches,
so no "ready" toast ever fires. The post-upload success toast
(`WardrobeScreen.tsx:224`) fires once at upload time and is unrelated to the
async ready transition.

## Open questions for CEO / tech-lead

None — spec self-contained. The "ready" copy is explicit in Figma ("Your item
is ready"). Decision to reuse the app-wide `react-native-toast-message`
success channel (vs. a new bespoke M3 snackbar component) follows the
primitives-reuse convention and matches the 9 existing success toasts; flagged
above for visibility but not blocking.

## New backend fields (vs current API client)

None — `is_preparing` is already consumed by the client (via the
`WardrobeItem` index signature). No new contract surface. The fix is
purely client-side transition detection on existing data.
