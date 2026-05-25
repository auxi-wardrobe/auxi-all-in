---
id: WAR-PR-008
type: feature
title: "[US] Backend defaults to OpenAI gpt-5-nano + recommendation engine v2"
state: Done
priority: P1
labels: [type:feature, area:backend, role:backend-dev, source:pr]
source_pr: https://github.com/ducga1998/wardrobe-backend/pull/34
source_repo: wardrobe-backend (ducga1998/wardrobe-backend)
author: ducga1998
merged_at: 2026-05-05T08:24:06Z
companion_pr: https://github.com/ducga1998/auxi-mobile/pull/5
created: 2026-05-05
---

## Context

Mobile was migrating off the Gemini-debug `/valen-get-recommendations`
endpoint to the production `/recommendation/start` + `/next` flow
(auxi-mobile#5). To unblock the mobile swipe loop with the right model
behavior, backend defaults needed to flip from Gemini to OpenAI
gpt-5-nano via the v2 engine. This PR ships that flip.

## What shipped

- `LLM_MODEL=gpt-5-nano` + `RECOMMEND_ENGINE=v2` documented in
  `API_DOCUMENTATION.md` env section.
- `blueprints/recommendation/engine_v2.py` — env `LLM_MODEL` now
  overrides the `model_name` baked into the active `AlgorithmConfig` row.
  (DB carried `gemini-2.0-flash` which previously beat the env var.)
- `services/llm_service.py:_is_openai_model` already matches `gpt-5-nano`
  via the `'gpt' in model_lower` check (line 169) — no allowlist change
  needed.

## Acceptance criteria

- [x] `POST /api/recommendation/start` with JWT returns 200 OK.
- [x] Response carries `engine_version: "v2"`.
- [x] Backend log: `Invoking LangChain adapter with model: gpt-5-nano,
      temperature: 0.3`.
- [x] `langchain_openai==1.1.7` / `openai==2.7.1` accept `gpt-5-nano` as
      a model string.
- [x] `pytest tests/test_llm_service.py
      tests/test_recommendation_engine_factory.py
      tests/test_recommendation_v2.py` — 32 passed.
- [x] iOS sim end-to-end via auxi-mobile#5: cold-launch → Home renders
      v2 outfit, swipe loop, heart save, `/next` 200 OK with
      `variation_axis: SILHOUETTE`.
- [x] `API_DOCUMENTATION.md` updated.

## Out of scope (filed separately)

- Per-request `mode: safe|power|creative` engine tuning — Linear AU-221
  backend ticket.
- Per-request `pinned_item_id` honor — Linear AU-233.
- `app.py` ignores `PORT` env breaking `test_server.py` — pre-existing,
  separate.
- Cleaner long-term fix: drop `model_name` from `llm_config` so env wins
  by default — flagged for tech-lead.

## Companion

- `ducga1998/auxi-mobile#5` — Home swipe Phase A/B/C, switches mobile to
  `/start` + `/next`.
