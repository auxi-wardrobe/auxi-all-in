# Testing Patterns

**Analysis Date:** 2026-05-08

This codebase spans two testing regimes: Jest + React Test Renderer (mobile), Pytest (backend), and Maestro (E2E integration tests). Each has specific patterns and conventions.

---

## Mobile (auxi/) — Jest + React Test Renderer + Maestro

### Test Framework

**Unit/Component Tests:**
- **Runner:** Jest 29.6.3
- **Config:** `jest.config.js` (preset: `react-native`)
- **Renderer:** React Test Renderer 19.2.0 (not React Testing Library)
- **Type support:** TypeScript 5.8 via Babel transpilation

**E2E Tests:**
- **Framework:** Maestro (MCP-driven, YAML-based)
- **Config:** `maestro/config.yaml`
- **Flows:** `maestro/flows/<feature>/<flow>.yaml`
- **Selectors:** testID + visible state assertions
- **Execution:** `maestro test maestro/flows/<feature>/<name>.yaml` (requires `JAVA_HOME` export)

### Run Commands

```bash
# Unit tests
yarn test                          # Run all tests once
yarn test --watch                  # Watch mode (re-run on file changes)
yarn test --coverage               # Coverage report (if implemented)

# Type checking
npx tsc --noEmit                   # TypeScript compilation check (must pass)

# Linting
yarn lint                           # ESLint (baseline: 4 errors in _HomeScreen.tsx, 3 warnings)

# E2E Maestro tests
maestro test maestro/flows/auth/login.yaml           # Single flow
maestro test maestro/flows/home/swipe.yaml
maestro test maestro/flows/                          # All flows in directory

# Full verification (before claiming done)
npx tsc --noEmit && yarn lint && yarn ios:sim
```

### Test Structure (Jest)

**Minimal Baseline:**
Only one test file exists: `__tests__/App.test.tsx`

```typescript
import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

test('renders correctly', async () => {
  await ReactTestRenderer.act(() => {
    ReactTestRenderer.create(<App />);
  });
});
```

**Pattern:**
- Test files in `__tests__/` directory (Jest convention)
- No describe blocks in current codebase (could add as codebase grows)
- Async rendering wrapped in `ReactTestRenderer.act()`
- Simple smoke tests for critical components

### Maestro Flow Structure

Maestro tests are **YAML-driven, deterministic UI tests** that execute against the running app.

**Location:** `maestro/flows/` organized by feature

**Basic Flow Pattern:**

```yaml
# maestro/flows/<feature>/<name>.yaml
appId: com.auxi2026.app  # Bundle ID
name: <descriptive-name>
tags:
  - <category>           # auth, home, wardrobe, etc.
  - <regression|smoke|sanity>
env:
  TIMEOUT_MS: 30000
  QA_EMAIL: ${QA_EMAIL}        # From environment
  QA_PASSWORD: ${QA_PASSWORD}
---
# Test steps follow dashes

- launchApp:
    clearState: true           # Clear app state before test
    clearKeychain: true        # iOS-only; clear saved tokens

- extendedWaitUntil:
    visible:
      id: <testID>            # Wait for element with testID
    timeout: ${TIMEOUT_MS}

- tapOn:
    id: <testID>              # Tap interactive element

- inputText: ${QA_EMAIL}      # Type into focused input

- hideKeyboard                # Dismiss keyboard

- assertVisible:
    id: <testID>              # Assert element visible

- assertNotVisible:
    id: <testID>              # Assert element NOT visible

- runFlow: ../_shared/login.yaml  # Run shared sub-flow
```

**Key Selectors:**
- `id: <testID>` — Primary selector (matches testID attribute)
- `visible: { id: ... }` — Wait for visibility
- `text: "..."` — Text content matching (fallback if no testID)

**Environment Variables:**
- `QA_EMAIL` — Test account email (from CI/local env)
- `QA_PASSWORD` — Test account password (from CI/local env)
- Custom env vars: `HOME_TIMEOUT_MS: 30000`

### Maestro Flows in This Codebase

**`maestro/flows/auth/login.yaml`:**
- Tests cold login from clean state
- Kills app and relaunches with `clearState: false` to verify token persists in Keychain
- Asserts: login screen visible → fill email/password → home screen appears
- Uses shared `_shared/login.yaml` sub-flow

**`maestro/flows/_shared/login.yaml`:**
- Reusable login sub-flow called by multiple tests
- Launches with `clearState: true` + `clearKeychain: true` (iOS)
- Fills email/password from `${QA_EMAIL}` and `${QA_PASSWORD}`
- Waits for home screen

**`maestro/flows/home/swipe.yaml`:**
- Tests outfit swiping and mode switching (likely, based on structure)

**`maestro/flows/_shared/ensure-home.yaml`:**
- Shared utility to ensure app is at home screen before test

### testID Naming Convention

**CRITICAL — Required for Maestro Determinism**

Format: `<feature>-<element>-<state-or-purpose>`

Examples from codebase:
- `auth-email-input` — Email input on login screen
- `auth-password-input` — Password input on login screen
- `auth-login-submit` — Login button
- `home-screen-root` — Home screen root view (identifier for presence check)
- `home-mode-pill-safe` — "Safe" mode selection pill
- `home-heart-toggle` — Heart icon (unfavorited state)
- `home-heart-toggle-saved` — Heart icon (favorited state, different testID)
- `home-tile-pin-0` — Pin icon on first outfit tile

**Rules:**
- Every interactive element (Pressable, TouchableOpacity, TextInput, swipeable, switch, segmented control) MUST have testID
- Static layout containers and pure text labels are exempt
- Stateful testIDs flip the suffix for state changes (never go `undefined`):
  - `home-heart-toggle` → `home-heart-toggle-saved` (not `home-heart-toggle` → `undefined`)
- Paired with `accessibilityLabel` for VoiceOver (human-readable, may differ):
  - `testID: 'home-tile-pin-0'` + `accessibilityLabel: 'Pin item'`

### Testing Best Practices (Mobile)

1. **Smoke Tests Before E2E:**
   - Run `yarn test` to catch import errors, render failures
   - Run `npx tsc --noEmit` to catch TypeScript errors

2. **Deterministic Selectors:**
   - Rely on testID, not text (text can change with localization)
   - Use testID for all Maestro assertions

3. **Environment Setup:**
   - QA test account must be registered on backend
   - Email: `qa-test@auxi.app` / Password: `QaTest!2026`
   - Backend running on `:5001` (hardcoded in `src/services/apiClient.ts`)

4. **Cold Boot Tests:**
   - Use `clearState: true` + `clearKeychain: true` in Maestro to force fresh login
   - Tests Keychain persistence by killing and relaunching app with `clearState: false`

5. **No Screenshot-Based Testing:**
   - Maestro uses testID + visibility assertions, not visual diffs
   - No Figma comparison in QA execution (that's `qa-ui` agent role)

---

## Backend (wardrobe-backend/) — Pytest

### Test Framework

**Runner:**
- **Framework:** Pytest (via `pytest` command)
- **Config:** Inline in pyproject.toml (minimal)
- **Fixtures:** `tests/conftest.py` (shared setup/teardown)
- **Markers:** `@pytest.mark.unit`, `@pytest.mark.integration`, `@pytest.mark.slow`

**Parallel Execution:**
- Plugin: `pytest-xdist` (parallel runs with `pytest -n auto`)
- Default: single-process; use `-n auto` for faster CI

### Run Commands

```bash
# All tests
pytest

# With coverage report
pytest --cov=. --cov-report=html

# Specific markers
pytest -m unit              # Fast unit tests only
pytest -m integration       # API integration tests
pytest -m "not slow"        # Skip slow image-processing tests

# Specific test
pytest tests/test_auth_unit.py::TestAuth::test_login_success

# Watch mode (requires pytest-watch)
ptw

# Parallel execution
pytest -n auto

# Stop on first failure
pytest -x

# Verbose output
pytest -v

# Automated end-to-end test suite (full server on port 5002)
python test_server.py       # Run before pushing
```

### Test File Organization

**Structure:**
```
tests/
├── conftest.py                         # Shared fixtures
├── test_auth_unit.py                   # Auth logic (unit)
├── test_auth_integration.py            # Auth endpoints (integration)
├── test_validation.py                  # Validation utils
├── test_gemini_service.py              # LLM service
├── test_recommendation_v2.py           # Recommendation engine
├── test_recommendation_engine_factory.py
├── test_v05_onboarding_integration.py
├── test_engine_v05_unit.py
├── test_engine_v05_repetition.py
├── test_multi_garment_logic.py
├── test_gender_filtering.py
├── test_recommendation_judge_service.py
├── test_segmentation.py
├── test_image_utils.py
├── test_file_utils.py
├── test_tryon.py
└── __init__.py
```

**Naming Convention:**
- `test_<module>.py` for files testing a module
- `Test<ClassName>` for test classes
- `test_<method>_<scenario>_<expected>` for test functions

Examples:
```python
# test_validation.py
def test_validate_file_size_invalid(large_file):
    """Test validating file size exceeding limit."""
    max_size = 3 * 1024 * 1024
    is_valid, file_size = validate_file_size(large_file, max_size)
    assert is_valid is False
    assert file_size > max_size

# test_auth_unit.py
class TestUserService:
    def test_create_user_valid_data_returns_user(self):
        pass

    def test_create_user_duplicate_email_raises_error(self):
        pass
```

### Fixtures (conftest.py)

**Common Fixtures:**

```python
import pytest
from fastapi.testclient import TestClient

# Application fixture
@pytest.fixture
def app():
    """Create FastAPI app for testing."""
    from app import create_app
    return create_app('testing')

# Test client
@pytest.fixture
def client(app):
    """FastAPI TestClient for API requests."""
    return TestClient(app)

# Authentication headers
@pytest.fixture
def auth_headers(client):
    """Get valid JWT token as Authorization header."""
    # 1. Register test user
    # 2. Login to get token
    # 3. Return {'Authorization': f'Bearer {token}'}
    response = client.post('/api/register', json={
        'email': 'test@example.com',
        'password': 'testPassword123'
    })
    
    login_response = client.post('/api/login', json={
        'email': 'test@example.com',
        'password': 'testPassword123'
    })
    
    token = login_response.json()['access_token']
    return {'Authorization': f'Bearer {token}'}

# Mock Redis
@pytest.fixture
def mock_redis():
    """Mock Redis for rate-limit testing."""
    import fakeredis
    return fakeredis.FakeRedis()
```

### Test Markers

Use markers to categorize tests:

```python
import pytest

@pytest.mark.unit
def test_password_hashing():
    """Unit test: hash_password function."""
    pass

@pytest.mark.integration
def test_login_endpoint():
    """Integration test: POST /api/login endpoint."""
    pass

@pytest.mark.slow
def test_image_processing():
    """Slow test: Gemini image generation."""
    pass
```

**Run by marker:**
```bash
pytest -m unit              # Fast unit tests only
pytest -m integration       # API integration tests
pytest -m "not slow"        # Skip slow tests
```

### Test Patterns

#### Unit Test Pattern

```python
class TestPasswordUtils:
    def test_hash_password_returns_hash(self):
        """hash_password returns a valid hash."""
        password = "testPassword123"
        hashed = hash_password(password)
        assert hashed != password
        assert len(hashed) > 0

    def test_verify_password_valid(self):
        """verify_password returns True for correct password."""
        password = "testPassword123"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True

    def test_verify_password_invalid(self):
        """verify_password returns False for incorrect password."""
        password = "testPassword123"
        hashed = hash_password(password)
        assert verify_password("wrongPassword", hashed) is False
```

#### Integration Test Pattern

```python
class TestAuthEndpoints:
    def test_register_success(self, client):
        """POST /api/register with valid data returns 201."""
        response = client.post('/api/register', json={
            'email': 'newuser@example.com',
            'password': 'validPassword123'
        })
        assert response.status_code == 201
        assert response.json()['id']

    def test_register_duplicate_email(self, client):
        """POST /api/register with existing email returns 400."""
        # Register first user
        client.post('/api/register', json={
            'email': 'existing@example.com',
            'password': 'password123'
        })
        
        # Try to register with same email
        response = client.post('/api/register', json={
            'email': 'existing@example.com',
            'password': 'password123'
        })
        assert response.status_code == 400
        assert 'already exists' in response.json()['detail']

    def test_protected_endpoint_unauthorized(self, client):
        """GET /api/secure without token returns 401."""
        response = client.get('/api/secure')
        assert response.status_code == 401

    def test_protected_endpoint_authorized(self, client, auth_headers):
        """GET /api/secure with valid token returns 200."""
        response = client.get('/api/secure', headers=auth_headers)
        assert response.status_code == 200
        assert response.json()['user_id']

    def test_response_includes_request_id(self, client, auth_headers):
        """All responses include X-Request-Id header."""
        response = client.get('/api/secure', headers=auth_headers)
        assert 'X-Request-Id' in response.headers
        assert response.headers['X-Request-Id']
```

#### Validation Test Pattern

```python
class TestFileValidation:
    @pytest.fixture
    def valid_image(self):
        """Create mock valid image file."""
        data = b'\x89PNG\r\n\x1a\n' + b'fake' * 100
        return FileStorage(
            stream=BytesIO(data),
            filename='test.png',
            content_type='image/png'
        )

    def test_validate_image_valid(self, valid_image):
        """validate_image_upload passes for valid image."""
        validate_image_upload(valid_image)  # No exception

    def test_validate_image_invalid_mime(self):
        """validate_image_upload raises for invalid MIME type."""
        data = b'fake pdf data'
        file = FileStorage(
            stream=BytesIO(data),
            filename='doc.pdf',
            content_type='application/pdf'
        )
        with pytest.raises(ValidationError):
            validate_image_upload(file)

    def test_validate_image_too_large(self):
        """validate_image_upload raises for oversized file."""
        data = b'x' * (4 * 1024 * 1024)  # 4MB
        file = FileStorage(
            stream=BytesIO(data),
            filename='large.jpg',
            content_type='image/jpeg'
        )
        with pytest.raises(ValidationError):
            validate_image_upload(file)
```

### Mocking Guidelines

**When to Mock:**
- External APIs (Gemini, S3, Google APIs)
- Time-dependent operations (timestamps, sleep)
- Random/UUID generation (for determinism)
- Slow operations (image processing, network calls)

**Don't Mock:**
- Database access (use test fixtures/in-memory DB)
- Request/response serialization (integration tests catch this)
- Authentication (test real flow with valid tokens)

**Mock Examples:**

```python
from unittest.mock import patch, MagicMock

def test_gemini_api_failure(client, auth_headers):
    """Gemini API failure returns 503."""
    with patch('services.gemini_service.GeminiService') as mock:
        mock.return_value.generate.side_effect = Exception("API down")
        response = client.post(
            '/api/tryon/highres',
            headers=auth_headers,
            json={'job_id': 'xyz'}
        )
        assert response.status_code == 503

def test_s3_upload_success(client, auth_headers):
    """S3 upload returns presigned URL."""
    with patch('utils.s3_utils.upload_to_s3') as mock_upload:
        mock_upload.return_value = 'https://s3.example.com/image.jpg'
        response = client.post(
            '/api/wardrobe/upload',
            headers=auth_headers,
            files={'image': ('test.jpg', b'data')}
        )
        assert response.status_code == 200
        assert 's3.example.com' in response.json()['url']
        mock_upload.assert_called_once()

def test_uuid_generation(client):
    """User ID is UUID."""
    with patch('uuid.uuid4', return_value=MagicMock(hex='test-id-123')):
        response = client.post('/api/register', json={
            'email': 'user@example.com',
            'password': 'password123'
        })
        # Verify UUID was used in response
        assert response.json()['id'] == 'test-id-123'
```

### Coverage

**Targets:**
- Minimum 80% code coverage for new code
- 95%+ for critical paths: auth, payments, data access
- Run: `pytest --cov=. --cov-report=html`

**What to Measure:**
- Function entry points (not every line)
- Error paths (exceptions, validation failures)
- State transitions (status changes, workflows)

**Coverage Report:**
```bash
pytest --cov=. --cov-report=html
# Opens htmlcov/index.html in browser
```

### Automated Test Server

**End-to-End Full System Test:**
```bash
python test_server.py
```

**What It Tests:**
- Health endpoints
- Middleware (request ID, response timing)
- Authentication flow (register → login → protected routes)
- Protected endpoint access
- Try-on endpoints (Gemini integration)
- Recommendation endpoints
- Error handling (404, 500, etc.)

**When to Run:**
- **Before every commit:** `python test_server.py` must pass
- **Part of PR checklist:** required verification gate
- **In CI/CD:** automatic validation before merge

**Port:**
- Starts backend on `:5002` (test port, separate from dev `:5001`)
- Cleans up after completion

### Pre-Commit Checklist

Before pushing or creating a PR:

```bash
# 1. Unit tests
pytest -m unit

# 2. Integration tests
pytest -m integration

# 3. All tests with coverage
pytest --cov=. --cov-report=html

# 4. Full end-to-end
python test_server.py

# 5. For mobile, type-check and lint
npx tsc --noEmit
yarn lint
```

If all pass: safe to commit and push.

### Test Examples from Codebase

**File Validation (`test_validation.py`):**
```python
def test_validate_file_extension_valid():
    """Test validating valid file extensions."""
    assert validate_file_extension('image.jpg') is True
    assert validate_file_extension('photo.jpeg') is True
    assert validate_file_extension('IMAGE.JPG') is True  # Case insensitive

def test_validate_file_size_invalid(large_file):
    """Test validating file size exceeding limit."""
    max_size = 3 * 1024 * 1024  # 3MB
    is_valid, file_size = validate_file_size(large_file, max_size)
    assert is_valid is False
    assert file_size > max_size
```

**Gemini Service (`test_gemini_service.py`):**
```python
class TestGeminiJobManager:
    def test_create_and_get_job(self):
        manager = GeminiJobManager()
        job_id = manager.create_job()
        assert job_id is not None
        job = manager.get_job(job_id)
        assert job.status == 'processing'

    def test_update_job_success(self):
        manager = GeminiJobManager()
        job_id = manager.create_job()
        manager.update_job(job_id, success=True, output={'data': 'test'})
        job = manager.get_job(job_id)
        assert job.status == 'completed'
```

---

## Integration Between Mobile & Backend Tests

### Contract Testing

**API Documentation:** `wardrobe-backend/API_DOCUMENTATION.md`
- Backend updates docs when endpoint changes
- Mobile syncs service clients to match
- Tech-lead reviews for breaking changes

**E2E Test Coverage:**
- Maestro flows test against real backend (`:5001`)
- Mobile dev runs `./scripts/qa-boot.sh` to start full stack
- Catches contract drift immediately

### Test Data / QA Account

**Registered Test User:**
- Email: `qa-test@auxi.app`
- Password: `QaTest!2026`
- Pre-registered on local backend (see `test_server.py`)

**Maestro Environment Variables:**
```bash
export QA_EMAIL="qa-test@auxi.app"
export QA_PASSWORD="QaTest!2026"
maestro test maestro/flows/auth/login.yaml
```

### Workflow

1. **Backend Developer:**
   - Adds endpoint / modifies route
   - Updates `API_DOCUMENTATION.md`
   - Runs `python test_server.py` (must pass)

2. **Mobile Developer:**
   - Reads updated API docs
   - Syncs `src/services/*.ts` client
   - Adds testID to new UI elements
   - Runs `yarn test` + `npx tsc --noEmit`

3. **QA (Maestro Flows):**
   - Authors E2E flows in `maestro/flows/<feature>/`
   - Uses testID selectors (deterministic)
   - Runs against live backend on `:5001`
   - Validates contract and UX together

---

## Summary Table

| Aspect | Mobile (Jest + Maestro) | Backend (Pytest) |
|--------|---|---|
| **Runner** | Jest 29 + Maestro | Pytest |
| **Fixtures** | Minimal; `__tests__/` | conftest.py with shared fixtures |
| **Test structure** | Simple smoke tests | Unit + integration + slow markers |
| **Mocking** | (minimal so far) | unittest.mock for APIs/time |
| **Selectors (E2E)** | testID + visible state | N/A (Pytest is unit/integration) |
| **testID requirement** | CRITICAL for Maestro | N/A (Python backend) |
| **Coverage targets** | Not enforced (yet) | 80% min, 95%+ critical paths |
| **Run before commit** | `yarn test` + `npx tsc` | `python test_server.py` |
| **Watch mode** | `yarn test --watch` | `ptw` (pytest-watch) |
| **Parallel** | Jest built-in | `pytest -n auto` |
| **Documentation** | maestro/README.md | CLAUDE.md testing section |

