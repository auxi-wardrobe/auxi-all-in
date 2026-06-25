# Phase 07 — OPTIONAL / DEFERRED — Backend `temp_c_override` + Finer Cold Bands

**Context:** [plan.md](plan.md) · `wardrobe-backend/` · gated by decisions D1/D2/D3 · CLAUDE.md "Two-Repo Contract"

## Status: ☐ DEFERRED — NOT on the MVP critical path
The mobile-only MVP (Phases 02–06) needs **zero** backend change: the engine already consumes the client-sent `weather.temp_c`. Take this phase ONLY if product decides one of:
- **D2** — the two coldest buckets (`0–7`, `-10–0`) MUST produce visibly different outfits (today both → backend `COOL` <15 ⇒ identical), or
- We want a **semantic** `temp_c_override` field + server-side bucket label for cleaner API docs / server analytics, instead of overloading `temp_c`.

If taken, this is an **API contract change** → requires **tech-lead sign-off** + `API_DOCUMENTATION.md` update + mobile client sync (CLAUDE.md two-repo rule).

## Key Insights (backend recon, file:line)
- Endpoint `POST /api/v05/recommendation/build` → `routers/v05_recommendation.py:45`; schema `BuildRequest`/`WeatherDTO` `schemas/v05_recommendation.py:43–85` (`weather.temp_c: float`).
- Service `services/v05_build_service.py:78–91` passes `temp_c` straight to `engine.build(BuildInput(temp_c=…))`; session context stores it (`:199`) → reused by `v05_try_another_service.py`.
- Buckets: `engine_v05.py:189–201` `_climate_bucket`; warmth gates `engine_v05_constants.py` (`WARM_OUTER_THRESHOLD`, footwear warmth gate).
- Concurrency: per-session SETNX Redis lock already guards try_another (`v05_try_another_service.py:154`); build is stateless + rate-limited 10/min.

## Option A — semantic override field (minimal)
- `WeatherDTO` += `temp_c_override: Optional[float] = None`. Service: `effective = body.weather.temp_c_override if not None else body.weather.temp_c`. Engine unchanged. Doc the field.
- Net effect identical to mobile-only mapping, but explicit in the contract + queryable server-side.

## Option B — finer cold bands (only if D2 = "must differ")
- Add a band below COOL in `_climate_bucket` (e.g. `<5 → FRIGID`) + corresponding warmth constraints/footwear gate in `engine_v05_constants.py` / `engine_v05_layers.py`. This is an **algorithm change** — needs backend-dev + product sign-off on the new warmth behavior + tests.

## Files (if taken)
- `wardrobe-backend/schemas/v05_recommendation.py` (field)
- `wardrobe-backend/services/v05_build_service.py` (resolve effective temp)
- `wardrobe-backend/blueprints/recommendation/engine_v05.py` + `engine_v05_constants.py` (Option B only)
- `wardrobe-backend/API_DOCUMENTATION.md:3589–3620` (mandatory)
- `auxi/src/services/v05Api.ts` `BuildRecommendationInput` (client sync, if field added)

## Verification (if taken)
- `cd wardrobe-backend && python test_server.py` (e2e :5002); assert override temp drives climate bucket + warmth gates; try_another preserves it.
- tech-lead reviews contract diff; mobile-dev syncs client.

## Todo (only if activated)
- [ ] Product confirms D2/D1 requires backend
- [ ] tech-lead sign-off on contract change
- [ ] Field / band implemented + tests
- [ ] API_DOCUMENTATION.md updated
- [ ] Client `v05Api.ts` synced

## Recommendation
**Skip for MVP.** Ship Phases 02–06 mobile-only; file a follow-up ticket if Mixpanel shows users picking the two cold buckets and expecting different results (D2).
