# V05 "Try Another" — Pool-Exhaustion Mechanics & Sustaining 10+ Taps

- **Date:** 2026-05-27
- **Scope:** READ-ONLY analysis, `wardrobe-backend/`
- **Branch:** `feat/v05-tester-simplify-and-rate-limit`
- **Trigger:** App got `outfit:null, fallback:true, variation_axis:"footwear"`,
  flags `["pool_exhausted","recompose_failed","recompose_pool_insufficient"]`,
  `pool_sizes_after_L1:{}` — user frustrated that try_another runs out fast.

This is a **known, documented issue**: `docs/pm/inbox/WAR-V05-followup-04-try-another-pool-depletion.md`
(P2, backend-dev). The observed response is the textbook tail-of-session
depletion case described there.

---

## 1. What each flag means + the pool vocabulary

The observed `fallback_flags` are assembled in
`services/v05_try_another_service.py:201-210`:

```python
return self._fallback_response(
    ..., ["pool_exhausted", "recompose_failed", *recompose_flags], ...)
```

So the three flags are emitted **in sequence as one failure cascade**:

- **`pool_exhausted`** — The cached Redis "pool" (the build-seeded alternates
  + any recomposed outfits appended later) had **no surviving candidate** after
  filtering out already-seen hashes + the current hash + (when an explicit axis
  was requested) candidates that don't vary on that axis. This is the
  `candidate is None` branch at `v05_try_another_service.py:189`. It is a hard
  literal: the in-memory pool is dry, **not** that the wardrobe is empty.

- **`recompose_failed`** — Because the pool was dry, the service fell through to
  Phase 4 recompose (`_recompose`, line 198). Recompose ran the engine
  (`V05RecommendationEngine.build()` with `force_axis` + `exclude_hashes`) and
  it **returned no usable outfit** (`recomposed is None`, line 201). This is the
  umbrella "recompose didn't save us" flag.

- **`recompose_pool_insufficient`** — The *specific* reason recompose failed.
  It is the `recompose_flags` element appended at
  `v05_try_another_service.py:552-554` when the engine raised
  `PoolInsufficientError`. Inside the engine that error is raised at one of
  several gates (`engine_v05.py`): no anchors in the cutoff
  (`no_anchors_in_top_30pct`, L2, line 604), no composable outfits
  (`no_valid_outfits_after_L2`, line 692), or — **most relevant here** — no
  candidate survived the `force_axis` / `exclude_hashes` filter
  (`no_outfits_after_force_axis_or_exclude_filter`, L5, line 874-884).

Other terms:

- **The "pool"** = the Redis session list `state["pool"]`
  (`utils/v05_session_cache.py`). Seeded at `/build` from the engine's L2
  oversample leftovers (`out.alternates`), capped at `V05_MAX_POOL=10` with
  FIFO eviction. It is **per-session**, keyed by `session_id`.

- **`variation_axis`** (silhouette / color / layering / footwear / accessory) =
  the single dimension the next outfit must differ on. When the client doesn't
  send `axis`, the backend cycles it by seen-count:
  `_pick_axis` (`v05_try_another_service.py:334-342`) over
  `_AXIS_CYCLE = [SILHOUETTE, LAYERING, COLOR, FOOTWEAR, ACCESSORY]`.
  Here `"footwear"` means this was (seen_count-1) % 5 == 3 → 4th cycle position.

- **`pool_sizes_after_L1` is `{}`** because this trace was built by the
  **try_another service**, not the engine. The service's `_trace()`
  (`v05_try_another_service.py:737-757`) hard-codes
  `pool_sizes_after_L1={}` — it never has the engine's L1 pool snapshot in
  scope (the recompose engine call happens on a worker thread and its trace
  isn't threaded back into the fallback response). So `{}` here means
  **"not populated by this layer"**, NOT "the L1 pool was empty". The real L1
  pool snapshot at the failing recompose is captured in the
  `v05_pool_insufficient` structured event (engine `_emit_and_raise`,
  `engine_v05.py:270-330`) — that's where to look in logs for the real numbers.

---

## 2. How the pool is built + depleted per session

### Build-time seeding (`services/v05_build_service.py:196-217`)
1. `/build` runs the engine once. The engine over-samples at L2
   (`n_anchors = max(count*3, COMPOSE_ANCHOR_COUNT=6)`,
   `COMPOSE_VARIANTS_PER_ANCHOR=2`) and returns `count` primaries +
   `alternates` (capped at `V05_BUILD_ALTERNATES=4`, `engine_v05.py:910-925`).
2. The service writes a Redis session: `primary`, `pool = alternates[:10]`,
   `seen = [primary_hash]`, `context`, `user_id`, `created_at`.
   (`V05SessionCache.create`, `v05_session_cache.py:51-76`). TTL 1h.

So a **fresh session starts with at most 4 alternates in the pool** (often
fewer on sparse wardrobes), plus the primary marked seen.

### Per-tap consumption (`_try_another_locked`, `v05_try_another_service.py:161-238`)
1. SETNX per-session lock (C4) — concurrent taps get 429 `session_locked`.
2. Load session; IDOR check; assert `current_outfit_hash ∈ seen`.
3. `_pick_axis` (or client axis).
4. `_select_from_pool` (line 344): drop everything in `seen` + current hash;
   apply `pinned_item_id`; if an **explicit** axis was requested, hard-filter to
   `axis_diff(current, o, axis) > 0`; score `1.0·axis_diff + 0.3·score +
   0.5·style_feedback_fit`; return `max`.
5. On a hit → append chosen hash to `seen`, return. **The pool list is never
   shrunk** — dedup is purely via the growing `seen` set.
6. On a miss (pool dry) → recompose; on recompose success append the new
   outfit to **both** `pool` and `seen` (lines 212-213).

### Where state lives
- **Redis only**, key `v05_try_another:{session_id}` (1h TTL refreshed on every
  write). No DB, no in-memory process state. Lock key
  `v05_session_lock:{session_id}` (5s TTL).
- If Redis is unavailable, `/build` degrades to `session_id=None` and
  try_another is impossible (client must rebuild).

### Axis rotation
- Client-driven if `axis` provided; else cycled by `(len(seen)-1) % 5` across
  the 5-axis cycle. Note the rotation is **stateless** — it's derived from seen
  count each call, so it always advances regardless of which axes succeeded.

---

## 3. Root cause of fast exhaustion (this case)

The failure is a **two-stage starvation** and the trace + the FU-04 eval
nail it:

**Stage A — the cached pool drains in ~2-4 taps.** Build seeds ≤4 alternates.
Each tap consumes one (via `seen` dedup). The accessory axis is *structurally
broken* (FU-03) so any accessory tap burns a cycle without ever serving from
the pool. So within the first cycle the pool is dry and **every** subsequent
tap must recompose.

**Stage B — recompose can't keep producing on-axis distinct outfits.** This is
the actual `recompose_pool_insufficient`. Three compounding constraints choke
the engine on the recompose path:

1. **Single-variant, anchor-bounded recompose.** On the force_axis path the
   engine composes `n_variants=1` per anchor (`engine_v05.py:653-654`) and the
   anchor set is bounded by the user's TOP+FULL_BODY pool *after* gender +
   climate (warmth) filtering. The FU-04 eval's rich W wardrobe (16 TOP) still
   only has ~5-6 *effective* anchors after filtering — and far fewer on a real
   user's smaller wardrobe.

2. **The rolling anchor exclusion.** `_collect_anchor_excludes`
   (`v05_try_another_service.py:242-305`) feeds the anchor item IDs from the
   **last 5 served outfits** into `BuildInput.exclude_ids`, forcing the engine
   to pick *different* TOP/BOTTOM/FULL_BODY anchors. On a sparse wardrobe this
   excludes nearly the whole anchor pool by the 4th-5th tap → L2 `select_anchors`
   returns `[]` → `no_anchors_in_top_30pct` OR L2 composes nothing →
   `no_valid_outfits_after_L2`. (The window was *already* tuned down from an
   absolute cap of 20 to a window of 5 precisely because of this — see the
   F2-tune comment at lines 74-83 — but a window of 5 is still ≈ the entire
   effective anchor pool on a small wardrobe.)

3. **The hard `force_axis` post-L5 filter.** Even when L2 composes candidates,
   the post-L5 axis filter (`engine_v05.py:810-848`) drops every candidate that
   doesn't flip the requested axis, then `exclude_hashes` drops every
   already-served hash (line 850-862). For the **footwear** axis in this trace:
   footwear variety is bounded by the number of distinct FOOTWEAR items that
   pass climate filtering; once each shoe has been paired with the surviving
   anchors and those hashes are all in `exclude_hashes`, the filter empties the
   pool → `no_outfits_after_force_axis_or_exclude_filter`. The engine has a
   graceful "axis_relaxed" degrade (lines 842-848) but `exclude_hashes` runs
   *after* it and can still empty the set.

**Net:** the wardrobe + axis + dedup math runs out of *distinct on-axis
combinations* the engine is willing to emit, after the small seeded pool is
consumed. FU-04's eval measured exactly this: first cycle (taps 1-5) 80% axis
success, second cycle (taps 6-10) 53%, the gap "entirely 2nd-cycle pool
depletion." `footwear` here was the axis on the cycle position that hit the
wall.

This is **not** a wardrobe-gap (no `wardrobe_gap` flag) and **not** an LLM-3
picker fault (the picker never gets candidates when `recompose_pool_insufficient`
fires — verified healthy in the eval).

---

## 4. Does a fresh `/build` reset the pool/session?

**Yes — completely.** `/build` always mints a **new** `session_id`
(`uuid.uuid4()`, `v05_build_service.py:196`) and writes a brand-new Redis
session with a fresh pool and `seen=[primary_hash]`
(`V05SessionCache.create`). It never reads or reuses an existing session.

Consequences:
- try_another **only** ever consumes the session whose `session_id` the client
  sends. It cannot "recover" an exhausted session — the exhausted `seen` list
  keeps growing and keeps shrinking the candidate space.
- A new `/build` gives a clean `seen=[primary]` and a fresh ≤4 alternate pool,
  so taps will succeed again until depletion recurs.
- **Frontend "stale flow across tabs" relevance:** because the session is pure
  Redis keyed by `session_id`, two tabs/screens that each ran `/build` hold
  **independent** sessions; a tab that calls try_another with a *stale*
  `current_outfit_hash` (not in *that* session's `seen`) gets `422 stale_hash`
  (`v05_recommendation.py:146-153`), and a tab using an expired/foreign
  `session_id` gets `410 session_expired` (IDOR check returns the same 410,
  service lines 177-178). The mobile contract says: on 410, silently rebuild.
  So the fix for "tabs out of sync" is client-side session ownership, but the
  backend behavior is deterministic: build = fresh session, try_another =
  bound to one session.

---

## 5. Ranked recommendations to sustain 10+ try_anothers

Ordered best-first. All are backend-only and live in the files above.

### #1 (BEST) — Reseed the pool when it falls below a threshold + deepen the recompose widen
**Change:** Two coordinated moves:
  - In `_try_another_locked`, after consuming a candidate, if
    `len(pool_after_dedup) < RESEED_FLOOR` (e.g. 2), fire **one** engine
    `build()` with `widen_candidates=True` (the LLM-3 wide path already exists,
    `engine_v05.py:785-795,995-1014`), take the axis-satisfying survivors that
    aren't in `seen`, and `append_pool` them (respecting the `V05_MAX_POOL`
    FIFO). This refills the pool *proactively* instead of waiting for a hard
    miss.
  - On the recompose path, request `count`-equivalent breadth: the widen path
    already composes `n_anchors=max(count*6, 6)` × `COMPOSE_VARIANTS_PER_ANCHOR`
    — surface **all** axis-satisfying survivors into the pool, not just the one
    picked outfit (today `_recompose` appends only the single chosen outfit,
    line 212).
**Why best:** Attacks the actual mechanic (supply running dry) at both the seed
and recompose stages, reuses code that already exists (widen_candidates +
`BuildOutput.candidates`), and keeps each tap a cache hit (fast, no per-tap
engine call after a reseed).
**Tradeoff / risk:** One heavier engine call on the reseed tap (mitigated: it's
amortized across the next N taps; widen path p95 was ~2.2s in eval, under the
2.5s SLA). Must dedup the reseeded outfits against `seen` and the existing pool
to honor the no-repeat contract. Medium implementation size.

### #2 — Relax the rolling anchor-exclusion window on sparse wardrobes
**Change:** Make `RECOMPOSE_ANCHOR_WINDOW` adaptive: scale it to the effective
anchor pool size (e.g. `min(5, effective_anchor_count // 2)`), or skip anchor
exclusion entirely once `len(seen) > effective_anchor_count`. Today it's a
fixed 5 (`v05_try_another_service.py:83`).
**Why:** Directly removes the "every anchor excluded by tap 4-5" choke
(Stage B #2). The FU-04 comment already acknowledges 5 ≈ whole anchor pool on
sparse wardrobes.
**Tradeoff / risk:** Loosening exclusion means more "same TOP/BOTTOM, different
shoe" outfits deep in a session — the exact pattern the F2-tune was added to
suppress. Acceptable *as a tail-of-session degrade* (better than a hard stop),
but needs a gate so it only loosens after the pool is genuinely strained, not
on tap 2. Low-medium size.

### #3 — Enlarge the seed pool: raise `V05_BUILD_ALTERNATES` + `V05_MAX_POOL`
**Change:** Env bump, e.g. `V05_BUILD_ALTERNATES=8`, `V05_MAX_POOL=16`, and
raise the engine's build oversample so ≥8 distinct alternates actually exist
to seed (`engine_v05.py:83`, `v05_session_cache.py:27`).
**Why:** Pushes Stage A exhaustion from ~tap 4 to ~tap 8-10 with near-zero risk;
the alternates are "free" L2 leftovers already computed at build.
**Tradeoff / risk:** Larger Redis payload per session (still small JSON). Does
**not** fix Stage B — once the deeper pool drains, recompose still chokes. Best
as a cheap **complement** to #1, not a standalone fix. Sparse wardrobes may not
even produce 8 distinct alternates, so the win is wardrobe-dependent. Trivial
size (config-led, but verify the engine actually emits that many alternates).

### #4 — Soft "you've seen them all" reshuffle instead of `outfit:null`
**Change:** When genuine exhaustion is hit (recompose returns None *and* a
reseed found nothing new), instead of `outfit:null + fallback:true`, serve a
**controlled repeat**: re-emit the highest-scoring *previously-seen* outfit on
that axis with a soft flag (e.g. `cycled:true`, message "You've seen them all —
here's a favorite again"). Cycle rather than hard-stop.
**Why:** Eliminates the dead-end UX entirely; the user can always tap again.
This is the product decision FU-04 AC explicitly asks to define.
**Tradeoff / risk:** Breaks the in-session no-repetition contract (a deliberate
correctness gate, `_select_from_pool` comment lines 352-355). Needs PM/tech-lead
sign-off and a distinct flag so the client renders it as "favorites" not "new".
Should only trigger after #1-#3 are exhausted. This is a **policy** change, not
just tuning — do not ship silently. Low code size, high coordination cost.

### #5 — Rotate across MORE axes / fix the dead accessory axis (FU-03)
**Change:** Fix accessory-axis zero-variation (separate ticket FU-03) so the
5-axis cycle actually has 5 working axes, widening the distinct-outfit space.
**Why:** Accessory is 0/6 today — one whole cycle position is wasted, which
*accelerates* perceived exhaustion (a tap that produces nothing).
**Tradeoff / risk:** Doesn't fix the depletion mechanic on its own, but removes
a guaranteed-fail axis. Tracked separately (FU-03, P1); fold the dependency into
the FU-04 fix. Medium size, already scoped elsewhere.

### Recommended package
Ship **#3 (cheap, immediate headroom) + #1 (the real fix: reseed + widen
surface) + #2 (adaptive window)** together, behind the existing env knobs so ops
can tune. Hold **#4** for a PM decision on terminal-exhaustion UX, and treat
**#5/FU-03** as a hard dependency for hitting the ≥80% full-session bar.

---

## Unresolved questions
- Product call (FU-04 AC): at genuine exhaustion, terminal "no more variations"
  vs controlled-repeat cycle (#4)? This needs PM, not backend, sign-off.
- The eval wardrobe is W-skewed; the M try_another path is **unvalidated**
  (M /build 422'd on the prod-mirror user). Any fix needs a re-eval on an
  M-gendered wardrobe before claiming the bar is met.
- Should the recompose engine's real `pool_sizes_after_L1` be threaded back into
  the try_another fallback trace? Today it's `{}`, which is misleading when
  debugging from the client response alone (the real numbers are only in the
  `v05_pool_insufficient` server event). Minor observability gap, worth a note.

## Key file:line references
- Flag assembly: `services/v05_try_another_service.py:189-210`
- Recompose + PoolInsufficient mapping: `services/v05_try_another_service.py:492-557`
- Pool select/dedup/axis filter: `services/v05_try_another_service.py:344-393`
- Rolling anchor exclusion: `services/v05_try_another_service.py:74-83, 242-305`
- Axis cycle: `services/v05_try_another_service.py:107-113, 334-342`
- Trace `pool_sizes_after_L1={}`: `services/v05_try_another_service.py:737-757`
- Session cache (Redis, TTL, FIFO cap): `utils/v05_session_cache.py:26-28, 51-130`
- Build seeds session: `services/v05_build_service.py:196-217`
- Engine recompose gates / force_axis + exclude_hashes filter:
  `blueprints/recommendation/engine_v05.py:584-657, 810-884`
- Alternates cap: `blueprints/recommendation/engine_v05.py:83, 910-925`
- Anchor selection bound: `blueprints/recommendation/engine_v05_layers.py:243-326`
- axis_diff semantics: `blueprints/recommendation/engine_v05_axis.py:31-101`
- Tickets: `docs/pm/inbox/WAR-V05-followup-04-try-another-pool-depletion.md`,
  `docs/pm/inbox/WAR-V05-followup-03-accessory-axis-zero-variation.md`
- Eval evidence: `wardrobe-backend/plans/reports/v05-eval-260525-1620-llm3-try-another.md`
