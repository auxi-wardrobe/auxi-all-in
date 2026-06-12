# AU-306 Cold-Weather Fix — Implementation Complete

**Date:** 2026-06-01 · **Plan:** `plans/260601-2142-au306-cold-weather-fix/` (3/3 phases done)
**Scope (B):** mobile dominant fix + within-spec backend warmth bug-fixes. `<15C` threshold (#2) deferred to Viet.
**Changes left UNCOMMITTED in working trees** (auxi + wardrobe-backend on their existing feature branches, mixed with in-flight work). No commit/push performed.

---

## What changed

### auxi (mobile) — Phase 1
- `src/services/weatherService.ts` — **rewritten**: removed silent warm-22°C fallback. Now caches each good reading (AsyncStorage `auxi:last_known_weather`), and on `/weather` failure logs (`console.warn` + `Sentry.addBreadcrumb`) and returns last-known cache, else a MILD `NEUTRAL_WEATHER` (18°C) placeholder. Added `getLastKnownWeather()`. (#6)
- `src/screens/HomeScreen.tsx` — weather effect now resolves **real device coords via `getCurrentLocation()`** (was hardcoded Hanoi `21.0285,105.8542`). On geolocation failure → last-known weather → NEUTRAL, all logged, never silent-warm. Weather state carries `condition`; build body derives `is_rainy` from it (was hardcoded `false`). Kept the `weatherLoaded` gate. (#1, #6, is_rainy)
- `src/services/__tests__/weatherService.test.ts` — updated to the new contract (cache + observable fallback + NEUTRAL 18°C). **6/6 pass.**

### wardrobe-backend — Phase 2
- `blueprints/recommendation/engine_v05_layers.py`:
  - `_warmth()` default `3 → 0` (fail-closed). Untagged items no longer leak into COOL `[3,4,5]`; consistent with `engine_v05.py`'s `0` default. (#4)
  - `_has_cool_weather_layer()` OUTER branch now requires `_warmth(it) >= WARM_OUTER_THRESHOLD` (3) — enforces Viet's locked 2026-05-13 decision; a warmth-1 light blazer no longer satisfies F6. Imported `WARM_OUTER_THRESHOLD`. (#3)
- `services/v05_try_another_service.py` — recompose `temp_c` no longer defaults to warm `20.0`; logs a warning and uses a MILD `18.0` when ctx lacks it (temp_c is normally persisted at build, so this only bites legacy sessions). (#5)
- `tests/test_v05_engine_weather_safety.py` — fixed pre-existing `FakeItem` fixture (added `image_png`, broken by the cutout branch) **and** added `TestAU306ColdWeatherWarmth` (5 new regression tests).

---

## Eval (thật kĩ)

| Check | Result |
|---|---|
| Backend warmth/weather/recompose blast-radius suite | **118 passed** (incl. 5 new AU-306 regression tests) |
| `test_v05_engine_weather_safety.py` (17) | all pass (was 6 erroring on a pre-existing fixture gap — fixed) |
| Mobile `weatherService.test.ts` (6) | all pass |
| auxi `tsc --noEmit` | 0 new errors (only pre-existing `_HomeScreen.tsx` + `reactotron` baseline) |
| auxi `eslint` (my files) | 0 new (introduced 1 exhaustive-deps error, fixed it) |
| **End-to-end engine demo** | 25°C→light items · 16°C→mid(3) no outer · **5°C→warm(4) + coat(4), untagged/light excluded** |

**Full-suite context:** 58 backend + 9 mobile failures exist on these branches but are **all pre-existing, orthogonal to AU-306** — proven by error type: `image_png` FakeItem gaps (cutout branch), `/weather` route 404s (test app), `V05RecommendationEngine` mock drift, `GeminiJobManager` import (gemini), RN `useNavigationState`/ESM-transform jest gaps. My changes introduce **zero** new failures (blast-radius suites all green).

---

## Deferred / env-blocked (NOT done — need infra or CEO)

1. **#2 `<15C` threshold** — CEO-locked; deferred to Viet per scope decision. Needs a Linear comment asking what "cold" means + repro.
2. **Prod-mirror null-rate query (Phase 2 Step 0)** + **untagged-warmth backfill (Step 2a)** — `PG:5433` not running. The code flip is safe in tests; before prod rollout, run the query and backfill untagged OUTER if the null-rate is non-trivial.
3. **Full `evals/v05-outfits-eval.py` `pool_insufficient` baseline comparison** — needs live data/stack; substituted with deterministic unit + engine-demo evidence.
4. **iOS sim smoke (qa-mobile)** — sim/stack not booted; substituted with jest + tsc/lint.
5. **Mobile fallback tiering** — implemented last-known-weather → NEUTRAL(18°C); the plan's locale-coarse coords tier (b) was skipped as YAGNI (over-engineering for an edge case). Last-resort still logs when used.
6. **try_another 3a (explicit persist + "session stale" signal)** — temp_c is already persisted at build (`v05_build_service.py:137,199`); I de-warm-biased the fallback + added logging rather than introduce a new client contract. The "rebuild required" signal is a follow-up if legacy-session logs show it firing.

---

## Coordination notes

- **Cross-repo / tech-lead:** Phase 2 edits `engine_v05_layers.py`, the same file as the in-flight **dress-exclusion** work (different functions — `_warmth`/`_has_cool_weather_layer` vs `select_anchors`/`layer6_diversify`). No line collision, but tech-lead should reconcile before merge; the F6 FULL_BODY branch is the shared surface.
- **Commit hygiene:** both submodule trees are dirty with unrelated in-flight work (collage-canvas on auxi; dress-exclusion + cutout + feedback on backend). My AU-306 hunks are surgical and enumerated above; staging only those per repo is recommended over a blanket commit.
- **Git note:** a stray `git stash`/pop during eval was a no-op (reflog confirms no apply); the 2 pre-existing `feedback-phase1` stashes are intact.

## Open questions

1. What does Viet mean by "cold" (15-19.9°C borderline vs sub-15°C)? Drives whether #2 reopens.
2. Production `warmth_level` null-rate (needs `:5433`) — decides backfill urgency before the `_warmth` default flip ships.
3. Which commit is live on Railway (rule out the `bc51084` widened-COOL branch).
