# Phase 04 — Guidance overlays + coachmark fix

**Priority:** P1 · **Status:** ☐ · **Agent:** mobile-dev · **Depends on:** phase 01 (extraction PASS), phase 03

## Goal

Two first-time guidance overlays per AU-303, replacing/extending the existing single `SwipeCoachMark`.

| Overlay | When | Copy | Icon | "See another" state |
|---|---|---|---|---|
| 1 — horizontal | first time Home shows outfits | "Swipe left or right to explore different outfit options." | hand-swipe-horizontal | inactive |
| 2 — vertical | after the user finishes exploring 3 outfits (1 full set) | "Swipe up to explore another outfit set. Swipe down to go back." | hand-swipe-up | active |

Both: centered white card, dimmed backdrop, "Got it" CTA, **tap-anywhere to dismiss** (ticket: "Touch
every to close"). Persist dismissal per overlay in AsyncStorage.

## Current state

- `SwipeCoachMark.tsx` exists, single overlay, key `@auxi/coachmark/swipe-home`, copy already says
  "Swipe left or right…" — but currently fires over a vertical-only screen (wrong). Reuse/generalize it.

## Design

1. Generalize `SwipeCoachMark` to accept `{ variant: 'horizontal' | 'vertical', copy, icon, storageKey }`
   OR add a second instance. Prefer one parameterized component (DRY).
2. Storage keys: `@auxi/coachmark/swipe-outfit` (overlay 1), `@auxi/coachmark/swipe-set` (overlay 2).
   (Migrate/retire the old `swipe-home` key — overlay 1 supersedes it; reset so existing users see the
   corrected first-time flow once. Confirm with PO whether to force re-show.)
3. Trigger overlay 1 when `sets.length > 0` and key1 unset.
4. Trigger overlay 2 when the user has viewed all 3 outfits of set 0 (track `outfitIndex` max reached == 2,
   or "completed 3 outfits") and key2 unset. Exact trigger pinned in phase 01.
5. Icons: hand-swipe SVGs from Figma (`figma-icons-sync`, `currentColor` convention). Add to
   `src/assets/icons/` if missing.
6. Copy lives in config (not inline) per auxi conventions — add to onboarding/config or a coachmark
   copy map; lift to i18n later.

## testIDs

- `home-coachmark-horizontal`, `home-coachmark-vertical`
- `home-coachmark-dismiss-horizontal`, `home-coachmark-dismiss-vertical`

## Todo

- [x] Parameterize SwipeCoachMark (variant/copy/icon/key) — single component, `variant: horizontal|vertical`, copy in `VARIANT_CONFIG`
- [x] Wire trigger conditions to phase-02/03 state — H: `sets.length>0`; V: `verticalCoachArmed` (after all 3 of set 0 viewed)
- [x] Add hand-swipe icons (export from Figma if missing) — exported `icon_swipe_up.svg` (node 3140:9902, currentColor, 54×54); `icon_swipe_hand.svg` reused for H
- [x] **"Got it"-only dismiss** (NOT tap-anywhere) + per-overlay AsyncStorage persistence — keys `@auxi/coachmark/swipe-outfit` + `@auxi/coachmark/swipe-set`
- [x] Retire old `swipe-home` key on mount (CEO: existing users see corrected flow once)
- [x] No new hex/font drift in touched files (token-lint script targets main worktree path; my diff introduced zero literals — verified by grep)

> CEO override applied: dismiss = **"Got it" button only** (not tap-anywhere).
> Copy in `VARIANT_CONFIG` (vertical = two text nodes; line 2 "Swipe down to go
> back" has NO trailing period per Figma).

## Success criteria

- Fresh install: overlay 1 on first outfit view; overlay 2 after first full set explored; neither re-shows
  after "Got it" / tap dismiss.
- Copy + icon + card match Figma (qa-ui Compare Pass 2/3 in phase 06).

## Next

Phase 05 reconciles the swipe counter / context-modal with the new two-axis model.
