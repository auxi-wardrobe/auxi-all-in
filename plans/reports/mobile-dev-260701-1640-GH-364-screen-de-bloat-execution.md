# Mobile Screen De-bloat — Execution Report

**Date:** 2026-07-01 · **Plan:** `plans/260701-1448-GH-364-mobile-screen-refactor/` · **Branch:** `refactor/au364-screens-integrated` (auxi, off origin/main, LOCAL — not pushed)
**Source scan:** `plans/reports/review-260701-1435-GH-364-mobile-screen-code-health.md`

## Outcome

Behavior + visual-preserving de-bloat of 6 of the 7 God-screens, executed by 5 parallel `mobile-dev` agents in isolated git worktrees, merged clean into one branch.

| Screen | Before | After | Δ | Notes |
|--------|-------:|------:|--:|-------|
| HomeScreen/index.tsx | 1767 | 1444 | −18% | 6 extractions; 3 core hooks deferred → SIM-QA |
| OutfitCanvasScreen.tsx | 1667 | 837 | −50% | 8 extractions; exit-guard deferred → SIM-QA |
| ItemDetailScreen.tsx | 1407 | 731 | −48% | 4 extractions; useItemDetail (mutations) left inline → SIM-QA |
| BodyScreen.tsx | 1016 | 436 | −57% | 6 extractions; useBodyTryOn left inline → SIM-QA |
| WardrobeScreen.tsx | 1044 | 573 | −45% | 8 extractions incl. 2 verbatim hooks → SIM smoke |
| see-this-on-me/SeeThisOnMeScreen.tsx | 757 | 601 | −21% | 3 extractions; reducer + syncHook deferred → SIM-QA |
| **Total** | **7658** | **4622** | **−40% (−3036)** | into **40 new files** (<200 lines each, a few single-responsibility ~211–232) |

- **35 granular commits** (one per extraction) + 4 merge commits = 39.
- **tsc: 11 → 7** — actually IMPROVED main: fixed HomeScreen's 4 pre-existing errors (dead `AI_NOTICE_DISMISSED_KEY` import + 3 missing `refineToast*` styles). Remaining 7 are pre-existing red-main baseline in untouched files (DatabaseScreen 1, SettingsScreen 1, notificationService 5).
- **ESLint clean** on all new files. **Every `track()` call preserved** (verified per screen: Home 22, Wardrobe 16, Body 6, etc. — counts unchanged vs main).
- **4 branches merged with ZERO conflicts** (each phase touched a disjoint screen dir).

## Method / safety posture

- Each phase ran in its own worktree off `origin/main`; disjoint files → clean integration.
- **Pure extraction only** — no visual changes, no primitive swaps, no routing changes. Everything that would alter rendered pixels/animation/navigation was deferred to a gated pass (below).
- **Risky state-machines**: agents extracted only when confidently behavior-preserving as verbatim moves; anything needing runtime observation to be sure was LEFT INLINE + flagged (no sim available this session — shared Metro/sim singletons + concurrent sessions).
- One agent (Phase 03) stalled after 4 good commits; its uncommitted leftover was **pure prettier reformatting** (verified line-by-line) → discarded, branch clean.

## NOT done — deferred, with reasons

**Phase 05 (SettingsScreen) — DEFERRED entirely.** Collides with active `feature/settings-ia-redesign` (IA being redesigned). Refactoring the current structure = wasted work. Do after that lands, or fold into it.

**Phase 08 (cross-file dedup) — FOLLOW-UP.** Photo-source sheet 3→1 on `MActionSheet` and try-on pipeline unification are both visual/behavior changes → gated + sim pass.

**Deferred core state-machines (need SIM-QA before merge):**
- Home: `useOutfitFeed` / `usePinnedOutfit` / `useTemperatureFlow` (trampoline-ref restructure of the recommendation core).
- Canvas: `useCanvasExitGuard` (nav-lifecycle `beforeRemove` state machine).
- ItemDetail: `useItemDetail` (fetch + 3 optimistic mutations + rollback) — left inline.
- Body: `useBodyTryOn` (submit + poll) — left inline.
- SeeThisOnMe: `useReducer` migration (18 useState) + `useTryOnStepSync`.

**DS-primitive migrations (separate designer/qa-ui gated pass — visual):** raw `Modal`→`MBottomSheet`/`MActionSheet` (ItemDetail picker, Body photo-source + lightbox, Wardrobe processing overlay); `TouchableOpacity`→`MButton`; status pills→`MChip`; legacy `PillButton`/`TopIconButton`→`M*`.

## Verification status

- ✅ Mechanically verified: tsc (7, better than main's 11), ESLint clean, all track() preserved, clean merges.
- ⚠️ NOT runtime-verified: no simulator this session. The verbatim hook moves (Canvas history/add/persist, Wardrobe upload/snackbar) and all screens want a **qa-mobile smoke** before any merge to main — priority paths: canvas discard-guard, wardrobe upload→ready-snackbar, home feed/pin/temp (though those hooks were left inline, the surrounding JSX moved).

## Next steps

1. **qa-mobile smoke** on `refactor/au364-screens-integrated` (sim-capable session) — the 6 screens' core flows.
2. Push branch + open PR (not done yet — awaiting go-ahead). PR must NOT merge before step 1.
3. Schedule the deferred core-hook extractions + DS-migration as their own gated tickets.
4. Sequence Settings (phase 05) after `settings-ia-redesign` lands.

## Unresolved questions

1. Confirm `FigmaPrimitives` (PillButton/TopIconButton) is legacy → migrate to `M*` (assumed).
2. Push + open PR now, or hold for local review first?
3. Mirror deferred items as Linear tickets via `pm`?
