---
name: wardrobe-fastapi-patterns
description: FastAPI service-repository patterns specific to wardrobe-backend. Use when adding routers, services, repositories, models, or migrations. Covers EphemeralFileManager, auth dependency, rate limits, and the API_DOCUMENTATION.md mandate.
---

# Wardrobe Backend FastAPI Patterns

The repo runs on a strict service-repository pattern. Each layer has a job:

```
Router (routers/)  →  Service (services/)  →  Repository (repositories/)  →  DB
   HTTP concerns        Business logic          SQLAlchemy queries
```

If you find yourself querying SQLAlchemy from a router, you've skipped two
layers — restructure.

## Adding a new endpoint

### 1. Repository (DB access only)

```python
# wardrobe-backend/repositories/my_feature_repo.py
from sqlalchemy import select
from sqlalchemy.orm import Session
from models.my_feature import MyFeature


class MyFeatureRepository:
    def get_by_id(self, db: Session, item_id: str) -> MyFeature | None:
        return db.execute(
            select(MyFeature).where(MyFeature.id == item_id)
        ).scalars().first()

    def list_by_user(self, db: Session, user_id: str) -> list[MyFeature]:
        return list(db.execute(
            select(MyFeature).where(MyFeature.owner_id == user_id)
        ).scalars().all())

    def create(self, db: Session, *, owner_id: str, name: str) -> MyFeature:
        obj = MyFeature(owner_id=owner_id, name=name)
        db.add(obj)
        db.commit()
        db.refresh(obj)
        return obj
```

No business logic. No HTTP. No rate-limit checks. Just queries.

### 2. Service (business rules)

```python
# wardrobe-backend/services/my_feature_service.py
from repositories.my_feature_repo import MyFeatureRepository


class MyFeatureService:
    def __init__(self, repo: MyFeatureRepository | None = None):
        self.repo = repo or MyFeatureRepository()

    async def create_for_user(self, db, user_id: str, name: str):
        # validation, side effects, business rules go here
        if not name.strip():
            raise ValueError("name required")
        return self.repo.create(db, owner_id=user_id, name=name.strip())
```

### 3. Router (HTTP concerns)

```python
# wardrobe-backend/routers/my_feature.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from auth.dependencies import get_current_user
from services.my_feature_service import MyFeatureService
from schemas.my_feature import MyFeatureCreate, MyFeatureOut

router = APIRouter(prefix="/my-feature", tags=["my-feature"])
service = MyFeatureService()


@router.post("", response_model=MyFeatureOut, status_code=201)
async def create_my_feature(
    payload: MyFeatureCreate,
    user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return await service.create_for_user(db, user.id, payload.name)
```

### 4. ⚠️ Update `API_DOCUMENTATION.md` in the SAME edit

Per `wardrobe-backend/CLAUDE.md`, this is mandatory:

```markdown
### `POST /my-feature`

**Description**: Create a new my-feature record for the authenticated user.
**Authentication**: Required
**Rate Limit**: 20 req/min
**Request body**:
```json
{ "name": "string" }
```
**Response 201**:
```json
{ "id": "uuid", "name": "string", "owner_id": "uuid" }
```
**Errors**:
- 400: invalid name
- 401: missing/invalid token
```

If you forget this, the mobile dev calling your endpoint won't know it
exists, and the contract drifts. Don't.

## Auth dependency

```python
@router.get("/secure")
async def secure(user = Depends(get_current_user)):
    return {"id": user.id}
```

`get_current_user`:
- validates JWT signature + expiry,
- ensures token type is `access` (rejects refresh tokens here),
- fetches the user from DB and rejects deleted/banned users,
- raises 401 on failure.

Never re-implement these checks inline.

## Rate limiting

```python
from utils.rate_limiter import rate_limit

@router.post("/upload")
@rate_limit(limit=10, period=60)
async def upload(...):
    ...
```

Defaults:
- auth endpoints: 5/min
- upload endpoints: 10/min
- processing (LLM/image): 20/min
- read endpoints: 60/min

## Ephemeral file handling

```python
from utils.file_utils import EphemeralFileManager
from utils.validation import validate_image_upload

async def process_upload(file):
    validate_image_upload(file)  # MIME + size; raises ValidationError
    with EphemeralFileManager() as efm:
        path = efm.save(await file.read(), extension=".jpg")
        return process(path)
    # files auto-deleted on context exit
```

Limits: images 3 MB · selfies 5 MB · thumbnails 500 KB. Allowed MIME:
`image/{jpeg,png,webp,gif}`.

Never use user-supplied filenames. Generate `uuid.uuid4().hex` or use
`secure_filename()`.

S3 only for persistent wardrobe items / try-on results — not for
ephemeral processing inputs.

## Request lifecycle (provided by middleware)

```python
async def handler(request: Request):
    request.state.request_id        # auto UUID, exposed as X-Request-Id
    request.state.processing_time   # set on response as X-Response-Time
    request.state.bearer_token      # parsed from Authorization header
```

Errors are formatted by the global exception handler as
`{"error": "...", "request_id": "..."}`. Never leak stack traces.

## Recommendation engine v2

```
session_start → outfit_v0 (initial weather-aware recommendation)
session/next  → cycles SILHOUETTE → LAYERING → COLOR → NEW_ANCHOR
```

- Common items: `owner_id="SYSTEM"`, `is_common_item=True`,
  IDs like `SYS_L2_TEE_WHT_REG_01`.
- Layer codes: `L1` base · `L2` mid · `L3` outer · `BT` bottom · `SH` shoes.
- Climate buckets: HOT ≥25°C · MILD 15–24°C · COOL <15°C.

Endpoints:
- `POST /api/v2/recommendation/start`
- `POST /api/v2/recommendation/next`
- `GET  /wardrobe/common-items`
- `POST /wardrobe/common-items/<id>/clone`

## Try-on

| Mode | Endpoint | Latency |
|---|---|---|
| Low-res preview | `POST /tryon/lowres` | 2–4s, local pose composit |
| High-res Gemini | `POST /tryon/highres` | 10–20s, S3-backed result |

High-res requires `"gemini_opt_in": true` in the body (explicit consent).

## Verification gate

```bash
cd wardrobe-backend
pytest -m unit               # fast unit tests
pytest -m integration        # API tests (need DB)
python test_server.py        # full e2e on :5002 — pre-commit gate
```

Don't claim "done" without these green.

## Anti-patterns to avoid

- Raw SQL with f-strings (SQL injection): `db.execute(f"SELECT * FROM users WHERE email='{email}'")` — use ORM.
- `subprocess.run(..., shell=True)` with user input — use array form, no shell.
- Decorator order: `@router.post(...)` MUST be first, then deps. Reversed order silently breaks.
- Logging tokens or passwords. Use `[REDACTED]`.
- Persistent storage for user uploads outside the documented S3 buckets.
