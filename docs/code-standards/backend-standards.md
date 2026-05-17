# Backend Standards (FastAPI)

Python 3.11 + FastAPI + SQLAlchemy conventions for `wardrobe-backend/`.

---

## Key Rules

### 1. Router → Service → Repository Pattern

Enforce separation of concerns across three layers:

```python
# routers/wardrobe.py - HTTP layer
from fastapi import APIRouter, Depends
from deps import get_current_user, get_db
from services.wardrobe_service import WardrobeService

router = APIRouter(prefix="/wardrobe", tags=["wardrobe"])

@router.get("/items")
@require_auth
async def list_items(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    service = WardrobeService(db)
    items = service.get_user_items(user.id)
    return [item.to_dict() for item in items]


# services/wardrobe_service.py - Business logic
from repositories.wardrobe_repo import WardrobeRepository

class WardrobeService:
    def __init__(self, db: Session):
        self.repo = WardrobeRepository(db)
    
    def get_user_items(self, user_id: str) -> List[WardrobeItem]:
        """Business logic: filter, sort, enrich."""
        items = self.repo.get_by_user_id(user_id)
        # Process, sort, enrich...
        return items


# repositories/wardrobe_repo.py - DB queries
from sqlalchemy.orm import Session
from models.wardrobe_item import WardrobeItem

class WardrobeRepository:
    def __init__(self, db: Session):
        self.db = db
    
    def get_by_user_id(self, user_id: str) -> List[WardrobeItem]:
        """Pure DB query."""
        return self.db.execute(
            select(WardrobeItem)
            .where(WardrobeItem.user_id == user_id)
            .order_by(WardrobeItem.created_at.desc())
        ).scalars().all()
```

### 2. API_DOCUMENTATION.md is the Contract

**MANDATORY:** Update `API_DOCUMENTATION.md` immediately when modifying routes.

```markdown
### GET /wardrobe/items

**Description:** List all wardrobe items for the authenticated user.

**Authentication:** Required (Bearer token)

**Rate Limit:** 60 requests/minute

**Query Parameters:**
- `category` (optional): Filter by category (tops, bottoms, shoes, accessories)
- `color` (optional): Filter by color (red, blue, etc.)

**Response (200):**
```json
{
  "items": [
    {
      "id": "item-123",
      "name": "Blue Jeans",
      "category": "bottoms",
      "color": "blue",
      "favorite": true,
      "created_at": "2026-05-17T10:30:00Z"
    }
  ]
}
```

**Errors:**
- `401 Unauthorized`: Missing or invalid token
- `400 Bad Request`: Invalid query parameter
```

This is the mobile client's contract. Keep it in sync.

### 3. Ephemeral File Handling

**ALWAYS use `EphemeralFileManager` for temporary files.**

```python
from utils.file_utils import EphemeralFileManager
from utils.validation import validate_image_upload

@router.post("/upload/image")
async def upload_image(file: UploadFile, user: User = Depends(get_current_user)):
    # Validate first
    validate_image_upload(file)
    
    # Process with ephemeral storage
    with EphemeralFileManager() as efm:
        temp_path = efm.save(file.file.read(), extension='.jpg')
        
        # Process image (Gemini, resize, etc.)
        tags = gemini_service.extract_tags(temp_path)
        s3_url = s3_utils.upload_to_s3(temp_path, user.id)
        
        # Temp file auto-deleted on exit
        
        return {"url": s3_url, "tags": tags}
```

Never leave temp files lingering.

### 4. Bearer Token Auth + Dependency Injection

```python
from fastapi import Depends, HTTPException
import jwt

# Method 1: Using dependency (preferred)
@router.get("/profile")
async def profile(user: User = Depends(get_current_user)):
    return {"id": user.id, "email": user.email}

# Method 2: Using decorator (for auth-only routes)
from utils.auth_utils import require_auth

@router.post("/logout")
@require_auth
async def logout(user: User = Depends(get_current_user)):
    # Blacklist token, etc.
    return {"success": True}
```

Token validation in `deps.py`:
```python
async def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    """Extract and validate Bearer token."""
    token = request.state.token  # Set by middleware
    
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")
    
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        token_type = payload.get("type")
        
        if token_type != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        
        user = db.execute(select(User).where(User.id == user_id)).scalars().first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidSignatureError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

### 5. Pydantic Schemas for All I/O

```python
from pydantic import BaseModel, Field

# Request schema
class CreateWardrobeItemRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    category: Literal["tops", "bottoms", "shoes", "accessories"]
    color: str
    occasions: List[str] = []

# Response schema
class WardrobeItemResponse(BaseModel):
    id: str
    name: str
    category: str
    color: str
    favorite: bool
    created_at: datetime
    
    class Config:
        from_attributes = True  # Support ORM models

# Router usage
@router.post("/items", response_model=WardrobeItemResponse)
async def create_item(
    request: CreateWardrobeItemRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WardrobeItemResponse:
    service = WardrobeService(db)
    item = service.create_item(user.id, request.dict())
    return WardrobeItemResponse.from_orm(item)
```

### 6. Error Handling & Logging

```python
import logging

logger = logging.getLogger(__name__)

@router.post("/recommendation")
async def get_recommendation(user: User = Depends(get_current_user), ...):
    try:
        outfit = engine_v05.generate(...)
        return outfit
    except TimeoutError:
        logger.error(f"Recommendation timeout for user {user.id}, request_id={request.state.request_id}")
        return {"error": "Recommendation generation timed out", "request_id": request.state.request_id}, 503
    except Exception as e:
        logger.error(f"Unexpected error: {e}, request_id={request.state.request_id}")
        return {"error": "Internal server error", "request_id": request.state.request_id}, 500
```

Never expose stack traces to users.

### 7. PEP 8 & Type Hints

- **Line length:** 100 characters max
- **Imports:** Group and sort (stdlib, third-party, local)
- **Type hints:** Required on all functions
- **Docstrings:** Google-style docstrings

```python
"""Module docstring."""
import asyncio
from typing import List, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from deps import get_db
from models import User


def process_items(items: List[str]) -> dict:
    """Process user items.
    
    Args:
        items: List of item IDs to process.
    
    Returns:
        Processing result dict with 'processed' count.
    
    Raises:
        ValueError: If items list is empty.
    """
    if not items:
        raise ValueError("Items list cannot be empty")
    
    return {"processed": len(items)}
```

---

## Project Structure

```
wardrobe-backend/
├── routers/                  # HTTP endpoints (grouped by feature)
├── services/                 # Business logic
├── repositories/             # DB access (SQLAlchemy queries)
├── models/                   # SQLAlchemy ORM
├── schemas/                  # Pydantic request/response schemas
├── middleware/               # Request lifecycle (auth, tracing)
├── utils/                    # Helpers (file, validation, rate limit, auth)
├── blueprints/               # Feature modules (recommendation, try-on)
├── tests/                    # Unit + integration tests
├── scripts/                  # One-off utilities (create_admin.py, seed_data.py)
├── migrations/               # Alembic database migrations
├── deps.py                   # FastAPI dependency injection
├── config.py                 # Environment-based configuration
├── app.py                    # FastAPI factory + lifespan
├── API_DOCUMENTATION.md      # **MANDATORY: Full API contract**
└── test_server.py            # Automated e2e test runner
```

---

## File Naming Convention

Use `snake_case` for all Python files:
- `recommendation_service.py`
- `wardrobe_repository.py`
- `validate_image_upload.py`

---

## Common Patterns

### Create Service with Dependency Injection

```python
# services/recommendation_service.py
from repositories.wardrobe_repo import WardrobeRepository
from blueprints.recommendation.engine_v05 import V05Engine

class RecommendationService:
    def __init__(self, db: Session):
        self.wardrobe_repo = WardrobeRepository(db)
        self.engine = V05Engine()
    
    async def get_recommendation(self, user_id: str, context: dict) -> Outfit:
        """Generate outfit recommendation."""
        items = self.wardrobe_repo.get_by_user_id(user_id)
        outfit = await self.engine.generate(items, context)
        return outfit
```

### Create Repository

```python
# repositories/recommendation_repo.py
from sqlalchemy import select
from models import RecommendationLog

class RecommendationRepository:
    def __init__(self, db: Session):
        self.db = db
    
    def log_recommendation(self, user_id: str, outfit_id: str, context: dict) -> RecommendationLog:
        """Log recommendation for analytics."""
        log = RecommendationLog(
            user_id=user_id,
            outfit_id=outfit_id,
            context=context
        )
        self.db.add(log)
        self.db.commit()
        self.db.refresh(log)
        return log
```

### Async Route Handler

```python
@router.post("/recommendation")
async def get_recommendation(
    context: RecommendationRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecommendationResponse:
    """Get outfit recommendation."""
    service = RecommendationService(db)
    outfit = await service.get_recommendation(user.id, context.dict())
    return RecommendationResponse.from_orm(outfit)
```

---

## Testing

### Unit Test Pattern

```python
import pytest

@pytest.mark.unit
def test_process_items_empty_list_raises_error():
    """Empty items list should raise ValueError."""
    with pytest.raises(ValueError):
        process_items([])

@pytest.mark.unit
def test_process_items_returns_count():
    """Should return count of processed items."""
    result = process_items(['a', 'b', 'c'])
    assert result['processed'] == 3
```

### Integration Test Pattern

```python
@pytest.mark.integration
def test_get_wardrobe_items_unauthorized_returns_401(client):
    """Protected endpoint requires auth."""
    response = client.get('/api/wardrobe/items')
    assert response.status_code == 401

@pytest.mark.integration
def test_get_wardrobe_items_authorized_returns_items(client, auth_headers):
    """Authorized request returns user's items."""
    response = client.get('/api/wardrobe/items', headers=auth_headers)
    assert response.status_code == 200
    assert 'items' in response.json()
```

### Run Tests

```bash
pytest                              # All tests
pytest -m unit                      # Unit tests only
pytest -m integration               # Integration tests only
pytest --cov=. --cov-report=html    # Coverage report
python test_server.py               # Automated e2e test runner
```

---

## Verification Before Shipping

```bash
python test_server.py           # Automated e2e tests (port 5002)
pytest                          # Unit + integration tests
pytest --cov=. --cov-report=html  # Coverage (aim for >80%)
```

---

## Known Issues

- **Legacy endpoints:** Some deprecated routes still in API. Cleanup queued (AU-148).
- **Rate limiter:** Basic implementation; should add Redis backing for distributed deployments.
- **Config management:** Algorithm config versioning works but admin approval workflow could be more robust.
