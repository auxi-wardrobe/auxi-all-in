# Push Notification System — Design Spec

> Date: 2026-06-28 · Status: **approved-pending-review** · Author: brainstorm session
> Repos: `auxi` (RN mobile) · `wardrobe-backend` (FastAPI) · `wardrobe-backend/wardrobe-admin` (React SPA)

## 1. Goal

A server-driven push notification system that:
1. Sends **schedule-related reminders** to a user's device — a **daily outfit reminder** (from existing `daily_notification` settings) and a **planned-outfit reminder** (from `schedule_entries`).
2. Lets an **admin** compose and send notifications to users from the admin SPA — targeting **all users**, **specific users**, or a **segment**, either immediately or scheduled for later.

Both paths share **one delivery engine** (FCM → APNs/Android). Every notification is **persisted server-side** so admin gets history now and an in-app inbox is a clean phase-2 add.

## 2. Non-goals (this spec)

- In-app notification inbox screen + unread badge (read-state column is added now; the screen is **Phase 4, future** — documented in §12, not built here).
- Rich/media push, notification grouping/channels beyond a single default channel.
- A/B testing, scheduling recurrence builder for admin (admin gets immediate + single scheduled time only).
- Web push (admin SPA / web preview). Mobile only.

## 3. Decisions (from brainstorm)

| Decision | Choice | Rationale |
|---|---|---|
| Reminder engine | **Server-push** | One unified path with admin; fires when app closed; change centrally. |
| Schedule triggers | **Daily reminder + planned-outfit reminder** | Both requested. |
| Admin targeting | **All + specific + segment** | All requested; segment is the heaviest (see §9). |
| Persistence | **Store every notification + per-recipient delivery** | Admin history now; inbox later on same data. |
| Provider | **Self-managed FCM** (`@react-native-firebase/messaging` + `firebase-admin`) | Free, data in-house, sends from own admin SPA, reuses self-hosted backend. |
| Deep-link control | **Curated screens + external URL** (registry §5.1); param screens deferred | Safe for broadcast, dropdown UX, fallback→Home; full "any screen" reach is phase 2. |
| Delivery processing | **Redis queue (reuse `queue_service.py`) + worker consumer**; per-user jobs | Push has spikes (everyone at 06:15) + FCM 500-cap + needs retry/crash-safety; infra already exists. |
| Scope | **Phases 0–3**; inbox = future | Complete working system; inbox deferred. |

## 4. Architecture

```
MOBILE (auxi)                  BACKEND (wardrobe-backend)                   ADMIN SPA
─────────────                  ──────────────────────────                   ─────────
@react-native-firebase/msg     routers/notifications.py (user)              Notifications page
 • request permission   ──────► POST  /api/notifications/device-token  ◄──┐  • compose form
 • get FCM token               DELETE /api/notifications/device-token    │  • audience select
 • POST {token,platform,tz}                                              │  • history table
 • token-refresh listener      routers/admin/notifications.py (admin) ◄──┘
 • tap → deepLinkHandler        POST /api/admin/notifications/send
   → navRef.navigate(screen)    GET  /api/admin/notifications[/{id}]
        ▲ push                  services/notification_service.py  (orchestrate · fan-out · dedup)
        │                       services/push_service.py ─ firebase-admin ─► FCM ─► APNs(iOS)/Android
    FCM/APNs                    models: device_token · notification · notification_delivery
        ▲ consumer sends        ──── Redis queue (reuse queue_service.py) ────
        │                       PRODUCERS ─enqueue per-user job→ [queue] ─BRPOP→ CONSUMER
        │                        • scheduler (APScheduler, NET-NEW) = WHEN     notification_worker.py
        └──────────────────────    ~15min daily · morning planned · sched-admin   = HOW (drain→push)
                                 • admin send endpoint = enqueue on request
```

**Delivery flow (single path, queue-backed):** a **producer** (scheduler tick OR admin send endpoint) resolves the audience → user ids, dedups, and **enqueues one job per user** onto a Redis queue. The **consumer** (`notification_worker.py`) `BRPOP`s each job → loads that user's `device_tokens` → `push_service.send_to_tokens(...)` (FCM multicast, 500-batch) → writes `notification_deliveries` with per-recipient status → cleans up tokens FCM reports as `NOT_REGISTERED` → retries transient errors. Scheduler decides **when**; the queue makes delivery reliable, spike-tolerant, and crash-safe.

## 5. Data model (3 new tables)

### `device_tokens`
| col | type | notes |
|---|---|---|
| id | uuid PK | |
| user_id | str FK→users, indexed | |
| token | str, **unique** | FCM registration token |
| platform | str | `ios` \| `android` |
| timezone | str | IANA tz e.g. `Asia/Saigon` — **required for daily reminder** |
| app_version | str nullable | diagnostics |
| created_at / last_seen_at | datetime | refreshed on each register |

- **Upsert on `token`**: re-registering updates `user_id` (handles logout→login on same device), `timezone`, `last_seen_at`.
- Delete on unregister (logout) and on FCM `NOT_REGISTERED`/`UNREGISTERED`.

### `notifications` (message / campaign)
| col | type | notes |
|---|---|---|
| id | uuid PK | |
| source | str | `system` \| `admin` |
| type | str | `daily_reminder` \| `planned_outfit` \| `admin_broadcast` \| `admin_direct` \| `admin_segment` |
| title | str | |
| body | str | |
| data | JSON | deep-link payload — see §5.1 registry (`{kind:'route', screen}` or `{kind:'external', url}`) |
| audience | JSON | `{mode:'all'|'users'|'segment', user_ids?:[], segment?:{...}}` (admin); null for per-user system runs |
| created_by | str FK→users nullable | admin id; null = system |
| scheduled_for | datetime nullable | null = immediate; future = queued |
| status | str | `queued` \| `sending` \| `sent` \| `failed` |
| created_at / sent_at | datetime | |

### `notification_deliveries` (per-recipient fan-out + future inbox)
| col | type | notes |
|---|---|---|
| id | uuid PK | |
| notification_id | uuid FK→notifications, indexed | |
| user_id | str FK→users, indexed | |
| status | str | `pending` \| `sent` \| `failed` \| `no_token` |
| read_at | datetime nullable | **future inbox** (column added now, unused in P0–3) |
| error | str nullable | FCM error code |
| created_at / sent_at | datetime | |

- **Dedup guard (system reminders):** unique-ish key `(user_id, type, local_date)` enforced in service logic (and/or a partial index) → at most one `daily_reminder` and one `planned_outfit` per user per local day.
- **Migration:** single Alembic revision, `down_revision = schedule1a2b` (current head per the shipped schedule feature) to keep one head.
- **Retention (ops):** system deliveries pruned after N days (e.g. 30) by the worker — system reminders are transient; admin notifications retained for history.

### 5.1 Deep-link destination registry (shared contract)

The notification tap routes to where `data` points. Admin picks the destination from a **curated registry** (no free-form `auxi://` typing). The same registry is the contract on both ends; admin renders it, mobile validates against it, `API_DOCUMENTATION.md` is the canonical list (no shared SDK → list duplicated in admin SPA + mobile, kept in sync manually).

**`data` payload — two kinds:**
```jsonc
// in-app screen (curated, param-free in v1)
{ "kind": "route", "screen": "Home" | "Schedule" | "Favourite" | "Creations" | "Settings" }
// external link
{ "kind": "external", "url": "https://..." }   // http/https only
```

**v1 curated screens** (param-free, safe for broadcast): `Home`, `Schedule`, `Favourite`, `Creations`, `Settings`. System reminders use this same shape — `daily_reminder`→`{kind:'route',screen:'Home'}`, `planned_outfit`→`{kind:'route',screen:'Schedule'}`.

**Resolution rules (mobile):**
- `kind:'route'` + `screen` in allowlist → `navRef.navigate(screen)`.
- `kind:'external'` + valid http(s) `url` → open in browser/in-app webview.
- unknown kind / screen not in allowlist / missing data → **fallback `Home`** (never crash).

**Deferred (phase 2+):** param screens (e.g. `ItemDetail` needing `itemId`) and an "advanced custom route" mode. When added, broadcasts to a param screen must warn the admin (param only resolves for the targeted user).

## 6. Backend components (`wardrobe-backend`)

Follows the existing service→repo→router→model pattern (mirrors `schedule`/`creations` modules).

- **Models:** `models/device_token.py`, `models/notification.py`, `models/notification_delivery.py`.
- **Repositories:** `repositories/device_token_repository.py` (upsert/get-by-user/delete-by-token), `repositories/notification_repository.py` (create message, create deliveries, list+stats, dedup lookup).
- **Service `services/notification_service.py`:** orchestration. Two halves: **`enqueue(notification)`** (producer side — resolve audience → user ids, dedup, push one job per user onto the Redis queue, reusing `services/queue_service.py`) and **`deliver(job)`** (consumer side — load tokens, call push, write deliveries, invalid-token cleanup, retry). Single entry point for **both** admin and system sends.
- **Service `services/push_service.py`:** thin FCM abstraction over `firebase-admin` (HTTP v1). `send_to_tokens(tokens, title, body, data) -> per-token result`; multicast batching (FCM 500/req); maps FCM errors → cleanup list. Isolated so it's mockable in tests and swappable later.
- **Router `routers/notifications.py`** (user, `get_current_user`):
  - `POST /api/notifications/device-token` — body `{token, platform, timezone, app_version?}`; upsert. Rate-limit ~20/min.
  - `DELETE /api/notifications/device-token` — body `{token}`; remove on logout. User-scoped (404 hides ownership).
- **Router `routers/admin/notifications.py`** (admin, `get_current_admin`), registered in `routers/admin/__init__.py`:
  - `POST /api/admin/notifications/send` — `{title, body, data?, audience, scheduled_for?}`. Immediate → send now; scheduled → persist `queued`, worker picks up.
  - `GET /api/admin/notifications` — paginated history + delivery stats (sent/failed/no_token, read counts).
  - `GET /api/admin/notifications/{id}` — detail + delivery breakdown.
- **Config/secrets (`settings.py`):** `FIREBASE_CREDENTIALS_JSON` (service-account JSON, Railway env). Pydantic `BaseSettings` reads it; no code change to load mechanism. (Note: `app.py` doesn't `load_dotenv`; the worker process must also read settings — runs via the same Pydantic settings, supply env in Railway.)
- **API doc:** update `API_DOCUMENTATION.md` (mandatory contract) for all new `/api/*` routes; admin routes noted as internal.

## 7. Push provider integration (FCM)

- **Backend:** `firebase-admin` initialized from `FIREBASE_CREDENTIALS_JSON`. Use HTTP v1 multicast. Handle `messaging/registration-token-not-registered` → delete token.
- **iOS:** upload an **APNs auth key (`.p8`)** to the Firebase project (Apple Developer portal — team already manages ASC keys). Add Push Notifications capability + `aps-environment` entitlement; configure `AppDelegate` for `@react-native-firebase/messaging`.
- **Android:** `google-services.json` in `android/app`; FCM auto-wires. Default notification channel.
- **EU residency note:** device tokens + payloads transit Google (FCM) — consistent with existing Gemini + Mixpanel-EU posture. Payloads carry **no PII** (ids only, localized copy generated client-or-template-side); free-text admin body is admin-authored, not user PII.

## 8. Mobile components (`auxi`)

- **Deps (native rebuild required):** `@react-native-firebase/app`, `@react-native-firebase/messaging`. Pod install + rebuild — coordinate per `ios-build-workflow-required.md` (shared sim/Metro singleton; never unilateral rebuild).
- **`src/services/notificationService.ts`:**
  - `registerDeviceForPush()` — request permission → get FCM token → `POST /api/notifications/device-token` with `{token, platform, timezone (from device), app_version}`.
  - token-refresh listener → re-register; `unregisterDevice()` on logout (`DELETE`).
- **Permission UX:** request contextually (after login / when enabling reminders), not cold on first launch. Denied → guidance + Open-Settings (AU-316 already scoped this affordance).
- **Settings tie-in:** reuse AU-316 `user_metadata.daily_notification {enabled, time, period, frequency}` **unchanged** — server engine reads it. When the user enables reminders, ensure a device token + permission exist. No settings-UI redesign.
- **Tap routing:** extend `src/services/deepLinkHandler.ts` (or a small `notificationRouter.ts`) to resolve push `data` against the §5.1 registry — `kind:'route'`+allowlisted `screen` → `navRef.navigate(screen)`; `kind:'external'` → open URL; anything unknown/missing → **fallback `Home`** (never crash). Keep the curated screen allowlist as a single mobile constant (mirror of §5.1). Handle foreground (`onMessage` → in-app banner), background (`setBackgroundMessageHandler`), and cold-start (`getInitialNotification`).
- **Analytics (required):** `push_permission_requested`, `push_permission_granted`/`_denied`, `device_token_registered`, `push_received` `{type}`, `push_opened` `{type}`. Add to `analytics.ts` + tracking-plan doc.

## 9. Admin SPA components (`wardrobe-admin`)

- **`src/services/notificationsService.ts`** — `send(payload)`, `getHistory(params)`, `getDetail(id)` (axios `api`, token auto-attached).
- **`src/pages/Notifications.tsx`:**
  - **Compose:** title, body, **destination picker** (§5.1: dropdown of curated screens — Home/Schedule/Favourite/Creations/Settings — or "External URL" → reveals a URL input; default Home), audience selector:
    - *All users* — broadcast.
    - *Specific users* — search by email (reuse `Users` page fetch pattern), multi-select.
    - *Segment* — **ship All+Specific first; segment is a fast-follow within Phase 2.** v1 segment attributes (server-side SQL filters): **`gender`**, **`inactive > N days`** (re-engagement, via `last_seen_at`/login), **`has-items`** (onboarded vs empty wardrobe). Resolved server-side; combinable later.
  - **Timing:** send now or pick `scheduled_for`.
  - **History table:** past notifications with sent/failed/no_token + read counts; row → detail.
- **Routing/nav:** add route in `App.tsx` + menu item in `Layout.tsx` (Bell icon). TanStack Query mutation + toast pattern as in `CommonItems`.

## 10. Reminder engine + delivery queue (NET-NEW)

Two decoupled pieces — the **scheduler** decides *when*, the **queue+consumer** make delivery reliable. Both run in a small worker process (new Railway service, or extend `ai_worker.py`).

### Scheduler (producer, APScheduler) — decides WHEN
- **Daily slot (adaptive content)** — every ~15 min: find users with `daily_notification.enabled=true` whose local time (from `device_tokens.timezone`) matches their `time`+`period` and whose `frequency` allows today (weekdays vs everydays). Content adapts per user:
  - has a `schedule_entries` row for *their* today → **planned-outfit** copy, payload `{kind:'route', screen:'Schedule'}`, type `planned_outfit`.
  - otherwise → **daily nudge** copy, payload `{kind:'route', screen:'Home'}`, type `daily_reminder`.
  **One slot per day → never double-notifies**; planned-outfit takes precedence. Dedup `(user, daily_slot, local_date)` at enqueue. Both variants gated by the single `enabled` toggle.
- **Scheduled-admin pickup** — `notifications` where `status=queued AND scheduled_for<=now` → enqueue its deliveries, mark `sending`→`sent`.
- **Retention** — prune system deliveries older than N days.

> **Default time:** 07:30 AM fallback when a user has no stored `daily_notification.time` (matches the AU-316 UAC intent). The engine always reads the stored value first. Reconcile mobile `DEFAULT_SETTINGS.time` to 07:30 for consistency (currently 06:15) — one-line change, confirm with CEO.

The scheduler tick stays **lightweight + idempotent**: it only queries who's due and enqueues; it never calls FCM directly.

### Queue + consumer (does the work reliably) — decides HOW
- **Queue:** reuse `services/queue_service.py` (Redis). A new list e.g. `notification_queue`. Job = per-user: `{notification_id, type, user_id, local_date, payload}`.
- **Consumer (`notification_worker.py`):** `BRPOP` loop → `notification_service.deliver(job)` → load user's `device_tokens` → `push_service` FCM multicast (≤500/req) → write `notification_deliveries` → cleanup invalid tokens → **retry** transient FCM/network errors (bounded; on final failure mark `failed`).
- **Why queued (not direct):** daily reminders spike (all users at one time), FCM caps 500/req, retry must be isolated per user, and a worker restart must resume without losing or duplicating sends (delivery record + dedup guard).
- **Admin immediate sends** flow through the **same** queue (endpoint enqueues, returns fast); broadcast to thousands never blocks the HTTP request.

### Cross-cutting for the engine
- **Timezone:** `device_tokens.timezone` is the source of truth (user_metadata has none). Multi-device different-tz user → dedup per user-day so they don't get N copies (one reminder per user/day regardless of device count — see §13 Q5).
- **Edge cases:** no token → `no_token` (skip, no crash); OS permission revoked → FCM cleanup eventually; time already passed today → next eligible day; DST via IANA tz math; duplicate enqueue → idempotent consume (delivery dedup).

### System reminder copy (v1, i18n en/vi/fr)
Localized per user (locale from profile/device); chosen by `type`. Stored as i18n keys, not literal payloads.

| type | lang | title | body |
|---|---|---|---|
| `daily_reminder` | en | Time to plan today's outfit ✨ | Open Auxi and pick your look for the day. |
| | vi | Đến giờ chọn đồ cho hôm nay ✨ | Mở Auxi chọn outfit cho ngày mới nào. |
| | fr | L'heure de choisir votre tenue ✨ | Ouvrez Auxi et composez votre look du jour. |
| `planned_outfit` | en | You planned an outfit for today 👗 | Tap to see your look in Schedule. |
| | vi | Bạn đã lên đồ cho hôm nay 👗 | Chạm để xem outfit trong Lịch. |
| | fr | Vous avez prévu une tenue aujourd'hui 👗 | Touchez pour la voir dans le Calendrier. |

Admin notifications: title/body are admin-authored free text (not i18n keys) — sent verbatim.

## 11. Cross-cutting

- **Security:** user endpoints `get_current_user` + user-scoped (IDOR-safe, 404 hides ownership); admin endpoints `get_current_admin` (403 on non-admin). Tokens never returned to clients. Rate-limit device-token + admin-send.
- **Idempotency:** dedup keys for system reminders; admin send is explicit (no auto-retry of a whole campaign, but per-token retry within a send).
- **Testing:** backend pytest (service with mocked `push_service`, repo CRUD, dedup, audience resolution, worker job selection with frozen time); mobile tsc/eslint + unit for `deepLinkHandler` payload routing + `notificationService` registration; admin manual + mutation tests. Push delivery itself verified on a **real device** (iOS simulator push is unreliable) — gated to a manual QA step.
- **Verification gates:** backend `python test_server.py`; mobile `npx tsc --noEmit && yarn lint` + `auxi-lint-tokens.sh`; admin `yarn build`; smoke against real backend (no mocks).

## 12. Phasing

| Phase | Deliverable | Repos | Verify |
|---|---|---|---|
| **0** | 3 models + migration (`down_revision=schedule1a2b`), `push_service` (FCM), `notification_service.deliver()` (send-one + fan-out + cleanup, mockable), device-token register/unregister endpoints, `FIREBASE_CREDENTIALS_JSON`, API doc | backend | pytest (mocked FCM); migration up/down; `/api/notifications/device-token` 401→works |
| **1** | firebase libs + native config (rebuild), permission flow, token+tz registration, refresh/unregister, tap→route via deepLinkHandler, foreground handler, Mixpanel events, tracking-plan | auxi | tsc/eslint/token-lint; manual push to real device routes correctly |
| **2** | Redis `notification_queue` + `notification_worker.py` **consumer** (drain→`deliver`), `notification_service.enqueue()`, `/api/admin/notifications/{send,list,detail}` (all/specific/segment, immediate→enqueue + scheduled), admin SPA Notifications page + history | backend + admin | admin sends broadcast → enqueued → device receives; worker retry/cleanup works; history shows stats |
| **3** | **scheduler** (APScheduler producer) in the worker: daily + planned-outfit jobs (per-tz, dedup, enqueue), scheduled-admin pickup, retention; Railway worker service config | backend | frozen-time unit tests select right users; live: a due user gets exactly one daily reminder |
| **4** *(future, not in this spec)* | In-app inbox: `GET /api/notifications` (user), `POST /api/notifications/{id}/read`, mobile inbox screen + unread badge — reads existing `notification_deliveries.read_at` | auxi + backend | — |

## 13. Resolved decisions (were open; chosen 2026-06-29)

1. **Default time + copy** → fallback **07:30 AM** (engine reads stored value first); reconcile mobile `DEFAULT_SETTINGS.time` 06:15→07:30 (CEO confirm, one-liner). Copy en/vi/fr in §10.
2. **Planned-outfit timing** → **no separate slot**. Shares the user's daily slot; content adapts (planned-outfit precedence over daily nudge); both gated by `enabled` (§10).
3. **Worker hosting** → **separate Railway service `notification-worker`** (isolate from `ai-worker`, which carries a deploy backlog). devops executes.
4. **Segment v1** → **All + Specific first; segment fast-follow** with attributes `gender` / `inactive>N days` / `has-items` (§9).
5. **Multi-device dedup** → **yes** — one reminder per user/local-day; consumer still multicasts to all the user's devices; dedup key `(user, slot, local_date)`.

### Remaining external prerequisites (human/ops, not code)
- Firebase project + APNs `.p8` key uploaded (Apple portal); `google-services.json` (Android) + `GoogleService-Info.plist` (iOS).
- `FIREBASE_CREDENTIALS_JSON` set on backend + `notification-worker` Railway services.
- iOS Push Notifications capability/entitlement on the App ID.
- Push delivery final verification needs a **real iOS device** (simulator push unreliable).
