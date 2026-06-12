# Journal — V05 diversity pivot execution (260611, /cook --auto)

## What shipped

Axis-based try_another variation fully replaced by distance-based diversity in one
session. Backend: 5 commits on `feature/v05-diversity-try-another` (worktree
`worktrees/wardrobe-backend-v05-diversity`, from origin/main 1d43902):
`7671dda` distance module → `5b070e5` selection rewrite + seen_signatures →
`1624bb2` recompose ladder + reseed + LLM-3 prompt → `0957065` contract/docs →
`f5a34d7` review fixes. Mobile: `49d5f095` on auxi `feature/v05-drop-axis-plumbing`
(axis plumbing deleted — zero senders/readers confirmed). Both branches LOCAL, unpushed.

## Gates

- tech-lead contract sign-off: PASS (wire-compatible with shipped app).
- code review: 8.5 → fixes → re-review 9.5/10, 0 critical.
- Live eval vs targets: fresh 100%/≥85 · full-session 93.3%/≥80 · p95 2.40s/≤2.5s ·
  0 5xx · 0 unflagged repeats. Old axis system: 80%/75%.

## Decisions worth remembering

- Distance = 0.50·Jaccard + 0.15·silhouette + 0.15·color + 0.10·layer + 0.10·footwear;
  floor 0.35 chosen so "same outfit, different shoes" (≈0.30) is rejected by design.
- Diversity vs ALL seen (seen_signatures, cap 30) — kills A→B→A oscillation that
  single-axis diff allowed.
- Graduated ladder instead of hard exhaustion: strict → 0.5×floor (`relaxed_distance`)
  → cycle → terminal. Relaxed serves are flagged, never silent.
- Review M1 mattered: ladder worst case (~24s) outlived the 5s session lock → 30s TTL
  + token-guarded compare-and-delete release.

## Gotchas hit

- `python test_server.py` gate is broken repo-wide (app.py:320 hardcodes 5001, harness
  probes 5002) → ticket WAR-BE-01. Boot via `python3 -m uvicorn app:app --port 5002`.
- Red-main baseline is real: ~31 env-dependent pre-existing failures + gemini collection
  error; every agent had to stash-diff before/after to prove zero new failures.
- Local checkout `dev/wardrobe_project/wardrobe-backend` sits on dirty WIP branch —
  worktree-from-origin/main convention (memory) saved us.
- Analytics break: `v05_pool_insufficient` inputs swap `force_axis` →
  `min_distance`+`seen_signatures_count`; dashboard owner must be told pre-deploy.

## Deferred / open

- Multimodal 5×5 quality spot-check + LLM-judge baseline (build path unchanged → low risk).
- M-skewed eval wardrobe (pre-existing gap).
- Push + PRs pending owner decision; deploy order: backend → mobile submodule bump.
- FU-06 (remove axis wire fields after mobile N+1), WAR-BE-01 filed in pm inbox.
