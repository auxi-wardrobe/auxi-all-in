# Home Grid — Sim Smoke (item-count layouts + padding)

**Date**: 2026-06-15
**Build**: live JS via Metro (new Home layout), bundle `com.auxi2026.app` ("Macgie")
**Device**: iOS Simulator — iPhone 16 Pro (iOS 18.1), logical 402×874
**Lane**: mobile-mcp exploratory verify (state confirmation, not Figma diff)
**Scope**: Home outfit grid adapts to outfit item count + header/footer restyle

## Overall verdict: PARTIAL

2-item and 3-item layouts PASS (arrangement + padding). 4 / 5 / 6 / >6 item
outfits never appeared in the recommendation deck — DATA LIMITATION, not a bug.
The deck cycled through 5 distinct outfits (captions: Clean and simple → Just
the basics → Comfortable choice → Calm and clear → Ready for today) and stopped
advancing; every outfit in the set was composed of 2 or 3 items only.

## Counts observed

| Count | Observed | Layout verdict | Padding/gap verdict | Screenshot |
|------|----------|----------------|---------------------|------------|
| 2 | YES | PASS | PASS | /tmp/auxi-grid-2items.png |
| 3 | YES | PASS | PASS | /tmp/auxi-grid-3items.png |
| 4 | NO (not in data) | n/a | n/a | — |
| 5 | NO (not in data) | n/a | n/a | — |
| 6 | NO (not in data) | n/a | n/a | — |
| >6 | NO (not in data) | n/a | n/a | — |

## Per-count detail

### 2 items — PASS
- Outfit "Just the basics." (also "Clean and simple.").
- item0 renders FULL width at top (hero); 2nd item is a small tile CENTERED on
  the next row (pin-1 at x≈221, i.e. horizontally centered, not left-flush).
  Matches the 1–2 item rule.
- Outer horizontal padding reads tight (~12px, hero left edge ≈ x12). Confirmed
  NOT the old wide-16 look. No overflow, no clipping of the hero.
- Tile selectors present: `home-tile-pin-356d611d1570-0`, `-1`.
- Screenshot: /tmp/auxi-grid-2items.png

### 3 items — PASS
- Outfit "Comfortable choice." (also "Calm and clear.", "Ready for today.").
- 2×2 grid with the lone 3rd tile LEFT-aligned on the bottom row:
  - tile0 top-left (pin x≈156, y≈215), tile1 top-right (pin x≈347, y≈215)
  - tile2 bottom-LEFT (pin x≈156, y≈422), bottom-right slot empty
  Matches the 3-item rule exactly.
- Top-row tiles separated by a small gap (~4px); outer padding tight (~12px).
  Reads correct, not the old wide gutter.
- Tile selectors present: `home-tile-pin-ecd46a59112e-0/-1/-2` (and other ids
  per outfit). No overflow, no misalignment, no clipping.
- Screenshot: /tmp/auxi-grid-3items.png

## Header — PASS
- 44×44 white card menu button (left), weather block centered ("34.4°C" /
  "Monday", small Inter text), 44×44 white card heart button
  (`home-heart-toggle`, 44×44) right. Padding reads ~12px. Looks correct.

## Footer — PASS (with dev-build caveat)
- Footer nav exposes `home-footer-tab-grid-active` and
  `home-footer-tab-collage`, each 48×48, sitting on a cream pill behind them.
  Shorter translucent bar consistent with the spec.
- CAVEAT: a RN LogBox dev-warning toast ("Open debugger to view warnings.")
  sits pinned at the very bottom and partially covers the footer pill. This is
  a DEV-BUILD artifact (Metro warnings), NOT a layout bug. The toast is a
  native overlay not present in the accessibility tree and could not be
  dismissed via tap (its area sits over the footer; tapping risks hitting the
  footer/content). It will not appear in a release build. Footer styling is
  assessable from the visible upper portion and reads correct.

## Visual bugs found
- None. No overflow, no misalignment, no wrong gap, no crash across all
  observed outfits. Footer is partially obscured only by the dev toast
  (build artifact, see caveat).

## Method / navigation notes (for next runner + qa-ui)
- Recommendation paging: a horizontal swipe over the CAPTION/upper card area
  (y≈155–350) cycles to the next outfit. The deck is finite and looped back to
  the last outfit ("Ready for today.") after ~5 outfits.
- A horizontal LEFT swipe over a TILE (lower card area) opens the adjust sheet
  ("Thoải mái hơn" / "Phong cách khác" / shuffle / "Sửa" / Hủy / OK), NOT a
  page change — cancel with "Hủy" (x≈33, y≈642).
- "Phối lại bộ đồ này" (`home-remix`, x≈55 y≈637) navigates into the
  Canvas/Collage editor ("Thêm vào Canvas"), not a new Home grid — back with
  the top-left chevron.
- Tapping a full-width hero tile navigates into item detail (e.g. "White DRS
  (Regular)") — back with the top-left chevron.

## Recommendation
- To validate 4 / 5 / 6 / >6 layouts, seed the QA account / backend with
  outfits containing 4+ items, OR ask qa-ui to author a Maestro flow that
  drives a deterministic 5- and 7-item outfit fixture so the hero+2-stacked and
  scrolling variants can be regression-locked. mobile-mcp can't surface counts
  the recommendation data doesn't generate.

## Screenshots
- /tmp/auxi-grid-2items.png (2-item, full-width hero + centered small)
- /tmp/auxi-grid-3items.png (3-item, 2×2 with lone left-aligned 3rd tile)
- /tmp/auxi-grid-initial.png (first Home load, reference)
