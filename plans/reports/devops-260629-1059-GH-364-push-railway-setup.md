# devops — Push-notification go-live: Railway setup (GH-364)

Date: 2026-06-29 · Executor: devops (gated prod) · Railway acct: duc2820@gmail.com

MCP token was dead (`Not authenticated`) → fell back to Railway CLI (`railway`, authed as
duc2820@gmail.com) + direct GraphQL with `user.accessToken` for source/config reads.

## Railway topology (project `wardrobe-backend`, id `fb0365a2-85d4-400d-a540-42d89068f651`)

Environment: `production` (id `72bc27df-ab73-422d-b2bd-256bbf898743`)

| Service | id | role | source / image | start cmd | restart |
|---|---|---|---|---|---|
| wardrobe-backend | `a767f87d-3eb2-4334-b69d-303992a06b65` | FastAPI prod API | repo `auxi-wardrobe/auxi-backend` | (Dockerfile/gunicorn, no override) | ON_FAILURE |
| ai-worker | `474d72b1-2c91-467b-97a9-163b9a8cab77` | EXISTING AI worker (unrelated to push) | repo `auxi-wardrobe/auxi-backend` | `python ai_worker.py` | ON_FAILURE, 1 replica |
| Redis | `45514c77-1d8a-4a7b-9513-987f45e7a5a8` | cache + queue | `redis:8.2.1` (+ volume, requirepass) | — | ON_FAILURE |
| Postgres | `6e23a828-749d-4b15-9d46-d4f61c251c5c` | prod DB | `postgres-ssl:17` | — | ON_FAILURE |

## TASK 1 — Firebase secret set (DONE, no deploy triggered)

- Variable: `FIREBASE_CREDENTIALS_JSON`
- Service: `wardrobe-backend` (API, `a767f87d...`), env production
- Value: len **2312**, sha256 prefix **894d2dd2cdd8** (Firebase SA JSON, project_id `macgie`, has
  private_key + client_email). Value never printed/logged.
- Method: piped via `railway variable set ... --stdin` (value never on cmdline) + `--skip-deploys`
  (per "don't trigger a deploy" constraint). Read-back from Railway: stored len 2312, sha256
  894d2dd2cdd8 → **matches source exactly**. Local temp file (mode 600) shredded after.
- Rollback: `railway variable delete FIREBASE_CREDENTIALS_JSON -p fb0365a2... -s a767f87d... -e 72bc27df...`
  (no deploy was triggered, so nothing else to revert).

## TASK 2 — Audit (read-only)

- Redis: **PROVISIONED** (`redis:8.2.1` service present). Connection var on API service: **`REDIS_URL`** (present).
- Vars the worker must share, all present on the API service: **`DATABASE_URL`**, **`REDIS_URL`**,
  **`FIREBASE_CREDENTIALS_JSON`** (just set).
- ai-worker already resolves `DATABASE_URL` + `REDIS_URL` (so the reference-wiring pattern is proven);
  it does NOT have `FIREBASE_CREDENTIALS_JSON` (expected — it's not a push worker). The notification
  worker is a SEPARATE new service, not a reuse of ai-worker (different start cmd / code path).

## TASK 3 — notification-worker service spec (DEFERRED — do not create yet)

Hard dependency: `notification_worker.py` + alembic migration `notif1a2b3c4d` (tables `device_tokens`,
`notifications`, `notification_deliveries`) exist ONLY on the un-merged `feat/push-notifications`
branch. NOT on prod `main`; migration NOT applied to prod DB. Creating the worker now → crash
(ModuleNotFound / relation does not exist).

Ready-to-run spec, model it on the existing **ai-worker** service:

- Source: repo `auxi-wardrobe/auxi-backend`, SAME branch the API deploys (prod = `main`). Worker must
  deploy the same commit that contains `notification_worker.py` AND after `notif1a2b3c4d` is applied.
- Start command: `python notification_worker.py`
- No HTTP port / no domain (BRPOP consumer + APScheduler producer). No healthcheck path.
- Restart policy: **ALWAYS** (long-running consumer should restart even on clean exit). (ai-worker uses
  ON_FAILURE; ALWAYS is the safer choice for a daemon loop — flag to tech-lead if they prefer parity.)
- Replicas: 1 (single consumer; APScheduler producer must NOT be multi-replica or reminders double-fire).
- Env via Railway reference variables (DRY, single source of truth = API service):
  - `DATABASE_URL`            = `${{ wardrobe-backend.DATABASE_URL }}`
  - `REDIS_URL`               = `${{ wardrobe-backend.REDIS_URL }}`
  - `FIREBASE_CREDENTIALS_JSON` = `${{ wardrobe-backend.FIREBASE_CREDENTIALS_JSON }}`
  - (alt: reference the source services directly — `${{ Postgres.DATABASE_URL }}` / `${{ Redis.REDIS_URL }}`)

### Blockers / who-does-what for go-live (ordered)

1. Merge `feat/push-notifications` → backend `main`; API redeploys (carries the new code).
2. Apply migration `notif1a2b3c4d` on prod DB (Railway pre-deploy alembic step; ESCALATE-tier — prod DB
   schema change, needs explicit go-ahead). Confirm 3 tables exist before step 3.
3. THEN create the worker service. My Railway MCP grant has set_variables / deploy / update_service /
   add_reference_variable but **NOT create_service** — worker creation needs Railway CLI
   (`railway add --service notification-worker`) or escalation. After create: set start cmd +
   restart ALWAYS + the 3 reference vars + 1 replica, then deploy.
4. Deploys hit a NEEDS_APPROVAL gate (deploymentApprove) — approve to release.

## Unresolved questions

- Restart policy: ALWAYS (my rec) vs parity with ai-worker's ON_FAILURE — tech-lead call.
- Worker deploy branch: assumed prod `main`; confirm the API's actual deploy branch at create time.
- Who runs the prod migration `notif1a2b3c4d` and when (release sequencing) — tech-lead decision.
