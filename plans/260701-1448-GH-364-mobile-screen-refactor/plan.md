# Mobile Screen Refactor — De-bloat auxi/src/screens

**Created:** 2026-07-01 · **Source report:** `plans/reports/review-260701-1435-GH-364-mobile-screen-code-health.md`
**Goal:** bring the 7 God-screens (50% of all screen code) under the project's 200-line rule via additive, behavior-preserving extraction. No redesign.

> ✅ **EXECUTED 2026-07-01** — branch `refactor/au364-screens-integrated` (LOCAL). 6/7 screens de-bloated: **−40% (7658→4622 lines)** into 40 new files, 35 commits, **tsc 11→7** (improved main). Phase 05 deferred (settings-ia-redesign collision), Phase 08 = follow-up. Execution report: `plans/reports/mobile-dev-260701-1640-GH-364-screen-de-bloat-execution.md`. Deferred core hooks + DS-migration need sim-QA before merge.

## Why
`screens/` = ~17.4k lines, 34/56 files >200. Seven files = 8,621 lines. Symptoms: God-components (API+state-machine+JSX fused), state sprawl (Home 22 useState/33 ref/22 effect), in-file duplication, raw RN primitives where `M*` exists, 3 parallel primitive families.

## Global conventions (apply to EVERY phase)
- **One screen per PR. Additive only — zero behavior change.** Extraction, not rewrite.
- Every new file **< 200 lines**. Hooks → `<screen>/hooks/`, components → `<screen>/components/` or `screens/<feature>/`.
- **Target `M*` primitives** (canonical per `design-system-primitives-required.md`). `FigmaPrimitives` (PillButton/TopIconButton) = legacy → migrate opportunistically, don't block on it. ← *decision #1, override here if wrong.*
- **Preserve all `track()` calls** (`analytics-tracking-required.md`) — move them with the code, don't drop.
- Per-PR gates: `npx tsc --noEmit` · `./scripts/auxi-lint-tokens.sh` · `auxi/scripts/auxi-lint-ds-primitives.sh` · archive build. Pure refactor ⇒ qa-ui/designer gate only if any pixel moves (shouldn't).
- Land on a branch off `main`; do NOT touch native/build (hot-reload only).

## Phases (ordered P0→P3)

| Phase | Screen | Lines | Prio | Status | Target |
|-------|--------|------:|:----:|:------:|-------:|
| [01](phase-01-home-screen.md) | HomeScreen/index.tsx | 1709 | P0 | 🟡 partial (1444; 6 extractions done; 3 core hooks → SIM-QA) | ~280 |
| [02](phase-02-outfit-canvas.md) | OutfitCanvasScreen.tsx | 1555 | P0 | ✅ done (1667→837, 8 commits; exit-guard → SIM-QA) | <200 shell |
| [03](phase-03-item-detail.md) | ItemDetailScreen.tsx | 1407 | P1 | ✅ done (1407→731, 4 commits; useItemDetail inline → SIM-QA) | ~250 |
| [04](phase-04-body-screen.md) | BodyScreen.tsx | 1016 | P1 | ✅ done (1016→436, 6 commits; useBodyTryOn → SIM-QA) | <200 |
| [05](phase-05-settings-screen.md) | SettingsScreen.tsx | 1133 | P1 | ⛔ DEFERRED — collides with active `feature/settings-ia-redesign` (IA being redesigned; refactoring current structure = wasted) | ~300 |
| [06](phase-06-wardrobe-screen.md) | WardrobeScreen.tsx | 1044 | P2 | ✅ done (1044→573, 8 commits; upload/snackbar hooks done → SIM smoke) | ~350 |
| [07](phase-07-see-this-on-me.md) | SeeThisOnMeScreen.tsx | 757 | P2 | ✅ done (757→601, 3 commits; reducer+syncHook → SIM-QA) | <300 |
| [08](phase-08-cross-file-dedup.md) | Cross-file dedup | — | P3 | 📋 FOLLOW-UP (not executed — DS-migration + pipeline-unify = visual/behavior change → gated + sim-QA pass) | 3→1 sheet, 1 try-on pipeline |

**Ordering rationale:** P0 = biggest + most-edited (stop the growth first). P1 = high line-count + clear DS violations. P2 = already partly migrated / healthier. P3 = architectural dedup, do last (needs P04/P07 landed).

## Dependencies / sequencing
- Phases 01–07 are **independent** — the target hooks/components don't exist yet, so no merge contention. Parallelizable across sessions if file ownership is disjoint (it is — each phase owns one screen dir).
- Phase 08 depends on **04 + 07** (photo-sheet consolidation touches Body + SeeThisOnMe; try-on pipeline unification needs both landed).

## Open decisions (non-blocking)
1. `FigmaPrimitives` legacy vs keep? → plan defaults to migrate-toward-`M*`. **Confirm.**
2. `SettingsSwitch` (wraps raw `Switch`) — retire for `MSwitch`? (phase 05)
3. Wardrobe AI-processing raw `Modal` — migrate to `MBottomSheet`? (phase 06)
4. ItemDetail exported helpers ("for tests") — check test imports before relocating (phase 03).
5. Legacy `_HomeScreen.tsx` — shared blocks? de-dupe or confirm deletion first (phase 01).

## Not doing (YAGNI)
- No visual/UX redesign, no new features, no token re-theming.
- `collage-seed-layout.ts` (623) left as-is — pure, cohesive, healthy despite length.
- Auth screens (250–556) deferred — smaller, lower blast radius; revisit after top 7.

## Follow-up (optional, needs your OK — outward-facing)
Mirror these 8 phases as Linear tickets via `pm` agent. Not done yet — confirm before I create external tickets.
