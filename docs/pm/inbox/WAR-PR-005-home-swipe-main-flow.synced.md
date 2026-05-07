---
id: WAR-PR-005
type: feature
title: "[US] Home swipe main flow — Phase A/B/C (heart save, pin, mode pills)"
state: Done
priority: P1
labels: [type:feature, area:mobile, role:mobile-dev, source:pr]
source_pr: https://github.com/ducga1998/auxi-mobile/pull/5
source_repo: auxi (ducga1998/auxi-mobile)
author: ducga1998
merged_at: 2026-05-05T08:23:36Z
linear_parent_epic: AU-220
linear_subissues: [AU-221, AU-222, AU-223, AU-233]
figma_node: "909:7328"
created: 2026-05-05
---

## Context

The Home surface had no real swipe loop — users couldn't save outfits,
pin a key item, or steer recommendations toward a specific mood. This
PR ships the full Figma `909:7328` Home swipe surface end-to-end,
covering the parent epic AU-220 and three sub-issues.

Backend dependency: companion PR `wardrobe-backend#34` flips defaults to
OpenAI gpt-5-nano + v2 engine. Safe to merge ahead because `/start`
already accepts `mode` and `pinned_item_id` as optional.

## What shipped

- **Phase A (AU-223)** — real vertical swipe loop, heart save
  (`saveFavourite` → 201), per-sheet save state, 3-swipe →
  ContextChipsModal counter, prefetch on `total - 2`, button labels
  match Figma ("Show another" / "This works" / "Edit context").
- **Phase B (AU-222)** — pin badge + long-press fallback, single-pin-at-
  a-time, "Pinned: <category>" header label, action-color ring on
  pinned tile, mobile splice fallback while backend doesn't yet honor
  `pinned_item_id`.
- **Phase C (AU-221)** — Safe / Power / Creative pill row, `mode`
  threaded on prefetch (service strips when `safe`), no auto-refetch
  on mode change.
- **Service contract switch** — `valenGetRecommendation` now façades
  `/recommendation/start` (cold) + `/next` (prefetch). Backend's
  Gemini-debug `/valen-get-recommendations` had body-shape contract
  drift; production `/start` is the right path.
- **4 critical bug fixes** caught by deep code review at the phase
  seams: outfit-hash collision, mode payload drift, counter
  double-increment, programmatic-scroll seam.

## Acceptance criteria

- [x] Vertical swipe through outfits, prefetch on `total - 2`.
- [x] Heart toggle persists per sheet, calls `POST /api/favourites` (201).
- [x] Long-press a tile sets pin; only one pin at a time; ring + header
      label reflect state.
- [x] Mode pill cycle Safe/Power/Creative threads `mode` on prefetch.
- [x] 3 swipes opens ContextChipsModal (counter doesn't double-increment).
- [x] `npx tsc --noEmit` clean against baseline.
- [x] `yarn lint` baseline preserved (4 errors / 3 warnings, all legacy).
- [x] iOS sim end-to-end via mobile-mcp on iPhone 16.
- [x] Curl smoke: `/start` 200 OK with `engine_version: "v2"` + gpt-5-nano
      in backend log; `/next` 200 OK with `variation_axis: SILHOUETTE`.
- [ ] Designer sign-off on visual fidelity vs Figma `1666:9723` /
      `1711:17062` / `1666:9869` — pending.

## Out of scope

- Backend per-mode tuning — separate Linear ticket pending.
- Backend honor `pinned_item_id` (replaces mobile splice fallback) —
  Linear AU-233.
- Phase D love-collection screen — Linear AU-226.
- Mood-check screens — Linear AU-224.
- Auto-remove-bg — Linear AU-225.

## Verification

19 screenshots in `auxi/docs/screenshots/home-swipe/` covering cold-
launch, login, onboarding, Home shell, mode pill cycle, heart save,
pin set/clear, "Show another" tap. Key shots:
- `13-home-with-outfit-v2.png` — full Figma layout with v2/gpt-5-nano.
- `16-heart-saved.png` — Phase A heart save state.
- `17-pin-via-long-press.png` — Phase B pin label + ring.
