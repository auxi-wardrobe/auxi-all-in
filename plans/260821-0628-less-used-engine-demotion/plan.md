# "Less use" must actually demote — V05 engine follow-up

**Date:** 2026-08-21
**Repo touched:** `wardrobe-backend` → branch `claude/less-use-item-suggestions-42g8un`
**Predecessor:** `plans/260626-0005-pr148-usage-frequency-backend/plan.md` §8 (deferred follow-up)
**Status:** Implemented, pushed, awaiting review + `/v05-eval`

---

## 1. The report

> "When user check the Less use function in the item detail, that item should not
> appear in new suggestions or decrease the chance of appearance in an outfit.
> The current version I still see a lot of less use item in the suggestions."

## 2. Root cause — the feature was never wired to the engine

PR #148 shipped `usage_frequency` deliberately as **display-only**; the down-ranking
was written down as a deferred follow-up and never picked up.

| Layer | State before this change |
|---|---|
| Mobile | ✅ correct — `updateUsageFrequency()` PATCHes, read-path falls back to the `less-used` style tag |
| `PATCH /wardrobe/items/{id}/usage-frequency` | ✅ persists field + dual-writes the tag |
| `models/wardrobe.py` / `to_dict()` | ✅ serves `usage_frequency` |
| **V05 engine** | ❌ **never read either spelling** |

`services/wardrobe_service.py:set_usage_frequency` said so in as many words:
*"Display-only — no recommendation-engine effect."* Nothing in
`blueprints/recommendation/**` referenced `usage_frequency` outside DTO
serialization. So a demoted item competed for every slot exactly like any other.

Measured on the repro wardrobe (2 normal + 1 demoted per family, 30 seeds):
**30/30 builds served at least one demoted item.** After the fix: **0/30.**

A second, quieter bug rode along: the dual-written `less-used` tag lands in
`style_tags`, which feeds `style_jaccard` (outfit cohesion), `dominant_style_tag`
(diversity), `compute_vibe_signature` (novelty/distance) and the L4 mood bonus.
Two demoted items therefore read as *stylistically coherent* purely because both
were demoted.

## 3. Design

Demotion is enforced at **Layer 1 (pool feasibility)**, not as a score penalty —
a penalty only reorders, and the report is that demoted items keep *appearing*.
The drop mirrors the existing rain-resistance gate: a soft preference with an
explicit relax path, never a hard gate that can strand a user.

```
L1 gates (gender / warmth / rain / formality)
   └── _drop_less_used(pool, keep_ids)          ← per category family
         ├─ family has non-demoted survivors  → drop the demoted ones
         └─ family is ENTIRELY demoted        → keep them (relax)
L2 compose
   └── zero candidates AND something was dropped
         → rebuild L1 with include_less_used=True, compose once more
   └── still zero → existing best-effort floor / wardrobe_gap paths
```

Three escape hatches, so a demotion can never cost the user an outfit:

1. **Fully-demoted family relaxes.** Demoting your only pair of shoes still
   gets you dressed.
2. **Compose-level retry.** Surviving L1 isn't enough — the survivors must also
   *compose*. If the demoted-free pool can't (e.g. the one remaining BOTTOM is
   `HIGH_RISK` against every anchor), the engine restores the demoted items and
   retries once, before the least-bad best-effort floor.
3. **Pinned item exempt.** `pinned_item_id` is passed as `keep_ids` — an explicit
   "build around THIS item" outranks the standing demotion.

Both spellings demote (`usage_frequency == 'LESS_USED'` **or** the legacy
`less-used` style tag), so items written before the column existed, or by a
client that hit the style-tag fallback path, are covered.

## 4. Files changed (`wardrobe-backend/`)

| File | Change |
|---|---|
| `blueprints/recommendation/engine_v05_constants.py` | `is_less_used()`, `style_signal_tags()`, `LESS_USED_MARKER_TAG`, `NON_STYLE_MARKER_TAGS` |
| `blueprints/recommendation/engine_v05_layers.py` | `layer1_feasibility(include_less_used=, keep_ids=)` + `_drop_less_used()`; style-signal reads routed through `style_signal_tags` |
| `blueprints/recommendation/engine_v05_signature.py` | `style_jaccard` / `dominant_style_tag` / `compute_vibe_signature` stop counting the marker tag |
| `blueprints/recommendation/engine_v05.py` | pass `keep_ids` (pinned item) to both L1 calls; compose-level safety retry; fallback flags |
| `services/wardrobe_service.py` | docstring — the endpoint is no longer display-only |
| `API_DOCUMENTATION.md` | documented recommendation effect + the three relax paths |
| `tests/test_v05_less_used_demotion.py` | **new** — 22 tests |

No migration, no schema change, no API contract change. **Mobile needs no change.**

## 5. Observability

| Signal | Where | Meaning |
|---|---|---|
| `less_used_demoted` | skipped log (per item) + `trace.fallback_flags` | item dropped from the pool |
| `less_used_relaxed_family_empty` | skipped log | family was entirely demoted, kept |
| `less_used_relaxed_no_compose` | `trace.fallback_flags` | survivors couldn't compose, demoted restored |
| `timings.L1_less_used_retry` | trace | cost of the safety retry |

`less_used_relaxed_no_compose` firing often would mean the drop is too
aggressive for real wardrobes — that's the metric to watch after deploy.

## 6. Verification

- 22 new tests pass (`tests/test_v05_less_used_demotion.py`), incl. end-to-end
  through `V05RecommendationEngine.build()`.
- Pre-fix simulation (L1 forced to `include_less_used=True`): 30/30 seeds served
  a demoted item. Post-fix: 0/30.
- Full backend suite diffed against baseline on the same machine — **identical
  failure set**, no regressions. (The ~182 pre-existing failures are environment
  gaps: missing `boto3`/google deps and `FakeItem` fixture drift, all present
  before this change.)
- `flake8` on the changed files diffed against baseline — no new findings.

## 7. Not done / follow-ups

- **`/v05-eval` not run** — needs a live DB + LLM keys, unavailable in this
  environment. Run it before merge to confirm outfit quality and the
  `PoolInsufficient` rate are unaffected on real wardrobes.
- **Live Redis `try_another` pools seeded before deploy** still hold demoted
  items until their TTL (`V05_TRY_ANOTHER_TTL_SECONDS`, default 1h) expires.
  Self-healing; flush the V05 session keys if the CEO wants it immediate.
- **Engine V2/V3 untouched.** Confirmed the mobile HomeScreen only calls
  `recommendV05` / `resetV05Session`; the legacy `/recommendation/next` path is
  not reachable from the suggestions surface.
- **Item-level favourite (`is_favorited`)** is the sibling gap flagged in the
  PR #148 plan §8 — still unaddressed, still a candidate for the inverse
  (promotion) treatment.

## Unresolved questions

- Should a demoted item be excluded from `try_another` variations *harder* than
  from the initial build? Currently identical (try_another recomposes via the
  same engine).
- Is the per-family relax the right granularity, or should TOP relax only when
  FULL_BODY is also starved (they're alternative anchors)? Current behaviour is
  the more permissive of the two.
- Deferred from PR #148 and still open: the Linear/GH issue id for traceability.
