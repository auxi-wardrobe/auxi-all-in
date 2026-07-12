---
phase: 1
title: L0 Context Schema + Weather Depth
status: planned
priority: P1
repos: [wardrobe-backend, auxi]
dependencies: []
---

# Phase 1: L0 Context Schema + Weather Depth

## Overview

Widen what the engine can see. Today only `temp_c` + `is_rainy` reach scoring
(`v05_build_service` persists them to session ctx via `repositories/v05_event_repository.py`;
`try_another` reuses them). Add an optional, backward-compatible **context object** carrying
richer real-life signals, ingest full weather on mobile, and persist the whole object to
session ctx so `build` and `try_another` agree. **No scoring change this phase** — just plumb
the data through. Comfort (P2) and explanation (P3) consume it.

## Requirements

Functional:
- New optional context fields on the recommendation-request `intent` (Pydantic), all nullable,
  omit-when-unknown (never send `null`/`""` — matches analytics hygiene):
  - Weather: `temp_c` (exists), `feels_like_c`, `humidity_pct`, `rain_prob` (0-1), `uv_index`, `wind_kph`, `is_rainy` (exists, derive from `rain_prob` if absent).
  - `mobility`: enum `walking|motorbike|car|public_transport` (SEA-critical; default unset).
  - `activity`: enum extending existing occasion vocab `office|presentation|wedding|cafe|date|travel|gym|casual` (reuse the occasion field if one exists — DRY, don't add a parallel concept).
  - `duration`: enum `short|full_day|day_to_night`.
- Bounds validation (fail-closed, mirrors AU-306 follow-up #7): `temp_c ge=-50 le=60`, `humidity_pct 0-100`, `rain_prob 0-1`, `uv_index 0-15`, `wind_kph 0-200`. Out-of-range → 422, not silent clamp.
- Persist the full context object to session ctx at build (extend the existing `temp_c`/`is_rainy` write); `try_another` reads it (no re-guess — mirrors AU-306 #5 fix: fail-closed, signal "stale session, rebuild" if absent).
- Mobile `weatherService` fetches the full payload (feels-like/humidity/rain_prob/uv/wind), not just temp; passes it in the build request.

Non-functional:
- 100% backward compatible: a request omitting all new fields behaves byte-identically to today.
- No new hot-path latency (context is passed data, not a lookup).
- No PII: never send raw lat/long to the engine or persist it — mobile resolves weather locally and sends only the derived scalars.

## Architecture

```
auxi weatherService.getCurrent()  ──► { temp_c, feels_like_c, humidity_pct,
                                         rain_prob, uv_index, wind_kph }
        + user context chips (P4)  ──► { mobility, activity, duration }
   → recommendationService build request.intent
       → routers/recommendation.py (Pydantic validate + bounds)
         → v05_build_service (persist FULL ctx to session)
           → repositories/v05_event_repository.py  (session/Redis)
             → engine reads ctx (P2 comfort, P3 explanation consume)
   try_another → v05_try_another_service reads persisted ctx (no re-guess)
```

## Related Code Files

Backend (create/modify):
- Modify: `wardrobe-backend/routers/recommendation.py` — extend request Pydantic model with optional context fields + bounds validators.
- Create: `wardrobe-backend/blueprints/recommendation/context_schema.py` — `RecommendationContext` dataclass/model + enums + `MISSING`-omit helpers (single source, imported by build/try_another/comfort/explain).
- Modify: `wardrobe-backend/services/v05_build_service.py` — persist full ctx object.
- Modify: `wardrobe-backend/repositories/v05_event_repository.py` — write/read the ctx blob (extend the temp_c/is_rainy path).
- Modify: `wardrobe-backend/services/v05_try_another_service.py` — read persisted ctx (drop any temp default; fail-closed).
- Modify: `wardrobe-backend/API_DOCUMENTATION.md` — document new optional context fields (mandatory; tech-lead signs off — public `/api/v05` contract change).

Mobile (modify):
- `auxi/src/services/weatherService.ts` — return the extended weather payload; keep graceful fallback (log, omit unknown fields, never send `null`).
- `auxi/src/services/*recommendation*.ts` — attach context to the build request.
- Tests: `auxi/src/services/__tests__/weatherService.test.ts` — extended payload + fallback observability.

## Implementation Steps

1. **Context schema module.** `context_schema.py`: the `RecommendationContext` with all fields optional; enums for mobility/activity/duration; a `to_session_dict()` that omits unknowns. Reuse the existing occasion field name if present (grep first — DRY).
2. **Router contract.** Add fields + Pydantic bound validators to the build request model. Unknown fields ignored; out-of-range → 422.
3. **Persist.** In `v05_build_service`, build the ctx object and hand it to the event repository; extend the session write to store the blob (not just temp_c/is_rainy).
4. **try_another parity.** Read the persisted ctx; remove any temp/rain default; if ctx absent (legacy/expired), return the existing "stale session, rebuild" signal.
5. **Mobile weather.** Expand `weatherService` to fetch + return the full scalar payload; wire into the build request; graceful degradation (omit fields the API didn't return).
6. **Docs + sign-off.** Update `API_DOCUMENTATION.md`; tech-lead reviews the contract before mobile depends on it.

## Success Criteria

- [ ] Legacy request (no new fields) → identical output + session behavior as pre-change (golden test).
- [ ] Full-context request persists all fields to session ctx; `try_another` reads them (no re-guess).
- [ ] Out-of-range weather (e.g. `temp_c=200`) → 422, not silent.
- [ ] Mobile sends real feels-like/humidity/rain_prob/uv/wind when available; omits (not `null`) when not.
- [ ] `API_DOCUMENTATION.md` diff includes the new fields; tech-lead sign-off recorded.
- [ ] Backend `pytest` + `python test_server.py` green; mobile `tsc --noEmit` + `yarn lint` clean.

## Risk Assessment

- **Contract drift** (mobile/back out of sync). Mitigation: additive-optional only; API doc + tech-lead gate per CLAUDE two-repo contract.
- **Session blob growth / legacy sessions.** Mitigation: small scalar blob; fail-closed rebuild signal for pre-schema sessions (reuse AU-306 pattern).
- **PII leak via coords.** Mitigation: mobile resolves weather; only derived scalars cross the boundary — never lat/long.
