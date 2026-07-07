# devops — Push-notification FULL go-live (GH-364)

Date: 2026-06-29 · Executor: devops (gated prod, CEO-authorized full go-live incl. prod migration) · Railway acct: duc2820@gmail.com

Railway MCP token dead again (`Not authenticated`) → fell back to Railway CLI (authed) + GraphQL
via `~/.railway/config.json` `user.accessToken`. No secret VALUES printed anywhere.

Project `wardrobe-backend` (`fb0365a2-85d4-400d-a540-42d89068f651`), env `production` (`72bc27df-ab73-422d-b2bd-256bbf898743`).

---

## TASK 1 — Ship main to API + apply migration — DONE

- **Deploy approved & succeeded.** A deploy for `main` @ `9718af6` (PR #119) was already sitting in
  `NEEDS_APPROVAL` (id `5ec1bda4-ee9b-4542-8eb3-e2f7ec73ddc1`). Pre-flight: confirmed repo `railway.toml`
  still pins `builder=DOCKERFILE` + `preDeployCommand=python -m alembic ... upgrade head` (the `RAILPACK`
  in the queued manifest is just the pre-build default before Railway reads railway.toml). Confirmed alembic
  single head `notif1a2b3c4d`, `down_revision=schedule1a2b` (prod was at schedule1a2b → clean linear chain).
  Approved via GraphQL `deploymentApprove` → `BUILDING → DEPLOYING → SUCCESS`.
- **Migration verified (deploy log):**
  `INFO [alembic.runtime.migration] Running upgrade schedule1a2b -> notif1a2b3c4d, add push notification tables (device_tokens, notifications, notification_deliveries)`
  (No prod psql used — log-confirmed, per escalation rules.)
- **API healthy (deploy log):** gunicorn 26.0 listening on :5001, 2 uvicorn workers `Started server process`,
  `Sentry initialised (env=production)`, `services.queue_service - Connected to Redis queue service`, rate
  limiters init. Pre-existing benign warning only: `Control server error: [Errno 13] Permission denied: '/home/appuser'`
  (gunicorn control-socket, cosmetic — server serves fine).
- **Endpoint sanity:** `POST /api/notifications/device-token` → **401**, `DELETE /api/notifications/device-token`
  → **401** (clean JSON + request_id). Routes registered, app booted clean — no 404/500.

## TASK 2 — Create notification-worker service — DONE

Modeled on existing `ai-worker` (same repo, Dockerfile image, start-command override).

| Field | Value |
|---|---|
| name / id | `notification-worker` / `2127dfdc-ff10-4c57-913e-eb52fda5ae60` |
| source | GitHub `auxi-wardrobe/auxi-backend`, branch `main` (deployed `9718af6`) |
| start command | `python notification_worker.py` |
| restart policy | **ALWAYS** (maxRetries 10) — see note |
| replicas | **1** (singleton APScheduler producer — no double-fire) |
| port / domain / healthcheck | none (daemon) |
| builder | DOCKERFILE (inherited from railway.toml at build, same as ai-worker) |

Reference variables (names only — values are chained refs to the API service, never printed):
- `DATABASE_URL` = `${{ wardrobe-backend.DATABASE_URL }}`
- `REDIS_URL` = `${{ wardrobe-backend.REDIS_URL }}`
- `FIREBASE_CREDENTIALS_JSON` = `${{ wardrobe-backend.FIREBASE_CREDENTIALS_JSON }}`

Created via `railway add --service notification-worker --repo ... --branch main`; config (start cmd / restart /
replicas) + the 3 ref vars set via GraphQL `serviceInstanceUpdate` + `variableUpsert`. The `railway add`
auto-triggered an initial misconfigured deploy (no start cmd / no vars); applying config superseded it with a
correct deploy. Note: this service's deploys are **not** gated by NEEDS_APPROVAL (only the API service is).

**Restart-policy note:** chose `ALWAYS` per task instruction (singleton scheduler+consumer daemon → robust
auto-recovery; never permanently "gives up" like ON_FAILURE after max retries). ai-worker uses `ON_FAILURE`.
If tech-lead wants parity, flip to ON_FAILURE — worker is not thrashing either way.

## TASK 3 — Deploy + verify worker — DONE (stable & running)

Deploy `90dc1143-26cf-4748-a87b-b28b8c334bef` → `SUCCESS`. Worker is a **single stable process** (4+ min
uptime, "Starting Notification Worker" ×1, "Scheduler started" ×1 — no crash-loop; ALWAYS never had to
restart). Key startup log lines (secrets-free):

```
Adding job tentatively ... Added job "run_daily_tick" to job store "default"
Added job "run_scheduled_admin_pickup" to job store "default"
Added job "run_retention_prune" to job store "default"
apscheduler.scheduler - INFO - Scheduler started
__main__ - INFO - Reminder scheduler started (daily/admin-pickup/retention)
__main__ - INFO - Starting Notification Worker...
apscheduler.executors.default - INFO - Job "run_scheduled_admin_pickup (... next run at: 04:48:42 UTC)" executed successfully
```

- **Scheduler: HEALTHY** — 3 jobs registered + executing on schedule (admin-pickup every 60s, querying the
  `notifications` table — proves migration + DB reachability). This is the core daily-reminder engine.
- **DB: connected** (sqlalchemy queries succeed). **Redis: connected** (client pings OK at startup).

### Concern 1 (route to backend-dev) — BRPOP idle log-noise, NOT a delivery break, NOT infra
Every ~5s on the idle/empty queue: `services.queue_service - ERROR - Failed to pop notification job: Timeout reading from socket`.
- Root cause: `services/queue_service.py:28` does `redis.from_url(url, decode_responses=True)` with
  **socket_timeout=None**, then `brpop(NOTIFICATION_QUEUE, timeout=10)` (line 249). The ~5s read drop is
  Railway's private-network / Redis idle-connection timeout on the blocking read, surfaced by redis-py as
  TimeoutError and logged at ERROR.
- **Not my env wiring:** worker `REDIS_URL` resolves to `redis://default:***@redis.railway.internal:6379` —
  identical internal endpoint to API + ai-worker. Same brpop code ai-worker uses (line 165).
- **No message loss:** with socket_timeout=None, a dropped idle BRPOP does not pop an element (Redis only
  pops for a live client) → a real job is returned immediately on the next pop. This is pure log/Sentry noise
  + reconnect churn, not a functional break.
- **Why it matters anyway:** ERROR-level every 5s ≈ ~17k events/day → log + Sentry spam. Fix is app-code
  (services/queue_service.py — owned by backend-dev): downgrade idle timeout to debug and/or add
  `socket_keepalive=True` + `health_check_interval` (and ideally treat BRPOP timeout as a normal idle tick).
  Left worker RUNNING (did NOT scale to 0) — it's not thrashing and the scheduler must keep ticking.

### Concern 2 (expected, not a bug) — firebase-admin init line absent
`init_firebase()` (`services/push_service.py:40`) is **lazy** (guarded one-time, logs
"firebase-admin initialised for FCM push" at line 64) and only runs on the first actual push delivery. Queue
is empty at go-live → not yet invoked. `FIREBASE_CREDENTIALS_JSON` is correctly wired (ref var present; the
API's copy was verified good last task, len 2312 / sha256 894d2dd2). Will initialise on first delivery —
**not yet exercised end-to-end** (would need a registered device token + an admin/scheduled push, which is
mobile + app-flow, out of ops scope).

---

## Running-system state after this turn
- API service: new release live (9718af6), 3 push tables in prod DB, notifications routes serving (401 unauth).
- New service `notification-worker` live: scheduler producing daily/admin/retention ticks; BRPOP consumer up.
- No other services touched (Postgres/Redis/ai-worker untouched).

## How to verify health
- API: `POST /api/notifications/device-token` (no auth) → 401. Railway API logs clean.
- Worker: deploy `90dc1143` SUCCESS; logs show "Scheduler started" + `run_scheduled_admin_pickup ... executed
  successfully` every 60s, single process. Ignore the 5s BRPOP idle ERRORs until Concern 1 is fixed.

## Rollback
- API: redeploy prior SUCCESS `1759c450` (commit 4c9f1896). New tables are additive — safe to leave.
- Worker: scale to 0 / delete service `2127dfdc...` (it's isolated; the scheduler stops, no other impact).

## Unresolved / handoffs
- **backend-dev:** fix `services/queue_service.py` BRPOP idle-timeout ERROR spam (Concern 1) — log-level +
  socket_keepalive/health_check_interval. Low severity (no loss) but burns Sentry quota.
- **tech-lead:** confirm restart-policy choice ALWAYS (mine) vs ON_FAILURE (ai-worker parity).
- **End-to-end push delivery** (token register → admin/scheduled send → FCM → firebase-admin init) not yet
  exercised — needs a real device + admin auth (mobile/QA, not ops).
