# Phase 3: Scheduler / Reminder Engine

> **Repo:** `wardrobe-backend` · **Spec:** [`spec.md`](./spec.md) §10, §13 · **Plan:** [`plan.md`](./plan.md) (Global Constraints + Locked interfaces)
> **For agentic workers:** implement task-by-task (superpowers:subagent-driven-development). Each task is TDD: write the failing test → run `pytest -v` (expect FAIL) → implement → re-run (PASS) → commit.

**Goal:** Add the APScheduler **producer** that decides *when* reminders fire. Every ~15 min it selects users whose local time matches their `daily_notification` slot, builds an adaptive payload (planned-outfit vs daily nudge), and enqueues one per-user job onto the Phase 2 `notification_queue`. Plus a scheduled-admin pickup job and a retention prune job. It runs inside the Phase 2 `notification-worker` process; it never calls FCM directly.

**Prereqs:** Phase 2 (`enqueue`, `notification_queue`, `notification_worker` consumer, `queue_service.push_notification_job`) + Phase 0 (`create_system_notification`, `deliver`, the 3 models). On this local branch (`feature/au318-mood-feedback`) **none of those exist yet** and the `schedule_entries` table lives on `auxi-backend` main, not here — so all Phase 0/2 entrypoints are consumed through thin, monkeypatch-able wrappers, and the `schedule_entries` lookup degrades gracefully + carries a "verify on up-to-date main" note.

## Interfaces consumed (VERBATIM — match these names/types exactly)

```python
# Phase 0 — services/notification_service.py
def create_system_notification(db, type_: str, title: str, body: str, data: dict) -> Notification
def deliver(db, job: dict) -> None                          # consumer side (Phase 2 worker loop)

# Phase 2 — services/notification_service.py
def enqueue(db, notification_id: str) -> int                # admin audience fan-out; returns #jobs pushed

# Phase 2 — services/queue_service.py (queue name: notification_queue)
queue_service.push_notification_job(job: dict) -> bool      # producer push
queue_service.pop_notification_job(timeout: int) -> dict|None
```

```jsonc
// Phase 2 queue job shape (this scheduler is a PRODUCER of exactly this)
{ "notification_id": "<uuid>", "type": "<type>", "user_id": "<uuid>",
  "local_date": "YYYY-MM-DD", "payload": { "kind":"route","screen":"Home" } }
```

```python
# Phase 0 models (Flask-SQLAlchemy extensions.db; read-only here)
Notification(id, source, type, title, body, data, audience, created_by,
             scheduled_for, status, created_at, sent_at)
NotificationDelivery(id, notification_id, user_id, status, read_at, error,
             created_at, sent_at)
DeviceToken(id, user_id, token, platform, timezone, app_version,
             created_at, last_seen_at)
```

## Locked Phase-3 constants (Global Constraints)

- **Adaptive single daily slot:** one reminder per user per local day. `schedule_entries` row for the user's local today → `planned_outfit` (→`Schedule`); else `daily_reminder` (→`Home`). Both gated by `daily_notification.enabled`.
- **Default time fallback:** `07:30` local when `daily_notification.time` unset. Stored value read first. Stored format is **12-hour `"HH:MM"` + `period` `AM|PM`** (per `schemas/auth.py::DailyNotificationSchema`).
- **Frequency gate:** `weekdays` = Mon–Fri; `everydays` = all 7 days.
- **Dedup key:** `(user_id, daily_slot, local_date)` — durable DB-delivery check inside `find_due_daily_users`, plus a Redis `SET NX` enqueue-time claim in `run_daily_tick`.
- **Timezone source of truth:** `device_tokens.timezone` (IANA). Multi-device user → one representative tz (most-recently-seen token); consumer still multicasts to all devices (spec §13 Q5). DST handled by `zoneinfo`.
- **15-min tick window:** half-open `(now_local - 15min, now_local]`; dedup is the exactly-once guarantee (avoids double-fire across adjacent ticks / restart).
- **No new `/api` route** in Phase 3 → no `API_DOCUMENTATION.md` change.

## Files overview

| Action | Path | Purpose |
|---|---|---|
| Modify | `requirements.txt` | add `APScheduler`, `tzdata` |
| Create | `repositories/reminder_repository.py` | selection/prune queries |
| Create | `services/reminder_service.py` | `find_due_daily_users`, `build_daily_payload`, copy table, tz math |
| Create | `services/notification_scheduler.py` | APScheduler factory + 3 job callables + thin P0/P2 wrappers |
| Modify | `notification_worker.py` | start the scheduler alongside the consumer loop |
| Modify | `tests/conftest.py` | ensure P0 models imported into metadata |
| Create | `tests/test_reminder_service.py` | selection + payload unit tests (time via monkeypatch/injection) |
| Create | `tests/test_notification_scheduler.py` | tick / pickup / retention tests |

> **Time control:** no `freezegun` in this repo (not added). Every schedulable function takes an explicit `now_utc` parameter (dependency-injected time) and an optional `db` (injected session). Tests pass frozen `now_utc` + the `db_session` fixture directly — no time library needed; `monkeypatch` covers the P0/P2 wrappers.

---

### Task 1: requirements — APScheduler + tzdata

**Files:**
- Modify: `requirements.txt`
- Test: `tests/test_scheduler_deps.py` (create)

**Interfaces:** Produces: import surface (`apscheduler`, `zoneinfo`). Consumes: none.

- [ ] Write failing test `tests/test_scheduler_deps.py`:
```python
"""Phase 3 deps smoke: APScheduler installed + zoneinfo has IANA data."""
from datetime import datetime, timezone


def test_apscheduler_importable():
    from apscheduler.schedulers.background import BackgroundScheduler  # noqa: F401
    sched = BackgroundScheduler(timezone="UTC")
    assert sched is not None


def test_zoneinfo_has_iana_db():
    from zoneinfo import ZoneInfo
    tz = ZoneInfo("Asia/Saigon")
    # Asia/Saigon is UTC+7 with no DST
    aware = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc).astimezone(tz)
    assert aware.hour == 7 and aware.minute == 30
```
- [ ] Run `pytest tests/test_scheduler_deps.py -v` → expect FAIL (`ModuleNotFoundError: apscheduler`).
- [ ] Edit `requirements.txt` — add under the Redis/queue area (after `redis>=5.0.1`):
```text
APScheduler>=3.10.0,<4.0        # Phase 3 reminder scheduler (runs inside notification-worker)
tzdata>=2024.1                  # IANA tz DB fallback (zoneinfo) for slim/Windows hosts
```
> `APScheduler` 4.x is an incompatible rewrite — pin `<4.0`. Python 3.9 ships `zoneinfo` (stdlib, PEP 615); `tzdata` guarantees IANA names resolve on hosts without a system tz DB. The scheduler runs **inside the existing notification-worker process** (Phase 2), not a new web process.
- [ ] `pip install -r requirements.txt` then re-run `pytest tests/test_scheduler_deps.py -v` → PASS.
- [ ] Commit: `chore: add APScheduler + tzdata for push reminder scheduler`

---

### Task 2: `find_due_daily_users` — per-tz selection + frequency + dedup

**Files:**
- Create: `repositories/reminder_repository.py`
- Create: `services/reminder_service.py` (selection half — payload half added in Task 3)
- Test: `tests/test_reminder_service.py` (create; selection tests)

**Interfaces:**
- Produces: `find_due_daily_users(db, now_utc) -> list[DueUser]` where `DueUser = (user: User, timezone: str, local_date: date, daily_notification: dict)`.
- Consumes: `models.user.User`, `models.device_token.DeviceToken`, `models.notification.Notification`, `models.notification_delivery.NotificationDelivery` (Phase 0).

- [ ] Add P0 model imports to `tests/conftest.py` `db_session` fixture (idempotent — may already be present from Phase 0). In the `from models import (...)` tuple add:
```python
        device_token,
        notification,
        notification_delivery,
```
> These three modules must exist (Phase 0). If running Phase 3 before Phase 0 merges, create stub models matching the locked schema, or rebase onto the branch where Phase 0 landed.
- [ ] Write failing `tests/test_reminder_service.py` (selection block):
```python
"""Phase 3 — reminder selection (frozen time via injected now_utc)."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone, timedelta

from models.user import User
from models.device_token import DeviceToken
from services.reminder_service import find_due_daily_users


def _user(db, *, enabled=True, time_="07:30", period="AM",
          frequency="weekdays", tz="Asia/Saigon"):
    u = User(
        id=str(uuid.uuid4()),
        email=f"r-{uuid.uuid4().hex[:8]}@example.com",
        password_hash="argon2-stub",
        user_metadata={
            "daily_notification": {
                "enabled": enabled, "time": time_,
                "period": period, "frequency": frequency,
            }
        },
    )
    db.add(u)
    db.flush()
    db.add(DeviceToken(
        id=str(uuid.uuid4()), user_id=u.id, token=f"tok-{uuid.uuid4().hex}",
        platform="ios", timezone=tz,
        created_at=datetime.now(timezone.utc),
        last_seen_at=datetime.now(timezone.utc),
    ))
    db.flush()
    return u


def test_due_user_selected_at_matching_local_time(db_session):
    # 00:30 UTC == 07:30 Asia/Saigon (UTC+7), a Monday
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)
    u = _user(db_session, time_="07:30", period="AM", tz="Asia/Saigon")
    due = find_due_daily_users(db_session, now)
    assert [d.user.id for d in due] == [u.id]
    assert due[0].local_date.isoformat() == "2026-06-29"


def test_two_timezones_only_matching_one_selected(db_session):
    # 00:30 UTC: 07:30 in Saigon (UTC+7) -> due; 09:30 in Tokyo (UTC+9) -> not due (07:30 target)
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)
    saigon = _user(db_session, tz="Asia/Saigon", time_="07:30", period="AM")
    _tokyo = _user(db_session, tz="Asia/Tokyo", time_="07:30", period="AM")
    due_ids = {d.user.id for d in find_due_daily_users(db_session, now)}
    assert saigon.id in due_ids
    assert _tokyo.id not in due_ids


def test_frequency_weekdays_skips_weekend(db_session):
    # 2026-06-28 is a Sunday; 00:30 UTC -> 07:30 Sunday in Saigon
    now = datetime(2026, 6, 28, 0, 30, tzinfo=timezone.utc)
    _user(db_session, frequency="weekdays", tz="Asia/Saigon")
    assert find_due_daily_users(db_session, now) == []


def test_frequency_everydays_fires_weekend(db_session):
    now = datetime(2026, 6, 28, 0, 30, tzinfo=timezone.utc)
    u = _user(db_session, frequency="everydays", tz="Asia/Saigon")
    assert [d.user.id for d in find_due_daily_users(db_session, now)] == [u.id]


def test_default_time_fallback_when_unset(db_session):
    # time omitted -> 07:30 local default. 00:30 UTC == 07:30 Saigon, Monday.
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)
    u = _user(db_session, time_=None, period=None, tz="Asia/Saigon")
    assert [d.user.id for d in find_due_daily_users(db_session, now)] == [u.id]


def test_out_of_window_not_selected(db_session):
    # target 07:30, tick at 08:00 local (00:30 -> +30min) is outside the 15-min window
    now = datetime(2026, 6, 29, 1, 0, tzinfo=timezone.utc)  # 08:00 Saigon
    _user(db_session, time_="07:30", period="AM", tz="Asia/Saigon")
    assert find_due_daily_users(db_session, now) == []


def test_disabled_user_not_selected(db_session):
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)
    _user(db_session, enabled=False, tz="Asia/Saigon")
    assert find_due_daily_users(db_session, now) == []


def test_no_device_token_skipped(db_session):
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)
    u = User(id=str(uuid.uuid4()), email=f"n-{uuid.uuid4().hex[:6]}@x.io",
             password_hash="s",
             user_metadata={"daily_notification": {"enabled": True,
                            "time": "07:30", "period": "AM",
                            "frequency": "weekdays"}})
    db_session.add(u)
    db_session.flush()
    assert find_due_daily_users(db_session, now) == []


def test_dedup_existing_delivery_skips(db_session):
    """A system daily-slot delivery already exists for this user's local_date."""
    from models.notification import Notification
    from models.notification_delivery import NotificationDelivery
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)
    u = _user(db_session, tz="Asia/Saigon")
    notif = Notification(id=str(uuid.uuid4()), source="system",
                         type="daily_reminder", title="t", body="b",
                         data={"kind": "route", "screen": "Home"},
                         status="sent", created_at=now)
    db_session.add(notif)
    db_session.flush()
    db_session.add(NotificationDelivery(
        id=str(uuid.uuid4()), notification_id=notif.id, user_id=u.id,
        status="sent", created_at=now))  # created_at 00:30 UTC == 07:30 Saigon today
    db_session.flush()
    assert find_due_daily_users(db_session, now) == []
```
- [ ] Run `pytest tests/test_reminder_service.py -v` → expect FAIL (`ModuleNotFoundError: services.reminder_service`).
- [ ] Create `repositories/reminder_repository.py`:
```python
"""DB access for the Phase 3 reminder scheduler.

Pure data layer — no business logic, no commit (callers commit). Mirrors the
repo convention used by app_feedback_repository.
"""
from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy.orm import Session

from models.user import User
from models.device_token import DeviceToken
from models.notification import Notification
from models.notification_delivery import NotificationDelivery

# Both daily-slot types share one slot/day (spec §10) — dedup spans both.
SLOT_TYPES = ("daily_reminder", "planned_outfit")


class ReminderRepository:
    def users_with_daily_enabled(self, db: Session) -> List[User]:
        """All users whose user_metadata.daily_notification.enabled is True.

        JSON-path filtering isn't portable across SQLite (tests) + Postgres
        (prod), so we load + filter in Python. Fine at current scale; add a
        generated column / partial index when the user table grows (YAGNI).
        """
        out: List[User] = []
        for u in db.query(User).all():
            dn = (u.user_metadata or {}).get("daily_notification") or {}
            if dn.get("enabled") is True:
                out.append(u)
        return out

    def latest_token(self, db: Session, user_id: str) -> Optional[DeviceToken]:
        """Most-recently-seen device token = the user's representative tz."""
        return (
            db.query(DeviceToken)
            .filter(DeviceToken.user_id == user_id)
            .order_by(DeviceToken.last_seen_at.desc())
            .first()
        )

    def recent_system_deliveries(
        self, db: Session, user_id: str, since_utc: datetime
    ) -> List[NotificationDelivery]:
        """System daily-slot deliveries for a user newer than since_utc."""
        return (
            db.query(NotificationDelivery)
            .join(Notification,
                  NotificationDelivery.notification_id == Notification.id)
            .filter(
                NotificationDelivery.user_id == user_id,
                Notification.source == "system",
                Notification.type.in_(SLOT_TYPES),
                NotificationDelivery.created_at >= since_utc,
            )
            .all()
        )

    def queued_scheduled_admin(
        self, db: Session, now_utc: datetime
    ) -> List[Notification]:
        """Admin notifications past their scheduled_for, still queued."""
        return (
            db.query(Notification)
            .filter(
                Notification.status == "queued",
                Notification.scheduled_for.isnot(None),
                Notification.scheduled_for <= now_utc,
            )
            .all()
        )

    def prune_old_system_deliveries(
        self, db: Session, cutoff_utc: datetime
    ) -> int:
        """Delete system NotificationDelivery rows created before cutoff.

        Two-step (select ids → delete) so it works on SQLite + Postgres
        without a DELETE..JOIN. Returns the number removed.
        """
        ids = [
            d.id
            for d in db.query(NotificationDelivery.id)
            .join(Notification,
                  NotificationDelivery.notification_id == Notification.id)
            .filter(
                Notification.source == "system",
                NotificationDelivery.created_at < cutoff_utc,
            )
            .all()
        ]
        if not ids:
            return 0
        (
            db.query(NotificationDelivery)
            .filter(NotificationDelivery.id.in_(ids))
            .delete(synchronize_session=False)
        )
        return len(ids)
```
- [ ] Create `services/reminder_service.py` (selection half — Task 3 appends the payload half to this same file):
```python
"""Phase 3 reminder engine — pure, unit-testable selection + payload logic.

The scheduler (services/notification_scheduler.py) is the only caller. This
module never touches Redis or FCM; it only answers "who is due now?" and
"what should they receive?".
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from typing import List, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy.orm import Session

from models.user import User
from repositories.reminder_repository import ReminderRepository, SLOT_TYPES

logger = logging.getLogger(__name__)

# --- tick / window constants (Global Constraints) ---
TICK_INTERVAL_MINUTES = 15
TICK_WINDOW_MINUTES = 15          # half-open lookback; dedup = exactly-once guarantee
DEFAULT_TARGET_TIME = time(7, 30)  # 07:30 local fallback when time unset
_DEDUP_LOOKBACK = timedelta(hours=36)  # cover any single-day + tz skew

_repo = ReminderRepository()


@dataclass
class DueUser:
    user: User
    timezone: str
    local_date: date
    daily_notification: dict


def _ensure_utc(now_utc: datetime) -> datetime:
    return now_utc if now_utc.tzinfo else now_utc.replace(tzinfo=timezone.utc)


def _parse_target_time(time_str: Optional[str], period: Optional[str]) -> time:
    """Combine stored 12-hour "HH:MM" + AM/PM into a 24-hour time.

    Unset / malformed -> 07:30 default. Handles 12 AM -> 00, 12 PM -> 12.
    A value with no period is treated as already-24h.
    """
    if not time_str:
        return DEFAULT_TARGET_TIME
    try:
        hh_s, mm_s = str(time_str).split(":")
        hh, mm = int(hh_s), int(mm_s)
    except (ValueError, AttributeError):
        return DEFAULT_TARGET_TIME
    p = (period or "").upper()
    if p == "AM" and hh == 12:
        hh = 0
    elif p == "PM" and hh != 12:
        hh += 12
    if not (0 <= hh <= 23 and 0 <= mm <= 59):
        return DEFAULT_TARGET_TIME
    return time(hh, mm)


def _frequency_allows(frequency: Optional[str], weekday: int) -> bool:
    """weekday: Mon=0 .. Sun=6."""
    if (frequency or "weekdays") == "everydays":
        return True
    return weekday <= 4  # Mon-Fri


def _already_notified(
    db: Session, user_id: str, tz: ZoneInfo, local_date: date, now_utc: datetime
) -> bool:
    """Durable dedup: a system daily-slot delivery already lands on this
    user's local_date. created_at (UTC) is mapped to the user's tz; the slot
    fires far from midnight so the local-date mapping is unambiguous."""
    since = now_utc - _DEDUP_LOOKBACK
    for d in _repo.recent_system_deliveries(db, user_id, since):
        created = d.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        if created.astimezone(tz).date() == local_date:
            return True
    return False


def find_due_daily_users(db: Session, now_utc: datetime) -> List[DueUser]:
    """Select users whose local time matches their daily slot this tick.

    Gates: enabled -> has device tz -> frequency allows weekday ->
    target time inside the half-open 15-min window -> not already notified
    today. One representative tz per user (latest token); the consumer still
    multicasts to every device.
    """
    now_utc = _ensure_utc(now_utc)
    due: List[DueUser] = []
    for user in _repo.users_with_daily_enabled(db):
        token = _repo.latest_token(db, user.id)
        if token is None or not token.timezone:
            continue
        try:
            tz = ZoneInfo(token.timezone)
        except (ZoneInfoNotFoundError, ValueError):
            logger.warning("Bad timezone %r for user %s", token.timezone, user.id)
            continue

        now_local = now_utc.astimezone(tz)
        local_date = now_local.date()
        dn = (user.user_metadata or {}).get("daily_notification") or {}

        if not _frequency_allows(dn.get("frequency"), now_local.weekday()):
            continue

        target_tod = _parse_target_time(dn.get("time"), dn.get("period"))
        target_local = datetime.combine(local_date, target_tod, tzinfo=tz)
        window_start = now_local - timedelta(minutes=TICK_WINDOW_MINUTES)
        if not (window_start < target_local <= now_local):
            continue

        if _already_notified(db, user.id, tz, local_date, now_utc):
            continue

        due.append(DueUser(user=user, timezone=token.timezone,
                           local_date=local_date, daily_notification=dn))
    return due
```
- [ ] Run `pytest tests/test_reminder_service.py -v` → all selection tests PASS.
- [ ] Commit: `feat: add reminder selection (find_due_daily_users) with per-tz window + dedup`

---

### Task 3: `build_daily_payload` — adaptive content + en/vi/fr copy

**Files:**
- Modify: `services/reminder_service.py` (append payload half)
- Test: `tests/test_reminder_service.py` (append payload block)

**Interfaces:**
- Produces: `build_daily_payload(db, user, local_date) -> DailyPayload` where `DailyPayload = (type: str, title: str, body: str, data: dict)`.
- Consumes: `schedule_entries` table (auxi-backend main — **not on this branch**) via `_has_planned_outfit`.

- [ ] Append failing payload tests to `tests/test_reminder_service.py`:
```python
# --- build_daily_payload ---
from datetime import date
from services import reminder_service
from services.reminder_service import build_daily_payload


def _u(db_session, locale=None):
    md = {"daily_notification": {"enabled": True}}
    if locale:
        md["locale"] = locale
    u = User(id=str(uuid.uuid4()), email=f"p-{uuid.uuid4().hex[:6]}@x.io",
             password_hash="s", user_metadata=md)
    db_session.add(u)
    db_session.flush()
    return u


def test_payload_planned_when_schedule_entry(db_session, monkeypatch):
    monkeypatch.setattr(reminder_service, "_has_planned_outfit",
                        lambda db, uid, d: True)
    p = build_daily_payload(db_session, _u(db_session), date(2026, 6, 29))
    assert p.type == "planned_outfit"
    assert p.data == {"kind": "route", "screen": "Schedule"}
    assert "👗" in p.title


def test_payload_daily_when_no_schedule(db_session, monkeypatch):
    monkeypatch.setattr(reminder_service, "_has_planned_outfit",
                        lambda db, uid, d: False)
    p = build_daily_payload(db_session, _u(db_session), date(2026, 6, 29))
    assert p.type == "daily_reminder"
    assert p.data == {"kind": "route", "screen": "Home"}
    assert "✨" in p.title


def test_payload_copy_locales(db_session, monkeypatch):
    monkeypatch.setattr(reminder_service, "_has_planned_outfit",
                        lambda db, uid, d: False)
    vi = build_daily_payload(db_session, _u(db_session, "vi"), date(2026, 6, 29))
    fr = build_daily_payload(db_session, _u(db_session, "fr"), date(2026, 6, 29))
    assert vi.title.startswith("Đến giờ")
    assert fr.body == "Ouvrez Auxi et composez votre look du jour."


def test_payload_locale_fallback_to_en(db_session, monkeypatch):
    monkeypatch.setattr(reminder_service, "_has_planned_outfit",
                        lambda db, uid, d: False)
    p = build_daily_payload(db_session, _u(db_session, "de"), date(2026, 6, 29))
    assert p.body == "Open Auxi and pick your look for the day."


def test_has_planned_outfit_degrades_without_model(db_session):
    """On a branch without the schedule_entries model, lookup returns False."""
    assert reminder_service._has_planned_outfit(
        db_session, "any", date(2026, 6, 29)) is False
```
- [ ] Run `pytest tests/test_reminder_service.py -v` → expect FAIL (`build_daily_payload` undefined).
- [ ] Append to `services/reminder_service.py`:
```python
# ---------------------------------------------------------------------------
# Adaptive payload + localized system copy (spec §10)
# ---------------------------------------------------------------------------

SUPPORTED_LOCALES = ("en", "vi", "fr")
DEFAULT_LOCALE = "en"

# Literal copy keyed by (type, lang). The backend renders literal title/body
# because FCM must display them when the app is backgrounded. The mobile side
# may re-localize from the i18n key form `notif.<type>.{title,body}` if needed.
SYSTEM_COPY = {
    "daily_reminder": {
        "en": ("Time to plan today's outfit ✨",
               "Open Auxi and pick your look for the day."),
        "vi": ("Đến giờ chọn đồ cho hôm nay ✨",
               "Mở Auxi chọn outfit cho ngày mới nào."),
        "fr": ("L'heure de choisir votre tenue ✨",
               "Ouvrez Auxi et composez votre look du jour."),
    },
    "planned_outfit": {
        "en": ("You planned an outfit for today 👗",
               "Tap to see your look in Schedule."),
        "vi": ("Bạn đã lên đồ cho hôm nay 👗",
               "Chạm để xem outfit trong Lịch."),
        "fr": ("Vous avez prévu une tenue aujourd'hui 👗",
               "Touchez pour la voir dans le Calendrier."),
    },
}

_DATA_BY_TYPE = {
    "daily_reminder": {"kind": "route", "screen": "Home"},
    "planned_outfit": {"kind": "route", "screen": "Schedule"},
}


@dataclass
class DailyPayload:
    type: str
    title: str
    body: str
    data: dict


def _resolve_locale(user: User) -> str:
    """No locale column exists today (gap) — read user_metadata.locale if the
    client wrote one, else default 'en'. Safe + forward-compatible."""
    loc = (user.user_metadata or {}).get("locale")
    return loc if loc in SUPPORTED_LOCALES else DEFAULT_LOCALE


def _has_planned_outfit(db: Session, user_id: str, local_date: date) -> bool:
    """True if the user has a schedule_entries row for their local today.

    VERIFY-ON-MAIN: the `schedule_entries` table + `ScheduleEntry` model live
    on auxi-backend main (migration schedule1a2b), NOT on this local branch.
    Shape per spec §10: (user_id, scheduled_date Date, kind, outfit JSON).
    Import is lazy so this module loads on a branch without the model; absent
    model -> degrade to False (daily_reminder). Confirm the model name /
    table / column (`scheduled_date`) against up-to-date main before shipping.
    """
    try:
        from models.schedule_entry import ScheduleEntry  # auxi-backend main
    except ImportError:
        logger.warning("ScheduleEntry model absent — defaulting to daily_reminder")
        return False
    return (
        db.query(ScheduleEntry)
        .filter(
            ScheduleEntry.user_id == user_id,
            ScheduleEntry.scheduled_date == local_date,
        )
        .first()
        is not None
    )


def build_daily_payload(db: Session, user: User, local_date: date) -> DailyPayload:
    """Adaptive: planned-outfit copy if a schedule entry exists for the user's
    local today (precedence), else the daily nudge. Localized en/vi/fr."""
    type_ = "planned_outfit" if _has_planned_outfit(db, user.id, local_date) \
        else "daily_reminder"
    lang = _resolve_locale(user)
    title, body = SYSTEM_COPY[type_].get(lang, SYSTEM_COPY[type_][DEFAULT_LOCALE])
    return DailyPayload(type=type_, title=title, body=body,
                        data=dict(_DATA_BY_TYPE[type_]))
```
- [ ] Run `pytest tests/test_reminder_service.py -v` → all PASS.
- [ ] Commit: `feat: adaptive daily payload (planned vs nudge) with en/vi/fr copy`

---

### Task 4: scheduler tick wiring — `run_daily_tick` + APScheduler factory + worker

**Files:**
- Create: `services/notification_scheduler.py`
- Modify: `notification_worker.py` (start scheduler in `main()`)
- Modify: `services/queue_service.py` (only if Phase 2 didn't add `push_notification_job` — see note)
- Test: `tests/test_notification_scheduler.py` (create; daily-tick block)

**Interfaces:**
- Consumes (VERBATIM): `create_system_notification(db, type_, title, body, data) -> Notification`; `queue_service.push_notification_job(job) -> bool`; Phase 2 queue name `notification_queue`.
- Produces: per-user queue job (locked job shape) + `Notification` rows (source=system); `build_scheduler() -> BackgroundScheduler`.

> **Producer routing decision (system vs admin):** system reminders are pushed **directly** onto `notification_queue` via `queue_service.push_notification_job(...)` after `create_system_notification(...)`. The scheduler already resolved the single user + tz + local_date + adaptive payload, so the locked `enqueue(db, notification_id)` (admin **audience fan-out**) would needlessly re-resolve. Both producers feed the **identical** queue + `deliver` consumer. (Scheduled-admin pickup in Task 5 DOES use `enqueue` — that's its purpose.) If the Phase 0/2 author prefers one producer entrypoint, generalize `enqueue` to accept a pre-built job; until then the scheduler pushes directly. All P0/P2 calls go through thin module-level wrappers so tests monkeypatch them in isolation.

- [ ] Write failing `tests/test_notification_scheduler.py` (daily-tick block):
```python
"""Phase 3 — scheduler job callables (frozen time + monkeypatched P0/P2)."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from models.user import User
from models.device_token import DeviceToken
from models.notification import Notification
from services import notification_scheduler as ns


def _due_user(db, tz="Asia/Saigon"):
    u = User(id=str(uuid.uuid4()), email=f"s-{uuid.uuid4().hex[:6]}@x.io",
             password_hash="s",
             user_metadata={"daily_notification": {"enabled": True,
                            "time": "07:30", "period": "AM",
                            "frequency": "weekdays"}})
    db.add(u)
    db.flush()
    db.add(DeviceToken(id=str(uuid.uuid4()), user_id=u.id,
                       token=f"t-{uuid.uuid4().hex}", platform="ios",
                       timezone=tz, created_at=datetime.now(timezone.utc),
                       last_seen_at=datetime.now(timezone.utc)))
    db.flush()
    return u


def _wire(monkeypatch, pushed, created):
    def fake_create(db, *, type_, title, body, data):
        n = Notification(id=str(uuid.uuid4()), source="system", type=type_,
                         title=title, body=body, data=data, status="queued",
                         created_at=datetime.now(timezone.utc))
        db.add(n)
        db.flush()
        created.append(n)
        return n
    monkeypatch.setattr(ns, "_create_system_notification", fake_create)
    monkeypatch.setattr(ns, "_push_job", lambda job: pushed.append(job))
    monkeypatch.setattr(ns, "_claim_daily_slot", lambda uid, ld: True)
    monkeypatch.setattr(ns, "_has_planned_outfit_for", lambda db, uid, ld: False)


def test_run_daily_tick_creates_and_pushes_once(db_session, monkeypatch):
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)  # 07:30 Saigon Mon
    u = _due_user(db_session)
    pushed, created = [], []
    _wire(monkeypatch, pushed, created)

    sent = ns.run_daily_tick(now_utc=now, db=db_session)

    assert sent == 1
    assert len(pushed) == 1
    job = pushed[0]
    assert job["user_id"] == u.id
    assert job["type"] == "daily_reminder"
    assert job["local_date"] == "2026-06-29"
    assert job["payload"] == {"kind": "route", "screen": "Home"}
    assert job["notification_id"] == created[0].id


def test_run_daily_tick_dedup_claim_blocks_double(db_session, monkeypatch):
    now = datetime(2026, 6, 29, 0, 30, tzinfo=timezone.utc)
    _due_user(db_session)
    pushed, created = [], []
    _wire(monkeypatch, pushed, created)
    monkeypatch.setattr(ns, "_claim_daily_slot", lambda uid, ld: False)

    assert ns.run_daily_tick(now_utc=now, db=db_session) == 0
    assert pushed == []


def test_build_scheduler_registers_three_jobs():
    sched = ns.build_scheduler()
    ids = {j.id for j in sched.get_jobs()}
    assert ids == {"daily_reminder_tick", "scheduled_admin_pickup",
                   "retention_prune"}
```
- [ ] Run `pytest tests/test_notification_scheduler.py -v` → expect FAIL (module missing).
- [ ] **If** `queue_service.push_notification_job` is absent (Phase 2 not merged), add to `services/queue_service.py` (names/queue must match Phase 2 VERBATIM):
```python
    def push_notification_job(self, job: dict) -> bool:
        """LPUSH a self-contained notification job onto notification_queue."""
        if not self.is_connected():
            logger.error("Redis not connected - cannot push notification job")
            return False
        self.redis_client.lpush("notification_queue", json.dumps(job))
        return True

    def pop_notification_job(self, timeout: int = 10):
        """BRPOP a notification job (consumer side)."""
        if not self.is_connected():
            return None
        res = self.redis_client.brpop("notification_queue", timeout=timeout)
        return json.loads(res[1]) if res else None
```
- [ ] Create `services/notification_scheduler.py`:
```python
"""Phase 3 — APScheduler producer + scheduled-admin + retention jobs.

Runs INSIDE the Phase 2 notification-worker process (not a web process).
The scheduler decides WHEN; the queue + deliver consumer (Phase 2) do HOW.

All Phase 0/2 entrypoints are reached through thin module-level wrappers
(_create_system_notification, _push_job, _enqueue, _has_planned_outfit_for,
_claim_daily_slot) so tests monkeypatch them and Phase 3 stays importable
even before Phase 0/2 land.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler
from sqlalchemy.orm import Session

from database import get_db_context
from services.queue_service import queue_service
from services.reminder_service import (
    TICK_INTERVAL_MINUTES,
    build_daily_payload,
    find_due_daily_users,
)
from repositories.reminder_repository import ReminderRepository

logger = logging.getLogger(__name__)

_repo = ReminderRepository()
RETENTION_DAYS = 30
_DEDUP_TTL_SECONDS = 48 * 3600


# --- thin P0/P2 wrappers (monkeypatch targets) ---------------------------

def _create_system_notification(db, *, type_, title, body, data):
    from services.notification_service import create_system_notification  # P0
    return create_system_notification(db, type_=type_, title=title,
                                      body=body, data=data)


def _push_job(job: dict) -> bool:
    return queue_service.push_notification_job(job)            # P2


def _enqueue(db, notification_id: str) -> int:
    from services.notification_service import enqueue          # P2
    return enqueue(db, notification_id)


def _has_planned_outfit_for(db, user_id, local_date) -> bool:
    from services.reminder_service import _has_planned_outfit
    return _has_planned_outfit(db, user_id, local_date)


def _claim_daily_slot(user_id: str, local_date: str) -> bool:
    """Redis SET NX enqueue-time claim — race/restart-safe within the window.
    Graceful: if Redis is down, fall back to the DB-delivery dedup only."""
    client = getattr(queue_service, "redis_client", None)
    if client is None:
        return True
    try:
        key = f"notif:dailyslot:{user_id}:{local_date}"
        return bool(client.set(key, "1", nx=True, ex=_DEDUP_TTL_SECONDS))
    except Exception as exc:  # noqa: BLE001 - never let dedup crash the tick
        logger.warning("daily-slot claim failed (%s) - relying on DB dedup", exc)
        return True


# --- job callables (DI: optional now_utc + db for tests) -----------------

def _run_daily_tick(db: Session, now_utc: datetime) -> int:
    sent = 0
    for d in find_due_daily_users(db, now_utc):
        local_date_str = d.local_date.isoformat()
        if not _claim_daily_slot(d.user.id, local_date_str):
            continue
        payload = build_daily_payload(db, d.user, d.local_date)
        notif = _create_system_notification(
            db, type_=payload.type, title=payload.title,
            body=payload.body, data=payload.data,
        )
        db.flush()
        _push_job({
            "notification_id": notif.id,
            "type": payload.type,
            "user_id": d.user.id,
            "local_date": local_date_str,
            "payload": payload.data,
        })
        sent += 1
    return sent


def run_daily_tick(now_utc: Optional[datetime] = None,
                   db: Optional[Session] = None) -> int:
    now_utc = now_utc or datetime.now(timezone.utc)
    if db is not None:
        return _run_daily_tick(db, now_utc)
    with get_db_context() as session:   # context commits on clean exit
        return _run_daily_tick(session, now_utc)


def _run_scheduled_admin_pickup(db: Session, now_utc: datetime) -> int:
    n = 0
    for notif in _repo.queued_scheduled_admin(db, now_utc):
        _enqueue(db, notif.id)          # P2: resolves audience, pushes jobs
        notif.status = "sending"        # flip off 'queued' so it isn't re-picked
        notif.sent_at = now_utc         # deliver() finalizes -> sent/failed
        db.flush()
        n += 1
    return n


def run_scheduled_admin_pickup(now_utc: Optional[datetime] = None,
                               db: Optional[Session] = None) -> int:
    now_utc = now_utc or datetime.now(timezone.utc)
    if db is not None:
        return _run_scheduled_admin_pickup(db, now_utc)
    with get_db_context() as session:
        return _run_scheduled_admin_pickup(session, now_utc)


def _run_retention_prune(db: Session, now_utc: datetime, days: int) -> int:
    cutoff = now_utc - timedelta(days=days)
    return _repo.prune_old_system_deliveries(db, cutoff)


def run_retention_prune(now_utc: Optional[datetime] = None,
                        days: int = RETENTION_DAYS,
                        db: Optional[Session] = None) -> int:
    now_utc = now_utc or datetime.now(timezone.utc)
    if db is not None:
        return _run_retention_prune(db, now_utc, days)
    with get_db_context() as session:
        return _run_retention_prune(session, now_utc, days)


# --- APScheduler factory --------------------------------------------------

def build_scheduler() -> BackgroundScheduler:
    """Background scheduler (UTC) registering the three Phase 3 jobs.
    coalesce + max_instances=1 → a backlog after downtime runs once, not N
    times; dedup keeps that idempotent."""
    scheduler = BackgroundScheduler(timezone="UTC")
    scheduler.add_job(run_daily_tick, "interval",
                      minutes=TICK_INTERVAL_MINUTES,
                      id="daily_reminder_tick", coalesce=True, max_instances=1)
    scheduler.add_job(run_scheduled_admin_pickup, "interval", minutes=1,
                      id="scheduled_admin_pickup", coalesce=True, max_instances=1)
    scheduler.add_job(run_retention_prune, "cron", hour=3, minute=0,
                      id="retention_prune", coalesce=True, max_instances=1)
    return scheduler
```
- [ ] Wire into `notification_worker.py` `main()` (Phase 2 file) — start the scheduler before the consumer loop and shut it down on exit:
```python
    from services.notification_scheduler import build_scheduler

    scheduler = build_scheduler()
    scheduler.start()
    logger.info("Reminder scheduler started (daily/admin-pickup/retention)")
    try:
        worker.start()          # existing Phase 2 BRPOP consumer loop
    finally:
        scheduler.shutdown(wait=False)
```
> If `notification_worker.py` doesn't exist yet (Phase 2 pending), create a minimal entrypoint that boots `build_scheduler()` + the Phase 2 consumer loop. The scheduler MUST live in the consumer process so one worker both produces (schedules) and is drained by the consumer.
- [ ] Run `pytest tests/test_notification_scheduler.py -v` → daily-tick + factory tests PASS.
- [ ] Commit: `feat: APScheduler producer — daily reminder tick wired into notification-worker`

---

### Task 5: scheduled-admin pickup

**Files:**
- (already implemented in Task 4 `notification_scheduler.py`)
- Test: `tests/test_notification_scheduler.py` (append pickup block)

**Interfaces:** Consumes `enqueue(db, notification_id) -> int` (P2, VERBATIM). Produces: status transition `queued -> sending`.

- [ ] Append failing pickup tests:
```python
def test_admin_pickup_enqueues_past_due_and_marks_sending(db_session, monkeypatch):
    now = datetime(2026, 6, 29, 9, 0, tzinfo=timezone.utc)
    past = Notification(id=str(uuid.uuid4()), source="admin",
                        type="admin_broadcast", title="Hi", body="b",
                        data={"kind": "route", "screen": "Home"},
                        audience={"mode": "all"}, status="queued",
                        scheduled_for=datetime(2026, 6, 29, 8, 0,
                                               tzinfo=timezone.utc),
                        created_at=now)
    db_session.add(past)
    db_session.flush()
    calls = []
    monkeypatch.setattr(ns, "_enqueue", lambda db, nid: calls.append(nid) or 3)

    n = ns.run_scheduled_admin_pickup(now_utc=now, db=db_session)

    assert n == 1
    assert calls == [past.id]
    assert past.status == "sending"
    assert past.sent_at == now


def test_admin_pickup_ignores_future_and_immediate(db_session, monkeypatch):
    now = datetime(2026, 6, 29, 9, 0, tzinfo=timezone.utc)
    future = Notification(id=str(uuid.uuid4()), source="admin",
                          type="admin_broadcast", title="L", body="b",
                          data={}, status="queued",
                          scheduled_for=datetime(2026, 6, 30, 8, 0,
                                                 tzinfo=timezone.utc),
                          created_at=now)
    immediate = Notification(id=str(uuid.uuid4()), source="admin",
                             type="admin_broadcast", title="N", body="b",
                             data={}, status="queued", scheduled_for=None,
                             created_at=now)
    db_session.add_all([future, immediate])
    db_session.flush()
    monkeypatch.setattr(ns, "_enqueue", lambda db, nid: 1)

    assert ns.run_scheduled_admin_pickup(now_utc=now, db=db_session) == 0
    assert future.status == "queued" and immediate.status == "queued"
```
- [ ] Run `pytest tests/test_notification_scheduler.py -v` → PASS (logic already in Task 4).
- [ ] Commit: `test: scheduled-admin pickup enqueues past-due, skips future/immediate`

---

### Task 6: retention prune

**Files:**
- (already implemented in Task 4 / `reminder_repository.py`)
- Test: `tests/test_notification_scheduler.py` (append retention block)

**Interfaces:** Produces: deletion of system `NotificationDelivery` rows older than N days (default 30).

- [ ] Append failing retention tests:
```python
def test_retention_prunes_old_system_deliveries(db_session):
    from models.notification_delivery import NotificationDelivery
    now = datetime(2026, 6, 29, 3, 0, tzinfo=timezone.utc)
    sys_notif = Notification(id=str(uuid.uuid4()), source="system",
                             type="daily_reminder", title="t", body="b",
                             data={}, status="sent", created_at=now)
    admin_notif = Notification(id=str(uuid.uuid4()), source="admin",
                               type="admin_broadcast", title="t", body="b",
                               data={}, status="sent", created_at=now)
    db_session.add_all([sys_notif, admin_notif])
    db_session.flush()
    old = datetime(2026, 5, 1, 3, 0, tzinfo=timezone.utc)     # > 30d ago
    fresh = datetime(2026, 6, 28, 3, 0, tzinfo=timezone.utc)  # < 30d ago
    db_session.add_all([
        NotificationDelivery(id=str(uuid.uuid4()), notification_id=sys_notif.id,
                             user_id="u1", status="sent", created_at=old),
        NotificationDelivery(id=str(uuid.uuid4()), notification_id=sys_notif.id,
                             user_id="u2", status="sent", created_at=fresh),
        NotificationDelivery(id=str(uuid.uuid4()),
                             notification_id=admin_notif.id,
                             user_id="u3", status="sent", created_at=old),
    ])
    db_session.flush()

    deleted = ns.run_retention_prune(now_utc=now, days=30, db=db_session)

    assert deleted == 1  # only the OLD SYSTEM delivery
    remaining = db_session.query(NotificationDelivery).count()
    assert remaining == 2  # fresh system + old admin (admin retained)
```
- [ ] Run `pytest tests/test_notification_scheduler.py -v` → PASS.
- [ ] Commit: `test: retention prune removes old system deliveries, keeps admin`

---

### Task 7: `notification-worker` Railway service (ops note — devops executes, NON-TDD)

**Files:** none in this repo beyond Task 4 (`notification_worker.py` is the entrypoint). This is an ops handoff — **do NOT execute Railway here.**

**Interfaces:** runtime env only.

Non-TDD steps (for the `devops` agent, per spec §13 Q3 — separate service from `ai-worker`):
- [ ] Provision a **new Railway service** `notification-worker` (isolated from `ai-worker`, which carries a deploy backlog). Same repo, same image.
- [ ] Start command: `python notification_worker.py` (boots the Phase 2 consumer + the Phase 3 `build_scheduler()`).
- [ ] Required env vars (Pydantic `Settings` + `os.environ` reads — `notification_worker.py` is not a uvicorn app, so set them on the service directly):
  - `FIREBASE_CREDENTIALS_JSON` — FCM service-account JSON (needed by Phase 0 `push_service` on the consumer side).
  - `REDIS_URL` — same Redis instance as the API (so `notification_queue` is shared producer↔consumer).
  - `DATABASE_URL` — same Postgres as the API.
  - `ENV=production`.
- [ ] Single instance only (one scheduler). If horizontally scaled later, move dedup to a distributed lock / DB unique index (the Redis `SET NX` claim already guards multi-instance, but APScheduler would fire N ticks — keep replicas=1 for Phase 3).
- [ ] Confirm container timezone is irrelevant: the scheduler runs in UTC and all per-user math uses `zoneinfo` + `device_tokens.timezone`.
- [ ] After deploy, verify in logs: `Reminder scheduler started (...)` and a daily tick line every ~15 min.
- [ ] No commit in this repo for this task (infra only).

---

## Phase 3 Done When

- [ ] `pytest tests/test_reminder_service.py tests/test_notification_scheduler.py tests/test_scheduler_deps.py -v` all green — frozen-`now_utc` tests select the correct users across two timezones, gate weekdays vs everydays, fall back to 07:30, and pick planned vs daily payload.
- [ ] A due user is selected/enqueued **exactly once per local day** (window + Redis claim + DB-delivery dedup all covered by tests).
- [ ] Scheduled-admin pickup enqueues past-due `queued` admin notifications via the locked `enqueue(...)` and flips them to `sending`; future/immediate untouched.
- [ ] Retention prune deletes system deliveries older than 30 days, retains admin deliveries.
- [ ] `build_scheduler()` registers `daily_reminder_tick` (15-min), `scheduled_admin_pickup` (1-min), `retention_prune` (daily 03:00 UTC).
- [ ] `python test_server.py` passes (no regression to the API process; the scheduler lives only in the worker).
- [ ] `requirements.txt` adds `APScheduler<4.0` + `tzdata`; no new `/api` route → no `API_DOCUMENTATION.md` change.

> **Real end-to-end requires the worker deployed** with `FIREBASE_CREDENTIALS_JSON` + shared `REDIS_URL`/`DATABASE_URL` (Task 7, devops). Until then Phase 3 is verified at the unit level only — actual FCM delivery is the Phase 0/2 consumer's job and needs a real iOS device (sim push unreliable, spec §11).

## Open assumptions / unresolved (confirm before/at PR)

1. **No `locale` field** on `users` or `device_tokens` (locked schema). Copy localization reads `user_metadata.locale` if the client wrote one, else `en`. If product wants device-locale accuracy, add a column in a follow-up (or carry locale on `device_tokens`).
2. **`schedule_entries` not on this branch.** `_has_planned_outfit` lazily imports `models.schedule_entry.ScheduleEntry` and degrades to `daily_reminder` if absent — VERIFY the model name / table / `scheduled_date` column against up-to-date `auxi-backend` main and adjust the import before shipping.
3. **Timezone math** uses stdlib `zoneinfo` + `tzdata` package (no `pytz` in repo). One representative tz per user = latest `last_seen_at` token (spec §13 Q5).
4. **System producer routing** pushes jobs directly via `queue_service.push_notification_job`; only scheduled-admin uses the locked `enqueue`. Confirm this split with the Phase 0/2 author (alternative: generalize `enqueue` to accept a pre-built job).
5. **Dedup durability** = Redis `SET NX` (enqueue-time) + DB-delivery scan (`find_due_daily_users`). No `local_date` column on `NotificationDelivery` (locked schema) — if Redis is ever absent in prod, consider a partial unique index follow-up in Phase 0.
6. **Default-time reconciliation** (mobile `DEFAULT_SETTINGS.time` 06:15 → 07:30) is a one-line mobile change + CEO confirm (spec §13 Q1) — out of scope for this backend phase; the engine already falls back to 07:30.
