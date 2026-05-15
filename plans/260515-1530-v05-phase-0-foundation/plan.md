# Phase 0 — V05 Foundation (tuning + measurement)

**Status**: Draft for review
**Date**: 2026-05-15
**Duration**: 2 weeks
**Spec ref**: `wardrobe-backend/docs/v05-llm-pivot-design-spec.md` §2.1.10 + §5
**Parent**: AU-252 (Suggestion System)

---

## Goal

Ship V05 tuning fixes + measurement infrastructure to:
1. Reduce V05 `pool_insufficient` failure rate ≥40%
2. Unlock anchor diversity (gate cho Phase 1 LLM-1)
3. Establish outcome metrics baseline (time-to-decision, accept, wear rate)
4. Enable nightly LLM-3 batch eval pipeline

## Why Phase 0 first

Per spec v2 §2.1.10:
- LLM-1 (Phase 1) hard depends on `anchor_diversity ≥ 3` ở top 20 candidates
- Cannot A/B test LLM-1 without Phase 0 baseline metrics
- V05 tuning fixes serve users today, không cần LLM ship

**Two-phase model**: Phase 0 → Phase 1. Phase 2/3 deferred indefinitely until Phase 1 prove value.

---

## Success criteria

| Metric | Target | Source |
|---|---|---|
| `v05_pool_insufficient_rate` | Drop ≥40% từ baseline | `v05_pool_insufficient_events` table |
| `anchor_diversity_p50` (top 20) | ≥3 distinct (top, bottom) pairs | New metric, post-engine |
| `time_to_decision_p50` | Baseline established | Mobile event log |
| `accept_rate` | Baseline established | Mobile event log |
| `wear_rate` | Baseline established | 24h prompt after pick |
| LLM-3 nightly eval | Running + dashboard live | Cron + admin dashboard |

---

## Sub-phase 1 — V05 engine fixes (Week 1, ~5 days)

### Task 1.1 — Formality cliff fix
**File**: `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py`

**Bug**: User 5bccb576 (151 items, COOL bucket) — 49 TOP items → chỉ 8 pass L2. Formality scoring rejects items where `formality > safe_anchor + 1` (too strict).

**Fix**:
- Allow formality range `[safe-1, safe+2]` ở L2
- Soft-penalty (score × 0.85) outside `[safe, safe+1]`
- Hard-reject only nếu `|delta| > 2`

**Verification**:
- Add unit test: COOL bucket + formality scoring
- Re-run eval user 5bccb576: pre-fix 8 TOP pass → post-fix expected ≥25
- Run `pytest tests/test_engine_v05_layers.py -v`

---

### Task 1.2 — COOL warmth + FOOTWEAR exemption fix
**File**: `wardrobe-backend/blueprints/recommendation/engine_v05.py` (line ~190)

**Bug**: COOL bucket (<15°C) uses `warmth=[3,4,5]` filter, NHƯNG FOOTWEAR L1 exempts warmth check → light sandals pass at 5°C → starvation detector miss → user gets 422 thay vì common boot injection.

**Fix**:
- Remove FOOTWEAR exemption khi `temp_c < 10°C`
- Apply same warmth filter as TOP/BOTTOM

**Verification**:
- Add eval scenario: temp_c=5, M, casual
- Pre-fix: HTTP 422 `pool_insufficient`
- Post-fix: HTTP 200 với common_essential boot injected
- `wardrobe_gap: true, wardrobe_gap_reason: cold_weather_no_outerwear`

---

### Task 1.3 — Visual_weight cap binding fix
**File**: `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py`

**Bug**: 21 visual_weight violations cho user 5bccb576. Cap = 6 cho all climates rejects OUTER+TOP+BOTTOM combos with weight sum >6 (too strict ở COOL khi cần heavy layering).

**Fix**:
- Increase cap to 8 chỉ cho COOL bucket
- Keep cap 6 cho HOT/WARM/MILD
- Add comment explaining bucket-specific rationale

**Verification**:
- Unit test: COOL bucket cap = 8, MILD cap = 6
- Re-run user 5bccb576 OUTER pool: pre-fix 7 items → post-fix expected ≥14

---

### Task 1.4 — Anchor diversity metric
**File**: New `wardrobe-backend/utils/anchor_diversity.py`

```python
def anchor_diversity_score(candidates: list) -> int:
    """Count distinct (top.id, bottom.id) pairs in top 20."""
    return len({(c.top.id, c.bottom.id) for c in candidates[:20]})
```

**Wire**:
- Compute in `routers/v05_recommendation.py` Build response
- Log to `v05_pool_insufficient_events.metadata` field (already JSONB)
- Add structured log entry: `anchor_diversity_p50`

**Verification**:
- Unit test on synthetic candidate list
- Production: query metric after deploy

---

### Task 1.5 — Engine fixes test suite
**Files**:
- `wardrobe-backend/tests/test_engine_v05_layers.py`
- `wardrobe-backend/tests/test_engine_v05_cool_bucket.py` (new)

**Coverage**:
- All 3 fixes have regression tests
- 5bccb576-like scenario reproducible
- Existing tests still pass: `pytest tests/test_engine_v05*.py -v`

---

## Sub-phase 2 — Measurement infrastructure (Week 2, ~5 days)

### Task 2.1 — Outcome events table
**Migration**: `wardrobe-backend/migrations/versions/XXXX_add_v05_outcome_events.py`

```sql
CREATE TABLE v05_outcome_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL,
  session_id  VARCHAR(50),
  event_type  VARCHAR(30) NOT NULL,  -- build|pick|wear|abandon
  outfit_id   VARCHAR(100),
  build_ts    TIMESTAMPTZ,
  picked_ts   TIMESTAMPTZ,
  worn_ts     TIMESTAMPTZ,
  metadata    JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON v05_outcome_events (user_id, event_type, created_at DESC);
CREATE INDEX ON v05_outcome_events (event_type, created_at DESC);
```

---

### Task 2.2 — Mobile event API
**File**: `wardrobe-backend/routers/v05_outcome.py` (new)

**Endpoints**:
- `POST /api/v05/event/pick` — outfit_id + session_id → log pick
- `POST /api/v05/event/wear` — outfit_id → log wear (24h prompt response)
- `POST /api/v05/event/abandon` — session_id → log close without pick

All return 204. Rate limit: 60/min/user.

**Verification**:
- `pytest tests/test_v05_outcome_router.py`
- Manual curl trên :5001

---

### Task 2.3 — LLM-3 nightly batch eval
**File**: `wardrobe-backend/scripts/llm3_nightly_eval.py` (new)

**Cron**: `0 3 * * *` (3am daily, via systemd or k8s cron)

**Logic**:
1. Fetch all outfits served previous day từ `v05_outcome_events` event_type=build
2. For each: call Claude Haiku scoring per `.claude/skills/v05-eval/references/rubric.md`
3. Store in new `v05_outfit_eval_scores` table:
   ```sql
   outfit_id, p1_weather, p2_coherence, p3_occasion,
   p4_identity, p5_wearability, p6_variation, final_score,
   hard_reject, hard_reject_reason, created_at
   ```
4. Aggregate per (climate × gender × occasion) → upsert into dashboard cache

**Provider**: Claude Haiku (`$0.25/1M input`). Budget cap: 1000 outfits/day = ~$3/month.

**Verification**:
- Dry-run on yesterday's data
- Spot-check 5 scores against em manual review

---

### Task 2.4 — Admin dashboard V05 metrics page
**File**: `wardrobe-backend/wardrobe-admin/src/pages/V05Metrics.tsx`

**Tabs**:
1. **Outcome metrics**: time-to-decision histogram, accept rate timeseries, wear rate timeseries
2. **LLM-3 eval**: per-dimension P1-P5 averages, hard reject rate, verdict distribution
3. **Anchor diversity**: histogram top 20 anchor groups per Build
4. **Pool insufficient trend**: daily failure count + failure_reason breakdown

Wire to existing admin API pattern (`routers/admin/*`).

**Verification**:
- Page loads at `/admin/v05-metrics`
- All 4 tabs render with data (sample if real data sparse)

---

### Task 2.5 — Mobile 24h wear prompt
**File**: `auxi/src/components/v05/WearPromptModal.tsx` (new)
**Hook**: `auxi/src/hooks/useWearPrompt.ts` (new)

**Logic**:
- After user picks outfit, schedule local notification 24h later
- On app open, check pending wear prompts
- Show modal: "Did you wear this outfit?" → Yes/No/Snooze
- Yes → POST `/api/v05/event/wear`

**Figma**: Cần anh design team. Nếu Figma chưa ready → MVP text modal (no styling), defer polish.

**Verification**:
- Maestro flow: build → pick → mock 24h → modal appears → Yes → API called
- qa-mobile chạy flow

---

## Dependencies

- ✅ PR #50 (climate fallback)
- ✅ PR #51 (PoolInsufficient logging)
- ✅ PR #52 (skip reason granularity)
- ✅ Backend :5001 + Postgres
- ⚠ Claude Haiku API key — verify exists trong `.env` hoặc add
- ⚠ Mobile build pipeline — verify Maestro CI green
- ⚠ Anh design team Figma cho wear modal (defer-able)

---

## Out of scope (defer)

- LLM-1 implementation (Phase 1)
- LLM-2 + LLM-3 user-facing (Phase 2/3 deferred indefinitely)
- Hot-climate test set 50 fixtures (Phase 1 prereq, separate)
- ToV phrasings list (Phase 3 prereq, anh Viet ownership)
- V05 → V06 migration (out of pivot scope)

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Formality fix breaks existing outfits | Medium | Regression test on 10 representative wardrobes pre-merge |
| Visual_weight cap loosening creates ugly combos | Medium | Apply only COOL initially, validate via LLM-3 eval |
| LLM-3 cost > expected | Low | Cap 1000 outfits/day, monitor 1 week |
| Mobile wear prompt response rate <20% | High | OK — baseline number even if low, surface as metric |
| Design Figma chưa ready cho wear modal | High | Ship text-only MVP, polish later |
| Anchor diversity metric reveals V05 fundamentally broken | Medium | Surface findings, decide V06 vs more tuning vs LLM workaround |

---

## Verification gates

### After Sub-phase 1 (engine fixes)
- [ ] `pytest tests/test_engine_v05_layers.py tests/test_engine_v05_cool_bucket.py` green
- [ ] Eval user 5bccb576 re-run: pool sizes improve to target
- [ ] `anchor_diversity_p50 ≥ 3` measured trên 10 test scenarios
- [ ] Production deploy → 48h watch: no regression in `v05_pool_insufficient_rate`
- [ ] PR review by tech-lead + merge

### After Sub-phase 2 (measurement infra)
- [ ] Migration applies cleanly (test DB + staging)
- [ ] Event API endpoints return 200 trên manual curl
- [ ] LLM-3 cron runs on staging — 1 night data validated
- [ ] Admin dashboard renders all 4 tabs với sample data
- [ ] Mobile build green, Maestro wear-prompt flow passes
- [ ] PR review + merge

### Phase 0 done gate
- [ ] Both sub-phase PRs merged to main
- [ ] Production running 1 week với new metrics
- [ ] Baseline numbers documented in `plans/reports/v05-phase-0-baseline-{date}.md`
- [ ] `anchor_diversity_p50 ≥ 3` confirmed in production
- [ ] → unblocks Phase 1 LLM-1 plan

---

## Timeline

```
Week 1 (May 18-22)
├── Mon-Tue: Task 1.1 Formality + Task 1.2 COOL/FOOTWEAR
├── Wed:     Task 1.3 Visual_weight + Task 1.4 Anchor diversity
├── Thu:     Task 1.5 Tests + integration
└── Fri:     PR #54 review + merge

Week 2 (May 25-29)
├── Mon:     Task 2.1 Migration + Task 2.2 Event API
├── Tue-Wed: Task 2.3 LLM-3 batch eval
├── Thu:     Task 2.4 Admin dashboard
├── Fri:     Task 2.5 Mobile wear prompt + PR #55

Week 3 (Jun 1-5) — baseline collection
└── Production data collection, dashboard validation

→ Phase 1 LLM-1 planning starts Jun 8
```

---

## Next steps

1. **Anh review plan** → flag tasks cần adjust hoặc remove
2. Em start Task 1.1 (formality cliff fix)
3. Each task ship as commit, sub-phase 1 = 1 PR, sub-phase 2 = 1 PR
4. After Phase 0 baseline data → write Phase 1 LLM-1 plan
