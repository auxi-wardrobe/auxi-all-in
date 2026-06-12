# AU-303 — Two-Axis Home Swipe (outfit ↔ set)

**Ticket:** [AU-303](https://linear.app/duncan-1/issue/AU-303) · **Owner:** mobile-dev · **Scope:** `auxi/`
**Figma:** `0nXXMAR4Arf1ZfjtQvtBh0` node `3140-8191` (3 frames: guidance-horizontal, home-active, guidance-vertical)
**Decision (2026-05-31, CEO):** follow AU-303. Supersedes the vertical-only model in `auxi/docs/HOME_SWIPE_PLAN.md` §1.

## The bug

Current Home is **vertical-only**: each vertical swipe = next individual outfit. No horizontal axis, no
"set" navigation unit, and the existing coachmark copy ("Swipe left or right…") contradicts the actual
vertical behavior. AU-303 wants **two intentional axes** to avoid infinite scroll:

| Axis | Action |
|---|---|
| Swipe **left/right** | browse the 3 outfits *within the current set* (outfit exploration) |
| Swipe **up** | next set (3 new outfits) · swipe **down** = previous set (set exploration) |
| First-time | guidance overlay 1 (horizontal) → after 3 outfits, guidance overlay 2 (vertical) |

## Phases

| # | Phase | Status | Gate |
|---|---|---|---|
| 01 | [Figma extraction + qa-ui review](phase-01-figma-extraction.md) | ☐ | qa-ui PASS on guidance overlays |
| 02 | [Set data model (group of 3)](phase-02-set-data-model.md) | ✅ | tsc clean |
| 03 | [Two-axis gesture rework](phase-03-two-axis-gesture.md) | ✅ (code) | sim: L/R = outfit, U/D = set — sim verify → qa-mobile/qa-ui |
| 04 | [Guidance overlays + coachmark fix](phase-04-guidance-overlays.md) | ✅ | first-time shows 2 screens |
| 05 | [Reconcile 3-swipe counter + docs](phase-05-reconcile-counter-docs.md) | ✅ | context modal still fires |
| 06 | [Verification](phase-06-verification.md) | ☐ | tsc + lint + Maestro + qa-mobile |

## Key dependencies / risks

- **Model shift**: `listOutfits` (flat) → sets of 3. Prefetch (`ensureBuffer`/`TARGET_AHEAD`) and the
  unfavorited-swipe counter both key off a flat active index — both must move to a `(setIndex, outfitIndex)`
  coordinate. See phase 05.
- **Gesture lib**: current impl uses native `ScrollView` vertical snap only. 2D needs either nested
  pagers (vertical FlatList of sets, each page a horizontal FlatList of 3) or `react-native-pager-view`.
  Decide in phase 03 — prefer nested paged FlatList (no new dep) unless gesture conflict forces otherwise.
- **`HOME_SWIPE_PLAN.md` is now stale** — its §1 explicitly rejects horizontal cards. Rewrite §1 in phase 05
  so the repo's source-of-truth doc matches AU-303, or future agents will re-introduce the bug.
- **Workflow gate**: this is Figma→RN work. Phase 01 (extraction → qa-ui review) MUST pass before any code,
  per umbrella CLAUDE.md canonical workflow. No shortcutting.

## CEO decisions (2026-05-31) — locked

- **Phase 01 = PASS** (extraction + qa-ui). Overlays contain only "Got it"; the "See another / Show another"
  active-vs-inactive is the home pagination button behind the scrim, NOT inside the overlay (ticket brief
  was wrong — pm to fix wording). Overlays differ only by icon+copy → parameterize `SwipeCoachMark.tsx`.
- **Q2 trigger:** guidance overlay 2 fires **after the user views all 3 outfits** of the first set.
- **Q3 dismiss:** **"Got it" button only** (NOT tap-anywhere). Overrides ticket's "Touch every to close".
- Token drifts (scrim `#262421`@70%, inactive dot `#c6bcb1`) → route via `figma-theme-sync`.

## Out of scope (separate tickets)

Pin (AU-222), 3 modes selector (AU-221), love-collection screen (AU-226). Don't regress their existing
wiring, but don't build them here.
