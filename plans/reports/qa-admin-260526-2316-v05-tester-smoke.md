# V05 Recommendation Tester — Admin UI Smoke Test

**Date:** 2026-05-26 23:16 · **Surface:** wardrobe-admin SPA `/v05-tester` · **Mode:** browser (Playwright)
**Verdict:** ✅ PASS — feature works end-to-end (build + run-as-user + try-another).

## Environment
- Admin SPA: `http://localhost:5173` (vite dev, started for this test)
- Backend: `:5001` → **local mirror** `wardrobe_local` (PG :5433), env=development
- Admin login: `admin@auxi.app` / `Admin!2026` (role=admin) — pw set in mirror via `scripts/create_admin.py` logic
- Run-as target: `qa-test@auxi.app` (65 wardrobe items, richest in mirror)

## Setup friction (resolved before testing)
1. `:5001` was found pointed at **Railway PROD DB** (restarted, picked up disk `.env`). Browser admin login 401'd. → Per user approval, restarted uvicorn with `DATABASE_URL=wardrobe_local` (no `--reload`, so it can't flip back). Now connected to `127.0.0.1:5433`.
2. `.env` admin creds (`admin@auxi.app`/`Admin!2026`) are **local-only** — invalid against Railway prod.
3. `create_admin.py` crashes standalone (`AuthToken` mapper unresolved — script imports only `models.user`). Worked around by importing `models.auth_token` too. **Minor bug** worth fixing in the script.

## Steps & results
| Step | Result |
|---|---|
| Login as admin | PASS → dashboard, 0 errors |
| Open `/v05-tester` | PASS full render: header, Run-as picker, form, empty state |
| Run-as search "qa-test" | PASS admin user-search returns user; badge **"65 wardrobe items"** (green) |
| Build Outfits (20C, casual, U, count 3) | PASS **2 outfits** returned (suggested #1, score 0.684), session cached -> Try Another enabled |
| Outfit cards | PASS items w/ images, category, color code, style tags, HRID; styling note; vibe signature panel |
| Engine Trace panel | PASS v0.5, tier pools, LLM diagnostics, anchor diversity, pool sizes, layer timings, skipped logs |
| Try Another (Outfit #1, auto axis) | PASS variation chain depth 1, axis **Silhouette**, score 0.625, **56ms**, `cache_hit` (Redis pool fast path); "Reset chain" appears |

## Engine observations (not UI bugs — graceful degradations)
- **LLM-1 fallback `client_init_error`** (0ms, cache miss) -> styling notes are rule-based templates ("Clean and simple.", "Calm and clear."). Cause: no working OpenAI key in local backend env (LLM-1/3 = OpenAI gpt-4o-mini). Engine degrades correctly.
- **Fallback flag `style_diversity_unmet`**, count=2 (not 3 requested), **78 skipped logs** -> constrained pool after 20C/casual filter on qa-test's wardrobe (safe=1 / elevated=4 / exploratory=0). Engine handled gracefully.
- LLM-3: `n/a` (not shipped / not invoked).

## UI issues found
- **[low] antd deprecation warning** (console): `[antd: Select] popupClassName is deprecated. Please use classNames.popup.root`. From the Run-as `<Select>` (`V05RecommendationTester.tsx` `popupClassName="v05-user-picker-popup"`). Cosmetic; should migrate before antd drops it.
- No functional console errors during the build/try-another flow. (The 3 login 401 errors in console were from the pre-restart attempt against Railway, not the test.)

## State left behind
- `:5001` running on local mirror (PID rotated). **Disk `.env` still points at Railway** — if backend is restarted normally it returns to prod.
- `:5173` admin dev server left running.
- Mirror `wardrobe_local`: `admin@auxi.app` password set to `Admin!2026`, role=admin (mirror only).

## Unresolved questions
- Is the LLM-1 `client_init_error` expected locally (no key), or should the local env carry an OpenAI key for full-fidelity testing? Affects whether styling notes are LLM-generated in QA.
- Should `scripts/create_admin.py` be patched to import the full model registry so it runs standalone?
