# Phase 2: Delivery Queue + Admin Send

Wire the **producer/consumer delivery path** and the **admin send surface**: a Redis `notification_queue`, a `notification_worker.py` consumer, `notification_service.enqueue` + `resolve_audience`, the `/api/admin/notifications/{send,list,detail}` endpoints, and the admin SPA Notifications page (compose + history). All-users and specific-users ship first; **segment targeting is a clearly-labeled fast-follow** (Task 11).

**Prereqs: Phase 0** (already merged on `wardrobe-backend` main) provides — `models/{device_token,notification,notification_delivery}.py`, `services/push_service.py` (`init_firebase`, `send_to_tokens`), `services/notification_service.py` with `create_system_notification(db, type_, title, body, data)` + `deliver(db, job)`, the device-token endpoints, and the single Alembic head `down_revision = schedule1a2b`. Phase 2 **consumes** these — it does NOT redefine models, `push_service`, `deliver`, or `create_system_notification`.

> ⚠️ **Local checkout is stale.** This repo is currently on `feature/au318-mood-feedback`; the `schedule`/`creations` modules and Phase 0's notification models are NOT present. **Task 1 forces a sync to up-to-date `auxi-backend` main with a single migration head before any Phase 2 code.** Mirror the in-repo `app_feedback` module (`models/app_feedback.py` → `repositories/app_feedback_repository.py` → `services/app_feedback_service.py` → `routers/admin/app_feedback.py` + `tests/test_app_feedback_*.py`) for layering, and `ai_worker.py` for the worker loop.

## Files overview

### Backend (`wardrobe-backend`)
- **Modify** `services/queue_service.py` — generic `push_notification_job` / `pop_notification_job` + `NOTIFICATION_QUEUE` const.
- **Modify** `repositories/notification_repository.py` — `get`, `create`, `list`, `get_delivered_user_ids`, `summary_for`, `get_detail`.
- **Modify** `services/notification_service.py` — add `resolve_audience` + `enqueue` (Phase 0's `create_system_notification`/`deliver` stay).
- **Create** `notification_worker.py` (repo root, sibling of `ai_worker.py`) — BRPOP consumer.
- **Create** `schemas/notification.py` — admin request/response Pydantic models + curated-screen vocab.
- **Create** `routers/admin/notifications.py` — send/list/detail; register in `routers/admin/__init__.py`.
- **Modify** `routers/admin/__init__.py` — include the new router.
- **Modify** `API_DOCUMENTATION.md` — document the 3 admin routes (internal `/admin/*`).
- **Modify** `tests/conftest.py` — shared `notif_db` fixture.
- **Create** tests: `tests/test_notification_queue_helpers.py`, `tests/test_notification_repository.py`, `tests/test_notification_service_audience.py`, `tests/test_notification_service_enqueue.py`, `tests/test_notification_worker.py`, `tests/test_admin_notifications_router.py`.

### Admin SPA (`wardrobe-backend/wardrobe-admin`)
- **Modify** `src/types/index.ts` — notification types.
- **Create** `src/services/notificationsService.ts` — `send` / `getHistory` / `getDetail` + curated-screen options.
- **Create** `src/pages/Notifications.tsx` — compose form + history table + detail modal.
- **Modify** `src/App.tsx` — register `/notifications` route.
- **Modify** `src/components/layout/Layout.tsx` — Bell nav item.

## Locked interfaces (match VERBATIM — from `plan.md`)

```python
# services/notification_service.py
def resolve_audience(db, audience: dict) -> list[str]      # audience={mode,user_ids?,segment?}
def enqueue(db, notification_id: str) -> int               # returns #jobs pushed
# Phase 0 (consume, do not touch):
def create_system_notification(db, type_: str, title: str, body: str, data: dict) -> Notification
def deliver(db, job: dict) -> None
```

```jsonc
// Queue job shape (producer → consumer). Queue name: "notification_queue".
{ "notification_id": "<uuid>", "type": "<type>", "user_id": "<uuid>",
  "local_date": "YYYY-MM-DD", "payload": { "kind":"route","screen":"Home" } }
```

```
POST   /api/admin/notifications/send  {title,body,data,audience,scheduled_for?} -> 202 {notification_id,status}
GET    /api/admin/notifications       ?limit&offset -> {notifications:[...],total}
GET    /api/admin/notifications/{id}  -> {notification, summary:{sent,failed,no_token,read}}
```
- `type` by audience mode: `all`→`admin_broadcast`, `users`→`admin_direct`, `segment`→`admin_segment`. `source="admin"`.
- `data` payload: `{"kind":"route","screen":<Home|Schedule|Favourite|Creations|Settings>}` or `{"kind":"external","url":<http(s)>}`.

```ts
// src/services/notificationsService.ts
send(payload:{title;body;data;audience;scheduled_for?}): Promise<{notification_id;status}>
getHistory(params:{limit;offset}): Promise<{notifications;total}>
getDetail(id:string): Promise<NotificationDetail>
```

---

## Task 1: Prerequisite gate (sync) + queue push/pop helpers

Force an up-to-date checkout, confirm Phase 0 + single migration head, then add the generic Redis helpers both producer and consumer need.

**Files:**
- Verify only: git branch, `alembic heads`, presence of Phase 0 files.
- Modify: `services/queue_service.py`
- Modify: `tests/conftest.py` (shared `notif_db` fixture)
- Test: `tests/test_notification_queue_helpers.py`

**Interfaces:** Produces `services.queue_service.NOTIFICATION_QUEUE`, `queue_service.push_notification_job(job)->bool`, `queue_service.pop_notification_job(timeout)->dict|None`.

- [ ] **Sync gate (do this first):**
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git fetch origin
  git checkout main && git pull --ff-only origin main   # canonical auxi-backend main
  ```
- [ ] Confirm Phase 0 landed (all must exist):
  ```bash
  ls models/notification.py models/notification_delivery.py models/device_token.py \
     services/push_service.py services/notification_service.py
  grep -n "def create_system_notification\|def deliver" services/notification_service.py
  ```
  If any are missing, **STOP** — Phase 0 is not merged; do not proceed.
- [ ] Confirm exactly one Alembic head (no split):
  ```bash
  python -m alembic heads        # expect a SINGLE head (the Phase 0 revision, down_revision=schedule1a2b)
  ```
  More than one head → resolve before writing migrations-adjacent code.
- [ ] Add the shared test fixture to `tests/conftest.py` (mirrors `test_app_feedback_admin.py`'s `threaded_db`, with the 3 Phase-0 models added so `create_all` builds their tables):
  ```python
  @pytest.fixture
  def notif_db():
      """SQLite test DB + a get_db dependency override for notification tests.

      Mirrors the threaded_db pattern in tests/test_app_feedback_admin.py.
      Yields (main_session, get_db_dependency).
      """
      import os
      import tempfile
      from sqlalchemy import create_engine
      from sqlalchemy.orm import sessionmaker
      from models import (  # noqa: F401  (register tables on shared metadata)
          wardrobe, user, token, auth_token, body, favorite, tryon, decision,
          recommendation_log, v05_event, recommendation_feedback, app_feedback,
          notification, notification_delivery, device_token,
      )
      from extensions import db as flask_db

      fd, db_path = tempfile.mkstemp(suffix=".db")
      os.close(fd)
      url = f"sqlite:///{db_path}?check_same_thread=False"
      engine = create_engine(url, connect_args={"check_same_thread": False})
      flask_db.metadata.create_all(engine)
      SessionFactory = sessionmaker(bind=engine)

      def _get_db():
          s = SessionFactory()
          try:
              yield s
          finally:
              s.close()

      main = SessionFactory()
      yield main, _get_db
      main.close()
      engine.dispose()
      try:
          os.unlink(db_path)
      except OSError:
          pass
  ```
  (Add `import pytest` at top of conftest if not already present.)
- [ ] **TDD — write the failing test** `tests/test_notification_queue_helpers.py`:
  ```python
  """Phase 2 — generic Redis helpers for the notification queue.

  Uses fakeredis (already a dev dep — conftest's mock_redis uses it) so the
  test never needs a live Redis.
  """
  import fakeredis
  import pytest

  from services.queue_service import queue_service, NOTIFICATION_QUEUE


  @pytest.fixture
  def fake_redis(monkeypatch):
      fake = fakeredis.FakeStrictRedis(decode_responses=True)
      monkeypatch.setattr(queue_service, "redis_client", fake)
      return fake


  def _job(uid="u1"):
      return {
          "notification_id": "n1",
          "type": "admin_broadcast",
          "user_id": uid,
          "local_date": "2026-06-29",
          "payload": {"kind": "route", "screen": "Home"},
      }


  def test_push_returns_true_and_enqueues(fake_redis):
      assert queue_service.push_notification_job(_job()) is True
      assert fake_redis.llen(NOTIFICATION_QUEUE) == 1


  def test_pop_roundtrips_the_job(fake_redis):
      queue_service.push_notification_job(_job("uX"))
      popped = queue_service.pop_notification_job(timeout=1)
      assert popped == _job("uX")


  def test_pop_returns_none_when_empty(fake_redis):
      assert queue_service.pop_notification_job(timeout=1) is None


  def test_push_returns_false_when_disconnected(monkeypatch):
      monkeypatch.setattr(queue_service, "redis_client", None)
      assert queue_service.push_notification_job(_job()) is False
  ```
- [ ] Run — expect FAIL (`ImportError: cannot import name 'NOTIFICATION_QUEUE'`):
  ```bash
  python -m pytest tests/test_notification_queue_helpers.py -v
  ```
- [ ] **Implement** — append to `services/queue_service.py` (module-level const + two methods on `QueueService`):
  ```python
  # --- Notification queue (Phase 2) ----------------------------------------
  NOTIFICATION_QUEUE = "notification_queue"
  ```
  ```python
      # add these as methods of QueueService:
      def push_notification_job(self, job: Dict[str, Any]) -> bool:
          """LPUSH one per-user notification job onto the Redis list."""
          if not self.is_connected():
              logger.error("Redis not connected - cannot push notification job")
              return False
          try:
              self.redis_client.lpush(NOTIFICATION_QUEUE, json.dumps(job))
              return True
          except Exception as e:
              logger.error(f"Failed to push notification job: {e}")
              return False

      def pop_notification_job(self, timeout: int = 10) -> Optional[Dict[str, Any]]:
          """Blocking BRPOP one notification job; decoded dict or None."""
          if not self.is_connected():
              return None
          try:
              result = self.redis_client.brpop(NOTIFICATION_QUEUE, timeout=timeout)
              if not result:
                  return None
              return json.loads(result[1])
          except Exception as e:
              logger.error(f"Failed to pop notification job: {e}")
              return None
  ```
  (`redis.from_url(..., decode_responses=True)` is already set, so `result[1]` is a `str` — `json.loads` works directly.)
- [ ] Run — expect PASS. Commit:
  ```bash
  python -m pytest tests/test_notification_queue_helpers.py -v
  git add services/queue_service.py tests/conftest.py tests/test_notification_queue_helpers.py
  git commit -m "feat: add notification_queue push/pop helpers + shared notif test fixture"
  ```

---

## Task 2: `notification_repository` — create / get / list / dedup-lookup / summary

**Files:**
- Modify: `repositories/notification_repository.py`
- Test: `tests/test_notification_repository.py`

**Interfaces:** Consumes Phase 0 `models.notification.Notification`, `models.notification_delivery.NotificationDelivery`. Produces `NotificationRepository.{get, create, list, get_delivered_user_ids, summary_for, get_detail}` (used by `enqueue` Task 4 + admin router Task 6).

> `create` is generic (admin path). If Phase 0 already added a generic repo `create`, reuse it instead of duplicating — keep one creator.

- [ ] **TDD — failing test** `tests/test_notification_repository.py`:
  ```python
  """Phase 2 — NotificationRepository: create / list+total / dedup lookup / summary."""
  import uuid
  from datetime import datetime, timezone

  from repositories.notification_repository import NotificationRepository


  def _notif(db, *, type_="admin_broadcast", status="sending"):
      from models.notification import Notification
      n = Notification(
          source="admin", type=type_, title="t", body="b",
          data={"kind": "route", "screen": "Home"}, audience={"mode": "all"},
          status=status,
      )
      db.add(n)
      db.commit()
      return n


  def _delivery(db, notification_id, user_id, status="sent", read=False):
      from models.notification_delivery import NotificationDelivery
      d = NotificationDelivery(
          notification_id=notification_id, user_id=user_id, status=status,
          read_at=datetime.now(timezone.utc) if read else None,
      )
      db.add(d)
      db.commit()
      return d


  def test_create_persists_and_returns_row(notif_db):
      main, _ = notif_db
      repo = NotificationRepository()
      row = repo.create(
          main, source="admin", type_="admin_broadcast", title="Hi",
          body="Body", data={"kind": "route", "screen": "Home"},
          audience={"mode": "all"}, created_by="admin-1", status="sending",
      )
      main.commit()
      assert row.id and row.source == "admin" and row.status == "sending"
      assert repo.get(main, row.id).title == "Hi"


  def test_list_returns_rows_desc_and_total(notif_db):
      main, _ = notif_db
      repo = NotificationRepository()
      for _ in range(3):
          _notif(main)
      rows, total = repo.list(main, limit=2, offset=0)
      assert total == 3 and len(rows) == 2


  def test_get_delivered_user_ids_dedups_by_type_and_date(notif_db):
      main, _ = notif_db
      repo = NotificationRepository()
      n = _notif(main, type_="daily_reminder")
      _delivery(main, n.id, "userA")
      _delivery(main, n.id, "userB")
      today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
      got = set(repo.get_delivered_user_ids(main, type_="daily_reminder", local_date=today))
      assert got == {"userA", "userB"}
      # a different type does not match
      assert repo.get_delivered_user_ids(main, type_="planned_outfit", local_date=today) == []


  def test_summary_counts_statuses_and_reads(notif_db):
      main, _ = notif_db
      repo = NotificationRepository()
      n = _notif(main)
      _delivery(main, n.id, "u1", status="sent", read=True)
      _delivery(main, n.id, "u2", status="sent")
      _delivery(main, n.id, "u3", status="failed")
      _delivery(main, n.id, "u4", status="no_token")
      summary = repo.summary_for(main, n.id)
      assert summary == {"sent": 2, "failed": 1, "no_token": 1, "read": 1}


  def test_get_detail_returns_notif_and_summary(notif_db):
      main, _ = notif_db
      repo = NotificationRepository()
      n = _notif(main)
      _delivery(main, n.id, "u1", status="sent")
      notif, summary = repo.get_detail(main, n.id)
      assert notif.id == n.id and summary["sent"] == 1
      assert repo.get_detail(main, "missing") == (None, None)
  ```
- [ ] Run — expect FAIL:
  ```bash
  python -m pytest tests/test_notification_repository.py -v
  ```
- [ ] **Implement** — add to `repositories/notification_repository.py` (mirror `app_feedback_repository.py`: `select`, `db.execute(...).scalars()`, `func.count()`, caller commits):
  ```python
  from __future__ import annotations

  from typing import List, Optional, Tuple

  from sqlalchemy import func, select
  from sqlalchemy.orm import Session

  from models.notification import Notification
  from models.notification_delivery import NotificationDelivery


  class NotificationRepository:
      """DB access for notifications + delivery aggregates. Callers commit."""

      def get(self, db: Session, notification_id: str) -> Optional[Notification]:
          return db.get(Notification, notification_id)

      def create(
          self,
          db: Session,
          *,
          source: str,
          type_: str,
          title: str,
          body: str,
          data: dict,
          audience: Optional[dict] = None,
          created_by: Optional[str] = None,
          scheduled_for=None,
          status: str = "queued",
      ) -> Notification:
          row = Notification(
              source=source,
              type=type_,
              title=title,
              body=body,
              data=data,
              audience=audience,
              created_by=created_by,
              scheduled_for=scheduled_for,
              status=status,
          )
          db.add(row)
          db.flush()  # populate id/created_at without committing
          return row

      def list(
          self, db: Session, *, limit: int, offset: int
      ) -> Tuple[List[Notification], int]:
          total = db.execute(
              select(func.count()).select_from(Notification)
          ).scalar_one()
          rows = db.execute(
              select(Notification)
              .order_by(Notification.created_at.desc())
              .limit(limit)
              .offset(offset)
          ).scalars().all()
          return list(rows), int(total)

      def get_delivered_user_ids(
          self, db: Session, *, type_: str, local_date: str
      ) -> List[str]:
          """User ids already delivered for (type, local_date) — system dedup.

          local_date matched against date(deliveries.created_at). Phase 2 uses
          the server date for admin sends (which never dedup); Phase 3's
          scheduler supplies the per-user local date.
          """
          rows = db.execute(
              select(NotificationDelivery.user_id)
              .join(Notification, Notification.id == NotificationDelivery.notification_id)
              .where(Notification.type == type_)
              .where(func.date(NotificationDelivery.created_at) == local_date)
              .distinct()
          ).scalars().all()
          return list(rows)

      def summary_for(self, db: Session, notification_id: str) -> dict:
          counts = {"sent": 0, "failed": 0, "no_token": 0, "read": 0}
          rows = db.execute(
              select(NotificationDelivery.status, func.count())
              .where(NotificationDelivery.notification_id == notification_id)
              .group_by(NotificationDelivery.status)
          ).all()
          for st, c in rows:
              if st in counts:
                  counts[st] = int(c)
          read = db.execute(
              select(func.count())
              .select_from(NotificationDelivery)
              .where(NotificationDelivery.notification_id == notification_id)
              .where(NotificationDelivery.read_at.is_not(None))
          ).scalar_one()
          counts["read"] = int(read)
          return counts

      def get_detail(self, db: Session, notification_id: str):
          notif = db.get(Notification, notification_id)
          if notif is None:
              return None, None
          return notif, self.summary_for(db, notification_id)
  ```
- [ ] Run — expect PASS. Commit:
  ```bash
  python -m pytest tests/test_notification_repository.py -v
  git add repositories/notification_repository.py tests/test_notification_repository.py
  git commit -m "feat: notification_repository create/list/dedup-lookup/summary"
  ```

---

## Task 3: `notification_service.resolve_audience` (all + users)

Segment mode returns `[]` here (a stub `_resolve_segment`); Task 11 implements it. This keeps All + Specific shippable now.

**Files:**
- Modify: `services/notification_service.py` (ADD `resolve_audience` + `_resolve_segment` stub; Phase 0 functions untouched)
- Test: `tests/test_notification_service_audience.py`

**Interfaces:** Produces `resolve_audience(db, audience: dict) -> list[str]` (consumed by `enqueue` Task 4 + router Task 6).

- [ ] **TDD — failing test** `tests/test_notification_service_audience.py`:
  ```python
  """Phase 2 — resolve_audience: all / users (segment is Task 11 fast-follow)."""
  import uuid

  from services import notification_service


  def _user(db, gender=None):
      from models.user import User
      u = User(id=str(uuid.uuid4()), email=f"{uuid.uuid4().hex[:8]}@e.com",
               password_hash="x", role="user", gender=gender)
      db.add(u)
      db.commit()
      return u


  def test_all_returns_every_user_id(notif_db):
      main, _ = notif_db
      ids = {_user(main).id for _ in range(3)}
      assert set(notification_service.resolve_audience(main, {"mode": "all"})) == ids


  def test_users_filters_to_existing_ids(notif_db):
      main, _ = notif_db
      u1, u2 = _user(main), _user(main)
      out = notification_service.resolve_audience(
          main, {"mode": "users", "user_ids": [u1.id, u2.id, "ghost-id"]}
      )
      assert set(out) == {u1.id, u2.id}


  def test_users_empty_list_returns_empty(notif_db):
      main, _ = notif_db
      assert notification_service.resolve_audience(main, {"mode": "users", "user_ids": []}) == []


  def test_segment_stub_returns_empty(notif_db):
      main, _ = notif_db
      _user(main)
      assert notification_service.resolve_audience(main, {"mode": "segment", "segment": {"gender": "female"}}) == []


  def test_unknown_mode_returns_empty(notif_db):
      main, _ = notif_db
      assert notification_service.resolve_audience(main, {"mode": "nope"}) == []
  ```
- [ ] Run — expect FAIL (`AttributeError: module ... has no attribute 'resolve_audience'`):
  ```bash
  python -m pytest tests/test_notification_service_audience.py -v
  ```
- [ ] **Implement** — add to `services/notification_service.py` (module-level; keep Phase 0's `create_system_notification`/`deliver`):
  ```python
  from sqlalchemy import select
  from sqlalchemy.orm import Session

  from models.user import User
  from repositories.notification_repository import NotificationRepository

  _repo = NotificationRepository()
  SYSTEM_TYPES = {"daily_reminder", "planned_outfit"}


  def resolve_audience(db: Session, audience: dict) -> list[str]:
      """Resolve an audience spec -> list of user ids.

      audience = {"mode": "all"|"users"|"segment", "user_ids"?: [...], "segment"?: {...}}
      """
      audience = audience or {}
      mode = audience.get("mode")
      if mode == "all":
          return list(db.execute(select(User.id)).scalars().all())
      if mode == "users":
          ids = audience.get("user_ids") or []
          if not ids:
              return []
          return list(
              db.execute(select(User.id).where(User.id.in_(ids))).scalars().all()
          )
      if mode == "segment":
          return _resolve_segment(db, audience.get("segment") or {})
      return []


  def _resolve_segment(db: Session, segment: dict) -> list[str]:
      # Fast-follow (Task 11) — segment targeting not enabled yet.
      return []
  ```
  (If `_repo`/imports already exist in the file from Phase 0, don't duplicate — reuse.)
- [ ] Run — expect PASS. Commit:
  ```bash
  python -m pytest tests/test_notification_service_audience.py -v
  git add services/notification_service.py tests/test_notification_service_audience.py
  git commit -m "feat: notification_service.resolve_audience (all + users)"
  ```

---

## Task 4: `notification_service.enqueue` (fan-out + system dedup)

**Files:**
- Modify: `services/notification_service.py` (ADD `enqueue`)
- Test: `tests/test_notification_service_enqueue.py`

**Interfaces:** Consumes `resolve_audience` (Task 3), `NotificationRepository.{get,get_delivered_user_ids}` (Task 2), `queue_service.push_notification_job` (Task 1). Produces `enqueue(db, notification_id: str) -> int`. Emits the locked job shape onto `notification_queue`.

- [ ] **TDD — failing test** `tests/test_notification_service_enqueue.py`:
  ```python
  """Phase 2 — enqueue: audience fan-out (#jobs) + system-reminder dedup."""
  import json
  import uuid
  from datetime import datetime, timezone

  import fakeredis
  import pytest

  from services import notification_service
  from services.queue_service import queue_service, NOTIFICATION_QUEUE


  @pytest.fixture
  def fake_redis(monkeypatch):
      fake = fakeredis.FakeStrictRedis(decode_responses=True)
      monkeypatch.setattr(queue_service, "redis_client", fake)
      return fake


  def _user(db):
      from models.user import User
      u = User(id=str(uuid.uuid4()), email=f"{uuid.uuid4().hex[:8]}@e.com",
               password_hash="x", role="user")
      db.add(u)
      db.commit()
      return u


  def _admin_notif(db, *, type_="admin_broadcast", audience=None, data=None):
      from models.notification import Notification
      n = Notification(
          source="admin", type=type_, title="t", body="b",
          data=data or {"kind": "route", "screen": "Home"},
          audience=audience or {"mode": "all"}, status="sending",
      )
      db.add(n)
      db.commit()
      return n


  def test_broadcast_fans_out_one_job_per_user(notif_db, fake_redis):
      main, _ = notif_db
      [_user(main) for _ in range(3)]
      n = _admin_notif(main)
      count = notification_service.enqueue(main, n.id)
      assert count == 3
      assert fake_redis.llen(NOTIFICATION_QUEUE) == 3
      job = json.loads(fake_redis.lindex(NOTIFICATION_QUEUE, 0))
      assert job["notification_id"] == n.id
      assert set(job.keys()) == {"notification_id", "type", "user_id", "local_date", "payload"}
      assert job["payload"] == {"kind": "route", "screen": "Home"}


  def test_specific_users_only_enqueues_targets(notif_db, fake_redis):
      main, _ = notif_db
      u1 = _user(main)
      _user(main)  # not targeted
      n = _admin_notif(main, type_="admin_direct",
                       audience={"mode": "users", "user_ids": [u1.id]})
      assert notification_service.enqueue(main, n.id) == 1


  def test_system_reminder_dedups_already_delivered(notif_db, fake_redis):
      main, _ = notif_db
      a, b = _user(main), _user(main)
      n = _admin_notif(main, type_="daily_reminder", audience={"mode": "all"})
      # pre-existing delivery today for user a -> a must be skipped
      from models.notification_delivery import NotificationDelivery
      main.add(NotificationDelivery(notification_id=n.id, user_id=a.id, status="sent"))
      main.commit()
      count = notification_service.enqueue(main, n.id)
      assert count == 1
      job = json.loads(fake_redis.lindex(NOTIFICATION_QUEUE, 0))
      assert job["user_id"] == b.id


  def test_missing_notification_returns_zero(notif_db, fake_redis):
      main, _ = notif_db
      assert notification_service.enqueue(main, "missing") == 0
  ```
- [ ] Run — expect FAIL:
  ```bash
  python -m pytest tests/test_notification_service_enqueue.py -v
  ```
- [ ] **Implement** — add `enqueue` to `services/notification_service.py`:
  ```python
  from datetime import datetime, timezone

  from services.queue_service import queue_service


  def enqueue(db: Session, notification_id: str) -> int:
      """Producer: resolve audience -> dedup (system) -> push one job per user.

      Returns the number of jobs pushed onto `notification_queue`.
      """
      notif = _repo.get(db, notification_id)
      if notif is None:
          return 0

      user_ids = resolve_audience(db, notif.audience or {})
      local_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

      if notif.type in SYSTEM_TYPES:
          already = set(
              _repo.get_delivered_user_ids(db, type_=notif.type, local_date=local_date)
          )
          user_ids = [uid for uid in user_ids if uid not in already]

      payload = notif.data or {"kind": "route", "screen": "Home"}
      pushed = 0
      for uid in user_ids:
          job = {
              "notification_id": notif.id,
              "type": notif.type,
              "user_id": uid,
              "local_date": local_date,
              "payload": payload,
          }
          if queue_service.push_notification_job(job):
              pushed += 1
      return pushed
  ```
- [ ] Run — expect PASS. Commit:
  ```bash
  python -m pytest tests/test_notification_service_enqueue.py -v
  git add services/notification_service.py tests/test_notification_service_enqueue.py
  git commit -m "feat: notification_service.enqueue fan-out + system dedup"
  ```

---

## Task 5: `notification_worker.py` — BRPOP consumer

Mirror `ai_worker.py` structure (signal handlers, loop, `get_db_context`). APScheduler producer is **Phase 3** — leave a clear extension point comment, don't build it.

**Files:**
- Create: `notification_worker.py` (repo root, sibling of `ai_worker.py`)
- Test: `tests/test_notification_worker.py`

**Interfaces:** Consumes `queue_service.pop_notification_job` (Task 1) + Phase 0 `notification_service.deliver`. Produces `NotificationWorker.process_next_job()` + bounded `_deliver_with_retry`.

- [ ] **TDD — failing test** `tests/test_notification_worker.py`:
  ```python
  """Phase 2 — notification_worker consumer: pop -> deliver dispatch + retry."""
  from contextlib import contextmanager
  from unittest.mock import MagicMock

  import pytest


  @contextmanager
  def _fake_db_ctx():
      yield MagicMock()


  def _job():
      return {"notification_id": "n1", "type": "admin_broadcast", "user_id": "u1",
              "local_date": "2026-06-29", "payload": {"kind": "route", "screen": "Home"}}


  def test_process_next_job_dispatches_to_deliver(monkeypatch):
      import notification_worker as nw
      from services.queue_service import queue_service
      import services.notification_service as nsvc

      calls = []
      monkeypatch.setattr(queue_service, "is_connected", lambda: True)
      monkeypatch.setattr(queue_service, "pop_notification_job", lambda timeout=10: _job())
      monkeypatch.setattr(nsvc, "deliver", lambda db, job: calls.append(job))
      monkeypatch.setattr(nw, "get_db_context", _fake_db_ctx)

      nw.NotificationWorker().process_next_job()
      assert calls == [_job()]


  def test_no_job_does_not_call_deliver(monkeypatch):
      import notification_worker as nw
      from services.queue_service import queue_service
      import services.notification_service as nsvc

      calls = []
      monkeypatch.setattr(queue_service, "is_connected", lambda: True)
      monkeypatch.setattr(queue_service, "pop_notification_job", lambda timeout=10: None)
      monkeypatch.setattr(nsvc, "deliver", lambda db, job: calls.append(job))
      monkeypatch.setattr(nw, "get_db_context", _fake_db_ctx)

      nw.NotificationWorker().process_next_job()
      assert calls == []


  def test_transient_error_is_retried_then_succeeds(monkeypatch):
      import notification_worker as nw
      import services.notification_service as nsvc

      attempts = {"n": 0}

      def flaky(db, job):
          attempts["n"] += 1
          if attempts["n"] == 1:
              raise RuntimeError("transient FCM blip")

      monkeypatch.setattr(nsvc, "deliver", flaky)
      monkeypatch.setattr(nw, "get_db_context", _fake_db_ctx)
      monkeypatch.setattr(nw.time, "sleep", lambda *_: None)

      nw.NotificationWorker()._deliver_with_retry(_job())
      assert attempts["n"] == 2
  ```
- [ ] Run — expect FAIL (`ModuleNotFoundError: No module named 'notification_worker'`):
  ```bash
  python -m pytest tests/test_notification_worker.py -v
  ```
- [ ] **Implement** `notification_worker.py` (repo root):
  ```python
  """Background Notification Worker.

  Consumer half of the push pipeline: BRPOP one per-user job off
  `notification_queue` and hand it to notification_service.deliver (Phase 0),
  which loads the user's device tokens, calls push_service (FCM), writes
  notification_deliveries, and cleans up invalid tokens.

  Mirrors ai_worker.py. The APScheduler PRODUCER (daily slot, scheduled-admin
  pickup, retention) is Phase 3 — see `start()` extension point below.
  """
  import logging
  import os
  import signal
  import sys
  import time

  # Add project root to path (mirrors ai_worker.py)
  sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

  from database import get_db_context
  from services import notification_service
  from services.queue_service import queue_service

  # Import models so SQLAlchemy mappers/relationships resolve in the worker proc
  from models.user import User  # noqa: F401
  from models.notification import Notification  # noqa: F401
  from models.notification_delivery import NotificationDelivery  # noqa: F401
  from models.device_token import DeviceToken  # noqa: F401

  logger = logging.getLogger(__name__)


  class NotificationWorker:
      """Drains notification_queue and delivers each job (bounded retry)."""

      MAX_RETRIES = 3

      def __init__(self):
          self.running = False
          self.setup_logging()

      def setup_logging(self):
          logging.basicConfig(
              level=logging.INFO,
              format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
          )

      def start(self):
          logger.info("Starting Notification Worker...")
          self.running = True
          signal.signal(signal.SIGINT, self.signal_handler)
          signal.signal(signal.SIGTERM, self.signal_handler)
          # --- Phase 3 extension point ---------------------------------------
          # An APScheduler producer (daily-slot tick, scheduled-admin pickup,
          # retention prune) will be started HERE, sharing this process. It
          # only enqueues; this loop stays the sole consumer. Do NOT add it now.
          while self.running:
              try:
                  self.process_next_job()
              except Exception as e:  # never let the loop die
                  logger.error(f"Error in notification worker loop: {e}")
                  time.sleep(5)

      def stop(self):
          logger.info("Stopping Notification Worker...")
          self.running = False

      def signal_handler(self, signum, frame):
          logger.info(f"Received signal {signum}, shutting down...")
          self.stop()

      def process_next_job(self):
          if not queue_service.is_connected():
              logger.warning("Redis not connected, waiting...")
              time.sleep(10)
              return
          job = queue_service.pop_notification_job(timeout=10)
          if not job:
              return  # idle tick, loop again
          logger.info(
              "Delivering notification %s -> user %s",
              job.get("notification_id"), job.get("user_id"),
          )
          self._deliver_with_retry(job)

      def _deliver_with_retry(self, job):
          for attempt in range(1, self.MAX_RETRIES + 1):
              try:
                  with get_db_context() as db:
                      notification_service.deliver(db, job)
                  return
              except Exception as e:
                  logger.error(
                      "deliver failed (attempt %s/%s) for %s: %s",
                      attempt, self.MAX_RETRIES, job.get("notification_id"), e,
                  )
                  if attempt < self.MAX_RETRIES:
                      time.sleep(min(2 ** attempt, 30))
          logger.error(
              "Giving up notification %s -> user %s after %s attempts",
              job.get("notification_id"), job.get("user_id"), self.MAX_RETRIES,
          )


  def main():
      worker = NotificationWorker()
      try:
          worker.start()
      except KeyboardInterrupt:
          logger.info("Received keyboard interrupt")
      except Exception as e:
          logger.error(f"Notification worker crashed: {e}")
      finally:
          worker.stop()
          logger.info("Notification worker stopped")


  if __name__ == "__main__":
      main()
  ```
- [ ] Run — expect PASS. Commit:
  ```bash
  python -m pytest tests/test_notification_worker.py -v
  git add notification_worker.py tests/test_notification_worker.py
  git commit -m "feat: notification_worker BRPOP consumer (deliver dispatch + retry)"
  ```

---

## Task 6: Admin endpoints — `routers/admin/notifications.py` + schemas + register

**Files:**
- Create: `schemas/notification.py`
- Create: `routers/admin/notifications.py`
- Modify: `routers/admin/__init__.py`
- Test: `tests/test_admin_notifications_router.py`

**Interfaces:** Consumes `get_current_admin` (`deps/auth.py`), `get_db` (`deps/database.py`), `NotificationRepository` (Task 2), `notification_service.enqueue` (Task 4). Produces the 3 locked HTTP endpoints under `/api/admin/notifications`.

- [ ] **TDD — failing test** `tests/test_admin_notifications_router.py` (mirrors `tests/test_app_feedback_admin.py` — overrides `get_current_user` so the real `get_current_admin` role-gate runs; monkeypatches `queue_service.redis_client` with fakeredis so `enqueue` works):
  ```python
  """Phase 2 — admin notifications router: send (immediate/scheduled), list, detail, RBAC."""
  import uuid
  from datetime import datetime, timedelta, timezone

  import fakeredis
  import pytest
  from fastapi import FastAPI
  from fastapi.testclient import TestClient


  @pytest.fixture
  def fake_redis(monkeypatch):
      from services.queue_service import queue_service, NOTIFICATION_QUEUE
      fake = fakeredis.FakeStrictRedis(decode_responses=True)
      monkeypatch.setattr(queue_service, "redis_client", fake)
      return fake, NOTIFICATION_QUEUE


  def _user(db, role="user"):
      from models.user import User
      u = User(id=str(uuid.uuid4()), email=f"{role}-{uuid.uuid4().hex[:8]}@e.com",
               password_hash="x", role=role)
      db.add(u)
      db.commit()
      return u


  def _admin_app(get_db_dep, current_user):
      from routers.admin.notifications import router
      from deps.auth import get_current_user
      from deps.database import get_db
      app = FastAPI()
      app.include_router(router, prefix="/api/admin")
      app.dependency_overrides[get_db] = get_db_dep
      app.dependency_overrides[get_current_user] = lambda: current_user
      return app


  def test_non_admin_forbidden_403(notif_db):
      main, get_db_dep = notif_db
      normal = _user(main, role="user")
      client = TestClient(_admin_app(get_db_dep, normal))
      resp = client.post("/api/admin/notifications/send", json={
          "title": "x", "body": "y",
          "data": {"kind": "route", "screen": "Home"},
          "audience": {"mode": "all"},
      })
      assert resp.status_code == 403


  def test_send_broadcast_immediate_enqueues(notif_db, fake_redis):
      main, get_db_dep = notif_db
      fake, queue_name = fake_redis
      admin = _user(main, role="admin")
      [_user(main) for _ in range(3)]  # 3 normal + 1 admin = 4 recipients ('all')
      client = TestClient(_admin_app(get_db_dep, admin))
      resp = client.post("/api/admin/notifications/send", json={
          "title": "Hello", "body": "Body",
          "data": {"kind": "route", "screen": "Schedule"},
          "audience": {"mode": "all"},
      })
      assert resp.status_code == 202, resp.text
      assert resp.json()["status"] == "sending"
      assert fake.llen(queue_name) == 4


  def test_send_scheduled_future_queues_without_enqueue(notif_db, fake_redis):
      main, get_db_dep = notif_db
      fake, queue_name = fake_redis
      admin = _user(main, role="admin")
      _user(main)
      client = TestClient(_admin_app(get_db_dep, admin))
      future = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
      resp = client.post("/api/admin/notifications/send", json={
          "title": "Later", "body": "Body",
          "data": {"kind": "route", "screen": "Home"},
          "audience": {"mode": "all"}, "scheduled_for": future,
      })
      assert resp.status_code == 202
      assert resp.json()["status"] == "queued"
      assert fake.llen(queue_name) == 0


  def test_send_invalid_screen_422(notif_db, fake_redis):
      main, get_db_dep = notif_db
      admin = _user(main, role="admin")
      client = TestClient(_admin_app(get_db_dep, admin))
      resp = client.post("/api/admin/notifications/send", json={
          "title": "x", "body": "y",
          "data": {"kind": "route", "screen": "Nope"},
          "audience": {"mode": "all"},
      })
      assert resp.status_code == 422


  def test_send_external_requires_http_422(notif_db, fake_redis):
      main, get_db_dep = notif_db
      admin = _user(main, role="admin")
      client = TestClient(_admin_app(get_db_dep, admin))
      resp = client.post("/api/admin/notifications/send", json={
          "title": "x", "body": "y",
          "data": {"kind": "external", "url": "ftp://bad"},
          "audience": {"mode": "all"},
      })
      assert resp.status_code == 422


  def test_list_and_detail_with_stats(notif_db, fake_redis):
      main, get_db_dep = notif_db
      admin = _user(main, role="admin")
      from repositories.notification_repository import NotificationRepository
      from models.notification_delivery import NotificationDelivery
      repo = NotificationRepository()
      n = repo.create(main, source="admin", type_="admin_broadcast", title="t",
                      body="b", data={"kind": "route", "screen": "Home"},
                      audience={"mode": "all"}, status="sent")
      main.add(NotificationDelivery(notification_id=n.id, user_id="u1", status="sent"))
      main.add(NotificationDelivery(notification_id=n.id, user_id="u2", status="failed"))
      main.commit()
      client = TestClient(_admin_app(get_db_dep, admin))

      lst = client.get("/api/admin/notifications", params={"limit": 10, "offset": 0})
      assert lst.status_code == 200
      body = lst.json()
      assert body["total"] == 1
      assert body["notifications"][0]["summary"]["sent"] == 1
      assert body["notifications"][0]["summary"]["failed"] == 1

      det = client.get(f"/api/admin/notifications/{n.id}")
      assert det.status_code == 200
      assert det.json()["summary"]["sent"] == 1

      assert client.get("/api/admin/notifications/missing").status_code == 404
  ```
- [ ] Run — expect FAIL:
  ```bash
  python -m pytest tests/test_admin_notifications_router.py -v
  ```
- [ ] **Implement** `schemas/notification.py` (mirror `schemas/app_feedback.py`'s vocab-tuple + validator pattern; Pydantic v2):
  ```python
  """Pydantic schemas for admin notification send/list/detail (Phase 2).

  CURATED_SCREENS is the shared deep-link contract (spec §5.1). The same list
  is mirrored in the admin SPA + mobile app + API_DOCUMENTATION.md.
  """
  from __future__ import annotations

  from datetime import datetime
  from typing import List, Optional

  from pydantic import BaseModel, Field, field_validator, model_validator

  CURATED_SCREENS: tuple[str, ...] = ("Home", "Schedule", "Favourite", "Creations", "Settings")
  AUDIENCE_MODES: tuple[str, ...] = ("all", "users", "segment")
  DATA_KINDS: tuple[str, ...] = ("route", "external")


  class NotificationData(BaseModel):
      kind: str
      screen: Optional[str] = None
      url: Optional[str] = None

      @field_validator("kind")
      @classmethod
      def _kind(cls, v: str) -> str:
          if v not in DATA_KINDS:
              raise ValueError(f"data.kind must be one of {list(DATA_KINDS)}")
          return v

      @model_validator(mode="after")
      def _shape(self):
          if self.kind == "route":
              if self.screen not in CURATED_SCREENS:
                  raise ValueError(f"data.screen must be one of {list(CURATED_SCREENS)}")
          else:  # external
              u = self.url or ""
              if not (u.startswith("http://") or u.startswith("https://")):
                  raise ValueError("data.url must be an http(s) URL for external links")
          return self


  class Audience(BaseModel):
      mode: str
      user_ids: Optional[List[str]] = None
      segment: Optional[dict] = None

      @field_validator("mode")
      @classmethod
      def _mode(cls, v: str) -> str:
          if v not in AUDIENCE_MODES:
              raise ValueError(f"audience.mode must be one of {list(AUDIENCE_MODES)}")
          return v

      @model_validator(mode="after")
      def _required(self):
          if self.mode == "users" and not self.user_ids:
              raise ValueError("audience.user_ids required when mode='users'")
          if self.mode == "segment" and not self.segment:
              raise ValueError("audience.segment required when mode='segment'")
          return self


  class AdminNotificationSendRequest(BaseModel):
      title: str = Field(..., min_length=1, max_length=120)
      body: str = Field(..., min_length=1, max_length=500)
      data: NotificationData = Field(
          default_factory=lambda: NotificationData(kind="route", screen="Home")
      )
      audience: Audience
      scheduled_for: Optional[datetime] = None


  class AdminNotificationSendResponse(BaseModel):
      notification_id: str
      status: str


  class NotificationSummary(BaseModel):
      sent: int = 0
      failed: int = 0
      no_token: int = 0
      read: int = 0


  class NotificationOut(BaseModel):
      id: str
      source: str
      type: str
      title: str
      body: str
      data: dict
      audience: Optional[dict] = None
      status: str
      scheduled_for: Optional[datetime] = None
      created_at: datetime
      sent_at: Optional[datetime] = None


  class NotificationListItem(NotificationOut):
      summary: NotificationSummary


  class NotificationListResponse(BaseModel):
      notifications: List[NotificationListItem]
      total: int


  class NotificationDetailResponse(BaseModel):
      notification: NotificationOut
      summary: NotificationSummary
  ```
- [ ] **Implement** `routers/admin/notifications.py` (mirror `routers/admin/app_feedback.py`: `prefix="/notifications"`, `get_current_admin`, `get_db`, router commits):
  ```python
  """Admin routes for composing + sending push notifications (Phase 2).

  Mounted under /api/admin via routers/admin/__init__.py:
    POST /notifications/send      — compose + send (immediate enqueue or schedule)
    GET  /notifications           — paginated history + per-row delivery stats
    GET  /notifications/{id}      — single notification + delivery breakdown
  """
  from __future__ import annotations

  import logging
  from datetime import datetime, timezone

  from fastapi import APIRouter, Depends, HTTPException, Query, status
  from sqlalchemy.orm import Session

  from deps.auth import get_current_admin
  from deps.database import get_db
  from models.user import User
  from repositories.notification_repository import NotificationRepository
  from schemas.notification import (
      AdminNotificationSendRequest,
      AdminNotificationSendResponse,
      NotificationDetailResponse,
      NotificationListItem,
      NotificationListResponse,
      NotificationOut,
      NotificationSummary,
  )
  from services import notification_service

  logger = logging.getLogger(__name__)

  router = APIRouter(prefix="/notifications", tags=["Admin Notifications"])

  _repo = NotificationRepository()
  _TYPE_BY_MODE = {
      "all": "admin_broadcast",
      "users": "admin_direct",
      "segment": "admin_segment",
  }


  def _is_future(dt: datetime | None) -> bool:
      if dt is None:
          return False
      if dt.tzinfo is None:  # treat naive input as UTC
          dt = dt.replace(tzinfo=timezone.utc)
      return dt > datetime.now(timezone.utc)


  def _to_out(n) -> NotificationOut:
      return NotificationOut(
          id=n.id, source=n.source, type=n.type, title=n.title, body=n.body,
          data=n.data or {}, audience=n.audience, status=n.status,
          scheduled_for=n.scheduled_for, created_at=n.created_at, sent_at=n.sent_at,
      )


  @router.post(
      "/send",
      response_model=AdminNotificationSendResponse,
      status_code=status.HTTP_202_ACCEPTED,
      summary="Compose + send a push notification (admin)",
  )
  def send_notification(
      body: AdminNotificationSendRequest,
      admin: User = Depends(get_current_admin),
      db: Session = Depends(get_db),
  ) -> AdminNotificationSendResponse:
      type_ = _TYPE_BY_MODE[body.audience.mode]
      scheduled = body.scheduled_for
      future = _is_future(scheduled)

      notif = _repo.create(
          db,
          source="admin",
          type_=type_,
          title=body.title,
          body=body.body,
          data=body.data.model_dump(exclude_none=True),
          audience=body.audience.model_dump(exclude_none=True),
          created_by=admin.id,
          scheduled_for=scheduled,
          status="queued" if future else "sending",
      )
      db.commit()

      if not future:
          # immediate: enqueue one job per recipient; the worker delivers.
          notification_service.enqueue(db, notif.id)
          db.commit()

      return AdminNotificationSendResponse(notification_id=notif.id, status=notif.status)


  @router.get(
      "",
      response_model=NotificationListResponse,
      summary="List notification history + delivery stats (admin)",
  )
  def list_notifications(
      limit: int = Query(default=50, ge=1, le=200),
      offset: int = Query(default=0, ge=0),
      admin: User = Depends(get_current_admin),
      db: Session = Depends(get_db),
  ) -> NotificationListResponse:
      rows, total = _repo.list(db, limit=limit, offset=offset)
      items = [
          NotificationListItem(
              **_to_out(n).model_dump(),
              summary=NotificationSummary(**_repo.summary_for(db, n.id)),
          )
          for n in rows
      ]
      return NotificationListResponse(notifications=items, total=total)


  @router.get(
      "/{notification_id}",
      response_model=NotificationDetailResponse,
      summary="Notification detail + delivery breakdown (admin)",
  )
  def get_notification(
      notification_id: str,
      admin: User = Depends(get_current_admin),
      db: Session = Depends(get_db),
  ) -> NotificationDetailResponse:
      notif, summary = _repo.get_detail(db, notification_id)
      if notif is None:
          raise HTTPException(
              status_code=status.HTTP_404_NOT_FOUND,
              detail={"error": "Notification not found"},
          )
      return NotificationDetailResponse(
          notification=_to_out(notif), summary=NotificationSummary(**summary)
      )
  ```
- [ ] **Register** in `routers/admin/__init__.py` — add the import + include (alongside the others):
  ```python
  from routers.admin.notifications import router as notifications_admin_router
  # ...
  router.include_router(notifications_admin_router)
  ```
- [ ] Run — expect PASS. Commit:
  ```bash
  python -m pytest tests/test_admin_notifications_router.py -v
  git add schemas/notification.py routers/admin/notifications.py routers/admin/__init__.py tests/test_admin_notifications_router.py
  git commit -m "feat: admin notifications send/list/detail endpoints"
  ```
- [ ] Full backend gate:
  ```bash
  python -m pytest tests/test_notification_*.py tests/test_admin_notifications_router.py -v
  python test_server.py
  ```

---

## Task 7: API documentation

**Files:** Modify `API_DOCUMENTATION.md`.

**Interfaces:** Documents the 3 admin routes (contract per project rule; these are internal `/admin/*`, no auxi consumer).

- [ ] Append a section to `API_DOCUMENTATION.md` (follow `.claude/rules/api-documentation.md` format):
  ```markdown
  ## Admin Notifications (internal `/admin/*` — admin role required)

  > Internal ops surface (admin SPA). Not part of the public `/api/*` mobile
  > contract. Auth: `get_current_admin` (403 for non-admins).
  > Deep-link `data`: `{"kind":"route","screen":<Home|Schedule|Favourite|Creations|Settings>}`
  > or `{"kind":"external","url":"https://..."}` (http/https only). Unknown → mobile falls back to Home.

  ### `POST /api/admin/notifications/send`
  Compose + send. `audience.mode`: `all` | `users` (needs `user_ids`) | `segment`
  (needs `segment` — fast-follow). Immediate (no `scheduled_for`/past) → enqueued now
  (`status:"sending"`); future `scheduled_for` → persisted `status:"queued"` (Phase-3 scheduler sends).
  - Rate limit: 20/min
  - Request:
    ```json
    {
      "title": "string (1–120)",
      "body": "string (1–500)",
      "data": {"kind": "route", "screen": "Home"},
      "audience": {"mode": "users", "user_ids": ["<uuid>"]},
      "scheduled_for": "2026-07-01T07:30:00Z  (optional, ISO-8601)"
    }
    ```
  - Response (202): `{ "notification_id": "<uuid>", "status": "sending" | "queued" }`
  - Errors: `403` non-admin · `422` invalid screen / non-http(s) url / missing user_ids|segment

  ### `GET /api/admin/notifications?limit&offset`
  Paginated history (newest first) with per-row delivery summary.
  - Response (200):
    ```json
    {
      "notifications": [
        {"id": "<uuid>", "source": "admin", "type": "admin_broadcast",
         "title": "...", "body": "...", "data": {...}, "audience": {...},
         "status": "sent", "scheduled_for": null, "created_at": "...", "sent_at": null,
         "summary": {"sent": 10, "failed": 1, "no_token": 2, "read": 3}}
      ],
      "total": 42
    }
    ```

  ### `GET /api/admin/notifications/{id}`
  - Response (200): `{ "notification": { ...same fields, no summary... }, "summary": {"sent","failed","no_token","read"} }`
  - Errors: `403` non-admin · `404` not found
  ```
- [ ] Commit:
  ```bash
  git add API_DOCUMENTATION.md
  git commit -m "docs: admin notifications endpoints in API_DOCUMENTATION"
  ```

---

## Task 8: Admin SPA — types + `notificationsService.ts`

**Files:**
- Modify: `wardrobe-admin/src/types/index.ts`
- Create: `wardrobe-admin/src/services/notificationsService.ts`

**Interfaces:** Produces the locked `notificationsService.{send,getHistory,getDetail}` + `CURATED_SCREENS`. Mirrors `commonItemsService.ts` (service-object pattern, `api` axios instance).

- [ ] Append to `src/types/index.ts`:
  ```ts
  // ─────────────────────────────────────────────────────────────────────────────
  // Push notifications (admin compose + history)
  // ─────────────────────────────────────────────────────────────────────────────

  export type NotificationKind = 'route' | 'external';
  export type CuratedScreen = 'Home' | 'Schedule' | 'Favourite' | 'Creations' | 'Settings';

  export interface NotificationData {
    kind: NotificationKind;
    screen?: CuratedScreen;
    url?: string;
  }

  export type AudienceMode = 'all' | 'users' | 'segment';

  export interface NotificationSegment {
    gender?: string;
    inactive_days?: number;
    has_items?: boolean;
  }

  export interface NotificationAudience {
    mode: AudienceMode;
    user_ids?: string[];
    segment?: NotificationSegment;
  }

  export interface SendNotificationPayload {
    title: string;
    body: string;
    data: NotificationData;
    audience: NotificationAudience;
    scheduled_for?: string; // ISO-8601
  }

  export interface SendNotificationResponse {
    notification_id: string;
    status: string;
  }

  export interface NotificationSummary {
    sent: number;
    failed: number;
    no_token: number;
    read: number;
  }

  export interface NotificationItem {
    id: string;
    source: string;
    type: string;
    title: string;
    body: string;
    data: NotificationData;
    audience: NotificationAudience | null;
    status: string;
    scheduled_for: string | null;
    created_at: string;
    sent_at: string | null;
    summary: NotificationSummary;
  }

  export interface NotificationHistoryResponse {
    notifications: NotificationItem[];
    total: number;
  }

  export interface NotificationDetail {
    notification: Omit<NotificationItem, 'summary'>;
    summary: NotificationSummary;
  }
  ```
- [ ] Create `src/services/notificationsService.ts`:
  ```ts
  import api from './api';
  import type {
    CuratedScreen,
    NotificationDetail,
    NotificationHistoryResponse,
    SendNotificationPayload,
    SendNotificationResponse,
  } from '../types';

  // Curated deep-link destinations (spec §5.1). Mirror of the backend
  // CURATED_SCREENS tuple + the mobile allowlist — keep in sync manually.
  export const CURATED_SCREENS: { value: CuratedScreen; label: string }[] = [
    { value: 'Home', label: 'Home' },
    { value: 'Schedule', label: 'Schedule' },
    { value: 'Favourite', label: 'Favourite' },
    { value: 'Creations', label: 'Creations' },
    { value: 'Settings', label: 'Settings' },
  ];

  export const notificationsService = {
    /** POST /admin/notifications/send */
    send: async (payload: SendNotificationPayload): Promise<SendNotificationResponse> => {
      const { data } = await api.post<SendNotificationResponse>(
        '/admin/notifications/send',
        payload,
      );
      return data;
    },

    /** GET /admin/notifications?limit&offset */
    getHistory: async (params: { limit: number; offset: number }): Promise<NotificationHistoryResponse> => {
      const { data } = await api.get<NotificationHistoryResponse>('/admin/notifications', { params });
      return data;
    },

    /** GET /admin/notifications/{id} */
    getDetail: async (id: string): Promise<NotificationDetail> => {
      const { data } = await api.get<NotificationDetail>(`/admin/notifications/${id}`);
      return data;
    },
  };
  ```
- [ ] Type-check:
  ```bash
  cd wardrobe-admin && npx tsc --noEmit
  ```
- [ ] Commit:
  ```bash
  git add src/types/index.ts src/services/notificationsService.ts
  git commit -m "feat(admin): notifications service + types"
  ```

---

## Task 9: Admin SPA — `Notifications.tsx` (compose + history)

Single cohesive page. Compose: title, body, destination picker (curated screen dropdown OR External URL), audience (**All** / **Specific users** via `/admin/users` search multi-select; **Segment** radio present but disabled — enabled in Task 11), timing (send-now / scheduled `datetime-local`). History: table with sent/failed/no_token/read counts, row → detail modal. Mirrors `CommonItems.tsx` (`useMutation` + local notification banner) and `Users.tsx` (`/admin/users` fetch via TanStack Query).

**Files:** Create `wardrobe-admin/src/pages/Notifications.tsx`.

**Interfaces:** Consumes `notificationsService` (Task 8) + `api.get('/admin/users')`. Sends the locked `SendNotificationPayload`.

- [ ] Create `src/pages/Notifications.tsx`:
  ```tsx
  import React, { useState } from 'react';
  import { useMutation, useQuery } from '@tanstack/react-query';
  import {
    Bell, PaperPlaneTilt, MagnifyingGlass, X, CaretLeft, CaretRight, Eye, Spinner,
  } from '@phosphor-icons/react';
  import classNames from 'classnames';
  import api from '../services/api';
  import { notificationsService, CURATED_SCREENS } from '../services/notificationsService';
  import type {
    AudienceMode, CuratedScreen, NotificationAudience, NotificationData,
    NotificationDetail, SendNotificationPayload, User, UsersResponse,
  } from '../types';

  const inputCls =
    'w-full px-3 py-2 bg-slate-800 border border-slate-700 text-slate-100 rounded-lg focus:ring-indigo-500 focus:border-indigo-500';
  const labelCls = 'block text-xs font-medium text-slate-400 uppercase tracking-wider mb-1';
  const HISTORY_LIMIT = 20;

  const STATUS_BADGE: Record<string, string> = {
    sent: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
    sending: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
    queued: 'bg-sky-500/10 text-sky-400 border-sky-500/20',
    failed: 'bg-red-500/10 text-red-400 border-red-500/20',
  };

  const Notifications: React.FC = () => {
    // ── compose state ─────────────────────────────────────────────────────────
    const [title, setTitle] = useState('');
    const [bodyText, setBodyText] = useState('');
    const [destKind, setDestKind] = useState<'route' | 'external'>('route');
    const [screen, setScreen] = useState<CuratedScreen>('Home');
    const [url, setUrl] = useState('');
    const [mode, setMode] = useState<AudienceMode>('all');
    const [selectedUsers, setSelectedUsers] = useState<User[]>([]);
    const [userSearch, setUserSearch] = useState('');
    const [debouncedSearch, setDebouncedSearch] = useState('');
    const [doSchedule, setDoSchedule] = useState(false);
    const [scheduledFor, setScheduledFor] = useState('');
    const [banner, setBanner] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

    // ── history state ─────────────────────────────────────────────────────────
    const [page, setPage] = useState(0);
    const [detailId, setDetailId] = useState<string | null>(null);

    React.useEffect(() => {
      const t = setTimeout(() => setDebouncedSearch(userSearch), 400);
      return () => clearTimeout(t);
    }, [userSearch]);

    React.useEffect(() => {
      if (banner) {
        const t = setTimeout(() => setBanner(null), 3500);
        return () => clearTimeout(t);
      }
    }, [banner]);

    const userResults = useQuery<UsersResponse>({
      queryKey: ['notif-user-search', debouncedSearch],
      queryFn: async () =>
        (await api.get('/admin/users', { params: { page: 1, search: debouncedSearch } })).data,
      enabled: mode === 'users' && debouncedSearch.trim().length > 0,
    });

    const history = useQuery({
      queryKey: ['notif-history', page],
      queryFn: () => notificationsService.getHistory({ limit: HISTORY_LIMIT, offset: page * HISTORY_LIMIT }),
    });

    const detail = useQuery<NotificationDetail>({
      queryKey: ['notif-detail', detailId],
      queryFn: () => notificationsService.getDetail(detailId as string),
      enabled: !!detailId,
    });

    const buildData = (): NotificationData =>
      destKind === 'route' ? { kind: 'route', screen } : { kind: 'external', url: url.trim() };

    const buildAudience = (): NotificationAudience =>
      mode === 'users' ? { mode: 'users', user_ids: selectedUsers.map((u) => u.id) } : { mode: 'all' };

    const urlValid = /^https?:\/\//.test(url.trim());
    const canSend =
      !!title.trim() &&
      !!bodyText.trim() &&
      (destKind === 'route' || urlValid) &&
      (mode !== 'users' || selectedUsers.length > 0) &&
      (!doSchedule || !!scheduledFor);

    const sendMutation = useMutation({
      mutationFn: () => {
        const payload: SendNotificationPayload = {
          title: title.trim(),
          body: bodyText.trim(),
          data: buildData(),
          audience: buildAudience(),
        };
        if (doSchedule && scheduledFor) payload.scheduled_for = new Date(scheduledFor).toISOString();
        return notificationsService.send(payload);
      },
      onSuccess: (res) => {
        setBanner({ type: 'success', message: `Notification ${res.status} · id ${res.notification_id.slice(0, 8)}` });
        setTitle('');
        setBodyText('');
        setSelectedUsers([]);
        setUserSearch('');
        setScheduledFor('');
        setDoSchedule(false);
        setPage(0);
        history.refetch();
      },
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      onError: (e: any) =>
        setBanner({
          type: 'error',
          message: e?.response?.data?.detail?.message || e?.response?.data?.detail || 'Send failed',
        }),
    });

    const toggleUser = (u: User) =>
      setSelectedUsers((prev) =>
        prev.find((x) => x.id === u.id) ? prev.filter((x) => x.id !== u.id) : [...prev, u],
      );

    const radio = (m: AudienceMode, label: string, disabled = false) => (
      <label
        className={classNames(
          'flex items-center gap-2 px-3 py-2 rounded-lg border cursor-pointer text-sm',
          mode === m ? 'border-indigo-500/50 bg-indigo-500/10 text-indigo-300' : 'border-slate-700 text-slate-300',
          disabled && 'opacity-40 cursor-not-allowed',
        )}
      >
        <input
          type="radio"
          name="audience"
          checked={mode === m}
          disabled={disabled}
          onChange={() => setMode(m)}
          className="accent-indigo-500"
        />
        {label}
      </label>
    );

    return (
      <div className="space-y-6">
        <div className="flex items-center gap-2">
          <Bell size={24} weight="duotone" className="text-indigo-400" />
          <h1 className="text-2xl font-bold text-slate-100">Notifications</h1>
        </div>

        {banner && (
          <div
            className={classNames(
              'px-4 py-3 rounded-lg border text-sm',
              banner.type === 'success'
                ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-300'
                : 'bg-red-500/10 border-red-500/20 text-red-300',
            )}
          >
            {banner.message}
          </div>
        )}

        {/* ── Compose ─────────────────────────────────────────────────────── */}
        <div className="bg-slate-800 rounded-xl border border-slate-700 p-6 space-y-4">
          <h2 className="text-lg font-semibold text-slate-100">Compose</h2>

          <div>
            <label className={labelCls}>Title</label>
            <input className={inputCls} value={title} maxLength={120} onChange={(e) => setTitle(e.target.value)} />
          </div>

          <div>
            <label className={labelCls}>Body</label>
            <textarea
              className={classNames(inputCls, 'min-h-[80px]')}
              value={bodyText}
              maxLength={500}
              onChange={(e) => setBodyText(e.target.value)}
            />
          </div>

          {/* Destination */}
          <div>
            <label className={labelCls}>Destination (on tap)</label>
            <div className="flex flex-col sm:flex-row gap-3">
              <select
                className={classNames(inputCls, 'sm:w-48')}
                value={destKind}
                onChange={(e) => setDestKind(e.target.value as 'route' | 'external')}
              >
                <option value="route">In-app screen</option>
                <option value="external">External URL</option>
              </select>
              {destKind === 'route' ? (
                <select
                  className={inputCls}
                  value={screen}
                  onChange={(e) => setScreen(e.target.value as CuratedScreen)}
                >
                  {CURATED_SCREENS.map((s) => (
                    <option key={s.value} value={s.value}>
                      {s.label}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  className={inputCls}
                  placeholder="https://..."
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                />
              )}
            </div>
            {destKind === 'external' && url.trim() !== '' && !urlValid && (
              <p className="text-xs text-red-400 mt-1">Must start with http:// or https://</p>
            )}
          </div>

          {/* Audience */}
          <div>
            <label className={labelCls}>Audience</label>
            <div className="flex flex-wrap gap-2">
              {radio('all', 'All users')}
              {radio('users', 'Specific users')}
              {radio('segment', 'Segment (coming soon)', true)}
            </div>

            {mode === 'users' && (
              <div className="mt-3 space-y-2">
                <div className="relative">
                  <input
                    className={classNames(inputCls, 'pl-10')}
                    placeholder="Search users by email..."
                    value={userSearch}
                    onChange={(e) => setUserSearch(e.target.value)}
                  />
                  <MagnifyingGlass className="absolute left-3 top-2.5 h-5 w-5 text-slate-500" />
                </div>

                {selectedUsers.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {selectedUsers.map((u) => (
                      <span
                        key={u.id}
                        className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs bg-indigo-500/10 text-indigo-300 border border-indigo-500/20"
                      >
                        {u.email}
                        <button onClick={() => toggleUser(u)} className="hover:text-white">
                          <X size={12} />
                        </button>
                      </span>
                    ))}
                  </div>
                )}

                {userResults.isFetching && (
                  <div className="text-xs text-slate-500 flex items-center gap-1">
                    <Spinner className="animate-spin" /> searching…
                  </div>
                )}
                {userResults.data && userResults.data.users.length > 0 && (
                  <div className="max-h-48 overflow-y-auto border border-slate-700 rounded-lg divide-y divide-slate-700">
                    {userResults.data.users.map((u) => {
                      const checked = !!selectedUsers.find((x) => x.id === u.id);
                      return (
                        <label
                          key={u.id}
                          className="flex items-center gap-2 px-3 py-2 text-sm text-slate-200 hover:bg-slate-700/50 cursor-pointer"
                        >
                          <input
                            type="checkbox"
                            checked={checked}
                            onChange={() => toggleUser(u)}
                            className="accent-indigo-500"
                          />
                          {u.email}
                        </label>
                      );
                    })}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Timing */}
          <div>
            <label className="flex items-center gap-2 text-sm text-slate-300">
              <input
                type="checkbox"
                checked={doSchedule}
                onChange={(e) => setDoSchedule(e.target.checked)}
                className="accent-indigo-500"
              />
              Schedule for later
            </label>
            {doSchedule && (
              <input
                type="datetime-local"
                className={classNames(inputCls, 'mt-2 sm:w-72')}
                value={scheduledFor}
                onChange={(e) => setScheduledFor(e.target.value)}
              />
            )}
          </div>

          <button
            disabled={!canSend || sendMutation.isPending}
            onClick={() => sendMutation.mutate()}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-indigo-500 text-white font-medium hover:bg-indigo-400 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {sendMutation.isPending ? <Spinner className="animate-spin" /> : <PaperPlaneTilt />}
            {doSchedule ? 'Schedule' : 'Send now'}
          </button>
        </div>

        {/* ── History ─────────────────────────────────────────────────────── */}
        <div className="bg-slate-800 rounded-xl border border-slate-700 overflow-hidden">
          <div className="px-6 py-4 border-b border-slate-700">
            <h2 className="text-lg font-semibold text-slate-100">History</h2>
          </div>
          {history.isLoading ? (
            <div className="p-12 flex justify-center">
              <Spinner size={28} className="animate-spin text-indigo-500" />
            </div>
          ) : history.isError ? (
            <div className="p-12 text-center text-red-400">Failed to load history.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-700 text-sm">
                <thead className="bg-slate-900/50 text-xs uppercase tracking-wider text-slate-500">
                  <tr>
                    <th className="px-4 py-3 text-left">Title</th>
                    <th className="px-4 py-3 text-left">Audience</th>
                    <th className="px-4 py-3 text-left">Status</th>
                    <th className="px-4 py-3 text-left">Sent / Failed / No-token / Read</th>
                    <th className="px-4 py-3 text-left">Created</th>
                    <th className="px-4 py-3" />
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-700">
                  {history.data?.notifications.map((n) => (
                    <tr key={n.id} className="hover:bg-slate-700/40">
                      <td className="px-4 py-3 text-slate-100 font-medium">{n.title}</td>
                      <td className="px-4 py-3 text-slate-400">{n.type.replace('admin_', '')}</td>
                      <td className="px-4 py-3">
                        <span
                          className={classNames(
                            'px-2 py-1 rounded-full border text-xs',
                            STATUS_BADGE[n.status] || 'bg-slate-700 text-slate-300 border-slate-600',
                          )}
                        >
                          {n.status}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-slate-300">
                        {n.summary.sent} / {n.summary.failed} / {n.summary.no_token} / {n.summary.read}
                      </td>
                      <td className="px-4 py-3 text-slate-400">{new Date(n.created_at).toLocaleString()}</td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => setDetailId(n.id)}
                          className="text-indigo-400 hover:text-indigo-300 inline-flex items-center gap-1 text-xs"
                        >
                          <Eye size={14} /> View
                        </button>
                      </td>
                    </tr>
                  ))}
                  {history.data?.notifications.length === 0 && (
                    <tr>
                      <td colSpan={6} className="px-4 py-12 text-center text-slate-500">
                        No notifications sent yet.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}

          {history.data && history.data.total > HISTORY_LIMIT && (
            <div className="flex items-center justify-between px-4 py-3 border-t border-slate-700">
              <button
                disabled={page === 0}
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-md border border-slate-700 text-slate-300 disabled:opacity-40"
              >
                <CaretLeft size={14} /> Prev
              </button>
              <span className="text-xs text-slate-500">
                {page * HISTORY_LIMIT + 1}–{Math.min((page + 1) * HISTORY_LIMIT, history.data.total)} of {history.data.total}
              </span>
              <button
                disabled={(page + 1) * HISTORY_LIMIT >= history.data.total}
                onClick={() => setPage((p) => p + 1)}
                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-md border border-slate-700 text-slate-300 disabled:opacity-40"
              >
                Next <CaretRight size={14} />
              </button>
            </div>
          )}
        </div>

        {/* ── Detail modal ────────────────────────────────────────────────── */}
        {detailId && (
          <div
            className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
            onClick={() => setDetailId(null)}
          >
            <div
              className="bg-slate-800 border border-slate-700 rounded-xl w-full max-w-lg p-6 space-y-4"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold text-slate-100">Notification detail</h3>
                <button onClick={() => setDetailId(null)} className="text-slate-400 hover:text-white">
                  <X size={20} />
                </button>
              </div>
              {detail.isLoading ? (
                <div className="py-8 flex justify-center">
                  <Spinner className="animate-spin text-indigo-500" size={24} />
                </div>
              ) : detail.data ? (
                <div className="space-y-3 text-sm">
                  <div>
                    <div className="text-slate-100 font-medium">{detail.data.notification.title}</div>
                    <div className="text-slate-400">{detail.data.notification.body}</div>
                  </div>
                  <div className="text-xs text-slate-500">
                    data: {JSON.stringify(detail.data.notification.data)}
                  </div>
                  <div className="grid grid-cols-4 gap-2 text-center">
                    {(['sent', 'failed', 'no_token', 'read'] as const).map((k) => (
                      <div key={k} className="bg-slate-900/60 rounded-lg p-3 border border-slate-700">
                        <div className="text-xl font-bold text-slate-100">{detail.data!.summary[k]}</div>
                        <div className="text-[10px] uppercase tracking-wider text-slate-500">{k.replace('_', ' ')}</div>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="text-red-400 text-sm">Failed to load detail.</div>
              )}
            </div>
          </div>
        )}
      </div>
    );
  };

  export default Notifications;
  ```
- [ ] Type-check + lint:
  ```bash
  cd wardrobe-admin && npx tsc --noEmit && npm run lint
  ```
- [ ] Commit:
  ```bash
  git add src/pages/Notifications.tsx
  git commit -m "feat(admin): Notifications page (compose + history + detail)"
  ```

---

## Task 10: Admin SPA — route + nav wiring + build

**Files:**
- Modify: `wardrobe-admin/src/App.tsx`
- Modify: `wardrobe-admin/src/components/layout/Layout.tsx`

**Interfaces:** Registers `/notifications` under `<Layout />`; adds a Bell sidebar item.

- [ ] In `src/App.tsx`: add the import and the route (inside the `<Layout />` route group, e.g. after the `app-feedback` route):
  ```tsx
  import Notifications from './pages/Notifications';
  ```
  ```tsx
  <Route path="notifications" element={<Notifications />} />
  ```
- [ ] In `src/components/layout/Layout.tsx`: add `Bell` to the phosphor import and a nav entry:
  ```tsx
  import { ChartBar, GridFour, Users, TShirt, List, X, Sparkle, MagicWand, Upload, ChatCenteredDots, ChatText, Bell } from '@phosphor-icons/react';
  ```
  ```tsx
  { name: 'Notifications', href: '/notifications', icon: Bell },
  ```
- [ ] Verify build + manual smoke:
  ```bash
  cd wardrobe-admin && npx tsc --noEmit && yarn build   # (or: npm run build)
  ```
  - [ ] Manual UI check: `npm run dev`, log in as admin → open **Notifications** in the sidebar → compose "All users" + screen Home → **Send now** → success banner; the new row appears in History with status `sending` and counts; click **View** → detail modal shows the summary. Switch to **Specific users**, search an email, select, send → row shows `admin_direct`.
- [ ] Commit:
  ```bash
  git add src/App.tsx src/components/layout/Layout.tsx
  git commit -m "feat(admin): register Notifications route + sidebar nav"
  ```

---

## Task 11 (FAST-FOLLOW): Segment targeting — backend branch + SPA UI

Clearly-labeled fast-follow so **All + Specific ship first**. Implements `_resolve_segment` (gender / inactive_days / has_items) and enables the Segment audience UI.

> ⚠️ **inactive-filter timestamp FLAG:** `models/user.py` has **`gender` + `created_at` only — NO `last_login`/`last_active`/`last_seen` field on `User`.** The best available activity proxy is **`device_tokens.last_seen_at`** (max per user; refreshed on each token register, spec §5). The inactive filter uses it; a user with **no device token** is treated as inactive (no `last_seen_at`). This is an approximation of in-app activity (it measures device-registration recency). Recommend a future `User.last_active_at` for an accurate signal — note it in the PR for CEO/tech-lead.

**Files:**
- Modify: `services/notification_service.py` (replace `_resolve_segment` stub)
- Test: `tests/test_notification_service_segment.py`
- Modify: `wardrobe-admin/src/pages/Notifications.tsx` (enable Segment UI + `buildAudience`)

**Interfaces:** Produces working `audience.mode == "segment"` resolution. `segment = {gender?, inactive_days?, has_items?}`.

- [ ] **TDD — failing test** `tests/test_notification_service_segment.py`:
  ```python
  """Phase 2 fast-follow — segment targeting (gender / inactive_days / has_items)."""
  import uuid
  from datetime import datetime, timedelta, timezone

  from services import notification_service


  def _user(db, gender=None):
      from models.user import User
      u = User(id=str(uuid.uuid4()), email=f"{uuid.uuid4().hex[:8]}@e.com",
               password_hash="x", role="user", gender=gender)
      db.add(u)
      db.commit()
      return u


  def _item(db, user_id):
      from models.wardrobe import WardrobeItem
      it = WardrobeItem(user_id=user_id, name="tee", category="top",
                        is_common_item=False, is_deleted=False)
      db.add(it)
      db.commit()
      return it


  def _token(db, user_id, days_ago):
      from models.device_token import DeviceToken
      seen = datetime.now(timezone.utc) - timedelta(days=days_ago)
      t = DeviceToken(user_id=user_id, token=uuid.uuid4().hex, platform="ios",
                      timezone="Asia/Saigon", last_seen_at=seen)
      db.add(t)
      db.commit()
      return t


  def test_segment_by_gender(notif_db):
      main, _ = notif_db
      f = _user(main, gender="female")
      _user(main, gender="male")
      out = notification_service.resolve_audience(main, {"mode": "segment", "segment": {"gender": "female"}})
      assert out == [f.id]


  def test_segment_has_items_true(notif_db):
      main, _ = notif_db
      onboarded = _user(main)
      _item(main, onboarded.id)
      _user(main)  # empty wardrobe
      out = notification_service.resolve_audience(main, {"mode": "segment", "segment": {"has_items": True}})
      assert out == [onboarded.id]


  def test_segment_inactive_days_uses_device_last_seen(notif_db):
      main, _ = notif_db
      stale = _user(main)
      _token(main, stale.id, days_ago=30)
      active = _user(main)
      _token(main, active.id, days_ago=1)
      out = set(notification_service.resolve_audience(
          main, {"mode": "segment", "segment": {"inactive_days": 7}}))
      assert stale.id in out and active.id not in out


  def test_segment_no_token_counts_as_inactive(notif_db):
      main, _ = notif_db
      no_device = _user(main)  # no token at all
      out = notification_service.resolve_audience(
          main, {"mode": "segment", "segment": {"inactive_days": 7}})
      assert no_device.id in out
  ```
- [ ] Run — expect FAIL:
  ```bash
  python -m pytest tests/test_notification_service_segment.py -v
  ```
- [ ] **Implement** — replace the `_resolve_segment` stub in `services/notification_service.py`:
  ```python
  from datetime import timedelta

  from sqlalchemy import func

  from models.wardrobe import WardrobeItem
  from models.device_token import DeviceToken


  def _resolve_segment(db: Session, segment: dict) -> list[str]:
      """Resolve a v1 segment spec -> user ids.

      segment keys (combinable):
        gender:        User.gender == value
        has_items:     bool — has >=1 personal (non-common, non-deleted) item
        inactive_days: int  — last activity older than N days.
                       NOTE: User has no last_login/last_active field, so we use
                       max(device_tokens.last_seen_at) as the best proxy; a user
                       with no device token is treated as inactive. (See PR note.)
      """
      segment = segment or {}
      q = select(User.id)
      gender = segment.get("gender")
      if gender:
          q = q.where(User.gender == gender)
      user_ids = list(db.execute(q).scalars().all())

      has_items = segment.get("has_items")
      if has_items is not None:
          owners = set(
              db.execute(
                  select(WardrobeItem.user_id)
                  .where(WardrobeItem.is_common_item == False)  # noqa: E712
                  .where(WardrobeItem.is_deleted == False)  # noqa: E712
                  .distinct()
              ).scalars().all()
          )
          user_ids = [u for u in user_ids if (u in owners) == bool(has_items)]

      inactive_days = segment.get("inactive_days")
      if inactive_days is not None:
          cutoff = datetime.now(timezone.utc) - timedelta(days=int(inactive_days))
          last_seen = dict(
              db.execute(
                  select(DeviceToken.user_id, func.max(DeviceToken.last_seen_at))
                  .group_by(DeviceToken.user_id)
              ).all()
          )
          user_ids = [
              u for u in user_ids
              if last_seen.get(u) is None or last_seen[u] < cutoff
          ]

      return user_ids
  ```
- [ ] Run — expect PASS. Commit:
  ```bash
  python -m pytest tests/test_notification_service_segment.py -v
  git add services/notification_service.py tests/test_notification_service_segment.py
  git commit -m "feat: notification_service segment targeting (gender/inactive/has-items)"
  ```
- [ ] **SPA — enable the Segment UI** in `src/pages/Notifications.tsx`:
  - Add segment state:
    ```tsx
    const [segGender, setSegGender] = useState('');
    const [segInactive, setSegInactive] = useState('');
    const [segHasItems, setSegHasItems] = useState<'' | 'true' | 'false'>('');
    ```
  - Enable the Segment radio (drop the `disabled`): `{radio('segment', 'Segment')}`.
  - Extend `buildAudience`:
    ```tsx
    const buildAudience = (): NotificationAudience => {
      if (mode === 'users') return { mode: 'users', user_ids: selectedUsers.map((u) => u.id) };
      if (mode === 'segment') {
        const segment: NotificationSegment = {};
        if (segGender) segment.gender = segGender;
        if (segInactive) segment.inactive_days = Number(segInactive);
        if (segHasItems !== '') segment.has_items = segHasItems === 'true';
        return { mode: 'segment', segment };
      }
      return { mode: 'all' };
    };
    ```
    (import `NotificationSegment` from `../types`).
  - Add a `canSend` clause: segment requires at least one attribute —
    `(mode !== 'segment' || !!segGender || !!segInactive || segHasItems !== '')`.
  - Render the segment panel under the audience radios when `mode === 'segment'`:
    ```tsx
    {mode === 'segment' && (
      <div className="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div>
          <label className={labelCls}>Gender</label>
          <select className={inputCls} value={segGender} onChange={(e) => setSegGender(e.target.value)}>
            <option value="">Any</option>
            <option value="female">Female</option>
            <option value="male">Male</option>
          </select>
        </div>
        <div>
          <label className={labelCls}>Inactive &gt; N days</label>
          <input className={inputCls} type="number" min={1} value={segInactive} onChange={(e) => setSegInactive(e.target.value)} placeholder="e.g. 7" />
        </div>
        <div>
          <label className={labelCls}>Has items</label>
          <select className={inputCls} value={segHasItems} onChange={(e) => setSegHasItems(e.target.value as '' | 'true' | 'false')}>
            <option value="">Any</option>
            <option value="true">Onboarded (has items)</option>
            <option value="false">Empty wardrobe</option>
          </select>
        </div>
      </div>
    )}
    ```
- [ ] Verify + commit:
  ```bash
  cd wardrobe-admin && npx tsc --noEmit && npm run lint && yarn build
  git add src/pages/Notifications.tsx
  git commit -m "feat(admin): enable segment audience targeting UI"
  ```

---

## Phase 2 Done When

- [ ] `services/queue_service.py` exposes `NOTIFICATION_QUEUE` + `push_notification_job` / `pop_notification_job` (Task 1).
- [ ] `notification_service.resolve_audience` (all/users/segment) + `enqueue` (fan-out + system dedup) implemented (Tasks 3, 4, 11).
- [ ] `notification_worker.py` consumer drains `notification_queue` → `deliver`, with bounded retry + graceful shutdown (Task 5). **APScheduler producer NOT built (Phase 3).**
- [ ] `repositories/notification_repository.py` has list+total, dedup lookup, and delivery summary (sent/failed/no_token/read) (Task 2).
- [ ] `POST/GET/GET /api/admin/notifications*` live, admin-gated (403 non-admin), registered in `routers/admin/__init__.py`; immediate → enqueued (`sending`), future → `queued` (Task 6).
- [ ] `API_DOCUMENTATION.md` documents all 3 admin routes (Task 7).
- [ ] Admin SPA: `notificationsService` + Notifications page (compose all/specific/segment + history with stats + detail) + route + Bell nav (Tasks 8–11).
- [ ] **End-to-end:** admin **Send now → broadcast** returns 202 → one job per recipient on `notification_queue` → `notification_worker` consumes and calls `deliver` (mocked `push_service` in tests; real FCM once Phase 0/1 native + `FIREBASE_CREDENTIALS_JSON` land) → History shows sent/failed/no_token/read counts; row → detail breakdown.
- [ ] Gates green:
  ```bash
  cd wardrobe-backend && python -m pytest tests/test_notification_*.py tests/test_admin_notifications_router.py -v && python test_server.py
  cd wardrobe-admin && npx tsc --noEmit && npm run lint && yarn build
  ```

> **Redis must be running** for the worker (`pop_notification_job` BRPOPs `notification_queue`); the admin `send` endpoint also pushes via Redis. Local: `redis-server` (or `make up`); prod: the `notification-worker` Railway service reads the same `REDIS_URL` (devops, Phase 3). Tests never need live Redis — they use `fakeredis` (already a dev dep) + mock `deliver`.
