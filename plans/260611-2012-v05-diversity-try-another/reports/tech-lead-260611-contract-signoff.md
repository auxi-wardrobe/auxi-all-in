# Tech-lead contract sign-off — V05 axis→diversity pivot (Phase 4 gate)

**Verdict: PASS** — backend branch `feature/v05-diversity-try-another`
(7671dda, 5b070e5, 1624bb2, 0957065) is contract-safe for the current
shipped auxi app and the admin tester. Mobile sync may proceed.

## Evidence

### 1. Backward compatibility — PASS
- Shipped auxi sends NO `axis`: `auxi/src/screens/HomeScreen.tsx:608`
  calls `recommendV05` without it; `v05Api.ts:656` only forwards `axis`
  when a caller passes it — no caller does.
- `variation_axis` is typed non-null at `auxi/src/services/v05Api.ts:384`
  but NEVER read at runtime (grep: only the type declaration) → always-null
  wire value cannot break the deployed app. Type fix lands in mobile sync.
- Admin tester `axis: null` → `Optional[VariationAxis]` accepts
  (`schemas/v05_try_another.py:75`). Valid enums accepted-then-ignored
  (`services/v05_try_another_service.py:215-221`); invalid still 422
  (pydantic validation unchanged). Verified by
  `test_explicit_axis_param_ignored` (green).
- New `fallback_flags` values (`relaxed_distance`,
  `recompose_distance_unsatisfied`) are additive strings in an opaque
  list; mobile only string-matches `variations_cycled` → safe.

### 2. Schemas vs docs — CONSISTENT
- `schemas/v05_try_another.py`: `axis` `deprecated=True` (75-86);
  `variation_axis` Optional + deprecated, default None (104-116). All four
  response constructors hardcode `variation_axis=None`
  (`v05_try_another_service.py:331,353,1035,1086`).
- `schemas/v05_recommendation.py:201-234`: `trace.min_distance`,
  `trace.distance_floor`, `trace.seen_signatures_count` — nullability rules
  match `API_DOCUMENTATION.md:4035-4043` and
  `docs/v05-try-another-mobile-contract.md:148-157`.
- `API_DOCUMENTATION.md:3887-4397` (committed in 0957065): examples all
  show `variation_axis: null`; flags vocabulary table complete;
  `recompose_axis_unsatisfied` explicitly retired (4277-4278);
  `llm3_call.fallback_reason` includes `distance_unsatisfied` (4141).
- Analytics swap confirmed: `engine_v05.py:320-328` emits `min_distance` +
  `seen_signatures_count` in `v05_pool_insufficient` inputs; `force_axis`
  gone from non-test code.
- Env knobs: `config.py:100-107` (`V05_MIN_DISTANCE`,
  `V05_MAX_SEEN_SIGNATURES`, `V05_POOL_RESEED_COUNT`); `V05_DIST_W_*` read
  at import in `engine_v05_distance.py:64-68`; `V05_RECOMPOSE_RESEED_CAP`
  no longer read anywhere.

### 3. Selection ladder vs mobile error matrix — COVERED
Floor → MMR → recompose strict → relaxed (+flag) → cycle → terminal: every
rung surfaces as a 200 shape on fields the deployed client already handles
(`fallback`, `cycled`, `wardrobe_gap`). 410/422/429 semantics unchanged
(`API_DOCUMENTATION.md:4367-4387` = contract doc §5 table). No new
contract-visible error state.

### 4. Deprecation path — REASONABLE
Accepted-ignored now; removal of `axis` + `variation_axis` + `VariationAxis`
enum deferred to a follow-up after mobile release N+1 confirms no
senders/readers. Matches umbrella submodule discipline (backend deploy →
mobile pin/sync → removal).

### Test gate
- Targeted contract tests green: 47/47
  (`test_v05_try_another_endpoint/service/distance_unit`).
- Full suite: 47 failures + 1 collection error (`test_gemini_service.py`)
  are **byte-identical to the base commit 1d43902** (per-test-ID diff:
  IDENTICAL FAILURE SETS) — pre-existing red-main baseline (AU-321/AU-322).
  **Zero NEW failures.**

## Findings (non-blocking)

| Sev | Finding | Owner |
|---|---|---|
| major (mobile-sync scope) | `v05Api.ts:384` `variation_axis: VariationAxis` must become `VariationAxis \| null`; drop/deprecate `axis` on `TryAnotherInput`/`RecommendV05Params`; analytics `try_another_succeeded` switches `variation_axis` → `trace.min_distance`+`distance_floor` per contract §10 | mobile-dev |
| minor | Stale axis-era comments in `v05Api.ts:314,340-343,503` — clean during sync | mobile-dev |
| minor | `v05_pool_insufficient` dashboards pivoting on `force_axis` break on deploy — notify PM/dashboard owner before backend deploy | pm/devops |
| minor | File the follow-up removal ticket (axis + variation_axis + enum, post mobile N+1) now so it doesn't drift | pm |

## Release order (umbrella rule)
1. Merge + deploy backend (devops executes; analytics note above first).
2. Mobile sync per `docs/v05-try-another-mobile-contract.md`, then bump
   submodule pins.
3. Follow-up removal ticket executes only after mobile N+1 ships.
