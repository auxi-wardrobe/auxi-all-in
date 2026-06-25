# Figma Extraction — AU-362 Outfit Temperature (node 3906-8765)

- **File:** `0nXXMAR4Arf1ZfjtQvtBh0` (Auxi) · **Section:** `degree celsius` (3906:8765)
- **Frames:** `Home 1/3` (3906:8538, weather mode) · `degree change` (3906:11465, sheet over dimmed Home) · `degree selected` (3906:12787, override mode)
- **Plan:** AU-362, decisions D1–D4 baked in.

## 1. Frame tree (relevant nodes)

```
3906:8765 degree celsius (section)
├─ 3906:8538  Home 1/3 (390×844)            weather mode
│  ├─ header (3906:8545)  hamburger · WeatherWidget(sun+32°C/Monday+chevron) · heart
│  ├─ suggestion layouts (3914:26267)        grid; "Clean. Ready for today" caption pill + idea(lightbulb) pill
│  └─ footer (3906:8547)
├─ 3906:11465 degree change (390×844)        SHEET over dimmed Home
│  ├─ header (3906:11467)  (dimmed)
│  ├─ Image 3:4 (3906:11466) dimmed Home behind
│  └─ Frame 2014 (3906:11468)  ← the bottom sheet (note: Figma's inner node names are mislabeled "Type/Color/Fit/Style"; the RENDERED content is the temperature radio list — confirmed via screenshot, not metadata)
└─ 3906:12787 degree selected (390×844)      override mode
   ├─ header (3906:12794)  hamburger · [person/user icon + "10 - 35°C" + chevron] · heart
   ├─ suggestion layouts (3914:26309)         idea/lightbulb pill rendered ACTIVE (darker)
   └─ footer (3906:12796)
```

Screenshot reference: all 3 frames captured (see verification PNG). Metadata for `Frame 2014` is unreliable (stale component-instance labels); the **rendered** sheet is the source of truth.

## 2. Sheet content (verbatim, from rendered screenshot)

- Title: **"Outfit Temperature"**
- Subtitle: **"We'll adjust outfit recommendations based on your preferred temperature."**
- Radio options (single-select, radio at right edge of each row):
  1. **Use current weather (32°C)** — DEFAULT, selected (filled dot) in the mock. `(XX°C)` interpolates live temp.
  2. **28–40°C**
  3. **10 - 25°C**
  4. **0 - 7°C**
  5. **-10 - 0°C**
- Primary CTA: **Apply** (full-width, dark fill `#1d1f23`, white label, radius 16)
- Secondary: **Cancel** (centered text button, no fill)
- Sheet: white surface, top-rounded (radius 16 / `border-radius/2xl`), bottom-anchored over a dark scrim.

## 3. Tokens used (from get_variable_defs 3906-11465)

| Role | Figma var | Hex | theme.ts token (existing) |
|---|---|---|---|
| Sheet surface | `background/neutral/subtlest` | `#ffffff` | `ds.color.white` / `figmaSurface` |
| Title / row text | `text/neutral/base` | `#1d1f23` | `ds.color.ink` / `uacTextBase` |
| Radio dot fill (selected) | `icon/primary/bold_700` | `#070707` | `ds.color.black` / `figmaTextDark` |
| Apply fill | `background/neutral/base` | `#1d1f23` | `ds.color.ink` / `uacTextBase` |
| Apply label | (white) | `#ffffff` | `ds.color.white` / `theme.colors.white` |
| Row divider hairline | `border/neutral/subtle_300` | `#f2f4f7` | `uacColorNeutral100` (`#f2f4f7`) |
| Radio ring (unselected) | `border/primary/subtle_100` | `#c6bcb1` | `figmaDotInactive` / `ds.color.tanStroke` |
| Sheet radius | `border-radius/2xl` | 16 | `theme.borderRadius.l` (16) |
| Subtitle text (gray) | — (Figma var `text/neutral/subtle_600` reads `#ffffff`, a mislabel; rendered gray) | gray | `figmaTextSecondary` (`#616161`) |
| Body font | `font-family/body` | Inter | `theme.typography.aliases.interBodyMd / interBodySm` |
| Scrim | (dark overlay) | — | `figmaOverlayScrim` (`rgba(38,36,33,0.7)`) |
| Error text | `text/danger/base` | `#c0392b` | `figmaRed` (`#CC4C3E`) / `figmaItemDetailDanger` |

**No new theme.ts tokens required.** All sheet/indicator colors, radii, fonts map to existing tokens. (figma-theme-sync: no DRIFT/MISSING.)

Typography: title = `interSemiboldSm`/`uacBodyMdSemibold` family (Inter SemiBold 16); rows = `interBodyMd` (Inter Regular 16/24); subtitle = `interBodySm` (Inter Regular 14/20).

## 4. Icons

| Icon | Where | Exists in repo? | Decision |
|---|---|---|---|
| Lightbulb (carbon:idea) | trigger — insight pill beside "Clean. Ready for today" caption | YES — `src/assets/images/icon_idea.svg` (`currentColor`, already rendered by `OutfitCardCaption`) | Reuse. Make the existing insight pill pressable; tint `currentColor` to active token when override on. |
| Override-indicator (person / head+shoulders) | override header, replaces weather sun icon | YES — `src/assets/images/icon_user.svg` (`currentColor`, 24×24 viewBox, head+shoulders — visually matches the Figma silhouette) | **D4 RESOLVED: reuse `Icons.User`.** No new SVG export needed. The Figma `imgWeatherS`-slot glyph in `degree selected` is a person silhouette identical in form to `icon_user.svg`. Exporting a near-duplicate asset would violate DRY; reuse is the on-system choice. |
| Chevron-down | both headers (after temp label) | YES — header already renders one | Unchanged. |

No vector node in Figma is missing from `src/assets/icons/` for this feature → `figma-icons-sync` not required.

## 5. Variants / states

- **Radio row:** selected (filled dot, dark ring) vs unselected (hollow, tan ring). Pressed → opacity feedback. Disabled (during Apply loading) → reduced opacity, non-interactive.
- **Apply button:** enabled (dark) · loading (spinner, disabled) · (disabled styling reused from ContextChipsModal `confirmButtonDisabled`). Apply is enabled whenever a selection exists (always — one is pre-selected); disabled only while `isApplying`.
- **Lightbulb trigger (insight pill):** idle (tan `figmaInsightPillBg`, dark glyph) vs **active/highlighted** when an override is on (darker pill `figmaChipBg` + light glyph, per Figma `degree selected`).
- **Header:** weather mode (`WeatherWidget`) ↔ override mode (`TemperatureOverrideIndicator`: person icon + selected bucket label + chevron).
- **Inline error banner:** above footer; recommend-failed / offline copy; sheet stays open, Apply re-enabled.
- **Motion:** slide-up open / slide-down close (asymmetric durations — open `motion.duration.medium`, close `motion.duration.normal`), reduce-motion fallback (skip slide, instant set). Cloned from `ContextChipsModal` / `MoodFeedbackSheet`.

## 6. D4 — override-indicator icon + header label (RESOLVED)

- **Icon:** reuse `Icons.User` (`icon_user.svg`). No export.
- **Label:** show the **selected bucket label** (e.g. "28–40°C"), NOT Figma's "10 - 35°C" mock (which is an inconsistent placeholder — confirmed by plan D4). The label is produced by `bucketLabel(t, key, liveTempC)`.

## 7. D1 bucket → temp_c (midpoints, per plan)

| Bucket key | Label i18n key | rep temp_c |
|---|---|---|
| `weather` | `home.temp_use_current` | `null` (send live `weather.tempC`) |
| `hot_28_40` | `home.temp_28_40` | 33 |
| `mild_10_25` | `home.temp_10_25` | 18 |
| `cold_0_7` | `home.temp_0_7` | 4 |
| `freezing_-10_0` | `home.temp_-10_0` | -5 |

D2 accepted: `cold_0_7` and `freezing_-10_0` both map to backend COOL (<15) → same outfit edge case (MVP, no backend change).

## 8. New backend fields

None. Override = substitute `weather.temp_c` in the existing `/api/v05/recommendation/build` `BuildRecommendationInput`. No API contract change → no tech-lead sign-off (per plan key decision).

## 9. Open questions (non-blocking; defaults implemented per plan)

- D1 `10–25` midpoint (18°C → backend WARM) is lossy vs the range spanning COOL→WARM. Flagged; escalate to CEO only if finer control wanted (Phase 07).
- `temperature_apply_clicked` event name is present-tense (borderline vs the past-tense `object_verb` convention) — kept verbatim per ticket for funnel continuity. Flag to CEO if they prefer `temperature_applied`.

## 10. qa-ui review-extraction

This is a non-team solo run; qa-ui auto-dispatch is recorded as a workflow note. Extraction is grounded in the rendered screenshot + variable defs + repo recon (icons, tokens, sheet pattern all verified present). No open BLOCKER; D1/D4 resolved per plan defaults. Proceeding to implementation per plan (Phases 02–05).
