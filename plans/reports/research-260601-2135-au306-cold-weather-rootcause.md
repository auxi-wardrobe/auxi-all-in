# AU-306 Research — Cold-Weather Outfits Feel Too Light (Root Cause)

**Ticket:** [AU-306](https://linear.app/duncan-1/issue/AU-306/bug-cold-weather-outfit-suggestions-feel-inappropriate) · filed by Viet (CEO, `vietdesign81@`) · assigned Minh Đức · Todo · no repro steps
**Date:** 2026-06-01 · **Method:** 5-agent parallel code investigation (backend engine, weather contract, item metadata, mobile flow, evals/history) + manual verification on current HEADs
**HEADs verified:** auxi `d76d98b2`, wardrobe-backend `4d33c4a` (+ `origin/main` spot-check)
**Confidence:** HIGH (every claim cited file:line, verified on disk)

---

## TL;DR

Not one bug — a **stacked failure**: a *warm-biased temperature INPUT* meets a *permissive cold THRESHOLD*. Cold-weather outfits come out light because:

1. **(Mobile, dominant)** The app fetches weather for **hardcoded Hanoi coords** and never uses device location, so a cold-located user is dressed for warm Hanoi.
2. **(Backend)** Even with a correct cold temp, the engine only forces a layer below **strict `<15°C`**; 15–19.9°C is "MILD" → no outer, light items allowed.

⚠️ **The current auxi HEAD is literally the prior AU-306 fix** (`weatherLoaded` gate) — it fixed a 22°C placeholder *race* but **missed the real cause**. The ticket is effectively still open.

---

## Critical context: prior fix attempt is incomplete

`git log -1` on auxi = `d76d98b2 fix(home): gate initial recommendation until real weather is loaded (AU-306)`. That commit added a `weatherLoaded` spinner gate (HomeScreen.tsx:474, 771–783) so the first build waits for real weather instead of sending the `tempC:22` initial-state placeholder. **Good, but orthogonal** — it still fetches Hanoi's weather. Whoever picks this up must not assume AU-306 is addressed by that commit.

---

## Ranked root causes (verified)

| # | Cause | Where | Repo | Likelihood |
|---|-------|-------|------|-----------|
| 1 | **Hardcoded Hanoi coords; `getCurrentLocation()` has 0 callers** → cold user gets Hanoi's warm `temp_c`, faithfully wired to engine | `auxi/src/screens/HomeScreen.tsx:478-479` (`getWeather(21.0285,105.8542)`), `auxi/src/utils/location.ts` (unused) → `:582` `weather:{temp_c: weather.tempC}` | auxi | **HIGH** |
| 2 | **COOL/layer threshold is strict `<15°C`** → 15.0–19.9°C = MILD, `l3_required=False`, no OUTER appended, warmth-2 items pass | `engine_v05_constants.py:251-272` (`warmth_constraint`), gate at `engine_v05_layers.py:450-454`, L1 filter `:203-208` | backend | **HIGH** |
| 3 | **F6 cold-safety gate accepts ANY outer regardless of warmth** — violates CEO-locked "OUTER ≥3". Also COOL ceiling caps at warmth 5 (heavy coats 6-7 barred) | `engine_v05_layers.py:125-131` (`if fam=="OUTER": return True`) vs `WARM_OUTER_THRESHOLD=3` "Viet locked 2026-05-13 Q1" in constants | backend | **MEDIUM** |
| 4 | **Missing `warmth_level` defaults to 3** in selection filter (lowest value still in COOL `[3,4,5]`) → untagged/light items leak into cold. Inconsistent with default `0` used in starvation checks | `engine_v05_layers.py:99-100` vs `engine_v05.py:225,434` | backend | **MEDIUM** (depends on prod null-rate, see open Qs) |
| 5 | **`try_another` recompose defaults `temp_c=20.0` (WARM)** when session ctx lacks it → light variation outfits for a cold session | `services/v05_try_another_service.py:457` | backend | **MEDIUM** (variation path only) |
| 6 | **Silent 22°C fallback** on any `/weather` failure, no logging → cold masked as mild | `auxi/src/services/weatherService.ts:9-23` (`MOCK_FALLBACK temp_c:22`) | auxi | **MEDIUM** |
| 7 | AU-308 `style_refinement`/mood/novelty can up-rank lighter/sheer outfits, zero warmth term (re-orders in-bucket only) | `engine_v05_style_rules.py:247-271`, applied `engine_v05.py:770-776` | backend | LOW |
| 8 | PR#71 / `bc51084` widened COOL floor to warmth 2 — **REFUTED for prod**: `origin/main` still `[3,4,5]`. Only relevant if a non-main tree is deployed via `railway up` | constants vs `tech-lead-260528-0012` review | backend | LOW (confirm deploy) |

---

## Contract status (auxi ↔ backend)

Structurally **intact**, soft semantic drift:
- ✅ **Units consistent °C end-to-end** — not a °C/°F mix-up on the V05 path. No `temp_f`/`fahrenheit` anywhere in `auxi/src`.
- ✅ Weather **is** wired into the engine (refutes "climate-blind pipeline" theory server-side): `HomeScreen:582` → `v05Api` → `POST /v05/recommendation/build` → `v05_build_service.py:81` → `BuildInput.temp_c`. `WeatherDTO.temp_c` is **required** (`schemas/v05_recommendation.py:44`).
- ⚠️ **V2 `/start2` `temp_c` unvalidated** (`routers/recommendation.py:92-96`) — no range/unit guard; a Fahrenheit value → hot bucket. (V05 build clamps `[-50,60]`.) Confirm whether auxi ever calls `/start2` (Home uses V05 build).
- ⚠️ **`is_rainy` hardcoded `false`** at `HomeScreen:582` despite `condition` being available → engine `rain_no_waterproof` path unreachable from Home.
- ⚠️ **No `feels_like`** forwarded — `weather_service.py:37-53` drops OpenWeather `main.feels_like`; raw air temp under-dresses on windy/damp days.

---

## Fix surfaces

**auxi (highest impact):**
- `HomeScreen.tsx:476-483` — replace Hanoi literal with `getCurrentLocation()`; on deny/fail use last-known/locale, **not** silent Hanoi. *(fixes #1 — the single biggest lever)*
- `weatherService.ts:9-23` — instrument/remove silent 22°C fallback; log to Sentry, surface "weather unavailable". *(fixes #6)*
- `HomeScreen.tsx:582` — derive `is_rainy` from `condition` (Rain/Snow/Drizzle). *(fixes is_rainy drift)*

**wardrobe-backend (needs product/CEO call on thresholds):**
- `engine_v05_constants.py:251-272` — raise COOL/`l3_required` boundary (e.g. `<18°C`) **or** add 15–18°C "cool-ish" light-outer sub-bucket, **and** a COLD `<8-10°C` tier demanding warmth≥4 base. (Inline NOTE shows this was already flagged & deferred — reopening is a Viet decision.) *(fixes #2)*
- `engine_v05_layers.py:125-131` — F6 OUTER branch must enforce `_warmth(it) >= WARM_OUTER_THRESHOLD(3)` (the constant already exists per Viet's locked decision) instead of accepting any OUTER. *(fixes #3)*
- `engine_v05_layers.py:99-100` — change missing-warmth default from `3` to fail-closed (`0`/`1`); reconcile with default-0 elsewhere. *(fixes #4)*
- `v05_try_another_service.py:457` — persist `temp_c` in session ctx at build; don't default to 20.0. *(fixes #5)*
- `routers/recommendation.py:92-96` — add `ge=-50, le=60` bound on V2 `temp_c`. *(closes °F gap)*

---

## Verification plan

1. **Repro #1 (mobile):** run auxi on local backend `:5001`; inspect actual `POST /v05/recommendation/build` body — `temp_c` sent = Hanoi temp regardless of real location. (Or temp-edit `:479` to cold coords and watch outfits warm up.)
2. **Repro #2 (threshold):** `POST /build` with `temp_c=16.0` vs `14.0` against a wardrobe with light+warm items → confirm 16°C returns no OUTER + warmth-2; 14°C forces layer. Demonstrates the cliff at 15°C.
3. **Repro #3 (F6 weak gate):** at `temp_c=5.0`, confirm a warmth-1 blazer passes `_has_cool_weather_layer`.
4. **Eval harness gap:** run `v05-eval` skill / `evals/v05-outfits-eval.py` cold scenarios. **Current rubric only hard-rejects "severe exposure <5°C, no outer"** (presence-of-outer only). ADD assertions: (a) 15–19.9°C carries a layer, (b) outer meets warmth floor, (c) 2°C outfit materially warmer than 14°C. `au308-style-rules-eval.py` has zero weather cases.
5. **Data hygiene:** prod-mirror PG `:5433` → `SELECT count(*) FROM wardrobe_items WHERE styling_metadata->>'warmth_level' IS NULL` to size the default-3 leak (#4).
6. **Confirm deployed commit:** ask devops which commit is live on Railway (manual `railway up`, not git auto-deploy) to rule in/out the `bc51084` widened-COOL branch (#8).

---

## Open questions

1. **What does Viet mean by "cold"?** Borderline 15–19.9°C MILD under-dressing, or sub-15°C where outer is forced but too light? Affects whether #2 (threshold) or #3 (weak outer) is the real complaint. *Recommend asking Viet for an example screenshot + location.*
2. **Reopen the 15°C boundary?** Code shows it was challenged (eval 260513) and intentionally kept — a product/CEO call. The complaint *came from the CEO*, so the spec may now change.
3. **`warmth_level` prod null-rate?** DB query blocked by SQLAlchemy mapper init error in agent sandbox — needs prod-mirror `:5433`.
4. **Which commit is on Railway prod?** Determines if #8 (widened COOL floor) compounds the issue.
5. **Should footwear cold-selection use the already-tagged `temperature_range` enum** (HOT/MILD/COOL/COLD) instead of `warmth_level`? It's the only field with an explicit COLD level but the cold filter ignores it (`gemini_tagger_v05.py:111,617` vs `engine_v05_layers.py:206`).
