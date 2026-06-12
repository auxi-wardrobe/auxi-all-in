# Figma Extraction — "First time" Home coach-mark overlay

**Figma:** `0nXXMAR4Arf1ZfjtQvtBh0` · frame **"first time"** `3140:9395` (section "Home | behavior guide")
**Overlay node:** `noti` `3140:9520` · 414×896
**Date:** 2026-05-30

## What it is
Home grid view (already shipped in `HomeScreen.tsx`) + a **one-time coach-mark modal** shown the first time the user reaches Home after onboarding. Explains the horizontal swipe-to-explore gesture. Dismissed via "Got it"; never shown again.

## Anatomy (node → spec)

| Node | Element | Spec |
|---|---|---|
| 3140:9521 | Scrim `Rectangle 346` | full-screen, bg `background/primary/bold_600` = `#262421`, **opacity 0.70** |
| 3140:9522 | `Basic Dialog` | bg white `#ffffff`, radius `border-radius/2xl` = **16**, width **366**, centered vertically (top 50%, translateY −50%), left 24 → 24px side margins on 414 |
| 3140:9523 | `Title & Description` | flex col, items center, gap **16**, padding **pt24 / px24 / pb4** |
| 3140:9642 | icon `material-symbols:swipe-outline` | **54×54**, fill `icon/primary/bold_700` = `#070707` |
| 3140:9524 | `Headline` | "Swipe left or right to explore different outfit options." · Poppins **Regular 400**, size **16**, line-height **24**, letter-spacing 0, color `text/neutral/base` = `#1d1f23`, **center** |
| 3140:9531 | `Divider` | **hidden=true** → not rendered |
| 3140:9533 | `Actions` | flex col, padding **pt12 / pb24 / px24** |
| 3140:9535 | `Button` "Got it" | **Text button** (transparent container, label-only) · height **56**, full-width, radius 100, Poppins **Medium 500**, size 16/24, color `#1d1f23` |

## Token → theme.ts mapping (verified)

| Figma var | Value | auxi token |
|---|---|---|
| background/primary/bold_600 | #262421 | `theme.colors.figmaCtaLabel` (theme.ts:23) |
| text/neutral/base | #1d1f23 | `theme.colors.uacTextBase` (theme.ts:72) |
| background/neutral/subtlest | #ffffff | `theme.colors.white` |
| border-radius/2xl | 16 | `theme.colors`→radius `uacPanel` (theme.ts:259) |
| body/md Regular | Poppins 16/24 | `theme.typography.aliases.poppinsBody` |
| body/md Medium | Poppins 16/24 | `theme.typography.aliases.poppinsButton` |
| spacing | 4/12/16/24 | `theme.spacing` xs/—/m/l |
| icon/primary/bold_700 | #070707 | baked into `icon_swipe.svg` |

## Implementation plan (reuse-first)
- **Icon:** new `src/assets/images/icon_swipe.svg` (54×54, fill #070707) + register in `src/assets/icons/index.ts`.
- **Button:** reuse `PillButton variant="text"` (FigmaPrimitives.tsx) — override `style={{height:56}}` (default 40) + `textStyle={{color: uacTextBase}}` (default figmaAction).
- **Overlay:** new `src/components/features/SwipeCoachMark.tsx` — RN `Modal transparent animationType="fade"` (SettingsDialog pattern), scrim View (figmaCtaLabel @ opacity .7) + centered dialog.
- **Persistence:** AsyncStorage one-time flag `@auxi/coachmark/swipe-home` (separate from `user.is_first_login`, which is already `false` by the time Home mounts). Pattern copied from `src/i18n/init.ts`.
- **Mount:** `HomeScreen.tsx` inside `home-screen-root` SafeAreaView, gated on `optionSets.length > 0` (only once there are outfits to swipe).
- **Strings:** component-level constants (HomeScreen uses no i18n; keep consistent, mark i18n-ready). testIDs: `home-coachmark`, `home-coachmark-got-it`.

## Open questions
- Scrim tap-to-dismiss? Figma shows only "Got it" → decision: scrim is inert, dismiss via button + Android back only.
- Show for pre-existing users on app update? One-time flag means yes (once). Acceptable for a gesture hint.
