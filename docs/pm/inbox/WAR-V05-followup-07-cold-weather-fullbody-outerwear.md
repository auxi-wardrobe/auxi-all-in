---
id: WAR-V05-FU-07
parent: V05-LLM-pivot
type: enhancement
title: "Cold-weather recommendations: pair full-body outfits with outerwear, or down-rank/exclude them below ~7°C"
state: Triage
priority: P2
labels: [type:enhancement, area:backend, role:backend-dev, v05, recommendation-engine, cold-weather, source:ceo]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 1-2d
linear_sync_status: pending_manual_entry
created: 2026-07-22
---

> **Linear MCP was not reachable in this session** — the `mcp__claude_ai_Linear__*`
> toolset was not surfaced. This ticket is captured here in the PM inbox with a
> Linear-mirroring schema so nothing is lost. On next authenticated session, sync
> to Linear (team: Auxi / backend) and set `linear_sync_status: synced` with the
> real issue ID/URL.

## Context

Product/CEO-requested recommendation-quality fix for the Valen (V05) recommender.
At cold / sub-zero temperatures the recommender can return a **FULL_BODY item
(dress / jumpsuit) + shoes with no outerwear**. A dress in freezing weather with
nothing over it reads as an inappropriate suggestion.

This fix must live in the **backend recommender**, not the client. The mobile app
(auxi) is intentionally a pass-through: it forwards a representative temperature
and renders whatever outfit comes back — it does NOT compose outfits by
temperature. Confirmed in `auxi/src/services/v05Api.ts` and
`auxi/src/config/temperature-buckets.ts`.

### Current behavior (as observed)

- The client sends a representative temp per bucket: the "< 0°C" bucket
  (`freezing_-10_0`) sends `temp_c = -5`; the "0–7°C" bucket (`cold_0_7`) sends
  `4`. Both collapse into the same **COOL** classification (backend classifies
  anything `< 15` as COOL), so today they yield identical candidate pools — an
  accepted MVP behavior, **not** the target of this ticket.
- **FULL_BODY is only dropped when `user.gender = "M"`.** For gender `W`/`U` it is
  eligible, and HomeScreen sends `gender: 'U'` on every build request — so a
  dress + shoes can and does come back at −5°C.
- The backend already emits a `cold_weather_no_outerwear` wardrobe-gap CTA when a
  COOL/cold outfit returns with no outerwear (referenced at
  `auxi/src/services/v05Api.ts:327`). So the "too light for cold" signal already
  exists **as a nudge**, but it does NOT prevent a full-body-without-outerwear
  outfit from being the top recommendation.

## Goal (CEO direction)

Do **NOT** hard-disallow dresses/jumpsuits in cold weather. Instead, in the
recommender, for cold temperatures (~below 7°C):

1. When a FULL_BODY item is chosen as the base, **try to include a suitable
   outerwear layer** in the composed outfit.
2. If suitable outerwear is available in the user's wardrobe → include it; outfit
   is fine.
3. If no suitable outerwear can be paired → **rank that full-body outfit much
   lower, or exclude it**, so it does not surface as a top pick when
   better-covered options exist.

## Acceptance criteria

- [ ] Below the cold threshold (~7°C / the COOL classification), a FULL_BODY-based
      outfit is only surfaced at normal rank when it includes an appropriate
      outerwear layer.
- [ ] If outerwear cannot be paired with a full-body item in cold weather, that
      outfit is down-ranked or excluded rather than returned as a top
      recommendation.
- [ ] Full-body outfits remain eligible in warm weather — no regression there.
- [ ] Behavior is temperature-driven **in the backend**; no mobile-client change
      is required or expected.
- [ ] Interaction with the existing `cold_weather_no_outerwear` wardrobe-gap CTA
      is considered — the gap CTA still fires when the user genuinely lacks
      outerwear, rather than silently dropping all options (avoid an empty-result
      cliff when the wardrobe has no coats).
- [ ] `API_DOCUMENTATION.md` updated **only if** the response shape / flags change
      (e.g. a new rank-reason or exclusion flag); pure ranking-logic changes with
      no contract change need no doc edit — state which applies.
- [ ] `python test_server.py` green; add/extend a recommender test that asserts a
      cold-weather FULL_BODY outfit either carries outerwear or is down-ranked/
      excluded (cover gender `U` and `W`).

## Out of scope

- Splitting the `freezing_-10_0` vs `cold_0_7` buckets into distinct candidate
  pools (both → COOL today is accepted MVP behavior).
- The `user.gender = "M"` FULL_BODY drop rule (leave as-is).
- Any mobile-client change (auxi is a pass-through by design).
- Redesigning the `cold_weather_no_outerwear` CTA copy/trigger beyond ensuring it
  still fires correctly under the new logic.

## Notes / open questions

- **Cold threshold** — confirm with product. Proposed ~7°C, aligns with the COOL
  `< 15` classification boundary. backend-dev to confirm whether the trigger is
  the COOL bucket or a finer temp cutoff (e.g. a dedicated `< 7°C` gate).
- **"Suitable outerwear"** — define the category set (OUTERWEAR / coats / jackets)
  plus any weather-weight attributes the engine already tracks (`warmth_level` on
  `physical_attributes` / `styling_metadata` — note the dual-read quirk found in
  AU-251).
- **"Much lower rank" vs "hard exclude"** — decide whether this is configurable /
  experiment-gated (env flag in line with existing `V05_*` config).

## Refs

- Client (pass-through evidence, do NOT change):
  `auxi/src/services/v05Api.ts` (gap CTA ref at `:327`),
  `auxi/src/config/temperature-buckets.ts`
- Backend recommender (where the fix lands):
  `wardrobe-backend/blueprints/recommendation/engine_v05.py`,
  `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py`
  (`_pre_filter_for_anchor_v05` — the climate/warmth gate, per AU-251),
  `wardrobe-backend/blueprints/recommendation/engine_v05_variation.py`
- Config precedent: existing `V05_*` env flags (see FU-04 refs)
- Related: AU-251 warmth_level dual-read (`physical_attributes` vs
  `styling_metadata`) — relevant to defining "suitable outerwear" by weight.
