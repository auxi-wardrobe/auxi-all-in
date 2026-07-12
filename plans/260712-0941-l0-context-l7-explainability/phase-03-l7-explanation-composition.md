---
phase: 3
title: L7 Structured Explanation Composition
status: planned
priority: P1
repos: [wardrobe-backend]
dependencies: [1]
---

# Phase 3: L7 Structured Explanation Composition

## Overview

Replace the flat 25-template `reasoning_human` string with a **structured, ranked
`explanation` object** composed from signals the engine already computes while scoring —
weather/comfort (P1/P2 `trace.comfort`), occasion (`intent`), wear-history (`usage_frequency`
/ outcome events), preference (style signals / affinity), pairing (co-wear from outcome events),
novelty (`novelty_score`). The composer is **deterministic** (no LLM in hot path), **ToV 1.2
safe**, and **PII-free**. `reasoning_human` stays as the human headline, upgraded to interpolate
the top factor. This is a *promotion of existing internal trace into a public field* — low risk,
reuses computation.

## Requirements

Functional:
- Engine response gains, per outfit:
  ```
  explanation: {
    headline: str,                 # upgraded reasoning_human, ToV-safe, ≤ ~90 chars
    factors: [                     # ranked by contribution, top 2-3 (never > 3)
      { kind, text, evidence }     # kind ∈ weather|comfort|occasion|wear_history|preference|pairing|novelty
    ]
  }
  ```
- Factor selection = the layers that ACTUALLY moved THIS outfit's score, read from `trace`
  (comfort multiplier, signal re-weight, novelty score, affinity, feasibility weather gate) —
  not generic boilerplate. Rank by |contribution|; tie-break by a fixed kind priority
  (weather > occasion > comfort > wear_history > preference > pairing > novelty).
- Per-kind deterministic templates render `text` from `evidence` (e.g.
  `weather` → "34°C, humid — picked light + breathable"; `wear_history` → "you've worn this piece only twice").
  `evidence` carries the structured values (`{temp_c:34, humidity_pct:85}`) for analytics/debug.
- **Vocab guard:** run rendered strings through the existing ToV 1.2 banned-word check
  (no "elevated/curated/refined/pulled-together/statement piece/chic/on-trend"). CI-lintable.
- **No PII:** never emit raw coords, raw free-text, emails, or exact GPS — only derived scalars +
  bounded vocab. Wear-history uses counts/relative ("only twice", "most-worn"), not timestamps.
- Fallback: if no factor crosses a min-contribution floor (cold-start user, sparse ctx) →
  headline from the existing 25 templates, `factors: []`. Never empty-string the headline.
- Deterministic: same seed + ctx + signals → identical `explanation` (assert in test).

Non-functional:
- Hot-path composition only reads already-computed trace — target < 5ms/outfit, no new queries.
  Pairing ("most-worn shoes") uses data already loaded for scoring; if a lookup is needed, cache it
  per-request, and if unavailable, drop the pairing factor (never add a query to the hot path).
- Never-raise: composition failure → fall back to template headline, log, continue.

## Architecture

```
engine_v05 (per outfit, after scoring)
  trace {feasibility, comfort, signal_reweight, novelty, affinity, wear_stats, pairing}
    → engine_v05_explain.compose(trace, ctx, intent)
        pick factors where |contribution| >= FLOOR
        rank, take top 3, render per-kind template (ToV-guarded)
        headline = render_headline(top_factor) or template_fallback()
      → outfit.explanation = {headline, factors[]}
```

Factor sources (reuse — do NOT recompute):
- `weather` / `comfort` ← `trace.comfort` + ctx (P1/P2)
- `occasion` ← `intent.activity`/occasion (P1)
- `wear_history` ← `usage_frequency` (`models/wardrobe.py`) + `v05_outcome_events` wear counts
- `preference` ← active `v05_user_style_signals` / `user_style_affinity` that hit this outfit
- `pairing` ← co-wear from `v05_outcome_events` (item most-worn-with), data already in scope
- `novelty` ← existing `novelty_score` / `vibe_signature` distance

## Related Code Files

- Create: `wardrobe-backend/blueprints/recommendation/engine_v05_explain.py` — `compose()`, per-kind templates, ToV guard call, ranking, fallback.
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05.py` — call `compose()` after packaging (L6); attach `explanation`; ensure `trace` carries the needed breadcrumbs (comfort from P2 already; add wear_stats/pairing breadcrumbs if not present).
- Modify: `wardrobe-backend/blueprints/recommendation/engine_v05_constants.py` — keep the 25 templates as fallback headlines; add per-kind factor templates + banned-word list (reuse if one exists).
- Modify: response Pydantic model (`routers/recommendation.py` / models) — add `explanation` field (additive, optional for old clients).
- Modify: `wardrobe-backend/API_DOCUMENTATION.md` — document `explanation` shape + factor kinds.
- Create tests: `wardrobe-backend/tests/test_engine_v05_explain.py` — ranking, determinism, ToV lint, PII-absence, fallback, factor-count ≤ 3.

## Implementation Steps

1. **Trace audit.** Confirm which breadcrumbs already exist on `trace` (comfort ✓ from P2, novelty ✓, affinity ✓). Add lightweight `wear_stats` + `pairing` breadcrumbs from data already loaded — no new hot-path query.
2. **Composer.** `engine_v05_explain.compose()`: gather candidate factors, filter by `FLOOR`, rank by |contribution| + fixed kind priority, cap at 3.
3. **Templates.** Per-kind render fns → `text` from `evidence`; headline interpolates the top factor. All strings pass the ToV banned-word guard (fail → drop/replace, never ship a banned word).
4. **Wire response.** Attach `explanation`; keep `reasoning_human` = headline for back-compat.
5. **Fallback + never-raise.** No qualifying factor → template headline + `factors:[]`; any exception → same fallback + log.
6. **Docs + sign-off.** API doc; tech-lead reviews the public shape.

## Success Criteria

- [ ] Hot+rainy+motorbike outfit → `factors[0].kind == "weather"` (or comfort) with real `evidence`; ≤ 3 factors.
- [ ] Deterministic: same seed+ctx+signals → identical `explanation` across two calls.
- [ ] ToV lint: rendered strings contain zero banned words (automated test).
- [ ] PII test: no coords/emails/free-text/timestamps in any factor `text` or `evidence`.
- [ ] Cold-start user (no signals, minimal ctx) → non-empty headline via template fallback, `factors:[]`.
- [ ] Composition exception simulated → response still returns with template headline (no 500).
- [ ] `explanation` absent-tolerant for old mobile builds (additive field).
- [ ] `pytest tests/test_engine_v05_explain.py` + `python test_server.py` green.

## Risk Assessment

- **Explanation says something the score didn't do** (trust-killer). Mitigation: factors derive ONLY from actual `trace` contributions, ranked by real magnitude — no hand-written "sounds good" reasons.
- **ToV / brand-voice violation.** Mitigation: banned-word guard in code + CI test; reuse existing list.
- **Hot-path latency from pairing lookups.** Mitigation: reuse in-scope data; drop factor rather than query; per-request cache.
- **PII via evidence.** Mitigation: whitelist evidence keys (scalars + bounded vocab only); PII-absence test.
