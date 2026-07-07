# AU-379 — Self Visualization 1.1: bug diagnosis + fix plan

**Issue:** [AU-379 [uac] Self Visualization 1.1](https://linear.app/duncan-1/issue/AU-379) (parent AU-328, Done).
**Feature:** "See This On Me" (STOM) — preview an outfit on yourself. Built June 2026 to **AU-328**, shipped TestFlight. AU-379 is the **v1.1 refinement**.
**Symptom (CEO):** feature exists but wrong across all 4 axes — bad generated image · generation fails · wrong step flow · wrong entry/returning-user.

---

## 0. IMPORTANT — red herring corrected

The first code-map read the `wardrobe-backend` submodule on `feature/au318-mood-feedback`, **41 commits behind `origin/main`**. Its "BLOCKER: missing `GET /api/body/active` / `PATCH /api/body/{id}` / provider field / contract drift" findings are **FALSE on main** — all exist. Do **not** plan against those. Truth below is verified against `origin/main` (backend) and `feat/auth-ds-primitives` (auxi, current, 5 behind main — has the feature).

## 1. Ground truth (verified on correct branches)

**Backend `origin/main` is healthy:**
- OpenAI `gpt-image-1` **primary** + Gemini **fallback**; `TRYON_IMAGE_PROVIDER` default `openai`; `provider` returned. `routers/tryon.py:112-161`, `blueprints/tryon/openai_service.py` (images.edit multi-image, retry/backoff, `_build_prompt` :187).
- `GET /api/body/active` (`body.py:228`), `PATCH /api/body/{id}` (`body.py:253`), multipart `POST /api/body` reads `body_shape/photo_type/is_primary`.
- Consent gate: `/tryon/highres` **hard-requires `gemini_opt_in=true`** (`tryon.py:236`).
- Body-photo validator → HTTP 422 `error_kind ∈ {no_person, screenshot_or_graphic, multiple_people, too_small_or_occluded}`.
- Persists each render (`models/tryon.py`, `save_tryon_result` `tryon.py:176`) **but exposes NO GET to retrieve it.**

**Mobile (auxi, current) — built to AU-328, contract aligned with backend main:**
- Flow: `src/screens/see-this-on-me/*` — StepSelfie/FullBody/BodyShape → GeneratingView → OutfitPreview; returning user = `StepReuseConfirm` (shows stored **body photo**, **re-generates**).
- Success screen (`OutfitPreview.tsx`): AU-328 **opt-in checkbox** + "Back to home" — **no Download**.
- Entry: static "Self visualization" row per favourite card (`favourite/FavouriteOutfitCard.tsx:315`) — **no profile-thumbnail swap**.
- Analytics: `try_on_*` taxonomy (`SeeThisOnMeScreen.tsx`) — **does not match** AU-379 names.

## 2. Symptom → cause map

| # | Symptom | Status | Cause |
|---|---|---|---|
| 1 | **Ảnh xấu / sai** | HYPOTHESIS (needs prod evidence) | prod likely not running OpenAI primary — `OPENAI_API_KEY`/`TRYON_IMAGE_PROVIDER` unset → always falls back to Gemini (lower fidelity); or deploy lag predates OpenAI path; or prompt/input tuning. Code on main is correct. |
| 2 | **Generate lỗi / không ra** | HYPOTHESIS (needs prod evidence) | body-photo validator 422 rejecting real selfies (memory: errored on a face photo); or prod deploy lag (404/500 on `/body/active` or `/tryon`); or OpenAI key missing → both providers fail; or S3. |
| 3 | **Luồng các bước sai** | CONFIRMED | AU-328→1.1 divergence: success screen must **drop checkbox + add Download**; step copy/indicator; body-shape "Use This Photo". |
| 4 | **Entry / returning-user sai** | CONFIRMED | (a) entry tile no thumbnail swap; (b) returning view is reuse-confirm/re-generate, **not** a "Visualization Detail" screen showing the **saved image** + Download/Retake/Close; (c) no GET latest-visualization endpoint + no mobile fetch; (d) Download unimplemented. |

**Net:** symptoms 1 & 2 are most likely **prod config/deploy**, not code — verify before writing backend code. Symptoms 3 & 4 are **real code work** (AU-328 → AU-379 1.1 alignment).

---

## Phase 0 — Prod diagnosis (devops) · evidence-first · DECISIVE
Disambiguates "config/deploy" vs "code" for symptoms 1 & 2. Do this before any backend code.

### ✅ RESULTS (2026-06-26, Railway CLI — prod `wardrobe-backend-production-c8d9`)
- **Prod is CURRENT** — live no-auth probe: `GET /api/body/active`→401 (exists), `/api/tryon/highres`→405 (POST route exists), `/api/body`→401. Recent `main` deployed. **Deploy-lag hypothesis KILLED.**
- **`OPENAI_API_KEY` = set** ✅; `S3_*` fully set ✅; Gemini `GOOGLE_STUDIO_KEY` set ✅. `TRYON_IMAGE_PROVIDER` unset → code default `openai`. **"missing OpenAI key" hypothesis KILLED.**
- Prod log buffer had **no recent try-on lines** (no one rendered in window) → no passive runtime evidence yet.

### ⇒ Revised conclusion for symptoms 1 & 2
NOT config/deploy. They are **runtime**: (1) gpt-image-1 raising at runtime → silent Gemini fallback (lower fidelity); or (2) inherent gpt-image-1 try-on fidelity / prompt+input quality; or (3) body-photo validator 422 rejecting real selfies; or (4) `gemini_opt_in` consent gate / timeout. **Only a live reproduce-with-logs can pick the winner** (needs test login + a real selfie + an outfit id) — heavier; was deferred pending CEO go-ahead.

## Phase 1 — Backend (backend-dev) · only what Phase 0 proves
- If deploy lag → redeploy main. If key missing → set `OPENAI_API_KEY` + `TRYON_IMAGE_PROVIDER=openai` (devops).
- **New `GET /api/tryon/latest`** (by active profile / outfit) → returns last saved visualization for the Detail screen. Update `API_DOCUMENTATION.md` + tech-lead contract sign-off.
- Body-photo validator: if Phase 0 shows it rejects valid selfies, loosen / improve `error_kind` mapping.
- gpt-image-1 prompt/input tuning if quality poor **with** key present (`_build_prompt` :187).

## Phase 2 — Mobile (mobile-dev) · AU-379 1.1 alignment
- **Success screen** (`OutfitPreview.tsx`): remove opt-in checkbox (1.1), **add Download**, keep Back to Home + Retake.
- **Download**: save-to-camera-roll / share sheet (success + detail). (`OutfitPreview.tsx:482` TODO.)
- **Returning user → new Visualization Detail screen**: saved image + Download + Retake + **Close**; fetch via new GET; replaces reuse-confirm as the default returning view. Register in `navigation.ts` + `AppNavigator.tsx`.
- **Entry tile**: when active profile exists, swap "Self visualization" → profile thumbnail / "View visualization" (`FavouriteOutfitCard.tsx`; gate on `bodyService.getActiveProfile()`).
- **Step copy/indicator + body-shape preview wording** per 1.1.
- **Edge/error states** per spec: no-face, blurry (non-blocking), generation-fail Retry/Retake, upload-fail, camera-permission.
- **Analytics** (rule: analytics-tracking-required): map to AU-379 taxonomy via `services/analytics.ts` — `self_visualization_started`, `selfie_uploaded`, `full_body_uploaded`, `body_shape_selected`, `profile_generation_started/completed/failed`, `profile_retaken`, `profile_downloaded`, `self_visualization_opened`; update `docs/analytics/mixpanel-tracking-plan.md`.

## Phase 3 — Gates · QA · deploy
- `npx tsc --noEmit` + `yarn lint` + `auxi-lint-tokens.sh` clean.
- qa-ui Compare (needs **AU-379 Figma frames** — not on the ticket, request from CEO).
- designer gate 6.5 (hard gate) → `auxi/docs/design-reviews/`.
- qa-mobile smoke on sim (watch sim-toolchain caveat).
- Backend deploy (devops) → mobile TestFlight via CI.

---

## Open questions / decisions
1. **No Figma on AU-379** — need frames for Visualization Detail, entry thumbnail, 1.1 success screen. Request from CEO.
2. **Prod access for Phase 0** — Railway MCP erroring this session; run via Railway CLI / devops.
3. **Priority** — both symptom groups selected. Suggest: Phase 0 first (cheap, may fix 1 & 2 via config), then mobile 1.1 alignment.
4. **CEO body-shape photos** (3) still pending — picker uses labeled fallback.
5. Confirm prod default provider + OpenAI image budget acceptable.
