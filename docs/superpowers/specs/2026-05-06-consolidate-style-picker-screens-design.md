# Consolidate style picker screens — design (PAUSED)

**Date:** 2026-05-06
**Status:** ⏸ Paused mid-design — implementation NOT started
**Linear parent:** [AU-71 Gamified Style Swipe](https://linear.app/duncan-1/issue/AU-71/us-03-gamified-style-swipe) · child: [AU-124](https://linear.app/duncan-1/issue/AU-124/integrate-swipe-flow-with-backend-apis)
**Owner on resume:** Đức (mobile)

## TL;DR

AU-71 as written specifies a Tinder-style swipe deck for style onboarding. Brainstorm pivoted: the modern, accessible pattern is a **vertical scroll feed of outfit cards with Love / Skip per card**, mapping to the existing `user_metadata.style_direction` enum (UI-only swap, no backend change). One open product question blocks subtask creation.

## Background

Three onboarding flows surfaced during discovery, only one of which actually exists in HEAD:

| | Flow | Reality |
|---|---|---|
| **A** | `Welcome → LocationPermission → GenderPreference → StylePreference (3-option grid: Slim / Classic / Relaxed) → Home` | ✅ Live in production. `StylePreferenceScreen.tsx` saves `user_metadata.style_direction = "more_polished" \| "stay_balanced" \| "more_relaxed"` via `completeOnboarding()`. |
| **B** | "Onboarding redesign": `PreferenceSeed → FitPreference → OutfitApproval → OnboardingConfirmation` | ❌ Does **not** exist. `auxi/CLAUDE.md` claims the screens are committed but `find auxi -name "*PreferenceSeed*" -o -name "*OutfitApproval*"` returns nothing. **Stale doc — fix on resume.** |
| **C** | AU-71's Tinder-style swipe deck | ❌ Not started. AC describes left/right swipe + AU-124 references endpoints (`GET /api/v1/onboarding/style-cards`, `POST /api/v1/users/style-preferences`) that don't exist in `wardrobe-backend/API_DOCUMENTATION.md`. |

The recommendation engine reads only `style_direction` (single enum). Per-item `style_tags` and per-session `style_feedback` exist for items/sessions but not for users.

## Decisions locked

### D1 — UX pattern: vertical scroll feed (not Tinder swipe)
Rationale: scroll is the dominant 2026 pattern (Pinterest, Instagram Shop). Hidden-affordance left/right swipe is dated, accidental, inaccessible. User feedback: *"scroll instead of swipe right or left as tinder, it more makes sense."*

### D2 — Data model: Option A — UI-only swap
Each outfit card is **pre-tagged with one of the 3 existing `style_direction` values**. User taps Love or Skip per card; we tally loves per direction and write the winner via the existing `completeOnboarding()` path. **Zero backend change. Same contract.**

Rejected:
- **Option B (multi-tag preference vector)** — requires new user field, new endpoint, recommendation-engine adaptation. Premature without evidence the 3-bucket model is too coarse.
- **Option C (gamification only, data discarded)** — wastes the signal.

## Open questions (must answer before subtask breakdown)

### Q1 — Placement: replace, insert before, or insert after the 3-option grid?
- **(1) Replace** ✅ recommended. Scroll feed *is* the style picker; `StylePreferenceScreen` deleted. One source of truth, shorter onboarding.
- **(2) Insert before** the grid (scroll feed seeds → grid confirms). Two-step capture, more forgiving.
- **(3) Insert after** the grid. Almost certainly drops conversion — extra screen for no real gain.

**Awaiting product decision.** Brainstorm paused here.

### Q2 — Skip semantics in scroll context
Tinder swipe has an explicit Skip button (AU-71 AC: "Skip → assign Basic default"). In a scroll feed, the user can simply scroll past every card without tapping Love. Decision needed:
- Treat scroll-past-without-Loving as Skip (= assign default `stay_balanced`)?
- Require an explicit "I'm done" button at the end?
- Auto-advance once N loves are recorded?

### Q3 — Card count + asset source
AU-71 says 5–10 cards. Need to decide:
- Exact count (8 is conventional for Tinder onboarding; scroll feed can carry more without fatigue, maybe 12–15).
- Where do the outfit images come from? Static bundled assets per `style_direction`? Or fetched from backend (which would require a new endpoint after all)?
- Cards must be filtered by gender (per AU-71 AC).

### Q4 — Tally tie-breaker
If loves are tied (e.g., 3 polished, 3 balanced), what wins? Suggested precedence: `stay_balanced > more_relaxed > more_polished` (favor the safer default).

## Out of scope (this round)

- ❌ Multi-tag preference vector (defer until single-direction signal is proven inadequate).
- ❌ Backend `/api/v1/onboarding/style-cards` endpoint — only needed if we ever go to multi-tag.
- ❌ Backend `/api/v1/users/style-preferences` endpoint — same.
- ❌ "Calculating your style…" loader screen logic (AU-124 spec) — optional polish; cheap to add post-MVP.
- ❌ Resume-mid-onboarding state (AU-124 edge case) — most users complete in one sitting; defer.

## Linear cleanup (do on resume)

1. **AU-71** — rewrite AC. Current AC describes Tinder swipe; should describe vertical scroll feed with Love/Skip per card, tallying to existing `style_direction`.
2. **AU-124** — rewrite or close. AC references two backend endpoints that don't exist. Under Option A this child becomes a small UI-only "tally and call `completeOnboarding`" task, not a backend wiring task. Likely consolidate into AU-71 once subtasks are written.
3. **`auxi/CLAUDE.md`** — remove the "Active work / known unfinished" entry that claims `PreferenceSeed → FitPreference → OutfitApproval → OnboardingConfirmation` screens exist. They don't.

## Resume protocol

When picking this back up:
1. Get product decision on **Q1** (placement). The other 3 questions can be brainstormed inline.
2. Write subtasks under AU-71 in Linear (UI build, asset prep, copy, navigation wiring, tally logic, gender filtering, testID coverage, Maestro flow).
3. Update AU-71 AC + close AU-124 (or fold into a sub-issue).
4. Hand off to `mobile-dev` agent. No backend work needed.
5. QA via `qa-ui` (Figma compare if AU-55 designs are ready) + `qa-mobile` (Maestro flow execution).

## Estimate (rough, post-product-decision)

Under Option A + Q1=(1) Replace:
- UI build: 1–2 days (scroll list of `OnboardingSelectionCard` variants + Love/Skip buttons)
- Asset prep: depends on AU-55 (Figma) — could be 0 days if Việt has cards ready, ~1 day if we need to commission them
- Tally logic + navigation wiring: 0.5 day
- Maestro flow + tests: 0.5 day

**Total: 2–3 days end-to-end** assuming assets are ready.

Compared to AU-124's original spec (full backend integration): we're saving ~1 week of stack work for the same MVP outcome.
