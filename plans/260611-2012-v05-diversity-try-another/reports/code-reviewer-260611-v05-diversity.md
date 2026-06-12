# Code Review — V05 axis→diversity pivot (`feature/v05-diversity-try-another`)

**Range:** `1d43902..HEAD` (7671dda, 5b070e5, 1624bb2, 0957065) · 45 files, +2813/−1677
**Verdict: 8.5/10 — 0 critical, 1 major, 5 minor.** Not auto-approve (< 9.5); ship after addressing or consciously accepting M1.

## Verified claims (ran code, not just read it)

- Distance parity: shoes-only swap on 4-item outfit = 0.30 in all three shapes (dict↔dict, dict↔sig, sig↔sig); numeric-vs-string item IDs normalize identically; `to_signature` idempotent; empty-seen → 1.0; both-empty/missing-field semantics match the docstring. Verified by direct execution.
- Floor consistency: `>= floor` on both engine (`engine_v05.py:839`) and service sides; service re-checks defensively after LLM-3 pick AND rule pick (`v05_try_another_service.py:738,785`). A below-floor outfit cannot reach the user unflagged on any normal path (relaxed serves carry `relaxed_distance` + halved `trace.distance_floor`; cycles carry `cycled=true`). One deep-session exception → M2.
- Ladder: retry fires ONLY on `recompose_pool_insufficient`, exactly once, at 0.5×floor; both-fail → cycle → terminal. Pinned by `TestGraduatedLadder` (asserts call counts + `BuildInput.min_distance` per rung).
- Reseed: `_extract_survivors` blocks picked/seen/current + below-floor, `append_pool_many` dedups vs existing pool hashes, top-K=3; only the served outfit enters `seen`/`seen_signatures`. Pinned by `TestPoolReseed` (asserts exact pool + signature contents).
- Legacy derive: `_ensure_signatures` backfills from `primary`+pool for resolvable seen hashes, in-memory on read, persisted on next write, never raises. Pinned by tests.
- IDOR: ownership check intact (`v05_try_another_service.py:207`, opaque 410); SETNX session lock + 429 intact; `get()` truncates session_id in logs.
- LLM-3 prompt: seen summaries are engine-derived enums (silhouette/color_family/layer_count) only — `style_feedback` never reaches the prompt. Injection surface unchanged (candidate item names, pre-existing).
- Perf: O(pool×seen) ≤ 20×30 = 600 trivial dict ops per pool pick; engine filter ~24×30. Negligible. 8s executor timeout path unchanged.
- Tests: 204 passed across the 17 touched/new V05 test files (1.09s). Includes a real-engine 10-tap session simulation (no mocks) asserting no dead-ends, pairwise-distinct serves, reseed observability.
- No stale `force_axis`/`current_signature` plumbing left in V05 production code (remaining hits are V2/V3/judge — different engines). API doc + mobile contract updated, incl. the analytics `force_axis`→`min_distance`/`seen_signatures_count` dashboard-migration warning.

## Major

**M1 — Session lock TTL (5s) vs ladder worst-case (~22s): lock expires mid-request, defeating C4.**
`acquire_lock` default `ttl_seconds=5` (`utils/v05_session_cache.py:253`), called with no override (`v05_try_another_service.py:184`). Worst case inside the lock is now 2× engine calls (8s each, `RECOMPOSE_TIMEOUT_SECONDS`) + 2× LLM-3 (3s each, `LLM3_TIMEOUT_S`) ≈ 22s. After 5s a concurrent tap acquires a "fresh" lock and both callers run GET→mutate→SETEX on the same session — lost `seen`/`seen_signatures` updates → repeat serves (the exact race C4 exists to prevent). Compounding: `release_lock` deletes unconditionally (no owner token), so the slow first caller deletes the second caller's lock on exit, opening a third entrant. *Pre-existing weakness (single rung was already 8+3 > 5s), but this diff doubles the window and adds a second LLM call.* Fix is cheap: `acquire_lock(session_id, ttl_seconds=int(2*RECOMPOSE_TIMEOUT_SECONDS + 2*LLM3_TIMEOUT_S + 2))`, or refresh the lock between ladder rungs; ideally token-guard the release (SET unique value, delete-if-match).

## Minor

**m2 — `seen` (unbounded) vs `seen_signatures` (cap 30) divergence can serve an unflagged repeat in >30-serve sessions.**
After 30 fresh serves the oldest outfits lose distance protection. The engine's `exclude_relaxed` hatch (`engine_v05.py:872-875`) can then restore an old SEEN outfit (its hash is still in `exclude_hashes`, but signature evicted → passes the distance filter), and the service drops engine fallback flags on the success path — the repeat ships as a fresh `recomposed` serve with no `cycled`/`exclude_relaxed` flag and an over-reported `trace.min_distance`. Requires >30 taps in one 1h session — rare. Cheapest mitigation: propagate the engine's `exclude_relaxed` flag into the response `fallback_flags` when present.

**m3 — Relaxed-rung survivors are pool dead weight.** Survivors from a 0.5×floor recompose pass only the relaxed floor; `_select_from_pool` enforces the strict floor on every later tap, so they get filtered forever while occupying FIFO slots (can evict servable entries). Consider filtering survivors at the STRICT floor regardless of the active rung.

**m4 — Reseed ordering deviates from plan wording.** plan.md §5 says reseed "surviving high-distance candidates (top-K)"; `_extract_survivors` sorts by `score` desc (`v05_try_another_service.py`, comment justifies it). Defensible (serve-time MMR re-ranks by distance anyway) — confirm intentional with the plan owner or update plan text.

**m5 — Worst-case latency doubled, single budget not shared.** The ladder can spend 8s (strict) + 8s (relaxed) sequentially; mobile sees up to ~22s before the cycle fallback. Consider deriving the retry timeout from remaining budget. (PoolInsufficient typically raises in <300ms, so the realistic path is fine.)

**m6 — Pre-existing: `_write` failure log leaks full session_id** (`utils/v05_session_cache.py:288-291`) while `get()` truncates to `[:8]` citing bearer-equivalence. Predates this diff; one-line fix worth folding in.

## Edge cases probed and cleared

- Relaxed path serving a duplicate: no — `exclude_hashes` (all seen + current) applies at both rungs; defensive distance check backstops (except m2 edge).
- Reseeded candidates duplicating pool/seen: no — dedup at both `_extract_survivors` and `append_pool_many`; FIFO eviction safe because signatures survive in `seen_signatures`.
- `create()` seeding all /build cards: alternates near-identical to any visible card now floor-filtered on tap 1 — intended per plan ("everything already shown"), `seen` hash list semantics (StaleHash contract) untouched.
- Engine distance filter no-op when `seen_signatures` empty — correct (`min_distance_to_seen` returns 1.0 anyway); legacy sessions always resolve ≥1 signature via `primary` in practice.
- Float-edge: served distance exactly at floor passes (`>=`) consistently on both sides.

## Positive

- Clean ownership split: engine filters strictly, service owns the relaxation ladder (no more engine-side `axis_relaxed` silent hatch) — well-commented, easy to reason about.
- Signature/dict parity guaranteed by single-source comparators (`engine_v05_axis` aliases) + carrying `footwear_ids` beyond the planned shape for exact parity.
- Trace observability (`min_distance` measured pre-`append_seen`, `distance_floor` per rung) is exactly what Phase 6 tuning needs.
- Test suite pins behavior, not implementation happy paths: engine-call counts, `BuildInput` contents per rung, exact pool/signature state, cap eviction, legacy derive, real-engine 10-tap simulation.

## Recommended actions (priority order)

1. M1: raise lock TTL to cover the ladder worst case (or refresh between rungs) + token-guard `release_lock`.
2. m2: surface engine `exclude_relaxed` into response `fallback_flags`.
3. m3: filter reseed survivors at the strict floor.
4. m6: truncate session_id in the `_write` warning.
5. m4/m5: confirm-as-intended; no code change required.

**Unresolved questions**
- Is score-ordered (vs distance-ordered) reseed intentional vs plan.md §5 wording? (m4)
- Should the relaxed rung skip its second LLM-3 call (cost: +3s, +1 paid call per exhaustion; cache key will miss since the candidate set differs)?

---

## Re-review — `f5a34d7` verification (260611-2304)

**FINAL: 9.5/10 — 0 critical, 0 major, 0 blocking minor.** All findings closed correctly; no new bugs introduced. Tests: 97 passed across the 4 touched files; full V05 sweep 557 passed / 31 failed — all 31 in the declared pre-existing env-dependent baseline (engine compose/integration/repetition/unit + onboarding-integration), zero in diversity-touched suites.

### M1 — CLOSED (verified, not just read)
- TTL: `V05_SESSION_LOCK_TTL_SECONDS` (config.py, default 30) ≥ worst case 2×8 + 2×3 + 2 = 24. Pinned by `test_lock_ttl_covers_ladder_worst_case`, which derives the bound from the live module constants — a future default bump of recompose/LLM-3 timeouts without a lock-TTL bump fails CI.
- Token guard: `acquire_lock` returns uuid4-hex token or `None` (SETNX with token value); release is compare-and-delete — Lua when the client supports scripting, bytes-safe GET/compare/DEL fallback otherwise. End-to-end expired-holder→successor scenario pinned (`test_expired_lock_successor_not_deleted_by_first_holder`).
- Exception flow audited: acquire happens BEFORE `try`; `None` → `SessionLocked` raised holding nothing (no release needed, nothing leaks); release with token in `finally` (`v05_try_another_service.py:187-193`). Repo-wide grep: exactly ONE call site, no caller anywhere (prod or tests) still uses the old bool/no-token signature.
- Degrade-open preserved: redis `None` → token returned, release noops; redis up at release for a never-set key → compare fails → noop. Safe.

### m2 — CLOSED
Engine emits `exclude_relaxed` in `trace["fallback_flags"]` (`engine_v05.py:875`); service reads it MagicMock-safely (`isinstance(out_trace, dict)`, lines 746-751) and carries it on BOTH success returns (llm3_pick :786, rule-based :847) into response `fallback_flags` (:354). Retry-success correctly takes flags from the rung that served (`recompose_flags = retry_flags`). When the hatch fires the entire restored candidate set is previously-SEEN, so the flag is accurate regardless of picker. API doc tells mobile/analytics to treat it like `variations_cycled` (not a fresh serve). Pinned positive + negative by `TestExcludeRelaxedPropagation`.

### m3 — CLOSED
`_extract_survivors` filters at `V05_MIN_DISTANCE` unconditionally; `min_distance` param removed and both call sites updated (no TypeError risk — grep-verified). Pinned by a carefully constructed mid-band candidate (d=0.30: above 0.175 relaxed, below 0.35 strict, highest score) asserted OUT of the reseeded pool. API doc updated.

### m6 — CLOSED
`_write` warning truncates `session_id[:8]` (`v05_session_cache.py:338`), consistent with `get()` (:159).

### m4/m5 — documented as intentional
m4 rationale in `_extract_survivors` docstring (reseed order only decides FIFO survival; serve-time re-ranks by distance); m5 latency-budget comment in the ladder with cross-ref to the lock TTL. Matches the prior review's confirm-as-intended disposition.

### Residual nits (informational, non-blocking)
1. `release_lock` fallback (`r.get`/`r.delete`) is not exception-wrapped — a redis outage between acquire and release propagates from the `finally` and 500s an otherwise-successful serve. Same class as the pre-fix unconditional `r.delete` (NOT a regression), but the new docstring claims "Noop when … the cache is unavailable", which only holds for the redis-is-None case. One-line `try/except` would make behavior match the docstring.
2. Lua release path has no CI coverage: local fakeredis lacks `eval` (raises `ResponseError` → suite exercised the fallback path, which behaved correctly). Script is the canonical Redlock compare-and-delete; low risk on redis-py in prod.
3. TTL invariant is static config: raising `V05_RECOMPOSE_TIMEOUT_SECONDS`/LLM-3 timeout via env without bumping `V05_SESSION_LOCK_TTL_SECONDS` silently breaks the coverage guarantee at runtime (test only pins defaults). Documented in three places; computing the default dynamically is a YAGNI-acceptable follow-up.

### Docs
`API_DOCUMENTATION.md` (reseed strict-floor note, `exclude_relaxed` flag row with mobile guidance, 429 lock semantics incl. token release) and `CLAUDE.md` (env-knob row) both updated — contract-doc rule satisfied; flag addition is additive, no breaking change to mobile.

**Verdict: ship.** 9.5/10 meets auto-approve threshold.
