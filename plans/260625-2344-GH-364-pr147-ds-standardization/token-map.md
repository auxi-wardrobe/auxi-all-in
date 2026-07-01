# PR #147 → `ds.*` token map

> Authoritative mapping for the exact tokens the 4 PR-#147 UI files use, derived
> from `auxi/src/theme/theme.ts` (the `ds.*` layer annotates its own aliases).
> Source PR: auxi-wardrobe/auxi-mobile#147. Canonical tier = `theme.ds.*`.
> Use this when migrating #147 (and the FavouriteScreen pattern it mirrors) onto `ds.*`.

## 0. Two DS bugs this PR surfaced (fix these in theme.ts FIRST)

1. **`ds.color.cream` alias annotation is wrong.** `theme.ts:426` says
   `cream: '#f2efec' // (alias: figmaBackground, figmaCardSurface)`. But
   `figmaBackground = '#FFFFFF'` (white, `theme.ts:21`), NOT `#f2efec`. Only
   `figmaCardSurface` is `#f2efec`. → Fix the comment: `figmaBackground`'s
   canonical is **`ds.color.white`**, not `cream`. (MyCreationsScreen sets the
   screen bg from `figmaBackground` = white, so it must map to `ds.color.white`.)

2. **Three destructive reds, only one canonical.**
   - `ds.color.danger = #bb251a` ← canonical (aliases `uacTextDangerBase`, `figmaDestructive`)
   - `figmaItemDetailDanger = #c0392b` ← a **second** red, NOT aliased to `ds.color.danger`
   - `ds.color.red = #ff0000` ← already flagged off-system
   PR #147 uses `figmaItemDetailDanger` (#c0392b) for the Discard label and the
   remove (⊖) icon → off the canonical destructive token. **Decision needed
   (CEO/designer):** alias `figmaItemDetailDanger → ds.color.danger` (#bb251a)
   and recolor, OR formally bless #c0392b as a distinct item-detail danger and
   document it. Until then, new destructive surfaces should use `ds.color.danger`.

## 1. Color

| PR token (file) | value | → `ds.*` | note |
|---|---|---|---|
| `figmaBackground` (MyCreations container) | `#FFFFFF` | `ds.color.white` | **not** cream — see bug #1 |
| `white` (menuButton, blur fallbacks) | `#FFFFFF` | `ds.color.white` | direct |
| `background` (Canvas container) | `#FFFFFF` | `ds.color.white` | generic→ds |
| `uacTextBase` (titles, body, date) | `#1d1f23` | `ds.color.ink` | direct |
| `figmaTextDark` (empty icon, moodPillText) | `#070707` | `ds.color.black` | direct |
| `figmaCardSurface` (collage surface) | `#f2efec` | `ds.color.cream` | direct |
| `figmaInsightPillBg` (moodPill bg) | `#e0d2c4` | `ds.color.tan` | **semantic mismatch** — "insight pill" bg reused as tag/mood pill; propose dedicated `ds.color.tagBg` (= tan) for chips |
| `figmaItemDetailDanger` (discard label, ⊖) | `#c0392b` | `ds.color.danger` | recolor to `#bb251a` — see bug #2 |
| `figmaOverlayScrim` (dialog scrim) | `rgba(38,36,33,0.7)` | **gap** | no `ds` scrim token — add `ds.color.scrim` (= this value; `dialogScrim` also exists for centered dialogs) |
| `figmaItemDetailHeaderBg` (header/button tint, blur fallback) | `rgba(255,255,255,0.9)` | **gap** | the blurred-header tint has no `ds` token — add `ds.color.headerBlurTint`; consumed by the BlurMenuHeader primitive (see spec) |

## 2. Border radius

| PR token | value | → `ds.radius.*` | note |
|---|---|---|---|
| `borderRadius.uacPanel` | 16 | `ds.radius.md` | direct |
| `borderRadius.uacButtonCta` | 16 | `ds.radius.md` | direct |
| `borderRadius.figmaTile` | 12 | `ds.radius.sm` | direct |
| `borderRadius.round` | 9999 | `ds.radius.full` (100) | intent match |
| `borderRadius.m` | 8 | **gap** | header-icon-button radius (8) is not in `ds.radius` (xs2 / sm12 …); MIconButton should own this. If kept, add `ds.radius.button8` |

## 3. Spacing

`ds.*` has **no spacing layer** — the canonical scale is the generic
`spacing.xs/s/m/l/xl/xxl` (4/8/16/24/32/48, on the 4px grid).

| PR token | value | canonical | note |
|---|---|---|---|
| `spacing.m / l / xl / s / xs` | 16/24/32/8/4 | already canonical | keep |
| `spacing.uacDimension12` | 12 | **gap** | 12 is on the 4px grid but unnamed in the generic scale (sits between `s`=8 and `m`=16). Add `spacing.sm = 12` and migrate `uacDimension12`/`uacDimension*` onto the generic scale |
| `spacing.uacButtonHeight` | 56 | — | PR hardcodes `height: 56` for the dialog buttons instead of using this; MButton encapsulates it |

## 4. Typography — naming drift, NOT a font bug

**The "Inter" aliases already render Poppins.** Every `inter*` alias in
`theme.ts` resolves to `Poppins-*` (e.g. `interSemiboldXsSm → 'Poppins-SemiBold'`,
`interBodySm → 'Poppins-Regular'`, `interCaptionXxs → 'Poppins-Regular'`). Same
for `manrope*`, `archivo*`, `playfair*`. So the CEO **Poppins-only** directive is
**already satisfied at render** — the drift is (a) misleading alias names and
(b) heavy duplication.

| PR alias | resolves to | fix |
|---|---|---|
| `poppinsH4SemiBold` | Poppins-SemiBold 24/32 | keep (already Poppins-named) |
| `uacBodyXsRegular` | Poppins-Regular 12/16 | keep / rename to scale |
| `poppinsButton` | Poppins-Medium 16/24 | keep |
| `interSemiboldXsSm` | Poppins-SemiBold 14/20 | **rename** → e.g. `bodySmSemibold` |
| `interBodySm` | Poppins-Regular 14/20 | **rename** → `bodySm` |
| `interCaptionXxs` | Poppins-Regular 10/12 | **rename** → `captionXxs` |

→ DS action: collapse the `inter*/manrope*/archivo*/playfair*` aliases into a
single Poppins-named type scale; keep thin back-compat re-exports during migration.

## 5. Magic numbers → tokens

| PR literal (file) | should be |
|---|---|
| `height: 56` (DiscardDialog buttons) | `spacing.uacButtonHeight` / MButton |
| `width:44,height:44` (menu button) | MIconButton `size="lg"` |
| `width:56,height:56` (remove button) | MIconButton hit target |
| `height: 24` (moodPill) | MChip/MTag height |
| `borderWidth: 1.5` (outlined Save) | MButton `dangerOutline`/`secondary` border |
| `translateY 320 → 0` (sheet slide-in) | add `motion`/`ds` sheet-travel constant; MBottomSheet owns it |
| `blurAmount: 8` / `4` | `ds` blur-amount constant (FavouriteScreen also uses 8) |
| `elevation: 1000` (snackbar overlay) | align to tier — `zIndex.toast`=1200 is set; elevation should track the tier, not a raw 1000 |

## 6. Already on-system (do NOT touch)

- `ds.shadow.headerIcon` (MyCreations menu button) — canonical ✓
- `theme.zIndex.toast` (snackbar) — canonical six-tier ✓
- `motion.duration.*` / `motion.easing.*` / `useReducedMotion()` (DiscardDialog) — canonical ✓
- `testID` + `accessibilityLabel` on every interactive element ✓
