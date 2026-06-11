# Figma Extraction — Item Detail as pushed screen (AU-312, Phase 1)

- **Figma file**: Auxi — `0nXXMAR4Arf1ZfjtQvtBh0`
- **Section node**: `2852:7175` "Item detail | Edit detail" (3339×3376) — CURRENT state (designer updated since AU-311)
- **Primary target frame**: `2852:14557` "detail" (414×896) — the view-item screen Home must PUSH to (Back header, no popup)
- **Adjacent frames (context, Edit flow)**: `3508:8356` "detail item - more - edit" (full edit list, Cancel/Save), per-field picker popups: `2852:15123` label, `2852:15222` categories, `2852:15453` Edit Color, `2852:15610` FIT, `2865:13145` Materials, `2852:15701` Style, `2870:13875` Energy, `2852:15813` Occasion, `2870:13377` date, `2870:14058` Name
- **Screenshots (this dir)**: `figma-au312-section-overview.png` (whole section), `figma-au312-detail-frame.png` (target frame)
- **Prior-rev extraction (AU-311)**: `plans/260610-1632-au311-item-detail-figma/figma-extraction-item-detail.md` — design has CHANGED since; diff in §What changed

## Frame tree — `detail` 2852:14557 (414×896)

```
Frame "detail" — bg background/primary/subtle_50 (#f2efec)
├── Instance "header" (3227:24191) 414×107, pinned top
│   ├── Bar: bg background/neutral/subtlest (#ffffff) @ 90% opacity, backdrop-blur 7.5
│   └── Inner: column justify-end, padding 12 → row, space-between
│       └── "menu" back button (left only): 44×44 WHITE rounded square
│           (radius ≈14, soft drop shadow — baked into image asset; shadow tint
│           plausibly background/overlay/dark/10 #8271371a) + back chevron 24×24
│           (glyph ~5.9×11.5, color Black #070707-ish)
│       Variant: property1=detail, centerIcon=no, rightIcon=no, title=no
│       → NO right-side icon (heart/favorite REMOVED vs current code)
├── Instance "Image 3:4" (2852:14558) 378×504, x=18 y=108 (18px side margins)
│   ├── bg #f2efec, item photo object-cover
│   └── "common" badge: centered, bottom 19; h 19, padX 12 (var ML=12),
│       radius 8, bg color/neutral/black/Alpha300 rgba(18,18,18,0.75);
│       text "common" Inter Regular 10/12 (Text-xxs), color color/neutral/50 #fcfcfd
└── Instance "detail" (2852:14560 → component 3516:18640) 414×284, anchored bottom
    ├── Frame "detail" card: bg #ffffff, radius-top 16/16, padding 16, column center
    │   └── "List items" w 382 → pt 12 → column, gap 16, centered, color text/neutral/base #1d1f23
    │       ├── Title "Denim jacket" — H4/SemiBold: Poppins SemiBold 24/32
    │       └── "Date: 11/06/2026" — Text-xs/Regular: Inter Regular 12/16
    └── Frame "button group": bg #ffffff, column center, gap 12, pt 16, pb 36, padX 16 (var XL)
        ├── Button "Build around this" — outline pill w 327:
        │   border 1.5 border/neutral/base #1d1f23, radius **17**, inner padX 20 padY 16
        │   gap 8; label Poppins Medium 16/24 (Text-md l-24/Medium) #1d1f23;
        │   trailing icon 24×24 (remix/mix glyph — partially obscured in Figma by a
        │   pasted cursor graphic; same asset family as AU-311 "Mix with this" icon)
        └── Row space-between, w full
            ├── left group, gap 12:
            │   ├── Icon button (trash): state-layer p 16 → 56×56, icon 24×24,
            │   │   color icon/danger/base #c0392b
            │   └── Text button "Less use": h 56, padX 20, gap 8, radius 100;
            │       label Poppins Medium 16/24 #1d1f23 + minus-circle icon 24×24 #c0392b
            └── Text button "Edit": h 56, padX 20, gap 8, radius 100;
                label Poppins Medium 16/24 #1d1f23 + edit pencil icon 24×24 (black)
```

Layout intent (responsive): header pinned top, bottom panel pinned bottom,
image centered in remaining space; image keeps 3:4 with 18px side margins
(414 frame → 378 wide). Implement flex-based, not absolute.

## Flows (arrows in section)

- `detail` —"Click more"/"Click Edit"→ `detail item - more - edit` (3508:8356):
  full editable list — Name, Color, Style, Energy, Label, Fit, Material,
  Occasion, Purchase Date rows with pencil icons + bottom **[Cancel] [Save ⬇]**.
- Each pencil opens a per-field picker popup over a scrim (frames listed above:
  radio list for Type/Material, checkbox lists for Occasion/Fit/Style/Energy,
  color picker with hex, calendar for date, text input + recommended-name chips
  for Name).
- Edit flow = separate concern (largely shipped under AU-311); AU-312 scope is
  the VIEW screen presentation. Differences in edit flow noted but not re-extracted
  row-by-row.

## Designer sticky note (node 2852:14638, verbatim intent)

- User can NOT delete a common item; only their uploaded items (matches AU-287 rule already in code).
- "Less used" = use this item less in the suggestion system.
- "Click change" opens user's wardrobe or upload from camera/library.
- "Mix with this" = same as the pinned-item feature — suggestion system finds best-mixing items. (Button now reads **"Build around this"**.)

## What changed vs AU-311 extraction (design update)

| Aspect | AU-311 rev | CURRENT (this extraction) |
|---|---|---|
| Read-mode body | Attribute rows (Name/Type/Style/… + More/Less + Edit link) | **Title + Date only** — attributes live in Edit flow |
| Primary CTA label | "Mix with this" | **"Build around this"** (same trailing icon) |
| Secondary labels | "Less used", "Change" | **"Less use"**, **"Edit"** |
| Header right | (code has heart/favorite) | **No right icon** (variant rightIcon=no) |
| Edit-list node | 2852:16316 | **3508:8356** (re-drawn; same field set) |
| Back button | 44×44 blur glyph | 44×44 **white rounded square + shadow** |

## Tokens used → theme.ts mapping (verified against worktree `src/theme/theme.ts`)

| Figma var | Value | theme.ts token | Status |
|---|---|---|---|
| background/primary/subtle_50 | #f2efec | `colors.figmaBackground` (theme.ts:15) | exists |
| background/neutral/subtlest | #ffffff | `colors.figmaSurface` / `colors.white` | exists |
| color/neutral/black/Alpha300 | rgba(18,18,18,0.75) | `colors.figmaCardTag` (theme.ts:17) | exists |
| color/neutral/50 | #fcfcfd | `colors.uacBackgroundNeutral50` (theme.ts:73) | exists (naming: it's a bg token; used here as badge TEXT color — reuse, don't duplicate) |
| text/neutral/base | #1d1f23 | `colors.uacTextBase` (theme.ts:77) | exists |
| border/neutral/base | #1d1f23 | `colors.uacBorderBase` (theme.ts:75) | exists |
| icon/danger/base = color/danger/400 | #c0392b | `colors.figmaItemDetailDanger` (theme.ts:86) | exists |
| icon/primary/bold_700 | #070707 | `colors.figmaTextDark` (theme.ts:57) | exists |
| **background/overlay/dark/10** | **#8271371a** (rgba(130,113,55,0.10)) | — | **MISSING** — appears in frame var defs; most plausible use = back-button drop-shadow tint (rect+shadow is image-baked in Figma). Add only once usage confirmed (figma-theme-sync before edit) |
| dimension/12 | 12 | `spacing.uacDimension12` | exists |
| dimension/16 / XL | 16 | `spacing.uacDimension16` / `spacing.m` | exists |
| dimension/24 | 24 | `spacing.uacDimension24` | exists (gap resolves 0 in this instance — single child; moot) |
| ML | 12 | `spacing.uacDimension12` | exists |
| header height 107 | 107 | `spacing.uacHeaderHeight` | exists |
| button padX 20 / padY 16 / h 56 | — | `spacing.uacButtonPaddingX/Y`, `uacButtonHeight` | exists |
| sheet top radius 16 | 16 | `borderRadius.uacPanel` / `l` | exists |
| pill radius 100 | 100 | `borderRadius.uacRadioPill` | exists |
| badge radius 8 | 8 | `borderRadius.m` | exists |

### Typography

| Figma style | Resolved | theme.ts alias | Status |
|---|---|---|---|
| H4/SemiBold (title) | Poppins SemiBold 24/32 | — | **MISSING alias** — `uacH4Bold` is Poppins-**Bold** 24/32 (weight 700 vs Figma 600). `Poppins-SemiBold.ttf` IS bundled (`src/assets/fonts/`). Add e.g. `poppinsH4SemiBold` |
| Text-xs/Regular (date) | Inter Regular 12/16 | `uacBodyXsRegular` (theme.ts:234) | exists |
| Text-md (l-24)/Medium (button labels) | Poppins Medium 16/24 | `uacBodyMdMedium` / `poppinsButton` | exists (note: Figma style var family = body/Inter but instance resolves Poppins Medium — designer override, follow rendered Poppins) |
| Text-xxs/Regular (badge) | Inter Regular 10/12 | `interCaptionXxs` (theme.ts:247) | exists |

### One-off literals (no Figma variable — flag, don't silently encode)

- **Button-group bottom padding 36** — not in spacing scale (l=24/xl=32). Likely home-indicator allowance → prefer safe-area inset + spacing, confirm.
- **"Build around this" radius 17** — between tokens (uacButtonCta=16, AU-311 used 16). Ask: intentional or nudge? Default proposal: reuse 16.
- **Image side margin 18** — derived from 414−378; not in spacing scale.
- **Badge height 19 / bottom offset 19** — one-off; height falls out of text+pad.
- **Back button 44×44, radius ≈14, white bg + soft shadow** — rect+shadow baked into an image asset in Figma, exact radius/shadow unverifiable via MCP. Existing `TopIconButton` primitive is 45×45 r14 but bg `figmaIconSurface` #E3E3EC (FigmaPrimitives.tsx:160-167) → needs white-bg + shadow variant.
- **Header bar: white @90% + backdrop-blur 7.5** — no blur lib installed (`package.json` has no `@react-native-community/blur`). Decision needed: rgba-white approximation vs new dependency.

## Icons audit (all present — none to export)

| Figma glyph | Size | Asset | Map |
|---|---|---|---|
| back chevron | 24 (glyph ~6×11.5) | `src/assets/images/icon_chevron_left.svg` | `Icons.ChevronLeft` |
| build-around/remix (CTA trailing) | 24 | `icon_remix.svg` | `Icons.Remix` — verify glyph match in qa-ui Pass 2 (Figma render obscured by pasted cursor) |
| trash | 24 | `icon_trash.svg` | `Icons.Trash` |
| minus circle (Less use) | 24 | `icon_minus_circle.svg` | `Icons.MinusCircle` |
| edit pencil | 24 | `icon_edit.svg` | `Icons.Edit` |

All icon colors map to theme tokens (#c0392b danger, #1d1f23/#070707 neutral) — no literal hex needed.

## Variants / states

- Back button: pressed state not drawn — use standard pressed opacity on the TopIconButton variant.
- "Build around this": only enabled state drawn; implement pressed (state-layer) per existing PillButton behavior.
- "Less use" toggle: active styling not drawn in THIS frame; AU-311 active treatment (#c0392b label + soft pink bg `figmaItemDetailLessUsedActive`) already shipped — keep unless CEO objects.
- "common" badge: only on catalog items (`is_common_item` / hrid SYSTEM/USR_* — AU-287 logic at ItemDetailScreen.tsx:290-297 stays).
- Catalog items: trash hidden (designer note re-confirms AU-287 rule).

## Current implementation gap (file:line)

**Presentation (the AU-312 ask):**
- `src/screens/HomeScreen.tsx:34` — imports `ItemDetailBottomSheet`.
- `src/screens/HomeScreen.tsx:1559` — `onItemPress={item => setSelectedItem(item)}`: item tap sets local state…
- `src/screens/HomeScreen.tsx:1586-1590` — …which renders `<ItemDetailBottomSheet visible={!!selectedItem} …/>` — a transparent RN `Modal` sliding from the bottom (`src/components/features/ItemDetailBottomSheet.tsx:62-77`) with a text "Close" button (`:79-83`), **no Back header, no navigation push** → exactly the popup the designer rejects.
- Target pattern already exists: `src/screens/WardrobeScreen.tsx:135-140` — `navigation.navigate('ItemDetail', { itemId: item.id })`.
- Destination screen exists and is registered: route type `src/types/navigation.ts:99` (`ItemDetail: { itemId: string }`), route `src/navigation/AppNavigator.tsx:99`, screen `src/screens/ItemDetailScreen.tsx:212` with Back header (`item-detail-back-btn`, ItemDetailScreen.tsx:683-694).

**Screen-content drift (ItemDetailScreen built against AU-311 rev, design since updated):**
- Heart/favorite button in header (`ItemDetailScreen.tsx:696-709`) — current Figma header variant has `rightIcon=no`.
- Read-mode attribute rows + More/Less expander (`ItemDetailScreen.tsx:744-792`) — current design shows **title + date only** in read mode.
- CTA copy: "Mix with this" (`:845`, i18n `wardrobe.itemDetail.mix_with_this`) → "Build around this"; "Less used" (`:905`) → "Less use"; "Change" (`:931`) → "Edit".
- No date line today; Figma shows "Date: <dd/mm/yyyy>" under the title.
- Home's tap payload is `Item` (`src/types/item.ts:1-12`, has `id`) vs route param `itemId` — wiring is trivial, but see Q7 on id-space.

**Gap summary**: Home presents item detail as a bottom-sheet popup; design requires a pushed full screen (existing `ItemDetail` route) whose read mode is also simpler than what's currently rendered.

## Open questions for CEO / tech-lead

1. **Favorite/heart**: updated header has no right icon — remove the heart from ItemDetailScreen? If yes, where does favoriting an item live afterwards?
2. **"Date:" field**: date ADDED (`created_at`, exists in contract) or PURCHASE date (no backend field — see below)? Figma shows `11/06/2026` (today-ish ⇒ likely created_at). Also confirm dd/mm/yyyy format.
3. **Read-mode rows**: confirm attribute rows (Type/Style/Color/Fit + More/Less) are fully removed from read mode (moved to Edit flow), i.e. delete, not hide.
4. **Radius 17** on "Build around this" vs token 16 — intentional?
5. **Header blur** (white 90% + blur 7.5): approximate with near-opaque white (no new dependency) or add `@react-native-community/blur`? Recommend approximation; content scrolls under header only marginally.
6. **"Build around this" action**: designer note equates it to the pinned-item mixing feature. Current button shows a coming-soon Alert (ItemDetailScreen.tsx:854-859). Keep alert with new copy for AU-312, or wire to pin+recommend now (scope grows)?
7. **Home item id-space**: Home passes recommendation `Item.id`; `wardrobeService.getWardrobeItem(id)` must resolve catalog/common items surfaced by Valen (design's "common" badge implies they open). Needs a runtime check in phase 2; if catalog ids 404, escalate to tech-lead (possible backend lookup gap).
8. Back-button exact radius/shadow are image-baked in Figma (unmeasurable via MCP) — implementing 44×44, r14, white bg, soft warm shadow (#827137 @10%); qa-ui to eyeball in Pass 2.

## New backend fields (vs current API client)

- **Purchase Date** — only if Q2 resolves to "purchase date": no such field on `WardrobeItem` (`src/services/wardrobeService.ts` interface — has `created_at` only). Would need backend-dev ticket; do NOT invent the endpoint/field.
- **Energy / Label / Material / Occasion-edit / Name-recommendations** — Edit-flow fields in `3508:8356` and picker frames still have no API contract (carried over from AU-311 §New backend fields; out of AU-312 view-screen scope).
- If Q2 = `created_at`: **None — all view-screen fields covered by current contract.**
