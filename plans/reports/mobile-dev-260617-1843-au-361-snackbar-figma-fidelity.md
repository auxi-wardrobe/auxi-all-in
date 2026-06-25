# mobile-dev — AU-361 item-ready toast → Figma M3 snackbar fidelity

- **Date:** 2026-06-17
- **Ticket:** AU-361 — item-ready toast must match the designed M3 snackbar
- **Trigger:** qa-ui ESCALATION on a landed functional fix — toast rendered via
  default `react-native-toast-message` `success` style, materially deviating
  from Figma.
- **Figma:** node-id `3915:30077` ("Your item is ready" instance) under section
  `2852:18884`. https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2852-18884
- **Scope:** Visual presentation only. Functional logic, dedup, polling, and
  analytics untouched.

## Note on the prior extraction artifact

The saved note (`plans/260617-1743-au-361-item-ready-toast/figma-extraction-item-ready-toast.md`)
§Snackbar visual spec is accurate, but its §NOTE concluded "reuse the global
`success` channel, don't build a bespoke snackbar." The qa-ui escalation
**overrides** that conclusion: the default success preset is the exact drift
being filed. This task implements the M3 snackbar as a NEW custom toast type,
per the escalation. The pixel spec from the note was reused verbatim.

## Figma spec extracted (live MCP: get_design_context + get_variable_defs)

| Property | Figma value | Token / source |
|---|---|---|
| Surface bg | `#4cf4d3` | `color/success/200-#4CF4D3` |
| Corner radius | 4px | rounded-[4px] → `borderRadius.s` (4) |
| Padding | 16 horizontal / 14 vertical | `px-[16px] py-[14px]` |
| Gap (icon↔text) | 8px | `dimension/8` → `spacing.s` (8) |
| Layout | horizontal, items-start | `flexDirection:'row'`, `alignItems:'flex-start'` |
| Icon container | 24px | `size-[24px]` |
| Icon glyph | 16px check-circle, `#070707` | `icon/primary/bold_700` → `figmaTextDark` |
| Text | Inter Regular 400, 14/20, ls 0, `#1d1f23` | `body/sm`, `text/neutral/base` → `uacTextBase` |
| Width | 344 | instance width |
| Elevation | M3/Elevation Light/3 (2 drop shadows) | RN shadow approximation |
| Copy | "Your item is ready" | i18n `wardrobe.list.item_ready_title` (already exists, 3 locales) |
| Position | bottom | unchanged |

Screenshot confirmed: teal/mint pill, leading check-circle, dark text.

## Files changed

| File | Change |
|---|---|
| `auxi/src/assets/images/icon_check_circle.svg` | NEW — check-circle glyph, `stroke="currentColor"`, 24 viewBox |
| `auxi/src/assets/icons/index.ts:43,86` | register `IconCheckCircle` → `Icons.CheckCircle` |
| `auxi/src/theme/theme.ts:113-118` | NEW token `figmaSnackbarSuccessBg: '#4cf4d3'` (color/success/200); glyph+text reuse `figmaTextDark` / `uacTextBase` |
| `auxi/src/components/feedback/toastConfig.tsx` | NEW — `toastConfig` exporting custom `successSnackbar` type (M3 snackbar component) |
| `auxi/App.tsx:18,84` | import `toastConfig`; mount `<Toast config={toastConfig} />` |
| `auxi/src/screens/WardrobeScreen.tsx:143-150` | ready-toast `type:'success'` → `type:'successSnackbar'` (only the type string + a clarifying comment) |

## Custom toast type + token added

- **Custom type:** `successSnackbar` — a NEW `react-native-toast-message` type,
  added via `<Toast config={toastConfig} />`. It does NOT restyle the global
  `success`/`error`/`info` presets, so the 9 other success toasts are
  unregressed.
- **Token:** `theme.colors.figmaSnackbarSuccessBg = '#4cf4d3'` (color/success/200).
  Surface bg references this token; glyph color references existing
  `figmaTextDark` (#070707), text references existing `uacTextBase` (#1d1f23).
  No literal hex in the screen or component.
- **Icon:** `icon_check_circle.svg` follows the `currentColor` convention,
  colored via `color={theme.colors.figmaTextDark}` (the established icon
  pattern). Registered in `assets/icons/index.ts`.
- **testID / a11y:** snackbar surface carries `testID="wardrobe-item-ready-snackbar"`
  and `accessibilityLabel={text1}` (VoiceOver reads the ready message) +
  `accessibilityRole="alert"`. testID ≠ a11yLabel.
- **i18n:** reuses existing `wardrobe.list.item_ready_title` (present in
  en-EN / vi-VN / fr-FR). No new strings, no duplication.

## Functional logic + analytics — UNTOUCHED (verified)

WardrobeScreen `reconcileReadyItems` transition detection is byte-identical
except the toast `type`:
- `is_preparing` true→false detection (`prevPreparing.has(item.id)`) — intact
- dedup ref (`readyToastedIdsRef.current.has/add`) — intact
- light/silent polling + `position:'bottom'` — intact
- analytics `track('item_ready_toast_shown', readyProps)` with `item_category` —
  intact (no event-name, property, or timing change → tracking plan unchanged)

## Verification

- `npx tsc --noEmit` (Node 20.12.2): **0 errors** (clean, incl. no legacy noise this run).
- `./scripts/auxi-lint-tokens.sh`: 34 pre-existing baseline violations in OTHER
  files (DatabaseScreen, BodyScreen, ItemDetailScreen, HomeScreen,
  ContextChipsModal, etc.). **Zero in any touched file.** Direct hex grep on
  `toastConfig.tsx` + `WardrobeScreen.tsx` returns nothing. The only hex I added
  (`#4cf4d3`) lives in `theme.ts` as a named token.
- Simulator: NOT run this session (mobile-dev has no mobile-mcp; sim verify is a
  qa-ui/qa-mobile handoff). **Code complete, visual verification pending** —
  recommend qa-ui Compare-mode Pass 2/3 (code vs Figma 3915:30077) and
  qa-mobile smoke that the snackbar renders on the `is_preparing` true→false
  transition.

## Open questions

- Vertical padding 14px has no exact spacing token (sits between `xs`=4 and
  `m`=16). Left as a numeric literal `14` (the token-lint only flags hex/font,
  not numbers). If the team wants it tokenized, add `spacing` entry — flagged,
  not blocking.
- M3 Elevation Light/3 is two stacked drop shadows; RN can only express one
  per view. Approximated with a single shadow (offset 0,4 / radius 8 /
  opacity 0.18 / elevation 3). qa-ui Compare should confirm it reads close
  enough on-device.
