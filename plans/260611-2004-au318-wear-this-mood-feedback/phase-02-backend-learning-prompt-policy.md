---
phase: 2
title: Backend Learning & Prompt Policy
status: completed
priority: P2
effort: 1d
dependencies:
  - 1
---

# Phase 2: Backend Learning & Prompt Policy

## Overview

Turn mood signals into soft preference learning and gate how often we prompt. On mood submit, map mood
tags → style axes via a static affinity map and write `V05UserStyleSignal` rows (`source='mood_feedback'`).
These ride the EXISTING engine L4 re-weight (`engine_v05.py:354-376`, `708-741`) — zero engine changes.
Add `GET /api/v05/mood-feedback/policy` returning `{should_prompt, tier}` from the user's mood-signal count
+ recency so the client knows whether to open the sheet. Weighted recency = `created_at` ordering + `decay_at`.

## Requirements

Functional:
- On mood submit (Phase 1 service hook), derive axis signals and persist `V05UserStyleSignal` rows with `source='mood_feedback'`, `confidence` per signal-strength hierarchy.
- Signal strength: wear + mood = strong (confidence ≈ 0.7); wear-only = existing outcome event (unchanged, write nothing new here); skipped modal = neutral (write nothing).
- `not_quite_me` (soft-negative) → write axis_dislike signals only (gentle), never aggressively narrows; respect existing min-confidence floor (0.3) and engine clamp `[0.5,1.5]`.
- `GET /api/v05/mood-feedback/policy` → `{ should_prompt: bool, tier: "every_save"|"frequent"|"occasional"|"contextual" }`.
- Tier thresholds v1 (KISS): `<5` active mood signals → `every_save` (always prompt); `<15` → `frequent` (always prompt); else → `occasional` (probabilistic, e.g. ~30%, + context-change trigger). `contextual` reserved for future; v1 may fold into `occasional`.

Non-functional:
- Decayed rows (past `decay_at`) excluded from both learning load and counts (matches engine's active-signal filter).
- Policy endpoint `Depends(get_current_user)`, read-only, cheap (count + max(created_at)); read rate limit (~60/min).
- Learning write must never break the save: wrap in try/except, log + continue (the favorite + mood already persisted in Phase 1). Mirror v05 outcome "never-raise" posture.

## Architecture

Affinity map (single source, `mood_affinity.py`) — mood tag → list of (axis, direction):
```python
# axes (engine_v05_layers.py:942-949): rubber_slides, loose_silhouette,
# tight_silhouette, dark_palette, bright_palette, heavy_layering
MOOD_AXIS_AFFINITY = {
  "relaxed":     [("loose_silhouette","like"), ("rubber_slides","like")],
  "comfortable": [("loose_silhouette","like")],
  "polished":    [("tight_silhouette","like"), ("rubber_slides","dislike")],
  "sharp":       [("tight_silhouette","like"), ("dark_palette","like")],
  "professional":[("tight_silhouette","like"), ("dark_palette","like")],
  "effortless":  [("loose_silhouette","like")],
  "lightweight": [("heavy_layering","dislike")],
  "elevated":    [("tight_silhouette","like")],
  "not_quite_me":[],  # handled as soft global down-weight, see step 3
  # ... map remaining vocab conservatively; unmapped tags contribute nothing (YAGNI)
}
```
Learning flow (extends Phase 1 service):
```
MoodFeedbackService.record_mood(...)            # Phase 1
  └─ after mood row saved:
       derive_axis_signals(mood_tags) -> {axis: direction}
       V05UserStyleSignalRepository.upsert(user_id, axis_likes, axis_dislikes,
                                           source='mood_feedback', confidence=0.7,
                                           decay_at=now+30d)
```
Read flow (unchanged engine): `engine_v05.py:354-376` already loads active `V05UserStyleSignal` rows into
the signal vector; `apply_signal_reweight()` (708-741) applies clamp `[0.5,1.5]`. Our rows are just more input.

Policy flow:
```
GET /api/v05/mood-feedback/policy
  → MoodFeedbackService.get_policy(user)
      n = repo.count_active_signals(user_id)
      last = repo.latest_signal_at(user_id)
      tier = every_save if n<5 elif frequent if n<15 else occasional
      should_prompt = True for every_save/frequent
                    | (n,last-based probability OR context_changed) for occasional
  ← {should_prompt, tier}
```

## Related Code Files

Create:
- `wardrobe-backend/blueprints/mood/mood_affinity.py` — `MOOD_AXIS_AFFINITY` + `derive_axis_signals()`
- `wardrobe-backend/routers/mood_feedback_policy.py` — `GET /api/v05/mood-feedback/policy`
- `wardrobe-backend/tests/test_mood_affinity.py` — affinity mapping + confidence
- `wardrobe-backend/tests/test_mood_feedback_policy.py` — tier threshold table

Modify:
- `wardrobe-backend/blueprints/mood/mood_feedback_service.py` (from Phase 1) — add `derive` + signal write, add `get_policy()`
- `wardrobe-backend/blueprints/mood/mood_feedback_repository.py` — reuse `count_active_signals`/`latest_signal_at` (added in Phase 1)
- `wardrobe-backend/models/v05_user_style_signal.py` — confirm `source` accepts `'mood_feedback'` (free str col per scout; no migration expected — verify)
- `wardrobe-backend/app.py` (or router registry) — register the policy router
- `wardrobe-backend/API_DOCUMENTATION.md` — document `GET /api/v05/mood-feedback/policy` (response shape, tiers)

Delete: none. **No edits to `engine_v05.py` / `engine_v05_layers.py`.**

## Implementation Steps

1. **Affinity map.** Create `mood_affinity.py` with `MOOD_AXIS_AFFINITY` (conservative; unmapped → no-op) and `derive_axis_signals(mood_tags) -> (axis_likes: dict, axis_dislikes: dict)`. Reuse axis names verbatim from `engine_v05_layers.py:942-949` (DRY — import a constant if one exists; else add a shared `AXES` tuple).
2. **Confidence.** Wear+mood is "strong positive" → fixed `confidence=0.7`. Respect existing floor: if a derived signal would be below 0.3 it is dropped (it won't be at 0.7, but keep the guard for future tuning).
3. **Soft-negative.** `not_quite_me` → mild global down-weight: write small `axis_dislikes` only for axes present in the outfit's context_snapshot if available, else write nothing. Never write strong dislikes — ticket: "negative feedback excessively narrows" is High-risk; clamp `[0.5,1.5]` + low confidence are the guardrails.
4. **Signal write.** In `MoodFeedbackService.record_mood`, after the mood row persists: `likes,dislikes = derive_axis_signals(mood_tags)`; if non-empty, upsert a `V05UserStyleSignal` row (`source='mood_feedback'`, `confidence=0.7`, `decay_at=now+30d`). Wrap in try/except → log, never raise (save already done).
5. **Policy service.** Add `get_policy(user)` using `count_active_signals` + `latest_signal_at`. Tier table per Requirements. For `occasional`, v1 should_prompt = simple probability (seed/rand) OR a `context_changed` flag if the caller passes recent context (optional v1 query param; default false → probability only).
6. **Policy router.** `GET /api/v05/mood-feedback/policy`, auth + read rate limit, returns `get_policy` result. Register in app.
7. **API doc + tech-lead.** Document the policy endpoint; tech-lead reviews (new public `/api/v05` surface the client depends on).

## Success Criteria

- [x] Submitting `mood_tags:["polished"]` writes one `V05UserStyleSignal` row, `source='mood_feedback'`, confidence 0.7, `decay_at≈+30d`.
- [x] Engine reflects it: a candidate on the `tight_silhouette` axis sees its multiplier shift, still within `[0.5,1.5]` (assert clamp holds).
- [x] `not_quite_me` alone never produces a multiplier below the clamp floor and never zeroes a candidate.
- [x] Decayed mood signals (force `decay_at` in past) excluded from learning load AND policy count.
- [x] `GET /api/v05/mood-feedback/policy`: new user (0 signals) → `{should_prompt:true,tier:"every_save"}`; 15+ signals → `tier:"occasional"`.
- [x] Learning-write failure (simulate repo raise) does NOT 500 the favorites save.
- [x] `pytest tests/test_mood_affinity.py tests/test_mood_feedback_policy.py` green; `pytest` part verified — pre-existing app.py port-5001 hardcode (baseline)
- [x] `git diff --stat blueprints/recommendation/` shows ZERO engine file changes.

## Risk Assessment

- **Recommendation diversity collapses from overfitting** (ticket High). Mitigations: ride existing clamp `[0.5,1.5]`; conservative affinity map (most tags map to ≤2 axes, many unmapped); fixed moderate confidence 0.7; 30-day decay sheds stale moods. No new engine math.
- **Negative feedback excessively narrows** (ticket High). Mitigation: `not_quite_me` only ever writes weak dislikes, never strong; clamp + floor bound it.
- **Emotional prompts become repetitive / decision fatigue** (ticket High). Mitigation: tier model reduces prompts as `count` grows; `occasional` is probabilistic.
- **Policy endpoint chattiness.** Mitigation: cheap query; client caches per session (Phase 4) and only refetches after submit.
