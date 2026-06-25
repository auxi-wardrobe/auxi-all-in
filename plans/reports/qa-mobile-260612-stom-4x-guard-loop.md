# QA Mobile — STOM body-photo guard 4× loop

**Date**: 2026-06-12 11:33
**Device**: iOS Simulator iPhone 16 Pro (18.1), UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`
**App**: `com.auxi2026.app` (relaunched fresh to load latest JS — no redbox on Home)
**Backend**: live on :5001 (worktree log `/tmp/auxi-wt-backend.log`)
**Metro**: :8081 (worktree JS)

## Status: BLOCKED — cannot enter STOM flow

The STOM entry path (Sidebar → My Favourite → a saved outfit → "Self visualization")
is broken at the **My Favourite** step. The Favourites list never loads, so there is
no saved outfit to open and no "Self visualization" action to reach. 0/4 cycles could
start. Stopped immediately per the STOP-on-failure instruction.

## Per-cycle results

| Cycle | (A) non-person blocked | (B) body accepted + render | Notes |
|-------|------------------------|----------------------------|-------|
| 1 | — not reached | — not reached | Blocked at Favourites list (500) |
| 2 | — not reached | — not reached | Blocked at Favourites list (500) |
| 3 | — not reached | — not reached | Blocked at Favourites list (500) |
| 4 | — not reached | — not reached | Blocked at Favourites list (500) |

## Root cause (backend, deterministic)

`GET /api/favorites?limit=20&offset=0&sort=recent` returns **500 Internal Server Error**.
The list-favorites query joins the V05 mood-feedback table `outfit_mood_signals`, which
does not exist in the DB the running backend is connected to — a **missing migration**.

The failing query references **16 outfit hashes**, i.e. the user *does* have favourites;
the endpoint crashes on the mood-signals join, not on empty data.

### Backend log excerpt (`/tmp/auxi-wt-backend.log`)
```
2026-06-12 11:33:19,272 - routers.favorites - ERROR - Error listing favorites:
  (psycopg2.errors.UndefinedTable) relation "outfit_mood_signals" does not exist
LINE 2: FROM outfit_mood_signals
[SQL: SELECT outfit_mood_signals.id, outfit_mood_signals.user_id,
  outfit_mood_signals.favorite_id, outfit_mood_signals.outfit_hash,
  outfit_mood_signals.mood_tags, outfit_mood_signals.context_snapshot,
  outfit_mood_signals.created_at, outfit_mood_signals.decay_at
FROM outfit_mood_signals
WHERE outfit_mood_signals.user_id = %(user_id_1)s
  AND outfit_mood_signals.outfit_hash IN (... 16 hashes ...)
  AND outfit_mood_signals.decay_at > %(decay_at_1)s
ORDER BY outfit_mood_signals.created_at ASC]
INFO:     127.0.0.1:50832 - "GET /api/favorites?limit=20&offset=0&sort=recent HTTP/1.1" 500 Internal Server Error
```

### App-side symptom
- Red toast on screen: `listFavourites error AxiosError: Request failed...`
- Favourites screen empty-error state: **"We couldn't load your favourites. Please try again."**

## Screenshots (`plans/reports/qa-screens/`)
- `setup-loaded.png` — Home, app loaded clean, no redbox
- `after-hamburger-logical.png` — sidebar open, "My Favourite" present
- `favourites-list.png` — Favourites loading spinner + red `listFavourites error` toast
- `favourites-list-2.png` — Favourites empty-error state "We couldn't load your favourites"

(No `cycleN-*` screenshots — STOM Step 1 never reached.)

## Routing
- **backend-dev** — apply the missing migration that creates `outfit_mood_signals`
  (V05 mood-feedback table) on the DB the :5001 worktree backend points at, OR make the
  list-favorites mood-signals enrichment tolerant of a missing table (degrade to empty
  mood data instead of 500). Suspected area: `wardrobe-backend/routers/favorites/*` (list
  handler) + the V05 mood-signals migration.

## Note on testIDs
The `stom-photo-error` / `stom-generate` / `stom-preview-image` testIDs in the acceptance
criteria are not present in the current `auxi/src` checkout — they live in the Metro
worktree JS that's actually serving the sim. That is expected and is NOT the blocker; the
blocker is purely the Favourites 500 gating the entry path.

## Unresolved questions
1. Is the :5001 backend supposed to have the `outfit_mood_signals` migration applied? If
   the STOM worktree was branched before that migration, the DB needs it.
2. Should list-favorites hard-depend on `outfit_mood_signals`, or degrade gracefully when
   the mood table is absent? Current behavior 500s the whole list on a missing optional join.

---
**Status**: BLOCKED
**Summary**: App relaunched clean, but the STOM entry path is dead at My Favourite — the
Favourites list 500s because backend table `outfit_mood_signals` does not exist (missing
migration). 0/4 STOM cycles could start. The guard itself was never exercised.
**Concerns**: Backend blocker, not a mobile bug. Needs backend-dev to add the migration (or
make the mood-signals join optional) before STOM body-photo guard can be tested.

---

# RETRY (2026-06-12 ~11:51) — Favourites fixed, now blocked on try-on generate 500

**Status**: BLOCKED — Cycle 1 (A) PASS, Cycle 1 (B) FAIL. Stopped after Cycle 1 per dispatch rule.

## Setup re-verified
- Relaunched clean: Home rendered, no redbox. `home-after-relaunch.png`.
- **My Favourite now LOADS** (the previous Favourites 500 is fixed): `GET /api/favorites?limit=20&offset=0&sort=recent HTTP/1.1" 200 OK`. Saved outfits render with per-card `favourite-self-visualization-<id>` buttons. `favourite-loaded.png`.

## Per-cycle table (retry)

| Cycle | (A) Non-person → blocked | (B) Body → accepted + renders |
|---|---|---|
| 1 | **PASS** | **FAIL** — try-on generate 500s, `stom-preview-image` never renders (after 1 retry) |
| 2 | not run (stopped) | not run |
| 3 | not run (stopped) | not run |
| 4 | not run (stopped) | not run |

## Cycle 1 (A) — PASS
Entered STOM (My Favourite → 27 May outfit → "Self visualization"). Step 1 → "Take photo" action sheet → "Choose from library" → picked a NON-PERSON image (board of app-UI mockup screens).
Inline red error: **"That looks like a screenshot or graphic, not a photo of a person. Please upload a photo of yourself for the try-on."** Screen STAYED on Step 1 (1/3), did NOT advance. `cycle1-A-reject.png`.
Backend guard: `routers.body - INFO - Rejected body upload (person check): kind=screenshot_or_graphic request_id=88ece61e-...`.

## Cycle 1 (B) — FAIL
Re-picked the CLEAN person photo (woman in white dress, full standing, plain white bg). Validated + ADVANCED to Step 2/3 (`stom-step-1-prompt-thumb` rendered). `cycle1-B-advanced.png`.
Step 2 = "Skip this step" → Step 3/3 "Choose the shape…" (`stom-shape-option-pear|hourglass|rectangle`).
Picked Hourglass → expand modal → "Use this photo" → generation started ("Creating your look…").
~15s later: **"We couldn't create your look. Please try again."** + "Try again" button. Console toast: `generateTryOn error AxiosError: Request fai…` (status 500).
Tapped "Try again" ONCE → same error. `stom-preview-image` NEVER rendered. `cycle1-B-preview-FAIL.png`.

### Root cause (backend 500 — NOT the guard)
Try-on image GENERATED successfully and uploaded to R2 (`PUT …/auxi/tryon/highres/375d63a6…png HTTP/1.1" 200`), but the success path crashed saving history:

```
routers.tryon - ERROR - Error in highres_tryon: Working outside of application context.
Traceback (most recent call last):
  File ".../routers/tryon.py", line 308, in highres_tryon
    response_data = _format_success_response(result, resources.options, "highres", user.id)
  File ".../routers/tryon.py", line 169, in _format_success_response
    history_service.save_tryon_result(user_id, uuid.uuid4().hex, upload_url)
  File ".../services/tryon_history_service.py", line 23, in save_tryon_result
    existing = self.tryon_repo.get_image_by_job_id(job_id)
  File ".../repositories/tryon_repository.py", line 43, in get_image_by_job_id
    return TryOnImage.query.filter_by(job_id=job_id).first()
RuntimeError: Working outside of application context.
INFO:     127.0.0.1:53389 - "POST /api/tryon/highres HTTP/1.1" 500 Internal Server Error
```

`TryOnImage.query` (Flask-SQLAlchemy scoped query) is accessed without a Flask app context in the post-generation history save. The generation itself succeeded (PNG in R2); the user only sees an error because the 200-result is converted into a 500 by the history-save crash. Only 1 `POST /api/tryon/highres` reached the backend; the "Try again" tap did not log a fresh backend request in the captured window.

## Routing
- **backend-dev** — `wardrobe-backend/routers/tryon.py:169` (`_format_success_response` → `history_service.save_tryon_result`) and `repositories/tryon_repository.py:43` (`TryOnImage.query` outside app context). Wrap the history save in `app.app_context()` / pass an explicit session so a successfully-generated try-on returns 200 instead of 500. Same class of "Flask query outside context" bug as the earlier Favourites 500.

## Screenshots (plans/reports/qa-screens/)
- `home-after-relaunch.png`, `favourite-loaded.png`, `cycle1-picker-grid.png`
- `cycle1-A-reject.png`, `cycle1-B-advanced.png`, `cycle1-shape-modal.png`, `cycle1-B-preview-FAIL.png`

## State left running
Metro :8081, backend :5001, app — all left running. App is on the STOM error screen (Cycle 1 (B) FAIL).

## Unresolved questions
1. Did "Try again" actually re-POST? Only 1 backend try-on request logged — confirm retry wiring once the 500 is fixed.
2. Cycles 2–4 not run; rerun the full 4× loop after the `tryon.py` app-context fix lands.

---

## run 3 (post try-on fix) — 2026-06-12 12:04–12:38

Re-ran the FULL 4× STOM guard loop after the two backend fixes landed (favourites 500 + try-on history-save 500). Device: iPhone 16 Pro (iOS 18.1, UDID 9DCBFE8A…). App `com.auxi2026.app`. Backend :5001 (worktree), Metro :8081. Clean app relaunch between every cycle.

**Result: DONE 4/4 — all cycles pass both (A) and (B).**

### Per-cycle results

| Cycle | (A) Non-person → blocked | (B) Body → renders | Notes |
|---|---|---|---|
| 1 | PASS — app-mockup/UI board → `screenshot_or_graphic` error, stayed Step 1 | PASS — person → Step 2 → Skip → Hourglass → preview rendered | (B) needed 1 relaunch (see Concern) |
| 2 | PASS — magenta flowers (nature) → `no_person` error, stayed Step 1 | PASS — person → Skip → Pear → preview rendered | (B) needed 1 relaunch (see Concern) |
| 3 | PASS — UI board → `screenshot_or_graphic` error, stayed Step 1 | PASS — person → Skip → Rectangle → preview rendered | (B) run fresh after relaunch |
| 4 | PASS — waterfall (nature) → `no_person` error, stayed Step 1 | PASS — person → Skip → Hourglass → preview rendered | (B) run fresh after relaunch |

All (A) errors surfaced on Step 1 via the inline error region and the user stayed on Step 1 (Take photo still available). Both guard variants observed:
- `screenshot_or_graphic`: "That looks like a screenshot or graphic, not a photo of a person. Please upload a photo of yourself for the try-on."
- `no_person`: "We couldn't find a clear photo of a person. Please upload a photo of yourself for the try-on."

All (B) generations produced `stom-preview-image` (378×504) showing the favourited outfit (white shirt + pink pleated skirt + black boots) on the uploaded person, and "Back to home" returned to Home every time. No retry needed on any (B) generation — all generated first try.

### Backend confirmation (both prior blockers fixed)

- **Favourites 500 → fixed:** `GET /api/favorites?limit=20&offset=0&sort=recent HTTP/1.1" 200 OK` on every cycle. Favourite list loaded with saved outfits.
- **Non-person guard:** `POST /api/body HTTP/1.1" 422 Unprocessable Content` for the (A) rejections (gatekeeper prompt returns `is_person=false`, `issue=screenshot_or_graphic`/`no_person`). Expected 422 guard, not a 500.
- **Try-on history-save 500 → fixed:** every (B) generation returned `POST /api/tryon/highres HTTP/1.1" 200 OK` AND persisted history without the prior `RuntimeError: Working outside of application context`. One representative successful line:

```
2026-06-12 12:18:09,521 - routers.tryon - INFO - High-res try-on produced by provider=openai
2026-06-12 12:18:10,043 - utils.s3_utils - INFO - Uploaded base64 image to s3://auxi/tryon/highres/6741fe67f1c14d37b4a5609373fb1668.png
2026-06-12 12:18:10,271 INFO sqlalchemy.engine.Engine ... {'job_id': 'f1af1673…', 'image_url': 'https://pub-3f31fc6ccb6e427bb12afe09359a1692.r2.dev/tryon/highres/6741fe67…png', 'processing_time_ms': 21605, …}
INFO:     127.0.0.1:57148 - "POST /api/tryon/highres HTTP/1.1" 200 OK
```

Provider = `openai` on all four (B) try-ons. Successful `POST /api/tryon/highres -> 200` at: 12:18:09 (C1), 12:25:53 (C2), 12:31:35 (C3), 12:37:53 (C4). The DB INSERT (history row with `processing_time_ms`) committed cleanly each time — this is exactly the path that previously 500'd, now green.

### Screenshots (plans/reports/qa-screens/)
- Per cycle A: `run3-cycle1-A.png`, `run3-cycle2-A.png`, `run3-cycle3-A.png`, `run3-cycle4-A.png`
- Per cycle B advanced (Step 2): `run3-cycle1-B-advanced.png` … `run3-cycle4-B-advanced.png`
- Per cycle B preview: `run3-cycle1-B-preview.png` … `run3-cycle4-B-preview.png`
- Nav/setup: `run3-home.png`, `run3-sidebar5.png`, `run3-favourites2.png`, `run3-library.png`

### Concern (minor, non-blocking) — stuck spinner on re-pick after inline error

Observed twice (cycle 1 and cycle 2): after an (A) rejection, tapping **Take photo → Choose from library again in the same Step-1 session** put the Step-1 button into a permanent spinner and the native picker did NOT reopen. No backend request was sent (no new `POST /api/body` logged), so it's a front-end picker-relaunch state bug, not a backend issue. Recovered every time by relaunching the app and re-entering STOM fresh — the picker then opened normally and (B) completed. To keep the loop deterministic I ran each (B) from a fresh relaunch.

- Repro: STOM Step 1 → pick non-person (inline error) → Take photo → Choose from library → button hangs on spinner, picker never appears.
- Repro rate: 2/2 attempts to re-pick in the same session.
- Severity: minor (a real user would hit this when correcting a bad upload; recoverable by reopening the screen, but confusing).
- Suspected area: STOM Step-1 photo-picker launch handler (loading flag not reset / picker promise not re-armed after a prior validation-error pick). Route to **mobile-dev** (auxi STOM Step 1 screen) to confirm and reset the picker `isLoading` state so re-pick after an error works without a relaunch. No Maestro flow exists for STOM yet; if this becomes a regression target, ask `qa-ui` to author one.

### Side observation (out of scope for STOM)
`GET /api/v05/mood-feedback/policy HTTP/1.1" 500 Internal Server Error` fired a few times during the runs (12:05, 12:18:?, etc.). Unrelated to the STOM try-on flow; flagging only — not investigated here.

### State left running
Metro :8081, backend :5001, app — all left running. App is on Home after Cycle 4 (B) "Back to home".

---

## Run 4 — in-session re-pick recovery (verifies the hot-fix)

**Date:** 2026-06-12 ~13:00–13:21 · **Build:** worktree JS hot-fix (Metro :8081), backend :5001 (worktree) · **Device:** iOS Simulator iPhone 16 Pro (UDID 9DCBFE8A-…), app `com.auxi2026.app`
**Setup:** Relaunched ONCE at start to load the hot-fixed JS (`terminate` + `launch`), confirmed Home + My Favourite loaded. **No relaunch between cycles** thereafter — the entire point of this run.

**Goal:** Confirm the previously-filed re-pick bug (run 3 Concern, lines 199–206) is FIXED. After a rejection, tapping "Choose from library" again in the SAME Step-1 session must reopen the native picker (no stuck spinner), accept a clean body, and complete the render — 4 times, no relaunch.

**Result: DONE 4/4 — re-pick recovery works in-session on every cycle. The run-3 spinner bug is FIXED.**

### Per-cycle results (in-session, no relaunch between cycles)

| Cycle | Reject shown (Step 1) | Picker REOPENED in-session | Body advanced (Step 2) | Preview rendered | Shape |
|---|---|---|---|---|---|
| 1 | PASS — pink flowers → `no_person` error, stayed Step 1 | PASS — Take photo → Choose from library reopened, no spinner | PASS — clean body → Step 2 | PASS — `stom-preview-image` | Hourglass |
| 2 | PASS — pink flowers → `no_person` error, stayed Step 1 | PASS — picker reopened, no spinner | PASS — clean body → Step 2 | PASS — `stom-preview-image` | Pear |
| 3 | PASS — pink flowers → `no_person` error, stayed Step 1 | PASS — picker reopened, no spinner | PASS — clean body → Step 2 | PASS — `stom-preview-image` | Rectangle |
| 4 | PASS — pink flowers → `no_person` error, stayed Step 1 | PASS — picker reopened, no spinner | PASS — clean body → Step 2 | PASS — `stom-preview-image` (default shape) | default |

Between cycles: returned to a clean STOM entry via "Back to home" → hamburger → My Favourite → Self visualization (the app was NEVER terminated/relaunched after the single setup relaunch).

Notes:
- The re-pick on Step 1 with the error banner showing puts the "Take photo" CTA at a lower position (below the inline error) — the action sheet reopened reliably each time once tapped. No stuck spinner ever observed.
- Reject error variant on all four cycles: `no_person` — "We couldn't find a clear photo of a person. Please upload a photo of yourself for the try-on." (Cycle 1's second re-pick attempt also surfaced the `screenshot_or_graphic` variant — "That looks like a screenshot or graphic…" — when a UI-mockup cell was tapped by mistake; it re-picked again in-session and validated, further confirming repeated in-session re-pick works.)
- Cycle 4 detail: re-entry landed on Step 2 with a still-valid body from a prior pick, so I used the header back chevron to return to Step 1 (chevron lives at logical ~(35, 96)), then ran reject → in-session re-pick → clean body → generate. Still a true in-session reject+re-pick, no relaunch.

### Cancel check (done once, during Cycle 3 entry) — PASS

Opened Step 1 → Take photo → Choose from library → native picker appeared → tapped the picker's "Cancel" (top-left, accessibility `Cancel` button) → picker dismissed cleanly back to STOM Step 1. No stuck spinner; "Take photo" CTA returned to normal and was immediately tappable again (verified by then running the cycle-3 reject from the same screen). Evidence: `recov-cancel.png`.

### Screenshots (plans/reports/qa-screens/)
- Reject (Step 1 inline error): `recov-cycle1-reject.png`, `recov-cycle2-reject.png`, `recov-cycle3-reject.png`, `recov-cycle4-reject.png`
- Re-pick advanced (Step 2 reached after clean body): `recov-cycle1-repick-advanced.png` … `recov-cycle4-repick-advanced.png`
- Preview rendered: `recov-cycle1-preview.png` … `recov-cycle4-preview.png`
- Cancel check: `recov-cancel.png`
- Nav/setup: `recov-home-loaded.png`, `recov-sidebar.png`, `recov-step1-initial.png`, `recov-actionsheet.png`, `recov-picker-grid.png`

### Verdict on the run-3 Concern (lines 199–206)
**FIXED.** The Step-1 photo-picker re-launch handler now reopens the native picker after a prior validation-error pick, without a relaunch — verified 4/4 in-session, no spinner hang, no backend re-issue needed. The minor bug previously routed to mobile-dev can be closed.

### State left running
Metro :8081, backend :5001, app — all left running. App is on the Cycle 4 preview screen ("Back to home" available). Not terminated.
