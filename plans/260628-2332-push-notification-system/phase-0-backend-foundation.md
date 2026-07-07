# Phase 0: Backend Foundation

**Goal:** Lay the `wardrobe-backend` foundation for push notifications — 3 SQLAlchemy models + one Alembic migration, a mockable FCM `push_service`, the `notification_service` consumer half (`create_system_notification` + `deliver`), the user-facing device-token register/unregister endpoints, the `FIREBASE_CREDENTIALS_JSON` setting, and the API doc. No queue, no scheduler, no admin endpoints (those are Phases 2–3).

**Prereqs:** none (base of the feature).

> **Spec:** [`spec.md`](./spec.md) · **Plan + locked interfaces:** [`plan.md`](./plan.md). Match every signature / column / status string in plan.md's "Locked cross-phase interfaces" VERBATIM.

> **Pattern mirror:** this phase mirrors the existing `app_feedback` module end-to-end (model → repository → service → router → migration → tests). The `schedule`/`creations` modules named in the spec live on `auxi-backend` `main` but are **not present in the local stale checkout**; `app_feedback` is the canonical in-repo sibling and uses the identical layering. All code below follows it.

> **Conventions confirmed from the repo (don't deviate):**
> - Models use Flask-SQLAlchemy: `from extensions import db` → `db.Model` / `db.Column`. UUID PK = `db.String(36)` with `default=lambda: str(uuid.uuid4())`. FK = `db.ForeignKey("users.id")`. JSON = `db.JSON` (generic; portable SQLite + Postgres).
> - Repositories are classes; methods take `db: Session` first; they `db.flush()` (never commit) — **callers (routers / worker) own the commit**.
> - Services in this feature are **module-level functions** (the locked contract uses free functions, not a class).
> - Routers: `APIRouter(prefix=..., tags=[...])`, `Depends(get_current_user)`, rate-limit via `utils.rate_limiter.get_rate_limiter` gated by `settings.RATE_LIMIT_ENABLED` (copy `routers/app_feedback.py` verbatim), commit in the router with try/except rollback.
> - Migrations are **hand-written + idempotent** (the alembic env can't see Flask-SQLAlchemy models, so autogenerate is unreliable — see `migrations/versions/appfb1a2b3c4d_add_app_feedback.py`).
> - Tests: model/repo/service tests use the `db_session` fixture in `tests/conftest.py` (in-memory SQLite, `create_all` from the model import list). Endpoint tests use the `threaded_db` + `TestClient` + `app.dependency_overrides` pattern from `tests/test_app_feedback_router.py`.

## Files overview

**Create:**
- `models/device_token.py` — `DeviceToken` model + `DEVICE_PLATFORMS` vocab tuple.
- `models/notification.py` — `Notification` model + `NOTIFICATION_SOURCES` / `NOTIFICATION_TYPES` / `NOTIFICATION_STATUSES` vocab tuples.
- `models/notification_delivery.py` — `NotificationDelivery` model + `DELIVERY_STATUSES` vocab tuple.
- `migrations/versions/notif1a2b3c4d_add_push_notifications.py` — single revision, creates all 3 tables; `down_revision = "schedule1a2b"`.
- `repositories/device_token_repository.py` — `DeviceTokenRepository` (`upsert`, `get_by_user`, `delete_by_token`).
- `repositories/notification_repository.py` — `NotificationRepository` (`create_notification`, `create_delivery`, `get`, `list_notifications`).
- `services/push_service.py` — `PushResult` dataclass, `init_firebase()`, `send_to_tokens()` (FCM via firebase-admin, mockable).
- `services/notification_service.py` — `create_system_notification()`, `deliver()` (P0 consumer half). `resolve_audience` / `enqueue` referenced only (Phase 2).
- `schemas/notification.py` — `DeviceTokenRegisterRequest`, `DeviceTokenDeleteRequest`, `OkResponse`.
- `routers/notifications.py` — user router: `POST` + `DELETE /api/notifications/device-token`.
- `tests/test_notification_models.py` — model persistence + (manual) migration up/down.
- `tests/test_device_token_repository.py` — upsert reassignment, get_by_user, delete (unconditional + user-scoped).
- `tests/test_notification_repository.py` — create_notification / create_delivery / get / list.
- `tests/test_push_service.py` — batching + invalid-token flagging with firebase mocked.
- `tests/test_notification_service.py` — `deliver()` sent / no_token / invalid-cleanup with `push_service` mocked.
- `tests/test_notifications_router.py` — the 2 endpoints (auth required, upsert, delete idempotent).

**Modify:**
- `settings.py` — add `FIREBASE_CREDENTIALS_JSON: str = ""`.
- `requirements.txt` — add `firebase-admin>=6.5.0`.
- `routers/__init__.py` — export `notifications_router`.
- `app.py` — register `notifications_router`.
- `tests/conftest.py` — add the 3 new models to the `db_session` import list so `create_all` builds the tables.
- `API_DOCUMENTATION.md` — document the 2 new `/api/notifications/device-token` routes.

---

## Task 1: Models + migration + test registration

Three models, one hand-written idempotent migration, and the conftest registration so the in-memory test DB builds the tables.

**Files:**
- Create: `models/device_token.py`, `models/notification.py`, `models/notification_delivery.py`
- Create: `migrations/versions/notif1a2b3c4d_add_push_notifications.py`
- Create: `tests/test_notification_models.py`
- Modify: `tests/conftest.py`

**Interfaces:**
- Produces (other phases depend on these, match plan.md verbatim):
  - `DeviceToken(id, user_id, token, platform, timezone, app_version, created_at, last_seen_at)`
  - `Notification(id, source, type, title, body, data, audience, created_by, scheduled_for, status, created_at, sent_at)`
  - `NotificationDelivery(id, notification_id, user_id, status, read_at, error, created_at, sent_at)`
  - `type` values: `daily_reminder` `planned_outfit` `admin_broadcast` `admin_direct` `admin_segment`.
  - Single migration head after this phase; `down_revision = "schedule1a2b"`.

Steps:

- [ ] **Verify the real current head FIRST.** Run, from the up-to-date `auxi-backend` `main` checkout (schedule + creations merged):
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m alembic -c migrations/alembic.ini heads
  ```
  Expect **exactly one** line: `schedule1a2b (head)`. If it prints multiple heads (e.g. `appfb1a2b3c4d (head)` + `au318a1b2c3d (head)`) or a different id, **STOP** — the checkout is stale/divergent. Rebase onto `auxi-backend` `main` before continuing, and set `down_revision` below to the real single head. (The local dev/Desktop checkouts at authoring time were stale: two heads, no schedule/creations.)

- [ ] Write `models/device_token.py`:
  ```python
  """FCM device token registry (push notifications, Phase 0).

  One row per (device, FCM token). `token` is unique — re-registering the
  same token reassigns `user_id` (handles logout->login on the same device).
  `timezone` (IANA) is required: the daily-reminder scheduler (Phase 3) uses
  it as the source of truth for a user's local time.

  Portability: generic SQLAlchemy column types so DDL works on both the
  in-memory SQLite test DB and Postgres prod (same rule as models/app_feedback.py).
  """
  from __future__ import annotations

  import uuid
  from datetime import datetime, timezone

  from extensions import db

  # Single source of truth for the bounded vocabulary; the Pydantic schema
  # imports this tuple. (No CHECK constraint here — platform is low-risk and
  # we keep the table lean; the schema validator rejects bad values at the edge.)
  DEVICE_PLATFORMS: tuple[str, ...] = ("ios", "android")


  class DeviceToken(db.Model):
      """A single registered FCM device token."""

      __tablename__ = "device_tokens"

      id = db.Column(
          db.String(36),
          primary_key=True,
          default=lambda: str(uuid.uuid4()),
      )
      user_id = db.Column(
          db.String(36),
          db.ForeignKey("users.id"),
          nullable=False,
          index=True,
      )
      token = db.Column(db.String(512), nullable=False, unique=True, index=True)
      platform = db.Column(db.String(16), nullable=False)
      timezone = db.Column(db.String(64), nullable=False)
      app_version = db.Column(db.String(32), nullable=True)
      created_at = db.Column(
          db.DateTime,
          nullable=False,
          default=lambda: datetime.now(timezone.utc),
      )
      last_seen_at = db.Column(
          db.DateTime,
          nullable=False,
          default=lambda: datetime.now(timezone.utc),
      )

      def __repr__(self) -> str:
          return (
              f"<DeviceToken id={self.id} user={self.user_id} "
              f"platform={self.platform}>"
          )
  ```

- [ ] Write `models/notification.py`:
  ```python
  """Notification (message / campaign) model — push notifications, Phase 0.

  One row per logical message: a system reminder run OR an admin campaign.
  Per-recipient fan-out lives in `notification_delivery`. `data` is the
  deep-link payload ({"kind":"route","screen":...} | {"kind":"external","url":...});
  `audience` is admin targeting (null for per-user system runs).
  """
  from __future__ import annotations

  import uuid
  from datetime import datetime, timezone

  from extensions import db

  NOTIFICATION_SOURCES: tuple[str, ...] = ("system", "admin")
  NOTIFICATION_TYPES: tuple[str, ...] = (
      "daily_reminder",
      "planned_outfit",
      "admin_broadcast",
      "admin_direct",
      "admin_segment",
  )
  NOTIFICATION_STATUSES: tuple[str, ...] = ("queued", "sending", "sent", "failed")


  class Notification(db.Model):
      """A single notification message / campaign."""

      __tablename__ = "notifications"

      id = db.Column(
          db.String(36),
          primary_key=True,
          default=lambda: str(uuid.uuid4()),
      )
      source = db.Column(db.String(16), nullable=False)
      type = db.Column(db.String(32), nullable=False)
      title = db.Column(db.String(255), nullable=False)
      body = db.Column(db.Text, nullable=False)
      data = db.Column(db.JSON, nullable=False)
      audience = db.Column(db.JSON, nullable=True)
      created_by = db.Column(
          db.String(36),
          db.ForeignKey("users.id"),
          nullable=True,
      )
      scheduled_for = db.Column(db.DateTime, nullable=True)
      status = db.Column(
          db.String(16),
          nullable=False,
          default="queued",
          server_default="queued",
      )
      created_at = db.Column(
          db.DateTime,
          nullable=False,
          default=lambda: datetime.now(timezone.utc),
      )
      sent_at = db.Column(db.DateTime, nullable=True)

      def __repr__(self) -> str:
          return (
              f"<Notification id={self.id} source={self.source} "
              f"type={self.type} status={self.status}>"
          )
  ```

- [ ] Write `models/notification_delivery.py`:
  ```python
  """Per-recipient delivery fan-out (push notifications, Phase 0).

  One row per (notification, user). `read_at` is added now but unused until
  the Phase 4 in-app inbox. Dedup of system reminders is a Phase 2 concern
  (enqueue-side), so there is intentionally no `type`/`local_date` column here.
  """
  from __future__ import annotations

  import uuid
  from datetime import datetime, timezone

  from extensions import db

  DELIVERY_STATUSES: tuple[str, ...] = ("pending", "sent", "failed", "no_token")


  class NotificationDelivery(db.Model):
      """A single per-recipient delivery record."""

      __tablename__ = "notification_deliveries"

      id = db.Column(
          db.String(36),
          primary_key=True,
          default=lambda: str(uuid.uuid4()),
      )
      notification_id = db.Column(
          db.String(36),
          db.ForeignKey("notifications.id"),
          nullable=False,
          index=True,
      )
      user_id = db.Column(
          db.String(36),
          db.ForeignKey("users.id"),
          nullable=False,
          index=True,
      )
      status = db.Column(
          db.String(16),
          nullable=False,
          default="pending",
          server_default="pending",
      )
      read_at = db.Column(db.DateTime, nullable=True)
      error = db.Column(db.String(255), nullable=True)
      created_at = db.Column(
          db.DateTime,
          nullable=False,
          default=lambda: datetime.now(timezone.utc),
      )
      sent_at = db.Column(db.DateTime, nullable=True)

      def __repr__(self) -> str:
          return (
              f"<NotificationDelivery id={self.id} "
              f"notification={self.notification_id} status={self.status}>"
          )
  ```

- [ ] Register the 3 models in `tests/conftest.py` so the in-memory DB builds the tables. Edit the `from models import (...)` block inside the `db_session` fixture:
  ```python
      from models import (  # noqa: F401
          wardrobe,
          user,
          token,
          auth_token,
          body,
          favorite,
          tryon,
          decision,
          recommendation_log,
          v05_event,
          recommendation_feedback,
          app_feedback,
          device_token,
          notification,
          notification_delivery,
      )
  ```

- [ ] Write the failing model test `tests/test_notification_models.py`:
  ```python
  """Push-notification models — persistence smoke (in-memory SQLite)."""
  from __future__ import annotations

  import uuid
  from datetime import datetime, timezone

  from models.device_token import DeviceToken
  from models.notification import Notification
  from models.notification_delivery import NotificationDelivery


  def _make_user(db_session):
      from models.user import User

      user = User(
          id=str(uuid.uuid4()),
          email=f"n-{uuid.uuid4().hex[:8]}@example.com",
          password_hash="argon2-stub",
      )
      db_session.add(user)
      db_session.commit()
      return user


  def test_device_token_persists(db_session):
      user = _make_user(db_session)
      tok = DeviceToken(
          user_id=user.id,
          token="fcm-tok-1",
          platform="ios",
          timezone="Asia/Saigon",
          app_version="1.0-build8",
      )
      db_session.add(tok)
      db_session.commit()
      fetched = db_session.get(DeviceToken, tok.id)
      assert fetched is not None
      assert fetched.token == "fcm-tok-1"
      assert fetched.created_at is not None
      assert fetched.last_seen_at is not None


  def test_notification_and_delivery_persist(db_session):
      user = _make_user(db_session)
      notif = Notification(
          source="system",
          type="daily_reminder",
          title="Time to plan today's outfit",
          body="Open Auxi and pick your look.",
          data={"kind": "route", "screen": "Home"},
          status="sending",
      )
      db_session.add(notif)
      db_session.commit()

      delivery = NotificationDelivery(
          notification_id=notif.id,
          user_id=user.id,
          status="sent",
          sent_at=datetime.now(timezone.utc),
      )
      db_session.add(delivery)
      db_session.commit()

      assert db_session.get(Notification, notif.id).data["screen"] == "Home"
      got = db_session.get(NotificationDelivery, delivery.id)
      assert got.status == "sent"
      assert got.read_at is None  # Phase 4 inbox column, unused now
  ```

- [ ] Run it — expect **FAIL** (`ModuleNotFoundError: No module named 'models.device_token'` until the models exist; if you wrote models first, run anyway to confirm green):
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_models.py -v
  ```

- [ ] Write the migration `migrations/versions/notif1a2b3c4d_add_push_notifications.py`:
  ```python
  """add push notification tables (device_tokens, notifications, notification_deliveries)

  Revision ID: notif1a2b3c4d
  Revises: schedule1a2b
  Create Date: 2026-06-29

  Hand-written + idempotent (same rationale as appfb1a2b3c4d): the alembic
  env does not see Flask-SQLAlchemy-registered models, so autogenerate is
  unreliable. Written by hand against models/device_token.py,
  models/notification.py, models/notification_delivery.py.
  """
  from alembic import op
  import sqlalchemy as sa
  from sqlalchemy import inspect


  # revision identifiers, used by Alembic.
  revision = "notif1a2b3c4d"
  down_revision = "schedule1a2b"
  branch_labels = None
  depends_on = None


  def upgrade() -> None:
      inspector = inspect(op.get_bind())
      existing = set(inspector.get_table_names())

      if "device_tokens" not in existing:
          op.create_table(
              "device_tokens",
              sa.Column("id", sa.String(length=36), primary_key=True),
              sa.Column(
                  "user_id",
                  sa.String(length=36),
                  sa.ForeignKey("users.id"),
                  nullable=False,
              ),
              sa.Column("token", sa.String(length=512), nullable=False),
              sa.Column("platform", sa.String(length=16), nullable=False),
              sa.Column("timezone", sa.String(length=64), nullable=False),
              sa.Column("app_version", sa.String(length=32), nullable=True),
              sa.Column(
                  "created_at",
                  sa.DateTime(),
                  nullable=False,
                  server_default=sa.func.now(),
              ),
              sa.Column(
                  "last_seen_at",
                  sa.DateTime(),
                  nullable=False,
                  server_default=sa.func.now(),
              ),
          )
          op.create_index(
              "ux_device_tokens_token", "device_tokens", ["token"], unique=True
          )
          op.create_index(
              "idx_device_tokens_user_id", "device_tokens", ["user_id"]
          )

      if "notifications" not in existing:
          op.create_table(
              "notifications",
              sa.Column("id", sa.String(length=36), primary_key=True),
              sa.Column("source", sa.String(length=16), nullable=False),
              sa.Column("type", sa.String(length=32), nullable=False),
              sa.Column("title", sa.String(length=255), nullable=False),
              sa.Column("body", sa.Text(), nullable=False),
              sa.Column("data", sa.JSON(), nullable=False),
              sa.Column("audience", sa.JSON(), nullable=True),
              sa.Column(
                  "created_by",
                  sa.String(length=36),
                  sa.ForeignKey("users.id"),
                  nullable=True,
              ),
              sa.Column("scheduled_for", sa.DateTime(), nullable=True),
              sa.Column(
                  "status",
                  sa.String(length=16),
                  nullable=False,
                  server_default="queued",
              ),
              sa.Column(
                  "created_at",
                  sa.DateTime(),
                  nullable=False,
                  server_default=sa.func.now(),
              ),
              sa.Column("sent_at", sa.DateTime(), nullable=True),
          )

      if "notification_deliveries" not in existing:
          op.create_table(
              "notification_deliveries",
              sa.Column("id", sa.String(length=36), primary_key=True),
              sa.Column(
                  "notification_id",
                  sa.String(length=36),
                  sa.ForeignKey("notifications.id"),
                  nullable=False,
              ),
              sa.Column(
                  "user_id",
                  sa.String(length=36),
                  sa.ForeignKey("users.id"),
                  nullable=False,
              ),
              sa.Column(
                  "status",
                  sa.String(length=16),
                  nullable=False,
                  server_default="pending",
              ),
              sa.Column("read_at", sa.DateTime(), nullable=True),
              sa.Column("error", sa.String(length=255), nullable=True),
              sa.Column(
                  "created_at",
                  sa.DateTime(),
                  nullable=False,
                  server_default=sa.func.now(),
              ),
              sa.Column("sent_at", sa.DateTime(), nullable=True),
          )
          op.create_index(
              "idx_notification_deliveries_notification_id",
              "notification_deliveries",
              ["notification_id"],
          )
          op.create_index(
              "idx_notification_deliveries_user_id",
              "notification_deliveries",
              ["user_id"],
          )


  def downgrade() -> None:
      op.drop_index(
          "idx_notification_deliveries_user_id",
          table_name="notification_deliveries",
      )
      op.drop_index(
          "idx_notification_deliveries_notification_id",
          table_name="notification_deliveries",
      )
      op.drop_table("notification_deliveries")
      op.drop_table("notifications")
      op.drop_index("idx_device_tokens_user_id", table_name="device_tokens")
      op.drop_index("ux_device_tokens_token", table_name="device_tokens")
      op.drop_table("device_tokens")
  ```

- [ ] Verify the migration applies and reverses cleanly (DB already at `schedule1a2b`; this applies only the new revision), then confirm a single head:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m alembic -c migrations/alembic.ini upgrade head      # creates the 3 tables
  python -m alembic -c migrations/alembic.ini heads             # expect: notif1a2b3c4d (head)
  python -m alembic -c migrations/alembic.ini downgrade -1      # drops the 3 tables
  python -m alembic -c migrations/alembic.ini upgrade head      # re-apply, leave at head
  ```
  Expect each command to exit 0 and `heads` to print exactly `notif1a2b3c4d (head)`.

- [ ] Run the model test — expect **PASS**:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_models.py -v
  ```

- [ ] Commit:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git add models/device_token.py models/notification.py models/notification_delivery.py \
          migrations/versions/notif1a2b3c4d_add_push_notifications.py \
          tests/test_notification_models.py tests/conftest.py
  git commit -m "feat: add push notification models + migration (device_tokens, notifications, notification_deliveries)"
  ```

---

## Task 2: device_token_repository

Upsert-by-token (reassigns `user_id`), get-by-user, and delete (unconditional for FCM cleanup + optional user-scoped for the unregister endpoint).

**Files:**
- Create: `repositories/device_token_repository.py`
- Create: `tests/test_device_token_repository.py`

**Interfaces:**
- Consumes: `models.device_token.DeviceToken`.
- Produces (used by `notification_service.deliver` + `routers/notifications.py`):
  ```python
  class DeviceTokenRepository:
      def upsert(self, db, *, user_id, token, platform, timezone, app_version) -> DeviceToken
      def get_by_user(self, db, user_id: str) -> list[DeviceToken]
      def delete_by_token(self, db, token: str, user_id: str | None = None) -> bool
  ```
  `delete_by_token(db, token)` deletes unconditionally (FCM invalid-token cleanup); `delete_by_token(db, token, user_id=...)` deletes only if owned by that user (endpoint, user-scoped). Returns `True` iff a row was deleted. Callers commit.

Steps:

- [ ] Write the failing test `tests/test_device_token_repository.py`:
  ```python
  """DeviceTokenRepository — upsert / get_by_user / delete (in-memory SQLite)."""
  from __future__ import annotations

  import uuid

  from models.device_token import DeviceToken
  from repositories.device_token_repository import DeviceTokenRepository


  def _make_user(db_session):
      from models.user import User

      user = User(
          id=str(uuid.uuid4()),
          email=f"dt-{uuid.uuid4().hex[:8]}@example.com",
          password_hash="argon2-stub",
      )
      db_session.add(user)
      db_session.commit()
      return user


  def test_upsert_inserts_then_reassigns_user(db_session):
      u1 = _make_user(db_session)
      u2 = _make_user(db_session)
      repo = DeviceTokenRepository()

      first = repo.upsert(
          db_session, user_id=u1.id, token="dup", platform="ios",
          timezone="Asia/Saigon", app_version="1.0",
      )
      db_session.commit()
      assert first.user_id == u1.id

      again = repo.upsert(
          db_session, user_id=u2.id, token="dup", platform="ios",
          timezone="Europe/Paris", app_version="1.1",
      )
      db_session.commit()

      assert again.id == first.id  # same row, not a duplicate
      assert again.user_id == u2.id
      assert again.timezone == "Europe/Paris"
      assert again.app_version == "1.1"
      assert db_session.query(DeviceToken).filter_by(token="dup").count() == 1


  def test_get_by_user_returns_all_user_tokens(db_session):
      u = _make_user(db_session)
      repo = DeviceTokenRepository()
      repo.upsert(db_session, user_id=u.id, token="a", platform="ios",
                  timezone="Asia/Saigon", app_version=None)
      repo.upsert(db_session, user_id=u.id, token="b", platform="android",
                  timezone="Asia/Saigon", app_version=None)
      db_session.commit()
      assert {t.token for t in repo.get_by_user(db_session, u.id)} == {"a", "b"}


  def test_delete_by_token_unconditional(db_session):
      u = _make_user(db_session)
      repo = DeviceTokenRepository()
      repo.upsert(db_session, user_id=u.id, token="x", platform="ios",
                  timezone="Asia/Saigon", app_version=None)
      db_session.commit()

      assert repo.delete_by_token(db_session, "x") is True
      db_session.commit()
      assert repo.get_by_user(db_session, u.id) == []
      assert repo.delete_by_token(db_session, "x") is False  # already gone


  def test_delete_by_token_user_scoped(db_session):
      u1 = _make_user(db_session)
      u2 = _make_user(db_session)
      repo = DeviceTokenRepository()
      repo.upsert(db_session, user_id=u1.id, token="owned", platform="ios",
                  timezone="Asia/Saigon", app_version=None)
      db_session.commit()

      # u2 cannot delete u1's token
      assert repo.delete_by_token(db_session, "owned", user_id=u2.id) is False
      db_session.commit()
      # owner can
      assert repo.delete_by_token(db_session, "owned", user_id=u1.id) is True
      db_session.commit()
      assert repo.get_by_user(db_session, u1.id) == []
  ```

- [ ] Run it — expect **FAIL** (`ModuleNotFoundError: No module named 'repositories.device_token_repository'`):
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_device_token_repository.py -v
  ```

- [ ] Write `repositories/device_token_repository.py`:
  ```python
  """DB access layer for device_tokens (push notifications, Phase 0).

  Pure data layer — no business logic, no auth. Callers commit.
  """
  from __future__ import annotations

  from datetime import datetime, timezone
  from typing import List, Optional

  from sqlalchemy import select
  from sqlalchemy.orm import Session

  from models.device_token import DeviceToken


  class DeviceTokenRepository:
      """Encapsulates DB queries for FCM device tokens."""

      def upsert(
          self,
          db: Session,
          *,
          user_id: str,
          token: str,
          platform: str,
          timezone: str,
          app_version: Optional[str],
      ) -> DeviceToken:
          """Insert a new token row, or — if `token` already exists — reassign
          it to `user_id` and refresh platform/timezone/app_version/last_seen_at.

          Token uniqueness is the upsert key so a logout->login on the same
          device moves the token to the new user instead of duplicating it.
          """
          row = db.execute(
              select(DeviceToken).where(DeviceToken.token == token)
          ).scalars().first()

          now = datetime.now(timezone.utc)
          if row is None:
              row = DeviceToken(
                  user_id=user_id,
                  token=token,
                  platform=platform,
                  timezone=timezone,
                  app_version=app_version,
                  created_at=now,
                  last_seen_at=now,
              )
              db.add(row)
          else:
              row.user_id = user_id
              row.platform = platform
              row.timezone = timezone
              row.app_version = app_version
              row.last_seen_at = now
          db.flush()
          return row

      def get_by_user(self, db: Session, user_id: str) -> List[DeviceToken]:
          return list(
              db.execute(
                  select(DeviceToken).where(DeviceToken.user_id == user_id)
              ).scalars().all()
          )

      def delete_by_token(
          self,
          db: Session,
          token: str,
          user_id: Optional[str] = None,
      ) -> bool:
          """Delete the row for `token`. When `user_id` is given, only delete
          if that user owns it (endpoint use, user-scoped). Returns True iff a
          row was deleted. `user_id=None` deletes unconditionally (FCM
          invalid-token cleanup).
          """
          stmt = select(DeviceToken).where(DeviceToken.token == token)
          if user_id is not None:
              stmt = stmt.where(DeviceToken.user_id == user_id)
          row = db.execute(stmt).scalars().first()
          if row is None:
              return False
          db.delete(row)
          db.flush()
          return True
  ```

- [ ] Run the test — expect **PASS**:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_device_token_repository.py -v
  ```

- [ ] Commit:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git add repositories/device_token_repository.py tests/test_device_token_repository.py
  git commit -m "feat: add device_token_repository (upsert/get_by_user/delete)"
  ```

---

## Task 3: notification_repository

Create message rows, create per-recipient delivery rows, fetch by id, and a basic paginated list (the list feeds the Phase 2 admin history).

**Files:**
- Create: `repositories/notification_repository.py`
- Create: `tests/test_notification_repository.py`

**Interfaces:**
- Consumes: `models.notification.Notification`, `models.notification_delivery.NotificationDelivery`.
- Produces (used by `notification_service`):
  ```python
  class NotificationRepository:
      def create_notification(self, db, *, source, type_, title, body, data,
                              audience=None, created_by=None, scheduled_for=None,
                              status="sending") -> Notification
      def create_delivery(self, db, *, notification_id, user_id, status,
                          error=None, sent_at=None) -> NotificationDelivery
      def get(self, db, notification_id: str) -> Notification | None
      def list_notifications(self, db, *, limit=50, offset=0) -> tuple[list[Notification], int]
  ```
  Callers commit. (`type_` keyword trailing-underscore avoids shadowing the builtin and the model attr name `type`.)

Steps:

- [ ] Write the failing test `tests/test_notification_repository.py`:
  ```python
  """NotificationRepository — create / get / list (in-memory SQLite)."""
  from __future__ import annotations

  import uuid

  from models.notification import Notification
  from models.notification_delivery import NotificationDelivery
  from repositories.notification_repository import NotificationRepository


  def _make_user(db_session):
      from models.user import User

      user = User(
          id=str(uuid.uuid4()),
          email=f"nr-{uuid.uuid4().hex[:8]}@example.com",
          password_hash="argon2-stub",
      )
      db_session.add(user)
      db_session.commit()
      return user


  def test_create_notification_defaults(db_session):
      repo = NotificationRepository()
      n = repo.create_notification(
          db_session, source="system", type_="daily_reminder",
          title="T", body="B", data={"kind": "route", "screen": "Home"},
      )
      db_session.commit()
      assert n.id is not None
      assert n.source == "system"
      assert n.type == "daily_reminder"
      assert n.status == "sending"
      assert n.audience is None
      assert n.created_by is None
      assert repo.get(db_session, n.id) is not None


  def test_create_delivery(db_session):
      user = _make_user(db_session)
      repo = NotificationRepository()
      n = repo.create_notification(
          db_session, source="system", type_="daily_reminder",
          title="T", body="B", data={"kind": "route", "screen": "Home"},
      )
      db_session.commit()
      d = repo.create_delivery(
          db_session, notification_id=n.id, user_id=user.id, status="no_token",
      )
      db_session.commit()
      assert d.id is not None
      assert d.status == "no_token"
      got = db_session.get(NotificationDelivery, d.id)
      assert got.notification_id == n.id


  def test_get_missing_returns_none(db_session):
      repo = NotificationRepository()
      assert repo.get(db_session, "nope") is None


  def test_list_notifications_paginates_desc(db_session):
      repo = NotificationRepository()
      for i in range(3):
          repo.create_notification(
              db_session, source="admin", type_="admin_broadcast",
              title=f"msg {i}", body="b", data={"kind": "route", "screen": "Home"},
          )
      db_session.commit()
      rows, total = repo.list_notifications(db_session, limit=2, offset=0)
      assert total == 3
      assert len(rows) == 2
  ```

- [ ] Run it — expect **FAIL** (`ModuleNotFoundError: No module named 'repositories.notification_repository'`):
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_repository.py -v
  ```

- [ ] Write `repositories/notification_repository.py`:
  ```python
  """DB access layer for notifications + deliveries (push, Phase 0).

  Pure data layer — no business logic, no auth. Callers commit.
  """
  from __future__ import annotations

  from datetime import datetime
  from typing import List, Optional, Tuple

  from sqlalchemy import func, select
  from sqlalchemy.orm import Session

  from models.notification import Notification
  from models.notification_delivery import NotificationDelivery


  class NotificationRepository:
      """Encapsulates DB queries for notification messages + deliveries."""

      def create_notification(
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
          scheduled_for: Optional[datetime] = None,
          status: str = "sending",
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
          db.flush()
          return row

      def create_delivery(
          self,
          db: Session,
          *,
          notification_id: str,
          user_id: str,
          status: str,
          error: Optional[str] = None,
          sent_at: Optional[datetime] = None,
      ) -> NotificationDelivery:
          row = NotificationDelivery(
              notification_id=notification_id,
              user_id=user_id,
              status=status,
              error=error,
              sent_at=sent_at,
          )
          db.add(row)
          db.flush()
          return row

      def get(self, db: Session, notification_id: str) -> Optional[Notification]:
          return db.get(Notification, notification_id)

      def list_notifications(
          self,
          db: Session,
          *,
          limit: int = 50,
          offset: int = 0,
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
  ```

- [ ] Run the test — expect **PASS**:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_repository.py -v
  ```

- [ ] Commit:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git add repositories/notification_repository.py tests/test_notification_repository.py
  git commit -m "feat: add notification_repository (create message/delivery, get, list)"
  ```

---

## Task 4: settings + requirements + push_service (FCM)

The mockable FCM abstraction over `firebase-admin`. Folds in the `FIREBASE_CREDENTIALS_JSON` setting and the `firebase-admin` dependency (both needed by this module).

**Files:**
- Modify: `settings.py`, `requirements.txt`
- Create: `services/push_service.py`
- Create: `tests/test_push_service.py`

**Interfaces:**
- Consumes: `settings.FIREBASE_CREDENTIALS_JSON`.
- Produces (match plan.md verbatim — Phase 2 worker + `notification_service.deliver` depend on these):
  ```python
  @dataclass
  class PushResult:
      success_count: int = 0
      failure_count: int = 0
      invalid_tokens: list[str] = []   # field(default_factory=list)
  def init_firebase() -> None                       # idempotent; reads settings.FIREBASE_CREDENTIALS_JSON
  def send_to_tokens(tokens: list[str], title: str, body: str, data: dict[str, str]) -> PushResult
  ```
  FCM `NOT_REGISTERED` / `UNREGISTERED` → `PushResult.invalid_tokens`. Multicast batched at 500/req. The real FCM call is isolated in `_send_multicast(...)` (single monkeypatchable seam) so the batching/aggregation logic is testable without firebase installed.

Steps:

- [ ] Add the setting to `settings.py` — insert after the Gemini block (after the `GEMINI_JOB_TTL_HOURS` line, before the recommendation-judge block):
  ```python
      # Firebase Cloud Messaging (push notifications)
      # Service-account JSON (stringified). Set via Railway env on the backend
      # AND the notification-worker service. Empty = push disabled (dev/test).
      FIREBASE_CREDENTIALS_JSON: str = ""
  ```

- [ ] Add the dependency to `requirements.txt` (append near the other service SDKs, e.g. right before `psycopg2-binary>=2.9.9`):
  ```
  firebase-admin>=6.5.0       # FCM push notifications (HTTP v1)
  ```
  Then install it into the active venv:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  pip install "firebase-admin>=6.5.0"
  ```

- [ ] Write the failing test `tests/test_push_service.py`:
  ```python
  """push_service — batching + invalid-token flagging, firebase fully mocked."""
  from __future__ import annotations

  import services.push_service as ps
  from services.push_service import PushResult


  def test_pushresult_defaults():
      r = PushResult()
      assert r.success_count == 0
      assert r.failure_count == 0
      assert r.invalid_tokens == []


  def test_send_to_tokens_empty_is_noop():
      r = ps.send_to_tokens([], "T", "B", {})
      assert (r.success_count, r.failure_count, r.invalid_tokens) == (0, 0, [])


  def test_send_to_tokens_unconfigured_marks_all_failed(monkeypatch):
      monkeypatch.setattr(ps.settings, "FIREBASE_CREDENTIALS_JSON", "", raising=False)
      monkeypatch.setattr(ps, "init_firebase", lambda: None)
      r = ps.send_to_tokens(["a", "b"], "T", "B", {})
      assert r.success_count == 0
      assert r.failure_count == 2
      assert r.invalid_tokens == []


  def test_send_to_tokens_aggregates_and_flags_invalid(monkeypatch):
      monkeypatch.setattr(ps.settings, "FIREBASE_CREDENTIALS_JSON", "{}", raising=False)
      monkeypatch.setattr(ps, "init_firebase", lambda: None)

      def fake_send(batch, title, body, data):
          # second token in the batch is reported invalid by FCM
          invalid = [batch[1]] if len(batch) > 1 else []
          return (len(batch) - len(invalid), len(invalid), invalid)

      monkeypatch.setattr(ps, "_send_multicast", fake_send)
      r = ps.send_to_tokens(["tokA", "tokB", "tokC"], "T", "B",
                            {"kind": "route", "screen": "Home"})
      assert r.success_count == 2
      assert r.failure_count == 1
      assert r.invalid_tokens == ["tokB"]


  def test_send_to_tokens_batches_over_500(monkeypatch):
      monkeypatch.setattr(ps.settings, "FIREBASE_CREDENTIALS_JSON", "{}", raising=False)
      monkeypatch.setattr(ps, "init_firebase", lambda: None)
      seen_batches = []

      def fake_send(batch, title, body, data):
          seen_batches.append(len(batch))
          return (len(batch), 0, [])

      monkeypatch.setattr(ps, "_send_multicast", fake_send)
      tokens = [f"t{i}" for i in range(1100)]
      r = ps.send_to_tokens(tokens, "T", "B", {})
      assert r.success_count == 1100
      assert seen_batches == [500, 500, 100]


  def test_is_invalid_token_error_maps_fcm_codes():
      class _Exc:
          def __init__(self, code):
              self.code = code

      assert ps._is_invalid_token_error(_Exc("NOT_REGISTERED")) is True
      assert ps._is_invalid_token_error(_Exc("UNREGISTERED")) is True
      assert ps._is_invalid_token_error(_Exc("registration-token-not-registered")) is True
      assert ps._is_invalid_token_error(_Exc("INTERNAL")) is False
      assert ps._is_invalid_token_error(None) is False


  def test_init_firebase_idempotent_without_creds(monkeypatch):
      # No creds -> init must not raise and must be safe to call twice.
      monkeypatch.setattr(ps, "_initialized", False, raising=False)
      monkeypatch.setattr(ps.settings, "FIREBASE_CREDENTIALS_JSON", "", raising=False)
      ps.init_firebase()
      ps.init_firebase()
  ```

- [ ] Run it — expect **FAIL** (`ModuleNotFoundError: No module named 'services.push_service'`):
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_push_service.py -v
  ```

- [ ] Write `services/push_service.py`:
  ```python
  """Thin FCM abstraction over firebase-admin (HTTP v1) — push, Phase 0.

  Isolated so it is mockable in tests and swappable later. The actual FCM
  call is confined to `_send_multicast`; `send_to_tokens` only batches and
  aggregates, so the logic is testable without firebase installed.
  """
  from __future__ import annotations

  import json
  import logging
  import threading
  from dataclasses import dataclass, field
  from typing import List, Optional, Tuple

  from settings import settings

  logger = logging.getLogger(__name__)

  # FCM multicast hard cap per request.
  _FCM_BATCH_SIZE = 500

  # FCM error identifiers that mean "this token is dead, delete it".
  _INVALID_TOKEN_CODES = {
      "NOT_REGISTERED",
      "UNREGISTERED",
      "REGISTRATION_TOKEN_NOT_REGISTERED",
  }

  _initialized = False
  _init_lock = threading.Lock()


  @dataclass
  class PushResult:
      success_count: int = 0
      failure_count: int = 0
      invalid_tokens: List[str] = field(default_factory=list)


  def init_firebase() -> None:
      """Initialize the firebase-admin app once. Idempotent; no-op (with a
      warning) when FIREBASE_CREDENTIALS_JSON is unset so dev/test never crash.
      """
      global _initialized
      if _initialized:
          return
      with _init_lock:
          if _initialized:
              return
          raw = settings.FIREBASE_CREDENTIALS_JSON
          if not raw:
              logger.warning(
                  "FIREBASE_CREDENTIALS_JSON unset — push notifications disabled"
              )
              _initialized = True
              return
          import firebase_admin
          from firebase_admin import credentials

          if not firebase_admin._apps:
              cred = credentials.Certificate(json.loads(raw))
              firebase_admin.initialize_app(cred)
          _initialized = True
          logger.info("firebase-admin initialised for FCM push")


  def _is_invalid_token_error(exc: Optional[Exception]) -> bool:
      """True if an FCM per-message exception means the token is unregistered."""
      if exc is None:
          return False
      if type(exc).__name__ == "UnregisteredError":
          return True
      code = getattr(exc, "code", "") or ""
      normalized = str(code).upper().replace("-", "_")
      return normalized in _INVALID_TOKEN_CODES


  def _send_multicast(
      batch: List[str], title: str, body: str, data: dict
  ) -> Tuple[int, int, List[str]]:
      """Send ONE <=500 batch via FCM. Returns (success, failure, invalid_tokens).

      This is the only firebase-touching function — monkeypatch it in tests.
      """
      from firebase_admin import messaging

      message = messaging.MulticastMessage(
          tokens=batch,
          notification=messaging.Notification(title=title, body=body),
          data=data,
      )
      resp = messaging.send_each_for_multicast(message)
      invalid = [
          batch[i]
          for i, r in enumerate(resp.responses)
          if not r.success and _is_invalid_token_error(r.exception)
      ]
      return resp.success_count, resp.failure_count, invalid


  def send_to_tokens(
      tokens: List[str], title: str, body: str, data: dict
  ) -> PushResult:
      """Multicast a notification to many tokens (batched at 500/req).

      Returns aggregate counts + the list of tokens FCM reports as invalid
      (caller deletes them). When firebase is unconfigured, marks everything
      failed without flagging tokens invalid (config issue, not a dead token).
      """
      result = PushResult()
      if not tokens:
          return result
      init_firebase()
      if not settings.FIREBASE_CREDENTIALS_JSON:
          result.failure_count = len(tokens)
          return result

      safe_data = {str(k): str(v) for k, v in (data or {}).items()}
      for start in range(0, len(tokens), _FCM_BATCH_SIZE):
          batch = tokens[start:start + _FCM_BATCH_SIZE]
          try:
              success, failure, invalid = _send_multicast(
                  batch, title, body, safe_data
              )
          except Exception as exc:  # network / FCM outage — whole batch fails
              logger.exception("FCM multicast batch failed: %s", exc)
              result.failure_count += len(batch)
              continue
          result.success_count += success
          result.failure_count += failure
          result.invalid_tokens.extend(invalid)
      return result
  ```

- [ ] Run the test — expect **PASS**:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_push_service.py -v
  ```

- [ ] Commit:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git add settings.py requirements.txt services/push_service.py tests/test_push_service.py
  git commit -m "feat: add push_service (FCM via firebase-admin) + FIREBASE_CREDENTIALS_JSON setting"
  ```

---

## Task 5: notification_service (create_system_notification + deliver)

The Phase 0 portion of the orchestration service: create a system notification row, and the consumer-side `deliver(db, job)` that loads a user's tokens, pushes, writes deliveries, and cleans up invalid tokens. `enqueue` / `resolve_audience` are referenced as Phase 2 — NOT implemented here.

**Files:**
- Create: `services/notification_service.py`
- Create: `tests/test_notification_service.py`

**Interfaces:**
- Consumes: `repositories.device_token_repository.DeviceTokenRepository`, `repositories.notification_repository.NotificationRepository`, `services.push_service` (+ `PushResult`).
- Produces (match plan.md verbatim):
  ```python
  def create_system_notification(db, type_: str, title: str, body: str, data: dict) -> Notification   # P0
  def deliver(db, job: dict) -> None                                                                   # P0
  # def resolve_audience(db, audience: dict) -> list[str]   # P2 — NOT in this phase
  # def enqueue(db, notification_id: str) -> int            # P2 — NOT in this phase
  ```
  Job shape (Phase 2 producer → this consumer):
  ```json
  {"notification_id":"<uuid>","type":"<type>","user_id":"<uuid>","local_date":"YYYY-MM-DD","payload":{"kind":"route","screen":"Home"}}
  ```
  `deliver` uses `notification_id` + `user_id` + `payload`; `type`/`local_date` are carried for Phase 2 dedup and unused here. `deliver` writes ONE delivery row per (notification, user): `no_token` if the user has no tokens, `sent` if `success_count > 0`, else `failed`. Callers commit.

Steps:

- [ ] Write the failing test `tests/test_notification_service.py`:
  ```python
  """notification_service — create_system_notification + deliver (push_service mocked)."""
  from __future__ import annotations

  import uuid

  import services.notification_service as ns
  from models.device_token import DeviceToken
  from models.notification_delivery import NotificationDelivery
  from repositories.device_token_repository import DeviceTokenRepository
  from services.push_service import PushResult


  def _make_user(db_session):
      from models.user import User

      user = User(
          id=str(uuid.uuid4()),
          email=f"nsvc-{uuid.uuid4().hex[:8]}@example.com",
          password_hash="argon2-stub",
      )
      db_session.add(user)
      db_session.commit()
      return user


  def _job(notification_id, user_id):
      return {
          "notification_id": notification_id,
          "type": "daily_reminder",
          "user_id": user_id,
          "local_date": "2026-06-29",
          "payload": {"kind": "route", "screen": "Home"},
      }


  def test_create_system_notification(db_session):
      n = ns.create_system_notification(
          db_session, type_="daily_reminder", title="T", body="B",
          data={"kind": "route", "screen": "Home"},
      )
      db_session.commit()
      assert n.source == "system"
      assert n.type == "daily_reminder"
      assert n.status == "sending"
      assert n.created_by is None
      assert n.audience is None


  def test_deliver_sent_path(db_session, monkeypatch):
      user = _make_user(db_session)
      DeviceTokenRepository().upsert(
          db_session, user_id=user.id, token="tok1", platform="ios",
          timezone="Asia/Saigon", app_version=None,
      )
      n = ns.create_system_notification(
          db_session, type_="daily_reminder", title="T", body="B",
          data={"kind": "route", "screen": "Home"},
      )
      db_session.commit()

      monkeypatch.setattr(
          ns.push_service, "send_to_tokens",
          lambda tokens, title, body, data: PushResult(
              success_count=1, failure_count=0, invalid_tokens=[]
          ),
      )
      ns.deliver(db_session, _job(n.id, user.id))
      db_session.commit()

      deliveries = (
          db_session.query(NotificationDelivery)
          .filter_by(notification_id=n.id).all()
      )
      assert len(deliveries) == 1
      assert deliveries[0].status == "sent"
      assert deliveries[0].sent_at is not None


  def test_deliver_no_token_path(db_session, monkeypatch):
      user = _make_user(db_session)  # no token registered
      n = ns.create_system_notification(
          db_session, type_="daily_reminder", title="T", body="B",
          data={"kind": "route", "screen": "Home"},
      )
      db_session.commit()

      calls = {"n": 0}

      def _spy(*a, **k):
          calls["n"] += 1
          return PushResult()

      monkeypatch.setattr(ns.push_service, "send_to_tokens", _spy)
      ns.deliver(db_session, _job(n.id, user.id))
      db_session.commit()

      d = (
          db_session.query(NotificationDelivery)
          .filter_by(notification_id=n.id).one()
      )
      assert d.status == "no_token"
      assert calls["n"] == 0  # never call FCM when there are no tokens


  def test_deliver_invalid_token_cleanup(db_session, monkeypatch):
      user = _make_user(db_session)
      DeviceTokenRepository().upsert(
          db_session, user_id=user.id, token="bad", platform="android",
          timezone="Asia/Saigon", app_version=None,
      )
      n = ns.create_system_notification(
          db_session, type_="daily_reminder", title="T", body="B",
          data={"kind": "route", "screen": "Home"},
      )
      db_session.commit()

      monkeypatch.setattr(
          ns.push_service, "send_to_tokens",
          lambda tokens, title, body, data: PushResult(
              success_count=0, failure_count=1, invalid_tokens=["bad"]
          ),
      )
      ns.deliver(db_session, _job(n.id, user.id))
      db_session.commit()

      assert db_session.query(DeviceToken).filter_by(token="bad").first() is None
      d = (
          db_session.query(NotificationDelivery)
          .filter_by(notification_id=n.id).one()
      )
      assert d.status == "failed"
      assert d.error == "all_failed"


  def test_deliver_missing_notification_is_noop(db_session):
      user = _make_user(db_session)
      # notification_id points at nothing -> no crash, no delivery row written
      ns.deliver(db_session, _job("does-not-exist", user.id))
      db_session.commit()
      assert db_session.query(NotificationDelivery).count() == 0
  ```

- [ ] Run it — expect **FAIL** (`ModuleNotFoundError: No module named 'services.notification_service'`):
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_service.py -v
  ```

- [ ] Write `services/notification_service.py`:
  ```python
  """Notification orchestration service — push notifications.

  Phase 0 implements the consumer half:
    - create_system_notification: persist a system message row.
    - deliver: load a user's device tokens, push via push_service, write a
      per-recipient delivery row, and delete tokens FCM reports as invalid.

  Phase 2 adds the producer half (resolve_audience + enqueue onto the Redis
  notification_queue, reusing services/queue_service.py).

  Callers (worker / router) own the commit.
  """
  from __future__ import annotations

  import logging
  from datetime import datetime, timezone

  from sqlalchemy.orm import Session

  from models.notification import Notification
  from repositories.device_token_repository import DeviceTokenRepository
  from repositories.notification_repository import NotificationRepository
  from services import push_service

  logger = logging.getLogger(__name__)

  _device_token_repo = DeviceTokenRepository()
  _notification_repo = NotificationRepository()


  def create_system_notification(
      db: Session,
      type_: str,
      title: str,
      body: str,
      data: dict,
  ) -> Notification:
      """Persist a system-sourced notification (source='system', no admin,
      no audience). Status starts at 'sending' — the Phase 2/3 worker advances
      it. Returns the created row (caller commits).
      """
      return _notification_repo.create_notification(
          db,
          source="system",
          type_=type_,
          title=title,
          body=body,
          data=data,
          audience=None,
          created_by=None,
          scheduled_for=None,
          status="sending",
      )


  def deliver(db: Session, job: dict) -> None:
      """Consumer entry point: deliver one per-user job.

      Loads the notification + the user's device tokens, pushes via FCM,
      writes a single NotificationDelivery row, and deletes any tokens FCM
      reports invalid. No-ops (no crash) if the notification is gone.
      """
      notification_id = job["notification_id"]
      user_id = job["user_id"]

      notification = _notification_repo.get(db, notification_id)
      if notification is None:
          logger.warning(
              "deliver: notification %s not found — skipping", notification_id
          )
          return

      tokens = [t.token for t in _device_token_repo.get_by_user(db, user_id)]
      if not tokens:
          _notification_repo.create_delivery(
              db,
              notification_id=notification_id,
              user_id=user_id,
              status="no_token",
          )
          return

      data = job.get("payload") or notification.data or {}
      result = push_service.send_to_tokens(
          tokens, notification.title, notification.body, data
      )

      # Clean up tokens FCM flagged as dead.
      for dead in result.invalid_tokens:
          _device_token_repo.delete_by_token(db, dead)

      if result.success_count > 0:
          _notification_repo.create_delivery(
              db,
              notification_id=notification_id,
              user_id=user_id,
              status="sent",
              sent_at=datetime.now(timezone.utc),
          )
      else:
          _notification_repo.create_delivery(
              db,
              notification_id=notification_id,
              user_id=user_id,
              status="failed",
              error="all_failed",
          )
  ```

- [ ] Run the test — expect **PASS**:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_service.py -v
  ```

- [ ] Commit:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git add services/notification_service.py tests/test_notification_service.py
  git commit -m "feat: add notification_service.create_system_notification + deliver (P0 consumer half)"
  ```

---

## Task 6: device-token endpoints (router + schemas + registration)

User-facing register / unregister endpoints, rate-limited like the `app_feedback` router, registered in `app.py`.

**Files:**
- Create: `schemas/notification.py`, `routers/notifications.py`
- Create: `tests/test_notifications_router.py`
- Modify: `routers/__init__.py`, `app.py`

**Interfaces:**
- Consumes: `repositories.device_token_repository.DeviceTokenRepository`, `deps.auth.get_current_user`, `deps.database.get_db`, `utils.rate_limiter.get_rate_limiter`, `settings`.
- Produces (match plan.md verbatim):
  ```
  POST   /api/notifications/device-token   {token,platform,timezone,app_version?} -> 200 {ok:true}   (user)
  DELETE /api/notifications/device-token   {token} -> 200 {ok:true}                                   (user)
  ```
  POST upserts. DELETE is user-scoped and **idempotent → always 200 {ok:true}** (never reveals whether the token existed or who owned it — this is how "404 hides ownership" from spec §6 is reconciled with the locked 200 contract). Rate limit 20/min per user (mirrors the `app_feedback` limiter pattern; schedule/creations use the same `get_rate_limiter` helper).

Steps:

- [ ] Write `schemas/notification.py`:
  ```python
  """Pydantic schemas for the user-facing device-token endpoints (push, P0)."""
  from __future__ import annotations

  from typing import Optional

  from pydantic import BaseModel, Field, field_validator

  from models.device_token import DEVICE_PLATFORMS


  class DeviceTokenRegisterRequest(BaseModel):
      """Body for POST /api/notifications/device-token."""

      token: str = Field(..., min_length=1, max_length=512)
      platform: str
      timezone: str = Field(..., min_length=1, max_length=64)
      app_version: Optional[str] = Field(default=None, max_length=32)

      @field_validator("platform")
      @classmethod
      def _validate_platform(cls, v: str) -> str:
          if v not in DEVICE_PLATFORMS:
              raise ValueError(
                  f"invalid platform: {v}. Allowed: {list(DEVICE_PLATFORMS)}"
              )
          return v

      @field_validator("token", "timezone")
      @classmethod
      def _strip_required(cls, v: str) -> str:
          trimmed = v.strip()
          if not trimmed:
              raise ValueError("must not be blank")
          return trimmed


  class DeviceTokenDeleteRequest(BaseModel):
      """Body for DELETE /api/notifications/device-token."""

      token: str = Field(..., min_length=1, max_length=512)

      @field_validator("token")
      @classmethod
      def _strip_token(cls, v: str) -> str:
          trimmed = v.strip()
          if not trimmed:
              raise ValueError("must not be blank")
          return trimmed


  class OkResponse(BaseModel):
      """Uniform {ok: true} envelope."""

      ok: bool = True
  ```

- [ ] Write the failing test `tests/test_notifications_router.py`:
  ```python
  """User device-token endpoints — auth, upsert, idempotent delete.

  Mirrors tests/test_app_feedback_router.py: a fresh FastAPI app with
  dependency_overrides on a thread-safe SQLite DB.
  """
  from __future__ import annotations

  import os
  import tempfile
  import uuid

  import pytest
  from fastapi import FastAPI
  from fastapi.testclient import TestClient
  from sqlalchemy import create_engine
  from sqlalchemy.orm import sessionmaker


  @pytest.fixture
  def threaded_db():
      from models import (  # noqa: F401
          wardrobe, user, token, auth_token, body, favorite, tryon, decision,
          recommendation_log, v05_event, recommendation_feedback, app_feedback,
          device_token, notification, notification_delivery,
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


  def _make_user(session):
      from models.user import User

      user = User(
          id=str(uuid.uuid4()),
          email=f"u-{uuid.uuid4().hex[:8]}@example.com",
          password_hash="argon2-stub",
      )
      session.add(user)
      session.commit()
      return user


  def _app(get_db_dep, user=None):
      from routers.notifications import router
      from deps.auth import get_current_user
      from deps.database import get_db

      test_app = FastAPI()
      test_app.include_router(router)
      test_app.dependency_overrides[get_db] = get_db_dep
      if user is not None:
          test_app.dependency_overrides[get_current_user] = lambda: user
      return test_app


  def test_register_requires_auth_401(threaded_db):
      main, get_db_dep = threaded_db
      client = TestClient(_app(get_db_dep, user=None))
      resp = client.post("/api/notifications/device-token", json={
          "token": "t", "platform": "ios", "timezone": "Asia/Saigon",
      })
      assert resp.status_code == 401


  def test_register_happy_path_200(threaded_db):
      main, get_db_dep = threaded_db
      user = _make_user(main)
      client = TestClient(_app(get_db_dep, user))
      resp = client.post("/api/notifications/device-token", json={
          "token": "fcm-1", "platform": "ios",
          "timezone": "Asia/Saigon", "app_version": "1.0-build8",
      })
      assert resp.status_code == 200, resp.text
      assert resp.json() == {"ok": True}

      from models.device_token import DeviceToken
      assert main.query(DeviceToken).filter_by(token="fcm-1").count() == 1


  def test_register_invalid_platform_422(threaded_db):
      main, get_db_dep = threaded_db
      user = _make_user(main)
      client = TestClient(_app(get_db_dep, user))
      resp = client.post("/api/notifications/device-token", json={
          "token": "fcm-1", "platform": "windows", "timezone": "Asia/Saigon",
      })
      assert resp.status_code == 422


  def test_register_upsert_reassigns_user(threaded_db):
      main, get_db_dep = threaded_db
      u1 = _make_user(main)
      u2 = _make_user(main)

      client1 = TestClient(_app(get_db_dep, u1))
      client1.post("/api/notifications/device-token", json={
          "token": "shared", "platform": "ios", "timezone": "Asia/Saigon",
      })
      client2 = TestClient(_app(get_db_dep, u2))
      resp = client2.post("/api/notifications/device-token", json={
          "token": "shared", "platform": "ios", "timezone": "Europe/Paris",
      })
      assert resp.status_code == 200

      from models.device_token import DeviceToken
      rows = main.query(DeviceToken).filter_by(token="shared").all()
      assert len(rows) == 1
      assert rows[0].user_id == u2.id
      assert rows[0].timezone == "Europe/Paris"


  def test_delete_requires_auth_401(threaded_db):
      main, get_db_dep = threaded_db
      client = TestClient(_app(get_db_dep, user=None))
      resp = client.request(
          "DELETE", "/api/notifications/device-token", json={"token": "t"}
      )
      assert resp.status_code == 401


  def test_delete_removes_own_token_200(threaded_db):
      main, get_db_dep = threaded_db
      user = _make_user(main)
      client = TestClient(_app(get_db_dep, user))
      client.post("/api/notifications/device-token", json={
          "token": "del-me", "platform": "ios", "timezone": "Asia/Saigon",
      })
      resp = client.request(
          "DELETE", "/api/notifications/device-token", json={"token": "del-me"}
      )
      assert resp.status_code == 200
      assert resp.json() == {"ok": True}

      from models.device_token import DeviceToken
      assert main.query(DeviceToken).filter_by(token="del-me").count() == 0


  def test_delete_unknown_token_is_idempotent_200(threaded_db):
      main, get_db_dep = threaded_db
      user = _make_user(main)
      client = TestClient(_app(get_db_dep, user))
      resp = client.request(
          "DELETE", "/api/notifications/device-token", json={"token": "ghost"}
      )
      # idempotent + hides ownership: always 200 {ok:true}, never 404
      assert resp.status_code == 200
      assert resp.json() == {"ok": True}
  ```

- [ ] Run it — expect **FAIL** (`ModuleNotFoundError: No module named 'routers.notifications'`):
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notifications_router.py -v
  ```

- [ ] Write `routers/notifications.py`:
  ```python
  """User-facing push notification endpoints (Phase 0).

  POST/DELETE /api/notifications/device-token — register / unregister an FCM
  device token. Authed, user-scoped, rate-limited 20/min per user (mirrors
  routers/app_feedback.py). DELETE is idempotent (always 200 {ok:true}); it
  is user-scoped so it never deletes another user's token and never reveals
  whether the token existed.
  """
  from __future__ import annotations

  import logging

  from fastapi import APIRouter, Depends, HTTPException, Request, status
  from sqlalchemy.orm import Session

  from deps.auth import get_current_user
  from deps.database import get_db
  from models.user import User
  from repositories.device_token_repository import DeviceTokenRepository
  from schemas.notification import (
      DeviceTokenDeleteRequest,
      DeviceTokenRegisterRequest,
      OkResponse,
  )
  from settings import settings
  from utils.rate_limiter import get_rate_limiter

  logger = logging.getLogger(__name__)

  router = APIRouter(prefix="/api/notifications", tags=["Notifications"])

  _repo = DeviceTokenRepository()

  # Token registration fires on login + token refresh — 20/min is generous
  # for a human and blocks scripted abuse.
  _RATE_LIMIT_PER_MIN = 20


  def _enforce_rate_limit(user: User) -> None:
      if not getattr(settings, "RATE_LIMIT_ENABLED", False):
          return
      limiter = get_rate_limiter(_RATE_LIMIT_PER_MIN)
      key = str(user.id)
      is_allowed, _ = limiter.check_rate_limit(key)
      if not is_allowed:
          retry_after = limiter.get_retry_after(key)
          raise HTTPException(
              status_code=status.HTTP_429_TOO_MANY_REQUESTS,
              detail={"error": "Rate limit exceeded", "retry_after": retry_after},
          )


  @router.post(
      "/device-token",
      response_model=OkResponse,
      summary="Register / refresh an FCM device token",
  )
  def register_device_token(
      request: Request,
      body: DeviceTokenRegisterRequest,
      user: User = Depends(get_current_user),
      db: Session = Depends(get_db),
  ) -> OkResponse:
      """Upsert the caller's FCM device token (reassigns on logout->login)."""
      _enforce_rate_limit(user)
      try:
          _repo.upsert(
              db,
              user_id=str(user.id),
              token=body.token,
              platform=body.platform,
              timezone=body.timezone,
              app_version=body.app_version,
          )
          db.commit()
          return OkResponse(ok=True)
      except HTTPException:
          raise
      except Exception:
          db.rollback()
          logger.exception("device-token register failed")
          raise HTTPException(
              status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
              detail={"error": "Failed to register device token"},
          )


  @router.delete(
      "/device-token",
      response_model=OkResponse,
      summary="Unregister an FCM device token (logout)",
  )
  def delete_device_token(
      request: Request,
      body: DeviceTokenDeleteRequest,
      user: User = Depends(get_current_user),
      db: Session = Depends(get_db),
  ) -> OkResponse:
      """Remove the caller's FCM device token. Idempotent + user-scoped:
      always returns 200 {ok:true}, never deletes another user's token, never
      reveals whether the token existed.
      """
      _enforce_rate_limit(user)
      try:
          _repo.delete_by_token(db, body.token, user_id=str(user.id))
          db.commit()
          return OkResponse(ok=True)
      except HTTPException:
          raise
      except Exception:
          db.rollback()
          logger.exception("device-token delete failed")
          raise HTTPException(
              status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
              detail={"error": "Failed to delete device token"},
          )
  ```

- [ ] Register the router in `routers/__init__.py` — add the import after the `app_feedback_router` line and add it to `__all__`:
  ```python
  from routers.notifications import router as notifications_router
  ```
  and add `"notifications_router",` to the `__all__` list.

- [ ] Register in `app.py` — add `notifications_router` to the `from routers import (...)` tuple (after `app_feedback_router,`), then add the include near the other feature routers (e.g. after the App Feedback include):
  ```python
  # Push Notifications (Phase 0 — device-token register/unregister)
  app.include_router(notifications_router)
  ```

- [ ] Run the router test — expect **PASS**:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notifications_router.py -v
  ```

- [ ] Run the full Phase 0 test set to confirm nothing regressed:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_models.py tests/test_device_token_repository.py \
      tests/test_notification_repository.py tests/test_push_service.py \
      tests/test_notification_service.py tests/test_notifications_router.py -v
  ```

- [ ] Commit:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git add schemas/notification.py routers/notifications.py routers/__init__.py app.py \
          tests/test_notifications_router.py
  git commit -m "feat: add device-token register/unregister endpoints (/api/notifications/device-token)"
  ```

---

## Task 7: API documentation

Document the two new public routes in the mandatory contract doc.

**Files:**
- Modify: `API_DOCUMENTATION.md`

**Interfaces:** none (doc only) — the doc IS the cross-repo contract (no shared SDK), so Phase 1 mobile syncs `auxi/src/services/notificationService.ts` against it.

Steps:

- [ ] Add a new `## Push Notifications` section to `API_DOCUMENTATION.md`. Insert it right **before** the `## Admin Interface` section (line ~2275, after the recommendation sections), matching the existing format (see "Reset User Preferences" at line ~667 as the template):
  ```markdown
  ## Push Notifications

  User-facing endpoints to register / unregister an FCM device token for push
  notifications. The token + IANA timezone are stored server-side; the timezone
  is the source of truth for the daily-reminder scheduler. Tokens are never
  returned to clients. (Admin compose/send + history endpoints arrive in
  Phase 2 under `/api/admin/notifications` — internal, not part of this public
  contract.)

  ### Register Device Token

  #### `POST /api/notifications/device-token`

  Register or refresh the caller's FCM device token. Upserts on `token`: if the
  token already exists it is reassigned to the current user (handles
  logout->login on the same device) and its timezone / app_version / last-seen
  are refreshed.

  **Authentication:** Required (`Authorization: Bearer <access_token>`)

  **Rate Limit:** 20 requests/minute per user

  **Request** (JSON):

  ```json
  {
    "token": "string - FCM registration token (required)",
    "platform": "string - 'ios' | 'android' (required)",
    "timezone": "string - IANA tz, e.g. 'Asia/Saigon' (required)",
    "app_version": "string - optional, diagnostics"
  }
  ```

  **Response (200 OK):**

  ```json
  { "ok": true }
  ```

  **Errors:**

  - `401 Unauthorized` - Missing/invalid access token
  - `422 Unprocessable Entity` - Invalid body (bad/blank token, platform not ios|android, blank timezone)
  - `429 Too Many Requests` - Rate limit exceeded
  - `500 Internal Server Error` - DB write failed

  ---

  ### Unregister Device Token

  #### `DELETE /api/notifications/device-token`

  Remove the caller's FCM device token on logout. Idempotent and user-scoped:
  it only deletes a token owned by the caller and always returns `200 {ok:true}`
  whether or not the token existed (never reveals existence or ownership).

  **Authentication:** Required (`Authorization: Bearer <access_token>`)

  **Rate Limit:** 20 requests/minute per user

  **Request** (JSON):

  ```json
  { "token": "string - FCM registration token to remove (required)" }
  ```

  **Response (200 OK):**

  ```json
  { "ok": true }
  ```

  **Errors:**

  - `401 Unauthorized` - Missing/invalid access token
  - `422 Unprocessable Entity` - Invalid body (blank token)
  - `429 Too Many Requests` - Rate limit exceeded
  - `500 Internal Server Error` - DB write failed

  ---
  ```

- [ ] Commit:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  git add API_DOCUMENTATION.md
  git commit -m "docs: document /api/notifications/device-token register + unregister"
  ```

---

## Phase 0 Done When

- [ ] `python -m alembic -c migrations/alembic.ini heads` prints exactly `notif1a2b3c4d (head)` (single head; `down_revision = schedule1a2b`).
- [ ] Migration up → down → up is clean: `upgrade head` creates `device_tokens` + `notifications` + `notification_deliveries` (with `ux_device_tokens_token` unique + the 3 fk indexes); `downgrade -1` drops all three; re-`upgrade head` succeeds.
- [ ] All six Phase 0 test files pass:
  ```bash
  cd /Users/nguyenminhduc/dev/wardrobe_project/wardrobe-backend
  python -m pytest tests/test_notification_models.py tests/test_device_token_repository.py \
      tests/test_notification_repository.py tests/test_push_service.py \
      tests/test_notification_service.py tests/test_notifications_router.py -v
  ```
- [ ] `python test_server.py` passes (full e2e on :5002 — confirms app boots with the new router registered, no import errors).
- [ ] Endpoints behave: `POST /api/notifications/device-token` without a token → 401; with auth + valid body → 200 `{ok:true}` and a row exists; re-POST same token as a different user reassigns it (no duplicate row); `DELETE` own token → 200 `{ok:true}` and row gone; `DELETE` unknown token → 200 `{ok:true}` (idempotent).
- [ ] `API_DOCUMENTATION.md` has the `## Push Notifications` section with both routes.
- [ ] Locked interfaces match plan.md verbatim: model columns/statuses, `PushResult(success_count, failure_count, invalid_tokens)`, `init_firebase()`, `send_to_tokens(tokens,title,body,data)`, `create_system_notification(db,type_,title,body,data)`, `deliver(db,job)`, the job shape, and the two HTTP routes returning `{ok:true}`.

## Notes

- **Real-device push verification is deferred to manual QA** — iOS simulator push is unreliable; FCM delivery is verified on a real device during Phase 1 QA, not here. Phase 0 proves the data model, the FCM abstraction (firebase mocked), the delivery logic (push_service mocked), and the endpoints.
- **`FIREBASE_CREDENTIALS_JSON` is an ops prerequisite** (devops): the service-account JSON must be set on the backend AND the Phase 3 `notification-worker` Railway services. Unset → `push_service` no-ops with a warning and `deliver` records `failed` deliveries; it never crashes, so Phase 0 ships and tests pass without it.
- **Stale-checkout caveat:** at authoring time both local checkouts (`dev/` and `Desktop/`) were on `feature/au318-mood-feedback` with two alembic heads and no `schedule`/`creations` modules. Implement on the up-to-date `auxi-backend` `main` (where `schedule1a2b` is the single head); re-verify the head in Task 1 step 1 before writing the migration.
- **Out of scope (referenced, not built):** `resolve_audience` + `enqueue` (Phase 2 producer), the Redis `notification_queue` + `notification_worker.py` consumer loop (Phase 2), admin `/api/admin/notifications/*` endpoints (Phase 2), the APScheduler engine + dedup `(user, slot, local_date)` + retention (Phase 3), and the `read_at`-based inbox (Phase 4).
