# Tech-Lead Review — PR #71 (V05 try_another sustain)

- **PR**: auxi-wardrobe/auxi-backend#71 · branch `feat/v05-tryanother-sustain-pool` → `main`
- **Reviewer**: tech-lead (read-mostly, no code edits)
- **Date**: 2026-05-28
- **Verdict**: **APPROVE-WITH-CONDITIONS**
- **Mobile `cycled` sync must land before merge?**: NO for merging the backend PR; **YES before the mobile release that flips to this backend** (deploy-order gate).

---

## Verdict summary

Backend PR is correct, well-tested (90/90 V05 tests green), additive on the wire, and ops-safe.
APPROVE the backend merge. The only hard conditions are (1) **deploy ordering** vs the
mobile `cycled` sync and (2) **submodule pin discipline** in the umbrella — neither blocks the
backend merge itself, but both block the umbrella bump / mobile ship.

---

## Per-item assessment

### 1. API contract change — `cycled: bool` + relaxed no-repeat guarantee — ACCEPTABLE
- `TryAnotherResponse.cycled: bool = Field(False, ...)` (`schemas/v05_try_another.py:87`). Additive,
  default `false`. Old clients that don't read it are unaffected (extra field, deserialize-and-ignore).
  **Non-breaking on the wire. PASS.**
- Guarantee relaxation "no UNFLAGGED repeats": fresh outfits still never repeat; repeats are explicitly
  flagged `cycled=true` + `fallback_flags=["variations_cycled"]`. This is the intended product call
  (unlimited try_another). Documented honestly in the schema docstring and API_DOCUMENTATION.md §V05.
  **ACCEPTABLE** — it's a deliberate, flagged semantic change, not silent drift.

### 2. Cross-repo sync — MOBILE SYNC IS NOT MERGED (uncommitted working-tree only) — CONDITION
- `auxi/src/services/v05Api.ts` and `HomeScreen.tsx` DO handle `cycled` / `variations_cycled` /
  `wardrobe_gap` correctly when present:
  - `v05Api.ts:673` `cycled = data.cycled === true || data.fallback_flags?.includes('variations_cycled')`
  - returns `RecommendV05Result { outfits, cycled, wardrobeGap }`; `cycled` re-served outfit rendered
    normally; `wardrobeGap` → terminal CTA; `home-cycled-hint` testID for the subtle hint.
  - **The field is consumed safely; mobile would NOT break or mis-render a cycled response.**
- BUT the committed state is the problem:
  - `git show HEAD:src/services/v05Api.ts | grep -c cycled` → **0** (NOT in committed auxi HEAD `bae0180f`).
  - `git show HEAD:src/screens/HomeScreen.tsx | grep -c cycled` → **0** (committed HEAD lacks it too).
  - The entire `cycled` sync exists ONLY as **uncommitted working-tree changes** on branch
    `feat/home-remix-canvas-figma`.
  - The branch `feat/v05-tryanother-client-sync` IS an ancestor of HEAD, but its committed
    `v05Api.ts` also has 0 `cycled` references — i.e. the "reported sync branch" does NOT carry the
    sync in committed form. The actual sync is loose, uncommitted local work.
- **Safety w/o the mobile sync**: even an OLD mobile client is safe. `cycled` is additive; a client
  ignoring it just renders the re-served outfit as a normal one-element batch (the pre-FU-04 façade
  already maps `data.outfit ? [data.outfit] : []`). No crash, no mis-render — worst case the user
  doesn't see the "seen them all" hint. So **backend can deploy ahead of mobile safely.**
- **CONDITION**: the mobile sync must be (a) committed to an auxi branch, (b) merged, (c) the umbrella
  submodule pin bumped — BEFORE the mobile release that depends on the hint UX. Do not pin the umbrella
  to an unmerged/uncommitted auxi HEAD.

### 3. Warmth band widening — CORRECT, low quality risk — PASS
- `warmth_constraint` (`engine_v05_constants.py:219-252`): `>28→[0,1,2]`, `>=20→[0,1,2,3]`,
  `>=15→[2,3,4]`, `<15→[2,3,4,5,6,7]`+l3_required.
- HOT still excludes warmth≥3 → "no sweater at 35°C" preserved. PASS.
- **MILD slides exclusion preserved AND strengthened**: at MILD allowed=`[2,3,4]`; footwear gate active
  (`temp_c 15 < FOOTWEAR_WARMTH_GATE_TEMP=22`, `engine_v05_layers.py:203-208`) → warmth-1 slides
  filtered (`1 not in [2,3,4]`). The new floor=2 is *tighter* on footwear than the old `[2,3]` would
  have been functionally identical for w=1; no regression. PASS.
- **COOL floor=2 reasoning sound**: `l3_required=True` forces a warm OUTER (≥3) / FULL_BODY (≥4) via the
  divergent thresholds (`engine_v05_layers.py:1163-1168`). A light base (w≥2) under a mandatory coat is
  realistic layering, not under-dressing. PASS.
- Residual risk (minor): WARM now admits warmth-0 ("untagged/very light") which could surface an
  untagged item at 20°C. Bounded — formality + gender gates still apply, and warmth-0 = "very light"
  is climate-appropriate for 20-28°C. Acceptable.

### 4. COOL common-injection — containment sufficient — PASS
- COOL-only (`l3_required` guard, `engine_v05.py:472-489`); WARM/MILD/HOT never diluted.
- Thin-family enrichment is ADDITIVE + NON-FATAL: only truly-EMPTY (`starved`) families raise
  WardrobeGapError; thin-only misses compose from the user's own pool (`engine_v05.py` `if not common
  and starved:` guard). PASS.
- Dilution containment: injected items tagged `_is_common_injected` → `source: common_essential` and
  carry the `COMMON_INJECTED_PENALTY=0.9` multiplier. 0.9× + COOL-only scoping is adequate — the
  penalty deprioritizes commons so user-owned cold pieces win when they exist; commons only fill the
  genuinely thin tropical-wardrobe-at-10°C case the eval measured. PASS.
- `self.db is None` guard in `_load_common_safety_items` (`engine_v05.py:1121-1126`) cleanly separates
  pure-pool unit tests from production catalog lookups. Good defensive hygiene.

### 5. Cycle contract risk — no correctness hole found — PASS
- **No "repeat treated as fresh"**: `cycled=true` + `variations_cycled` flag + populated `outfit`;
  mobile reads the top-level flag as authoritative (`v05Api.ts:673`). Honestly labeled.
- **Pinned-item integrity**: `_cycle_response` filters re-serve candidates by `pinned_item_id`
  (`v05_try_another_service.py:846-854`); if nothing seen carries the pin → returns None → honest
  fallback. No pin violation. PASS.
- **Seen-set integrity**: cycle intentionally does NOT append to `seen` (already present; idempotent,
  `v05_try_another_service.py:874-876`) and does not mutate the pool. No corruption.
- **Mid-session wardrobe_gap → cycle**: the FU-05 change attempts cycle FIRST regardless of the
  recompose `wardrobe_gap_*` flag, falling to honest `outfit:null` + `wardrobe_gap` only when nothing
  is re-serveable (`v05_try_another_service.py:217-247`). Correct: mid-session "can't compose NEW"
  ≠ initial-build "can't dress climate at all". The genuine gap CTA still surfaces via `_fallback_response`.
- **Concurrency**: per-session SETNX lock (`SessionLocked`→429) still guards the GET→mutate→SETEX race.
  Untouched by this PR. PASS.

### 6. Migrations / deploy — NO migration; env vars are additive-with-defaults — OPS PASS (note env)
- **No DB migration.** No schema/column change. Redis-only session state.
- **No NEW required env var.** All new knobs have safe code defaults:
  - `V05_COOL_ENRICH_DEPTH` (default 6) — new.
  - `V05_BUILD_ALTERNATES` raised default 4→8 (existing var, larger Redis session payload only).
  - `V05_RECOMPOSE_RESEED_CAP` (default 12), `V05_RECOMPOSE_TIMEOUT_SECONDS` (8.0) — existing/defaulted.
- **Ops action (informational, not blocking)**: none required for correctness. Optionally set
  `V05_BUILD_ALTERNATES`/`V05_COOL_ENRICH_DEPTH` in Railway if ops wants to tune; defaults are safe.
  Slightly larger Redis payload per session (8 vs 4 alternates) — negligible at current scale.
- Pool cap `V05_MAX_POOL=10` FIFO-caps the reseed, so RESEED_CAP=12 can't unbounded-grow the session.

---

## Conditions (must satisfy before the dependent mobile ship)
1. **Deploy order**: merge + deploy backend FIRST (safe — additive field, old mobile degrades
   gracefully). THEN commit/merge the auxi `cycled` sync, THEN bump the umbrella submodule pin, THEN
   ship mobile. Do NOT pin the umbrella to the current uncommitted auxi working tree.
2. **Mobile sync is uncommitted** — the `cycled` handling in `v05Api.ts` + `HomeScreen.tsx` is loose
   working-tree work, not in committed HEAD `bae0180f` nor in the "client-sync" branch's committed
   form. mobile-dev must commit it to a clean branch and open its own PR. Backend merge does not wait
   on this, but the umbrella pin bump does.
3. **API_DOCUMENTATION.md updated** — confirmed (§V05 lines ~3813-4157 cover `cycled`,
   `variations_cycled`, the never-dead-end shape, and the flag table). PASS.

## Non-blocking observations
- MILD-edge (15°C) fresh variety modest (~2-7) — bounded by compose breadth, not starvation. The PR
  flags this as a separate recompose-breadth follow-up. Agreed, out of scope here.
- WARM admitting warmth-0 is a minor quality watch item, not a blocker.
- Umbrella submodule pin currently `ba724ea` for auxi while auxi HEAD is `bae0180f` — pre-existing
  drift, unrelated to this PR, but worth a separate pin-hygiene pass.

## Unresolved questions
- Was the historical `feat/v05-tryanother-client-sync` branch's content superseded/rebased away?
  Its committed `v05Api.ts` has 0 `cycled` refs despite being an ancestor of auxi HEAD. mobile-dev
  should confirm the canonical home of the sync before committing.
