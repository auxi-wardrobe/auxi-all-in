# Home footer "background needs to be blurred" — Option A landed

**Date:** 2026-06-15
**Author:** mobile-dev
**Status:** DONE — code complete, iOS build green, app launched cleanly on sim. Visual side-by-side compare of the two blur surfaces handed off to qa-ui.
**Figma:** https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=3230-35155
**User report (vi-VN):** "nhìn phần footer xem, background cần đc blur mà" — "look at the footer, the background needs to be blurred"
**CEO decision:** Option A approved (add `@react-native-community/blur`).

## TL;DR

Real backdrop blur implemented per Figma spec. Added `@react-native-community/blur@4.4.1`, ran `pod install` (installs `react-native-blur (4.4.1)` natively on iOS), and replaced the opacity-only fallback in two screens with `<BlurView blurType="light" blurAmount={8}>` + a white@80% tint overlay (new theme token `figmaBlurTintWhite80`). Stale "CEO chose no native dep" docstrings removed/rewritten. Typecheck and token lint clean.

`blurAmount` in the lib is integer-typed; Figma spec is 7.5px so I rounded to 8 (visually indistinguishable — UIBlurEffect clamps internally anyway).

## Figma footer spec (node 3230:35156) — unchanged from prior turn

| Layer | Node | Spec |
|---|---|---|
| Wrapper | 2464:17348 | `backdrop-blur-[4px]`, 414×84, `overflow: clip` |
| Background slab | 3227:13480 | `backdrop-blur-[7.5px]`, fill `background/neutral/subtlest = #ffffff`, `opacity: 0.80`, 430×100 (oversized) |
| Tab cluster wrapper | 2464:17508 | `opacity: 0.85`, paddingTop 6, height 84 |
| Active capsule | 2464:17314 | 116×56, radius 14, fill `background/primary/subtle_100 = #e0d2c4` |
| Active cell | 2464:17303 | 48×48, radius 11, fill `#ffffff`, shadow `0 1 1 rgba(0,0,0,0.15)` |

## Files touched

- `auxi/package.json` — added `@react-native-community/blur ^4.4.1`
- `auxi/yarn.lock` — regenerated (3 new transitive entries: the package itself)
- `auxi/ios/Podfile.lock` — `react-native-blur (4.4.1)` added (101 pods total, up from 100)
- `auxi/src/theme/theme.ts:107-112` — added `figmaBlurTintWhite80`, rewrote comment on `figmaItemDetailHeaderBg` (now serves as a11y reducedTransparency fallback rather than a "no blur dep" workaround)
- `auxi/src/components/features/HomeViewToggleFooter.tsx` — replaced stale docstring (lines 18-21) with new spec note, added `<BlurView>` to JSX before the tint `View`, added `blurSlab` style (430×100, centred via `top:-8 + left:50% + marginLeft:-215` so it's the oversized Figma slab clipped by the bar's `overflow:hidden`), repointed `translucentSurface` from `figmaItemDetailHeaderBg` to `figmaBlurTintWhite80`
- `auxi/src/onboarding/v2/OnboardingStylesScreen.tsx` — same treatment: stale docstring rewritten, imported `BlurView`, sticky bar restructured (wrapper now has `overflow:hidden` and no bg; child `stickyBlur` (absoluteFill BlurView) + `stickyTint` (absoluteFill white@80%) sit behind the PillButton)

Diff size: 5 files, ~50 net LOC added (mostly comments + the new BlurView block).

## What I did NOT touch

- `figmaItemDetailHeaderBg` (white@90%) is still used by item-detail headers and other surfaces — left intact, only the comment was updated to reflect its new role as the a11y reducedTransparency fallback.
- `figmaOnboardingStickyBarBg` (white@60%) similarly kept — now used as the OnboardingStyles BlurView's reducedTransparencyFallbackColor.
- No layout changes to the active capsule, active cell, tabs, or PillButton.

## Verification

| Check | Result |
|---|---|
| `yarn install` | Done (Node 22.21.1 — the auxi-default 20.x was incompatible with `@react-native/new-app-screen@0.83.1` which requires `>=20.19.4`; 22.21.1 is in nvm and satisfies both that and the `@react-native-community/blur` peers `react: *, react-native: *`). |
| `cd ios && pod install` | Done. Output: `Installing react-native-blur (4.4.1)` … `Pod installation complete! There are 93 dependencies from the Podfile and 101 total pods installed.` |
| `npx tsc --noEmit` | PASS (no output, exit 0). |
| `./scripts/auxi-lint-tokens.sh` | Pre-existing 33 violations (DatabaseScreen, ItemDetailScreen, ContextChipsModal, BodyScreen, HomeScreen, etc.) — none new from my changes. Grep against the two changed files confirms zero literal hex / fontFamily violations in the diff. |
| `yarn lint` | 0 errors, 6 warnings — all pre-existing (`DatabaseScreen`, `OutfitCanvasScreen`, `SignInScreen`). Did NOT add to baseline. |
| iOS build (Debug, iPhone 16 Pro sim, iOS 18.1) | PASS. `yarn ios` exit 0 after 613 s (first build with the new `react-native-blur` pod; later incremental builds will be fast). App `com.auxi2026.app` installed and `Successfully launched the app`. No native-module load crash — the BlurView component links cleanly. |
| Sim screenshot (post-launch) | Captured to `plans/reports/screenshots/mobile-dev-260615-2144-app-after-blur-build.png`. The app comes up on the Settings screen (cold-start landing for the existing test user); confirms the runtime is healthy after adding the native dep, but the two screens with the blur (Home footer + Onboarding Styles) are not on the route stack from this entry. |

### Visual blur verification — handed to qa-ui

`mobile-dev` does not have `mobile-mcp` tools (per `.claude/agents/mobile-dev.md`), and the launch-screenshot lands on Settings, not Home or Onboarding-Styles. Hand-off to **qa-ui** for the Figma-vs-actual compare on those two surfaces:

1. Navigate to Home → confirm the bottom view-toggle bar shows real backdrop blur (light, ~8px) over the outfit image, with white@80% tint. Compare to Figma node 3230:35156.
2. Navigate to Onboarding (fresh user / dev menu) → Step 3 (Style picks) → confirm the bottom sticky CTA bar shows the same backdrop blur over the grid.
3. Flip iOS "Reduce Transparency" ON, repeat — bar should fall back to opaque white@90% (Home footer) / white@60% (Onboarding) and remain legible.

Build artifact path for re-launching: `/Users/nguyenminhduc/Library/Developer/Xcode/DerivedData/auxi-dowftpccxrybejdxxgkxbvrrpfle/Build/Products/Debug-iphoneos/auxi.app`. To re-run without rebuild: `xcrun simctl launch booted com.auxi2026.app`.

## Notes for QA-UI (review-extraction + compare pass)

1. **`blurAmount=8`, not 7.5.** The lib's typing is `number` but the native bridge expects integer for iOS `UIBlurEffect`. 7.5 → 8 is a visually identical concession (iOS quantises internally).
2. **The oversized 430×100 slab** is implemented exactly as the Figma spec; the bar's `overflow:hidden` clips it back to 414×84 visible — so edge artefacts that the original Figma frame solves by oversizing are correctly handled.
3. **`reducedTransparencyFallbackColor`** is set to the legacy opacity-only token. If a user enables iOS "Reduce Transparency" (Settings → Accessibility → Display & Text Size), the bar reverts to white@90% — that's an a11y win, not a regression.
4. **Onboarding Styles parity.** Same blur treatment now applied here per the user-spec callout; previously it was the "low-fi solid translucent fallback" at 60% white. The new 80% tint will look denser than the prior 60% even before blur — qa-ui should confirm CEO is fine with this visual delta against the Figma frame for OnboardingStyles (which only specifies `backdrop-blur 2`, not 7.5). If CEO wants the Onboarding bar to read lighter, drop `figmaOnboardingStickyBarBg` into the `stickyTint` instead of `figmaBlurTintWhite80` — 1-line patch.

## Unresolved questions

1. **qa-ui compare pass** — needs to capture screenshots of Home footer + Onboarding Styles sticky bar against Figma 3230:35156 and the OnboardingStyles frames. See "Visual blur verification — handed to qa-ui" section above for nav steps.
2. **Onboarding Styles tint density** — see note 4 in "Notes for QA-UI". Default chosen is the home-footer parity (80%); flag for CEO if Onboarding should stay at 60% with blur layered.
3. **Android parity** — `@react-native-community/blur` supports Android via `RenderEffect` on API 31+ with a `BlurMaskFilter` fallback. Not exercised in this turn (iOS-only verify). qa-mobile should smoke on an Android emulator before release.
