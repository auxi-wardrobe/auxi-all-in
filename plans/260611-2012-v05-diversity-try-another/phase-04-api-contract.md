---
phase: 4
title: API Contract
status: completed
priority: P1
effort: 0.5d
dependencies:
  - 3
---

# Phase 4: API Contract

## Overview
Schema + docs for the axis removal. Backward-compatible deprecation: old clients keep
working, new responses carry distance trace instead of `variation_axis`. Tech-lead
sign-off required (umbrella two-repo contract rule).

## Requirements
- Functional (schemas):
  - `TryAnotherRequest.axis: Optional[VariationAxis]` → kept, documented **deprecated,
    ignored** (do not 422 old clients).
  - `TryAnotherResponse.variation_axis` → `Optional[VariationAxis]`, always `null`;
    documented for removal after mobile confirms no readers (follow-up ticket).
  - Trace additions: `min_distance` (float, served outfit's distance to nearest seen),
    `distance_floor` (float, the active floor incl. relaxation).
  - Fallback-flag vocabulary: + `relaxed_distance`, `recompose_distance_unsatisfied`;
    − `recompose_axis_unsatisfied`.
- Non-functional: response shape change is additive-or-nullable only → no mobile crash
  on old app versions.

## Architecture
No new code; this phase is schemas + 4 docs + sign-off:
1. `API_DOCUMENTATION.md` §V05 try_another (~L3857-4128): request field table, response
   examples (all 5 shapes), selection-logic steps 1-9 rewritten as the
   floor → MMR score → recompose → relaxed → terminal ladder, flag vocabulary (~L4087).
2. `docs/v05-try-another-mobile-contract.md`: §3/§4 types, §10 axis-chip pattern deleted
   (feature removed), error matrix unchanged.
3. `wardrobe-backend/CLAUDE.md` §Recommendation Engine V05: rewrite "Variation axes"
   paragraph → distance-based diversity description + new env vars table
   (V05_MIN_DISTANCE, V05_MAX_SEEN_SIGNATURES, V05_POOL_RESEED_COUNT, V05_DIST_W_*).
4. `docs/project-changelog.md` (umbrella): entry for axis → diversity pivot.

## Related Code Files
- Modify: `wardrobe-backend/schemas/v05_try_another.py` (~L18-25 enum note, ~L56-104
  request/response field docs + Optional)
- Modify: `wardrobe-backend/API_DOCUMENTATION.md`
- Modify: `wardrobe-backend/docs/v05-try-another-mobile-contract.md`
- Modify: `wardrobe-backend/CLAUDE.md`
- Modify: `docs/project-changelog.md` (umbrella repo)

## Implementation Steps
1. Schema edits + docstrings (deprecation notes inline).
2. Doc updates 1-4 above.
3. Dispatch `tech-lead` to review the contract diff (request fields kept, response
   nullable-only) — must sign off before Phase 5 starts.
4. File follow-up issue: "remove `axis`/`variation_axis` fields after mobile release
   N+1 confirms no senders/readers" (drift-prevention rule: whoever changes a route
   files the other side's follow-up).

## Success Criteria
- [ ] OpenAPI /docs renders; old-shape request with `axis:"color"` → 200, axis ignored
- [ ] API_DOCUMENTATION.md + mobile contract + CLAUDE.md consistent with shipped schema
- [ ] tech-lead sign-off recorded (PR comment or plans/reports note)

## Risk Assessment
- Hidden `variation_axis` readers (mobile/admin) → Phase 5 greps both clients before the
  field is ever removed; this phase only makes it nullable, which TS tolerates.
