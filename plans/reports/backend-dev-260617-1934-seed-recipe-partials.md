# Seed Recipe — 3 Camera-Gated Mobile Partials (AU-361 / AU-354 / AU-358)

**Author:** backend-dev · **Date:** 2026-06-17 · **For:** qa-mobile
**Backend:** http://localhost:5001 (running, DO NOT restart) · Swagger `/docs`
**Server process:** PID 56900/57026, cwd `…/wardrobe-backend`, branch **`feature/au318-mood-feedback`** (the hazardous junk-drawer checkout)
**QA user:** `qa-test@auxi.app` / `QaTest!2026` · user_id `b32cb743-2264-411c-abf1-ee14f6733368`

---

## TL;DR (read this first)

| Feature | DB seeded? | Observable through the RUNNING server? |
|---|---|---|
| AU-361 item-ready snackbar | YES (`is_preparing=true` on 1 item) | **NO** — running server's `WardrobeItem.to_dict()` omits `is_preparing` |
| AU-354 reuse body-photo | YES (active profile: `is_primary`+`body_shape`+`full_body_url`) | **NO** — running server has no `GET /api/body/active` (returns 405) and `Body.to_dict()` omits the profile fields |
| AU-358 STOM quit + completion-notify | n/a (needs render) | **Quit/backgrounding: YES.** **Completion-notify: NO** — real render 500s (`current_app` Flask bug in this checkout) |

**Root cause (critical):** the running server is a **stale code checkout** (`feature/au318-mood-feedback`) pointed at a **newer Postgres schema**. The DB already has the columns these features need (`wardrobe_items.is_preparing`, `bodies.body_shape/full_body_url/is_primary/photo_type`), but this code's models/routers do **not** read them and the `/body/active` route does not exist here. So **seeding the DB is necessary but NOT sufficient** — the server must be running a build that implements these features.

**The build that implements all three:** `feat/au-346-visualization-profile` (verified: `is_preparing` in `WardrobeItem.to_dict()`, `GET /api/body/active` returning `{profile}`, `Body.to_dict()` with the profile fields). Branches `duc2820/au-307-be-pin-build` and `feat/recover-app-feedback-au308-style-rules` also carry both pieces.

---

## What I seeded (applied + DB-verified)

Both seeds are written to the live DB and are **already correct** for a feature-complete server build. They were a no-op against the running stale server (it can't surface them).

1. **Preparing item** — `wardrobe_items.is_preparing = true`
   - item id `e2879f93-eb14-43e7-9940-238e70f723b3` ("Leather Trousers · Black", bottoms)
   - DB read-back: `is_preparing = t` ✓

2. **Active body profile** — body id `8c22a301-6a68-4f3b-8ca3-bf81e8409718`
   - `is_primary = true` (all other qa-test bodies set to false — single primary)
   - `body_shape = 'hourglass'`, `photo_type = 'full_body'`
   - `full_body_url = image_url` (its own reachable R2 PNG)
   - R2 image verified reachable: `HTTP 200, image/png, 147954 bytes`
   - DB read-back: `is_primary=t · body_shape=hourglass · photo_type=full_body · full_body_url NOT NULL` ✓

### API verification against the RUNNING server (the honest result — all negative)

```
GET /api/wardrobe/items   → seeded item present, but  "is_preparing" key ABSENT
GET /api/body             → seeded body keys = [created_at, id, image_url, user_id]  (no profile fields)
GET /api/body/active      → HTTP 405 Method Not Allowed   (route does not exist on this build)
POST /api/tryon/highres   → HTTP 500 "Working outside of application context." (~3s)
```

---

## Login — get a qa-test JWT

```bash
TOKEN=$(curl -s -X POST http://localhost:5001/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"qa-test@auxi.app","password":"QaTest!2026"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
echo "$TOKEN" > /tmp/qa_token.txt   # (token = secret, do not paste in reports)
```

Response shape: `{access_token, refresh_token, expires_in, refresh_expires_in, token_type}`. No `user` object. The mobile app logs in through this same `/api/login`.

---

## AU-361 — item-ready snackbar

**Mechanism (verified):** field is `wardrobe_items.is_preparing` (boolean column, exists in DB). The mobile app (`auxi/src/screens/WardrobeScreen.tsx:91`) reads `item.is_preparing === true` per item; the snackbar fires when it flips `true → false` during the Wardrobe poll. There is **no API endpoint** to set/flip it — it's a DB-level flag (flipped by the AI-enhancement worker on this project). So the flip is a **psql one-liner**.

### Exact flip-to-ready command (run on demand while qa is watching Wardrobe)

```bash
cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
DBURL=$(grep -E '^DATABASE_URL=' .env | head -1 | cut -d= -f2- | tr -d '"')
psql "$DBURL" -c "UPDATE wardrobe_items SET is_preparing = false WHERE id = 'e2879f93-eb14-43e7-9940-238e70f723b3';"
```

Re-arm (set back to preparing) if you need another run:
```bash
psql "$DBURL" -c "UPDATE wardrobe_items SET is_preparing = true WHERE id = 'e2879f93-eb14-43e7-9940-238e70f723b3';"
```

### BLOCKER for qa-mobile
Against the **currently running server**, `/api/wardrobe/items` does **not** include `is_preparing` in the JSON (this checkout's `WardrobeItem.to_dict()` omits it). The app's poll therefore always reads `is_preparing === false` → the item never appears "preparing" → the flip produces no `true→false` transition the client can see → **snackbar will not fire.**
**Unblock:** server must run a build whose `WardrobeItem.to_dict()` emits `is_preparing` (e.g. `feat/au-346-visualization-profile`). Then: open Wardrobe (item shows preparing/spinner) → run the flip-to-false command → snackbar.

---

## AU-354 — reuse body-photo (active profile)

**Mechanism (verified):** the reuse-confirm screen calls `GET /api/body/active`, expecting `{ profile: { image_url, full_body_url, body_shape, is_primary, … } }` (`auxi/src/services/bodyService.ts:116`). "Active profile" = the user's `bodies` row with `is_primary = true`.

### Confirm the seeded active profile (DB — always true)
```bash
cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
DBURL=$(grep -E '^DATABASE_URL=' .env | head -1 | cut -d= -f2- | tr -d '"')
psql "$DBURL" -c "SELECT id, is_primary, body_shape, photo_type, (full_body_url IS NOT NULL) AS has_fb FROM bodies WHERE id='8c22a301-6a68-4f3b-8ca3-bf81e8409718';"
```

### Confirm via API (only works on a feature-complete build)
```bash
TOKEN=$(cat /tmp/qa_token.txt)
curl -s http://localhost:5001/api/body/active -H "Authorization: Bearer $TOKEN"
# feature-complete build → {"profile": {"id":"8c22a301…","body_shape":"hourglass","is_primary":true,"full_body_url":"https://pub-…r2.dev/…png", …}}
```

### BLOCKER for qa-mobile
The running server returns **HTTP 405** for `GET /api/body/active` (no such route on this checkout; the path collides with `DELETE /api/body/{body_id}`). Even `GET /api/body` omits the profile fields. So the app's `getActiveProfile()` throws → reuse-confirm screen cannot show the saved profile.
**Unblock:** server must run a build with the `GET /api/body/active` route + `Body.to_dict()` profile fields (e.g. `feat/au-346-visualization-profile`). The DB seed is already in place, so once that build is serving, the active profile appears immediately — no re-seed needed.

---

## AU-358 — self-viz quit + completion-notify

**How to start a render:** the STOM "generating" screen starts when the app fires `POST /api/tryon/highres` (JSON). Minimal contract (`HighresTryOnRequest`):
```json
{
  "body_id": "8c22a301-6a68-4f3b-8ca3-bf81e8409718",
  "wardrobe_item_ids": ["6b8557f1-e300-4972-9373-c7aab51ce0d7"],
  "gemini_opt_in": true,
  "prompt_params": { "body_shape": "hourglass" }
}
```
- `gemini_opt_in` MUST be `true` (else 400). `wardrobe_item_ids` 1–4. `body_id` must be owned by qa-test (the seeded body works). In the app: pick the active profile + an outfit → tap generate → the generating screen appears and the request fires.

**Render feasibility locally — verified:** a real high-res render **does NOT complete** on the running server. `POST /api/tryon/highres` returns **HTTP 500** in ~3s with:
> `"Working outside of application context."`

Cause: this checkout's `blueprints/tryon/gemini_service.py` calls Flask `current_app.config` inside a FastAPI app (no app context) — it throws before reaching Gemini. (Both `GOOGLE_STUDIO_KEY` and `OPENAI_API_KEY` are set in `.env`, and this checkout's try-on path is Gemini-only — `gemini-3-pro-image-preview` hardcoded; no OpenAI gpt-image-1 wiring here. But none of that matters because the request dies at the `current_app` call.)

### What qa-mobile CAN and CANNOT verify
- **CAN verify (quit / backgrounding UX):** start a render → the generating screen renders and the request is in flight → quit / send app to background. The `body_shape_generation_backgrounded` analytics + the quit/leave UX (`SeeThisOnMeScreen.tsx:418`) are exercised regardless of the eventual server result.
- **CANNOT verify (completion-notify):** `body_shape_generation_completed_notified` (`try-on-completion-notice.ts:50`) needs a render that **finishes successfully**. On this server the render 500s, so the client hits the error path, never the completion path. Completion-notify is **not testable here**.
- **Unblock:** a server build with a working FastAPI try-on path (no `current_app`) + reachable image provider. Render takes ~10–20s when healthy — long enough to background and return to a finished result.

---

## Quick "is the server feature-complete yet?" check for qa-mobile

Run this one probe; if it returns the profile JSON (not 405) you're on a good build and all seeds are live:
```bash
TOKEN=$(cat /tmp/qa_token.txt)
curl -s -o /dev/null -w "body/active → HTTP %{http_code}\n" \
  http://localhost:5001/api/body/active -H "Authorization: Bearer $TOKEN"
# 405 = stale build (features NOT observable) · 200 = feature-complete (proceed)
```

---

## Seed reference (IDs)

| Purpose | ID |
|---|---|
| qa-test user_id | `b32cb743-2264-411c-abf1-ee14f6733368` |
| Preparing item (AU-361) | `e2879f93-eb14-43e7-9940-238e70f723b3` |
| Active body profile (AU-354) | `8c22a301-6a68-4f3b-8ca3-bf81e8409718` |
| A valid top for renders (AU-358) | `6b8557f1-e300-4972-9373-c7aab51ce0d7` |

---

## Hygiene / safety
- **No production code touched.** No files written under `wardrobe-backend/` except this report under `plans/reports/`.
- **No git commit / revert / branch switch / clean.** The dirty working tree (~130 files) is untouched by me; the "44 files modified" hook warning refers to the pre-existing dirty checkout, not my edits.
- **DB writes:** only the two seed `UPDATE`s on qa-test's own rows (parameterized, fixed UUIDs — no string-interpolated user input). Shared Railway Postgres — writes are scoped to qa-test (`b32cb743…`) only.
- Server NOT restarted.

## Unresolved questions
1. Will devops/tech-lead restart the local server from `feat/au-346-visualization-profile` (or merge it forward) so qa-mobile can observe AU-361 + AU-354? Seeds are already in place for that build.
2. AU-358 needs a try-on build without the `current_app` Flask bug — is that on a separate branch, or does it need a fix? (Out of scope for this seeding task; flagging for tech-lead.)
