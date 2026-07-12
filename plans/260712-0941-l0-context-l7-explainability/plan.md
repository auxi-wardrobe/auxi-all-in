---
title: "L0 Context Enrichment + L7 Explainability — the trust wedge"
description: >-
  Enrich real-life context inputs (weather depth, mobility, activity, duration)
  into a soft comfort layer, and surface a structured, multi-factor "why" on
  every outfit. Both reuse data/scoring the V05 engine already computes — low
  infra, high trust lift. Cross-repo (wardrobe-backend + auxi), mobile-only surface.
status: planned
priority: P1
branch: claude/suggestion-engine-personalization-tgzmag
tags: [v05, recommendation, context, explainability, comfort, cross-repo]
blockedBy: []
blocks: []
created: '2026-07-12T09:41:00.000Z'
createdBy: architect
source: session
---

# L0 Context Enrichment + L7 Explainability

## Overview

Two paired wedges chosen as the highest-leverage / lowest-risk moat step:

- **L0 (context)** — engine today only sees `temp_c` + `is_rainy`. Widen the
  context it can reason on (feels-like, humidity, rain %, UV, wind, **mobility**,
  **activity/occasion**, **duration**) and turn it into a **soft Comfort layer**
  (conservative, metadata-gated, never-starve — mirrors the L4 mood re-weight posture).
- **L7 (explainability)** — replace the 25 static `reasoning_human` templates with a
  **structured, ranked `explanation.factors[]`** composed from signals the engine
  ALREADY computes during scoring (weather, occasion, comfort, wear-history,
  preference, pairing, novelty). Deterministic render, ToV-safe, no LLM in hot path.

**Why paired:** L0 produces the richest explanation factors; L7 renders them. You
cannot say *"breathable pick — 34°C + motorbike"* unless L0 captured humidity + mobility.
So L0 lands first, L7 consumes it.

**Scope guardrails:** additive + backward-compatible (all new context fields optional);
no change to L1/L2 core rules except metadata-gated soft modifiers; comfort is a clamped
`[0.5,1.5]` multiplier, not a hard gate (except safety-clear rain→footwear where metadata exists);
mobile-only (engine stays web-ready, no web client this round).

## Context Links

- Strategy gap-map: this session (L0/L7 = "untaken ground"); engine reality via
  `plans/reports/scout-260611-2004-au318-backend-outfit-feedback-surface.md`
- Weather path precedent: `plans/260601-2142-au306-cold-weather-fix/` (temp_c/is_rainy → session ctx)
- Wear-count proxy: `plans/260626-0005-pr148-usage-frequency-backend/` (`usage_frequency`, display-only today)
- Rules: `.claude/rules/analytics-tracking-required.md`, `.claude/rules/design-review-required.md`

## Key Decisions

- **Context schema (P1):** extend the recommendation-request `intent`/context with optional
  fields; persist to session ctx where `temp_c`/`is_rainy` already persist
  (`v05_build_service` → `repositories/v05_event_repository.py`). Zero breaking change.
- **Comfort (P2):** new `context_comfort.py` maps context → per-candidate soft multiplier +
  a few metadata-gated hard excludes (heavy rain → non-waterproof footwear IF `waterproof` known;
  heat+humidity → down-weight `heavy_layering`). Rides existing scoring clamp. Never starves the pool.
- **Explanation (P3):** engine emits `explanation: {headline, factors[]}`; factors chosen from the
  per-outfit scoring trace (`trace.*`), ranked by contribution, top 2-3. `reasoning_human` becomes the
  headline (upgraded to interpolate factors). ToV 1.2 vocab guard enforced; no PII; deterministic.
- **Mobile (P4):** compact context chips (mobility/duration/activity) + an expandable "why" affordance
  on the outfit card. Mixpanel events wired (`context_set`, `outfit_explanation_expanded`) per rule.
- **No LLM in hot path.** LLM narration remains a deferred side-endpoint.

## Dependencies

P1 → P2 (constraints read the schema) · P1 → P3 (factors read context) · P3 → P4 (UI renders factors;
input chips also feed P1 fields) · P5 last (cross-repo contract + eval).

## Phases

| Phase | Name | Repo | Status |
|-------|------|------|--------|
| 1 | [L0 Context Schema + Weather Depth](./phase-01-l0-context-schema-weather.md) | backend + auxi | Planned |
| 2 | [L0 Comfort Layer (metadata-gated)](./phase-02-l0-comfort-layer.md) | backend | Planned |
| 3 | [L7 Structured Explanation Composition](./phase-03-l7-explanation-composition.md) | backend | Planned |
| 4 | [Mobile Context Inputs + Why UI + Analytics](./phase-04-mobile-inputs-why-ui.md) | auxi | Planned |
| 5 | [Eval, QA & Cross-Repo Ship](./phase-05-eval-qa-ship.md) | both | Planned |

## Success Criteria (end-to-end)

- A hot+rainy+motorbike request returns an outfit whose top explanation factor cites the
  real context (`{temp_c, humidity, mobility}`), and comfort down-weighted heavy layering —
  without increasing `pool_insufficient` vs baseline.
- Explanation is deterministic (same seed+ctx → same factors), ToV-safe (banned-word lint clean),
  PII-free (no raw weather coords, no free text).
- Backward compatible: a legacy request with no new context fields behaves exactly as today.
- Tracking plan updated; designer gate PASS recorded for the mobile surface.
