# Push Notification System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Spec:** [`spec.md`](./spec.md) — read it first. This plan implements it.

**Goal:** A server-driven push notification system delivering schedule reminders (daily + planned-outfit) and admin-composed messages to user devices via FCM, queue-backed.

**Architecture:** FastAPI backend (service→repo→router) owns 3 tables + a `push_service` (FCM via `firebase-admin`) + a queue-backed `notification_service` (producer `enqueue` / consumer `deliver`, reusing the Redis `queue_service`). A separate `notification-worker` runs the consumer + an APScheduler producer. The RN app registers an FCM device token (+ timezone) and routes taps via a curated deep-link registry. The admin SPA composes/sends + views history.

**Tech Stack:** Python 3.9 · FastAPI · SQLAlchemy · Alembic · Redis · firebase-admin · APScheduler · React Native 0.83 · `@react-native-firebase/messaging` · React 19 + Vite + Ant Design (admin) · Mixpanel.

## Global Constraints

- **Provider:** self-managed FCM only (`@react-native-firebase/messaging` mobile + `firebase-admin` backend). No OneSignal/Expo.
- **Migration:** single Alembic revision, `down_revision = schedule1a2b` (current head). Keep one head.
- **Deep-link payload** (`notifications.data`): exactly `{"kind":"route","screen":<curated>}` or `{"kind":"external","url":<http(s)>}`. Curated screens v1: `Home`, `Schedule`, `Favourite`, `Creations`, `Settings`. Unknown → fallback `Home` (never crash).
- **Daily slot is adaptive + single:** one reminder per user per local day; if a `schedule_entries` row exists for the user's today → `planned_outfit` copy (→Schedule), else `daily_reminder` copy (→Home). Both gated by `daily_notification.enabled`. Default time fallback `07:30 AM`.
- **Dedup key:** `(user_id, daily_slot, local_date)` for system reminders, checked at enqueue + idempotent at consume.
- **Timezone** source of truth = `device_tokens.timezone` (IANA). DST via tz math.
- **Security:** user endpoints `get_current_user` + user-scoped (404 hides ownership); admin endpoints `get_current_admin` (403 non-admin). Tokens never returned to clients.
- **No PII in push payloads / Mixpanel props** (per `.claude/rules/analytics-tracking-required.md`). Admin body is admin-authored (allowed).
- **Analytics:** every new mobile interaction ships a Mixpanel event via `src/services/analytics.ts` + updates `auxi/docs/analytics/mixpanel-tracking-plan.md`.
- **API doc:** update `wardrobe-backend/API_DOCUMENTATION.md` for every new `/api/*` route.
- **Verification gates:** backend `python test_server.py`; mobile `npx tsc --noEmit && yarn lint` + `./scripts/auxi-lint-tokens.sh`; admin `yarn build`. Real-device push verification is a manual QA step (sim push unreliable).
- **iOS build:** native dep add (firebase) needs pod install + rebuild — coordinate per `.claude/rules/ios-build-workflow-required.md` (shared Metro/sim singleton; never unilateral rebuild).

---

## Locked cross-phase interfaces (contract — all phases match these names/types verbatim)

### Models (Phase 0)
```
DeviceToken      : id(str uuid pk) user_id(str fk idx) token(str unique) platform(str 'ios'|'android')
                   timezone(str IANA) app_version(str|None) created_at(dt) last_seen_at(dt)
Notification     : id(str uuid pk) source(str 'system'|'admin') type(str) title(str) body(str)
                   data(JSON) audience(JSON|None) created_by(str fk|None) scheduled_for(dt|None)
                   status(str 'queued'|'sending'|'sent'|'failed') created_at(dt) sent_at(dt|None)
NotificationDelivery : id(str uuid pk) notification_id(str fk idx) user_id(str fk idx)
                   status(str 'pending'|'sent'|'failed'|'no_token') read_at(dt|None) error(str|None)
                   created_at(dt) sent_at(dt|None)
```
`type` values: `daily_reminder` `planned_outfit` `admin_broadcast` `admin_direct` `admin_segment`.

### push_service.py (Phase 0)
```python
def init_firebase() -> None                       # idempotent; reads settings.FIREBASE_CREDENTIALS_JSON
def send_to_tokens(tokens: list[str], title: str, body: str, data: dict[str, str]) -> PushResult
# PushResult = dataclass(success_count:int, failure_count:int, invalid_tokens:list[str])
```

### notification_service.py (Phase 0 = deliver; Phase 2 = enqueue)
```python
def create_system_notification(db, type_: str, title: str, body: str, data: dict) -> Notification   # P0
def resolve_audience(db, audience: dict) -> list[str]            # P2; audience={mode,user_ids?,segment?}
def enqueue(db, notification_id: str) -> int                     # P2; returns #jobs pushed
def deliver(db, job: dict) -> None                              # P0; see job shape below
```

### Queue job shape (Phase 2 producer → Phase 2 consumer)
```jsonc
{ "notification_id": "<uuid>", "type": "<type>", "user_id": "<uuid>",
  "local_date": "YYYY-MM-DD", "payload": { "kind":"route","screen":"Home" } }
```
Queue name: `notification_queue`. Reuse `services/queue_service.py` push/pop helpers.

### HTTP endpoints
```
POST   /api/notifications/device-token   {token,platform,timezone,app_version?} -> 200 {ok:true}   (user)  P0
DELETE /api/notifications/device-token   {token} -> 200 {ok:true}                                   (user)  P0
POST   /api/admin/notifications/send     {title,body,data,audience,scheduled_for?} -> 202 {notification_id,status} (admin) P2
GET    /api/admin/notifications          ?limit&offset -> {notifications:[...],total}               (admin) P2
GET    /api/admin/notifications/{id}     -> {notification, summary:{sent,failed,no_token,read}}     (admin) P2
```

### Mobile `src/services/notificationService.ts` (Phase 1)
```ts
registerDeviceForPush(): Promise<void>     // permission → FCM token → POST device-token {token,platform,timezone,app_version}
unregisterDevice(): Promise<void>          // DELETE device-token (logout)
// deep-link resolution lives in deepLinkHandler.ts: resolveNotificationData(data) -> navigates or fallback Home
```

### Admin `src/services/notificationsService.ts` (Phase 2)
```ts
send(payload:{title;body;data;audience;scheduled_for?}): Promise<{notification_id;status}>
getHistory(params:{limit;offset}): Promise<{notifications;total}>
getDetail(id:string): Promise<NotificationDetail>
```

### Mixpanel events (Phase 1)
`push_permission_requested` · `push_permission_granted` · `push_permission_denied` · `device_token_registered` · `push_received {type}` · `push_opened {type}`

---

## Phases (each independently shippable)

| Phase | File | Repo(s) | Deliverable |
|---|---|---|---|
| 0 | [`phase-0-backend-foundation.md`](./phase-0-backend-foundation.md) | wardrobe-backend | 3 models + migration, `push_service` (FCM), `notification_service.deliver` + `create_system_notification`, device-token endpoints, config, API doc |
| 1 | [`phase-1-mobile-push-plumbing.md`](./phase-1-mobile-push-plumbing.md) | auxi | firebase libs + native config, permission, token+tz registration, refresh/unregister, deep-link tap routing, foreground handler, Mixpanel events |
| 2 | [`phase-2-queue-admin-send.md`](./phase-2-queue-admin-send.md) | wardrobe-backend + wardrobe-admin | Redis `notification_queue` + `notification_worker` consumer, `enqueue`+`resolve_audience`, admin send/list/detail endpoints (all/specific + segment fast-follow), admin SPA Notifications page + history |
| 3 | [`phase-3-scheduler-engine.md`](./phase-3-scheduler-engine.md) | wardrobe-backend | APScheduler producer (adaptive daily slot, scheduled-admin pickup, retention), per-tz selection + dedup, `notification-worker` Railway service |

**Dependencies:** P0 → P1 (mobile needs the device-token endpoint) and P0 → P2 (admin send needs models + deliver). P2 → P3 (scheduler enqueues onto P2's queue + consumer). P1 is parallelizable with P2 after P0.

**Phase 4 (future, NOT in this plan):** in-app inbox — `GET /api/notifications` + `POST /api/notifications/{id}/read` + mobile inbox screen, reading `notification_deliveries.read_at`.

## Implementation reconciliations (cross-phase flags from plan authoring — resolve during execution)
- **Stale local checkouts:** the local `wardrobe-backend`/`auxi` submodules are on stale junk-drawer branches; the spec's `schedule`/`creations` modules aren't present locally and there are divergent migration heads. **Implement on fresh worktrees off canonical `main`** (backend `auxi-wardrobe/auxi-backend`, mobile `auxi-wardrobe/auxi-mobile`); Task 1 of P0/P2/P3 must verify a single Alembic head and set the real `down_revision`. P0 mirrors the in-repo `app_feedback` module for layering (schedule/creations weren't visible).
- **System-reminder enqueue seam:** P3 currently calls `create_system_notification` then pushes per-user jobs directly; P2 defines `enqueue(notification_id)` (audience-resolving). Reconcile to **one path** — system reminders should `create_system_notification` then push the per-user job (audience already = that one user); keep `enqueue()` for admin audience resolution. Confirm both use the same `queue_service` helper + job shape.
- **Inactive segment proxy:** `User` has no `last_login`/`last_active` field → P2 uses `max(device_tokens.last_seen_at)` as the activity proxy (user with no token = inactive). Consider adding `User.last_active_at` later.
- **Mobile route name:** the curated `Creations` destination maps to the actual registered RN route **`MyCreations`** (load-bearing). Also: iOS needs `$RNFirebaseAsStaticFramework = true` (no `use_frameworks!`); add a `notificationService.web.ts` no-op stub so the RNW web preview still builds (firebase is native-only); IANA tz via the already-installed `react-native-localize`.
- **Locale for copy:** no `User.locale` field → P3 reads `user_metadata.locale`, falls back to `en`. Timezone via stdlib `zoneinfo` + `tzdata` (no pytz in repo).

## External prerequisites (human/ops — block live verification, not code authoring)
- Firebase project; APNs `.p8` key uploaded (Apple portal); `google-services.json` (Android) + `GoogleService-Info.plist` (iOS).
- `FIREBASE_CREDENTIALS_JSON` env set on backend + `notification-worker` Railway services (devops).
- iOS Push Notifications capability/entitlement on the App ID.
- A real iOS device for final push verification.
