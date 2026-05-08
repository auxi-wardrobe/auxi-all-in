# Coding Conventions

**Analysis Date:** 2026-05-08

This codebase spans two distinct technology stacks (React Native + TypeScript on mobile, Python FastAPI on backend). Both follow strict naming and style conventions with language-specific tooling.

---

## Mobile (auxi/) — React Native + TypeScript

### Naming Patterns

**Files:**
- Screens: PascalCase with `Screen` suffix (e.g., `HomeScreen.tsx`, `WelcomeScreen.tsx`)
- Services: camelCase with `Service` suffix (e.g., `recommendationService.ts`, `apiClient.ts`)
- Components: PascalCase (e.g., `ContextChipsModal.tsx`, `ItemDetailBottomSheet.tsx`)
- Types/Interfaces: PascalCase (e.g., `AuthStackParamList`, `Outfit`, `RecommendationMode`)
- Utils: camelCase (e.g., `location.ts`, `url.ts`)
- Directories: kebab-case (e.g., `src/components/`, `src/services/`, `src/types/`)

**Functions & Variables:**
- camelCase for all functions and variables: `const getImageUrl = (...) => {...}`
- Constants: UPPER_SNAKE_CASE (e.g., `GRID_GAP = 4`, `DEFAULT_RECOMMENDATION_MODE = 'safe'`)
- Booleans: prefix with `is`, `has`, `should`, `can` (e.g., `isLoading`, `hasFocus`, `shouldRender`)

**Types:**
- Interfaces: `I` prefix optional but not enforced (e.g., `AuthContextType`, `TryOnOutfitContext`)
- Generic types: singular noun (e.g., `Item`, `User`, `Outfit` — not `Items`)
- Type unions: explicit (e.g., `RecommendationMode = 'safe' | 'power' | 'creative'`)

**testID for Maestro/Detox:**
- Format: `<feature>-<element>-<state-or-purpose>` (e.g., `home-mode-pill-safe`, `auth-login-submit`)
- Every interactive element MUST have testID: `Pressable`, `TouchableOpacity`, `TextInput`, swipeable, switch, segmented control, etc.
- Static layout containers and pure text labels are exempt.
- Naming rules:
  - `auth-email-input` — login input field
  - `home-heart-toggle` vs `home-heart-toggle-saved` — flip suffix for state, never let testID go `undefined`
  - `home-mode-pill-safe` — mode selection pill
  - `home-screen-root` — root view identifier
  
**accessibilityLabel vs testID:**
- `testID` is machine-readable (Maestro/Detox selector)
- `accessibilityLabel` is human-readable (VoiceOver for blind users)
- Icon-only buttons MUST set both, but values MUST differ:
  - `testID: 'home-tile-pin-0'` + `accessibilityLabel: 'Pin item'` / `'Unpin item'`
- For text buttons, they can match or use only one, but if an element has a human-friendly label, use `accessibilityLabel` for a11y.

### Code Style

**Formatting:**
- **Tool:** Prettier 2.8.8
- **Config:** `.prettierrc.js` at repo root
  - `arrowParens: 'avoid'` — omit parens on single-arg arrows: `(x) => x` → `x => x`
  - `singleQuote: true` — use single quotes `'string'` not `"string"`
  - `trailingComma: 'all'` — trailing commas in multiline objects/arrays

**Linting:**
- **Tool:** ESLint with `@react-native` config (`.eslintrc.js`)
- **Baseline:** 4 known errors in `_HomeScreen.tsx` (legacy file pending deletion), 3 warnings
- **Standard:** Don't add new lint errors/warnings beyond baseline
- Run: `yarn lint`

**Import Organization:**
Order imports as:
1. React / React Native core
2. Third-party libraries (Navigation, TanStack Query, axios)
3. SVG icons (SVG Transformer imports)
4. Internal components
5. Internal services
6. Internal types
7. Utils / helpers

Example:
```typescript
import React, { useCallback, useMemo } from 'react';
import { View, Text, Pressable } from 'react-native';
import { useMutation } from '@tanstack/react-query';
import { useNavigation } from '@react-navigation/native';

import IconFavorite from '../assets/icons/icon_favorite.svg';
import { HomeHeader } from '../components/layout/HomeHeader';
import { recommendationService } from '../services/recommendationService';
import { Item, Outfit } from '../types/item';
import { theme } from '../theme/theme';
import { getImageUrl } from '../utils/url';
```

**No Path Aliases in Config:**
- Imports are relative or from installed packages only
- No `@/` or `@components/` aliases

### Error Handling

**Pattern:**
- Use `console.error()` for client-side errors
- Wrap async calls in try/catch
- Log context: `console.error('Error retrieving token', error)`
- Never expose full stack traces to users; show generic messages
- For API errors, extract `.error.response?.data` for details

Example:
```typescript
try {
  const credentials = await Keychain.getGenericPassword();
  config.headers.Authorization = `Bearer ${accessToken}`;
} catch (error) {
  console.error('Error retrieving token', error);
  // Don't re-throw; let request proceed without token
}
```

**Async/Await Pattern:**
- Use async/await for Promise chains
- Avoid mixing `.then()` and `async/await` in the same function
- Always wrap async functions in try/catch or return the Promise and let the caller handle it

Example (correct):
```typescript
const login = useCallback(async (data: LoginRequest) => {
  setIsLoading(true);
  try {
    await authService.login(data);
    await checkAuth();
  } catch (error) {
    throw error; // Caller handles
  } finally {
    setIsLoading(false);
  }
}, [checkAuth]);
```

### Component Design

**Functional Components Only:**
- All components are functional (React 19 hooks)
- Use `React.FC<Props>` type (optional but recommended)

**Custom Hooks:**
- Prefix with `use`: `useAuth()`, `useRecommendations()`
- Hooks live in `src/hooks/` or inline in component files if single-use

**Props Destructuring:**
```typescript
const HomeScreen: React.FC<{ route: RouteProp<...> }> = ({ route }) => {
  // Props destructured in signature
};
```

### Theme & Styling

**No Literal Hex Colors:**
- All colors defined in `src/theme/theme.ts`
- Use theme tokens: `color: theme.colors.primary`
- Legacy `_HomeScreen.tsx` has some inline hex (don't copy)

**SVG Icons:**
- Import as React components: `import IconFoo from '../assets/icons/icon_foo.svg'`
- Render with explicit dimensions: `<IconFoo width={20} height={20} />`
- Don't use `<Image>` component for SVG

**Constants for Magic Numbers:**
- Named constants at module top:
  ```typescript
  const GRID_GAP = 4;
  const SHEET_PADDING = 12;
  const CARD_WIDTH = Math.floor((screenWidth - SHEET_PADDING * 2 - GRID_GAP) / 2);
  ```

### Navigation Registration

**CRITICAL — Silent Failure Risk:**
- Every new screen MUST be added to `src/types/navigation.ts` in the appropriate `ParamList` type
- Every new screen MUST be registered in `src/navigation/AppNavigator.tsx` or `AuthNavigator.tsx`
- Skip either and you get silent runtime breakage on cold start
- Example in `navigation.ts`:
  ```typescript
  export type AppStackParamList = {
    Home: undefined;
    Settings: undefined;
    ItemDetail: { itemId: string };  // Define params here
  };
  ```

### Onboarding Copy

- Don't inline strings in onboarding screens
- All copy/artwork goes in `src/onboarding/config.ts`
- Reference via config: `const { title, subtitle } = onboardingConfig[screenName]`
- Simplifies future i18n migration

### Service Layer

**API Clients:**
- All HTTP via `src/services/apiClient.ts` (wraps axios)
- Never import axios directly into screens/components
- Each domain has a service file:
  - `authService.ts` — login, register, logout, token refresh
  - `recommendationService.ts` — `/api/recommendation`, `/api/v05/recommendation`
  - `wardrobeService.ts` — wardrobe items, upload, clone
  - `favouriteService.ts` — favorite/unfavorite
  - `bodyService.ts` — body reference photos
  - `tryOnService.ts` — try-on endpoints

**Service Pattern:**
```typescript
export const recommendationService = {
  async startRecommendation(params: StartRecommendationParams): Promise<RecommendationResponse> {
    return apiClient.post('/v2/recommendation/start', params).then(r => r.data);
  },
  async nextRecommendation(params: NextRecommendationParams): Promise<RecommendationResponse> {
    return apiClient.post('/v2/recommendation/next', params).then(r => r.data);
  },
};
```

---

## Backend (wardrobe-backend/) — Python FastAPI

### Naming Patterns

**Files & Modules:**
- Routers (HTTP handlers): `snake_case.py` in `routers/` (e.g., `auth.py`, `wardrobe.py`, `recommendation.py`)
- Services (business logic): `snake_case.py` in `services/` (e.g., `user_service.py`, `recommendation_service.py`)
- Repositories (DB access): `snake_case.py` in `repositories/` (e.g., `user_repo.py`, `wardrobe_repo.py`)
- Models (ORM classes): `snake_case.py` in `models/` (e.g., `user.py`, `wardrobe_item.py`)
- Schemas (Pydantic request/response): `snake_case.py` in `schemas/` (e.g., `auth.py`, `wardrobe.py`)
- Utils: `snake_case.py` in `utils/` (e.g., `auth_utils.py`, `validation.py`, `image_utils.py`)

**Classes:**
- PascalCase: `User`, `WardrobeItem`, `UserRepository`, `AuthService`, `ImageUtils`
- Suffixes signal role:
  - `Service` — business logic
  - `Repository` — DB access
  - `Manager` — lifecycle management (e.g., `GeminiJobManager`, `EphemeralFileManager`)

**Functions & Variables:**
- snake_case: `get_user_by_id()`, `validate_image()`, `hash_password()`
- Private functions: `_private_helper()` with leading underscore
- Constants: UPPER_SNAKE_CASE: `MAX_FILE_SIZE = 3 * 1024 * 1024`, `JWT_EXPIRY_MINUTES = 15`

**Type Hints:**
- Required on all function signatures
  ```python
  def get_user_by_id(db: Session, user_id: str) -> Optional[User]:
      ...
  ```
- Use `Optional[T]` from `typing` for nullable values, not `T | None` (Python 3.9 compatibility)
- Pydantic models for request/response validation

**Docstrings:**
- Triple-quoted docstrings on public functions/classes
  ```python
  def validate_image(file: FileStorage) -> bool:
      """
      Validate image file MIME type and size.
      Raises ValidationError if invalid.
      """
  ```

### Code Style

**Style Guide:** PEP 8
- 4-space indentation
- Max line length: 100 chars (soft)
- Two blank lines between top-level definitions
- One blank line between methods

**Linting & Formatting:**
- No explicit linter config committed (ruff/black via pyproject.toml minimal)
- Baseline: follow PEP 8
- Run: `pytest` validates via test suite

### Import Organization

Order imports as:
1. Standard library (datetime, uuid, os, logging, etc.)
2. Third-party libraries (fastapi, sqlalchemy, pydantic, requests, etc.)
3. Local/project imports (models, services, utils, schemas)

Example:
```python
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, field_validator

from services.user_service import UserService
from models.user import User
from schemas.auth import LoginRequest
from utils.auth_utils import hash_password, verify_password
```

**No Circular Imports:**
- Design repositories/services to avoid circular dependencies
- Router → Service → Repository → Model (acyclic)

### Error Handling

**Pattern:**
- Use `logger.error()`, `logger.warning()`, `logger.info()` via Python `logging` module
- Never log tokens (use `[REDACTED]`)
- FastAPI's global exception handler catches `HTTPException` and formats as `{ error, request_id }` JSON
- Always include context in log messages: `logger.error(f"Registration failed: {e}")`

Example:
```python
logger = logging.getLogger(__name__)

@router.post("/register")
async def register(data: RegisterRequest, db: Session = Depends(get_db)):
    try:
        existing_user = db.query(User).filter_by(email=data.email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already exists")
        logger.info(f"New user registered: {data.email}")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration failed: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
```

**Response Format:**
- Generic error messages to clients, detailed logs server-side
- Include `request_id` for debugging (auto-added by middleware)
  ```python
  return JSONResponse(
      status_code=401,
      content={"error": "Authentication failed", "request_id": request.state.request_id}
  )
  ```

**Async/Await:**
- FastAPI routes are async by default
- Use async/await; await calls to I/O-bound operations (DB, API calls)
  ```python
  @router.get("/items")
  async def get_items(db: Session = Depends(get_db)):
      items = await db.execute(select(Item))  # Or sync if using query()
      return items
  ```

### Service-Repository Pattern

**Flow:** Router → Service → Repository → ORM Model

**Router** (`routers/auth.py`):
- FastAPI endpoint handlers
- Dependency injection (auth, DB)
- Request/response serialization via Pydantic schemas
- HTTP status codes
- Minimal business logic

**Service** (`services/user_service.py`):
- Business logic (validation, orchestration)
- Calls repositories for data access
- Raises domain-specific exceptions

**Repository** (`repositories/user_repo.py`):
- SQLAlchemy ORM queries
- Returns model instances, not dicts
- No business logic; pure data access

Example:
```python
# routers/auth.py
@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: Session = Depends(get_db)):
    service = AuthService()
    token = service.login(data.email, data.password, db)
    return {"access_token": token, "token_type": "bearer"}

# services/auth_service.py
class AuthService:
    def login(self, email: str, password: str, db: Session) -> str:
        user = self.user_repo.get_by_email(db, email)
        if not user or not verify_password(password, user.password_hash):
            raise AuthError("Invalid credentials")
        return generate_access_token(user.id)

# repositories/user_repo.py
class UserRepository:
    def get_by_email(self, db: Session, email: str) -> Optional[User]:
        return db.query(User).filter_by(email=email).first()
```

### Database Access

**ORM Only — No Raw SQL:**
- Use SQLAlchemy ORM exclusively
- Never use f-strings or string formatting in SQL
- If raw SQL is unavoidable, use bound parameters

**Correct:**
```python
user = db.query(User).filter_by(email=email).first()
db.query(WardrobeItem).filter(WardrobeItem.owner_id == user_id).all()
```

**Never:**
```python
# WRONG - SQL Injection vulnerability
user = db.execute(f"SELECT * FROM users WHERE email='{email}'")
```

### File Handling

**EphemeralFileManager (Context Manager):**
```python
from utils.file_utils import EphemeralFileManager

# Always use context manager (auto cleanup)
with EphemeralFileManager() as efm:
    temp_path = efm.save(file_data, extension='.jpg')
    result = process_image(temp_path)
    # Files deleted automatically on exit
```

**Validation:**
```python
from utils.validation import validate_image_upload

# Always validate before processing
validate_image_upload(file)  # Raises ValidationError if invalid
```

**Secure Filenames:**
```python
import uuid
from werkzeug.utils import secure_filename

# Never use user-provided filenames
filename = f"{uuid.uuid4().hex}.jpg"  # CORRECT
safe_name = secure_filename(user_filename)  # For logging/display only
```

### Authentication & Authorization

**Protected Routes:**
```python
from deps.auth import get_current_user

@router.get("/secure")
async def secure_endpoint(user: User = Depends(get_current_user)):
    return {"user_id": user.id}
```

**Admin Routes:**
```python
@router.post("/admin/users")
async def admin_create_user(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Forbidden")
    ...
```

### Validation

**Pydantic Field Validators:**
```python
from pydantic import BaseModel, Field, field_validator

class LoginRequest(BaseModel):
    email: str = Field(..., description="User email")
    password: str = Field(..., min_length=6, description="User password")

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        if "@" not in v:
            raise ValueError("Invalid email")
        return v.lower()
```

### Comments

**When to Comment:**
- Explain WHY, not WHAT (code is the WHAT)
- Non-obvious business logic (e.g., phase references, workarounds)
- Known limitations or TODOs

Example:
```python
# PHASE A (AU-200): Until backend honors `pinned_item_id`,
# we apply a local fallback in the mobile client (HomeScreen.tsx)
def build_outfit_with_pin(outfit: Outfit, pinned_item: Optional[Item]) -> Outfit:
    ...
```

**No Docstrings for Obvious Functions:**
```python
# WRONG
def set_user_id(self, user_id: str) -> None:
    """Set the user ID."""
    self.user_id = user_id

# CORRECT (self-documenting)
def set_user_id(self, user_id: str) -> None:
    self.user_id = user_id
```

### Logging Standards

**Levels:**
- `logger.info()` — user actions, state changes, business events
- `logger.warning()` — recoverable errors, auth failures, edge cases
- `logger.error()` — application errors, exceptions
- `logger.debug()` — detailed debugging (off in production)

Example:
```python
logger.info(f"User {user_id} logged in successfully")
logger.warning(f"Login failed for {email} from {client_ip}")
logger.error(f"Database connection lost: {e}")
```

**Never Log Secrets:**
```python
# WRONG
logger.info(f"Token: {token}")

# CORRECT
logger.info(f"Token: [REDACTED]")
```

### Configuration

**Environment Variables:**
- Read via `os.environ.get()` or Pydantic Settings
- Required vars: `JWT_SECRET_KEY`, `GOOGLE_STUDIO_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- Defaults for non-critical config

**Settings Hierarchy:**
1. Environment variables (production)
2. `.env` file (local dev)
3. Code defaults (fallback)

Example:
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    GOOGLE_STUDIO_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash-exp"
    GEMINI_TIMEOUT_SECONDS: int = 60

settings = Settings()
```

---

## Shared Cross-Repo Conventions

### API Contract Documentation

**Mandatory: Update `API_DOCUMENTATION.md` on all endpoint changes.**
- When modifying `routers/*/routes.py` or changing request/response payloads
- Include: method, path, auth requirement, request/response schemas, error codes, rate limits
- Mobile dev syncs `src/services/*.ts` clients to match
- Tech-lead reviews contract changes for breaking shifts

### Rate Limiting

**Backend enforces per-endpoint limits:**
- Auth: 5 req/min (brute-force prevention)
- Upload: 10 req/min
- Processing: 20 req/min
- Reads: 60 req/min

**Mobile client:**
- Respects 429 (Too Many Requests) responses
- Logs rate-limit warnings
- Retries with exponential backoff (optional, design-specific)

### Commit Message Format

**Conventional Commits:**
```
<type>: <short description>

[optional body]
[optional footer]

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`

Example:
```
feat: Add Gemini-based high-res virtual try-on

Implement GeminiService with async job processing for high-quality
virtual try-on generation. Adds /tryon/highres endpoint for job submission
and /tryon/result/<job_id> for polling results.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## Summary Table

| Aspect | Mobile (RN/TS) | Backend (Python/FastAPI) |
|--------|---|---|
| **File naming** | PascalCase (screens), camelCase (services) | snake_case |
| **Class naming** | PascalCase | PascalCase |
| **Function naming** | camelCase | snake_case |
| **Constants** | UPPER_SNAKE_CASE | UPPER_SNAKE_CASE |
| **Formatter** | Prettier 2.8.8 | PEP 8 (no hard formatter) |
| **Linter** | ESLint (@react-native) | None (pytest validates) |
| **Testing** | Jest + Maestro (E2E) | Pytest + conftest.py |
| **Error handling** | console.error() + try/catch | logger + HTTPException |
| **Comments** | Rare; phase refs + workarounds | Rare; WHY not WHAT |

