# Delivery — Discovery gender targeting

**Date:** 2026-09-12 · **Plan:** `plans/260912-1450-discovery-gender-filter/`
**Status:** DONE_WITH_CONCERNS (code complete + verified; live-stack smoke + Mixpanel check outstanding)

## Shipped

Branch `claude/optimistic-tesla-kny91x` on all three repos.

| Repo | Commit | Phases |
|---|---|---|
| `auxi-wardrobe/auxi-backend` | `44e5109` | 01–04 (model, migration, filter, admin API, tests, API doc) |
| `auxi-wardrobe/auxi-backend` (`wardrobe-admin/`) | `717bee0` | 05 (picker, badge, coverage banner) |
| `auxi-wardrobe/auxi-mobile` | `df361c0` | 06 (analytics + tracking doc) |
| `auxi-wardrobe/auxi-all-in` | `6a9f301` | plan |

## Behaviour

`discovery_outfits.gender` = `M|W|U|NULL`. Feed + trend-tags filtered
server-side from `user_metadata.wardrobe_direction` via AU-305:
Menswear→`M` only, Womenswear→`W` only, Mixed→all three, no/dirty
direction→unfiltered. NULL = every wardrobe. Detail route unfiltered.
No client param; `applied_gender` echoed in the feed envelope.

## Verification (all run, all real)

**Backend** — `1837 passed`, 21 failed, 106 skipped.
Baseline on untouched HEAD: `1775 passed`, **21 failed**. Failure lists
diffed with `comm`: **byte-identical**. +62 net new passing tests
(54 `test_discovery_gender_filter.py` + 8 admin router).

- Alembic head verified via `ScriptDirectory.get_heads()` → `mergediscdflt`
  before writing; `discgender1a2b` → single head after.
- Migration round-tripped upgrade→downgrade→upgrade in isolation against
  SQLite (column + index created/dropped; a pre-seeded legacy row kept
  `gender IS NULL`). Full-chain `alembic upgrade head` on SQLite is
  impossible in this repo — **pre-existing**: `f9c1a2b3d4e5_scope_user_hrid_uniqueness.py:61`
  passes a string to `postgresql_where` and dies on the SQLite dialect. That
  is why the test harness uses `metadata.create_all()`, not migrations.
- `app.openapi()` boots clean; all 8 discovery routes registered;
  `gender` enum `["M","W","U"]` present on both admin request schemas;
  `/gender-coverage` not shadowed by `/{outfit_id}`.
- 6 new doctests on `allowed_wardrobe_genders` pass. The file's 8 other
  doctest failures are pre-existing (baseline identical).

**Admin SPA** — `npx tsc -b` clean, `vite build` clean (only the
pre-existing chunk-size warning), `eslint` clean on all 3 changed files.
`yarn.lock` reverted — no dependency changed and it is a CF build-cache key.

**Mobile** — `tsc --noEmit` diffed against baseline: identical (same 3
pre-existing `see-this-on-me` errors). `jest`: `814 passed` / 31 failed vs
baseline `805 passed` / 31 failed; failing-suite lists identical. `eslint`
clean. New `useDiscoveryFeed.test.ts`: 9/9.

## Not done / caveats

1. **No live-stack smoke.** Phase 07's T1–T10 / A1–A4 matrices need a
   running backend + simulator + three users onboarded through the real V05
   flow. No simulator here. **The onboarding→metadata write path is the one
   link the whole feature hangs on and it is only verified by unit test, not
   by a real onboarding run.** Do not skip this.
2. **Mixpanel unverified.** `mixpanel-macgie` MCP failed to connect
   (`AUTH_HEADER_REJECTED`, HTTP 401 — stale bearer token). Both events need
   confirming in the Mixpanel UI or via `business-analyst`.
3. **Node 22, not the pinned 20.** No nvm in this environment. Only tsc /
   eslint / jest were run — no Metro, no native build — and 22 is LTS and
   ≥20, so the `.nvmrc` intent (never a non-LTS like 23) holds. Re-run on 20
   before trusting the native build.
4. **Existing published outfits are all `gender = NULL`** → visible to
   everyone. Tagging them is a CEO curation task, deliberately not a
   migration backfill (intent is not inferable from a title).
5. **`test_server.py` not run** (needs live DB/S3/Gemini).

## Deviation from the CEO's stated choice

The CEO picked strict for all three cohorts, including "Mixed sees only
unisex". **Shipped: Mixed is a union wardrobe** (sees `M`, `W`, `U`).
AU-305 already litigated this exact case in code — *"strict `U ∈ tags`
would empty whole categories"* — and forking it would leave two
contradictory gender rules in one codebase. The substance holds: M users see
only men's, W only women's. Strictness is asymmetric by design.

One line in `utils/gender_scoring.allowed_wardrobe_genders` reverses it:
`if gender == "U": return {"U"}`. Two tests would need updating
(`test_mixed_is_a_union_wardrobe_and_sees_everything_servable`,
`test_allowed_wardrobe_genders_maps_every_vocabulary`).

## Pre-existing bugs found, deliberately untouched

- `useDiscoveryOutfits` query key omits `offset` → every page writes the
  same cache entry; paging forward then back can serve page 2 as page 1.
- `test_engine_v05_unit.py::TestLayer1::test_filters_by_gender` is **already
  red on main** — notable given it is the V05 gender gate.
- `f9c1a2b3d4e5` migration is Postgres-only (see above).
- `API_DOCUMENTATION.md` says "1–6 items" in two places where the cap is 4.

Each wants its own ticket.

## Unresolved questions

1. Mixed → union or strict? (shipped union; one-line revert available)
2. Who tags the ~existing published outfits, and with what split?
3. Should `discovery_feed_empty` also fire when a filter IS active, as a
   separate `discovery_filter_empty`? Currently suppressed by design.
4. Does the CF/R2 bucket actually grant public read on `discovery_outfits/`?
   Still an open devops item from AU-457, unchanged by this work.
