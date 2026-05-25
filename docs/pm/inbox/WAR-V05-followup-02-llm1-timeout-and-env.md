---
id: WAR-V05-FU-02
parent: V05-LLM-pivot
type: bug
title: "[V05] LLM-1 robustness: 1.5s timeout causes ~1/3 fallbacks + OPENAI_API_KEY env gap"
state: Backlog
priority: P1
labels: [type:bug, area:backend, role:backend-dev, v05, llm1, source:ticket-b-eval]
team: Auxi
workspace: duncan-1
owner: backend-dev
estimate: 2-4h
linear_sync_status: pending
created: 2026-05-25
---

## Context

Surfaced during the Ticket B (PR #63) live eval. Two independent LLM-1
robustness issues, both orthogonal to the compose-diversity fix:

1. **Timeout too tight.** `LLM_TIMEOUT_S` is hardcoded at `1.5s`, which
   sits right at gpt-4o-mini's typical single-shot latency (~1.0–1.3s).
   Result: roughly **1/3 of LLM-1 calls time out and silently fall back**
   to the deterministic path even when the candidate pool is sufficient.
   This affects prod, not just the eval.

2. **OPENAI_API_KEY env gap.** LLM-1 (OpenAI gpt-4o-mini) reads
   `OPENAI_API_KEY` from `os.environ`, but the app loads config via
   pydantic-settings which does NOT populate `os.environ`. A bare launch
   raises `client_init_error` and LLM-1 falls back. Prod (Railway) injects
   the key as a real process env var so it likely works there — but this
   should be **confirmed**, since a silent fallback would mean LLM-1 has
   been effectively dead in prod regardless of pool size.

## Acceptance criteria

- [ ] Make `LLM_TIMEOUT_S` configurable and raise the default to a safe
      margin above observed gpt-4o-mini latency (e.g. 3–4s). Verify the
      timeout-induced fallback rate drops materially on the eval matrix.
- [ ] Have the OpenAI client read the key from `settings` (single source
      of truth) instead of `os.environ`, OR add a startup check that fails
      fast / warns loudly if the key is unreachable.
- [ ] Confirm (via logs or a one-off prod check) whether LLM-1 has been
      silently falling back in production due to either issue.
- [ ] Emit a structured log/metric on every LLM-1 fallback with the reason
      (timeout vs client_init vs insufficient_pools) so this is observable
      going forward.

## Out of scope

- LLM-1 prompt/diversity tuning.
- Tier-pretag promotion (see WAR-V05-FU-01).

## Refs

- Eval report: `wardrobe-backend/plans/reports/v05-eval-260525-1526-ticket-b-compose-diversity.md`
- Ticket B PR: auxi-wardrobe/auxi-backend#63
- Files: V05 LLM-1 diversifier service (`wardrobe-backend/services/v05_llm1_diversifier_service.py`) + config
