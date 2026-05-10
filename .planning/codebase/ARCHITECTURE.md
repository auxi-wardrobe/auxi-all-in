# Architecture

**Analysis Date:** 2025-05-08

## Pattern Overview

**Overall:** Multi-client, service-repository backend pattern with two-repo HTTP contract

**Key Characteristics:**
- Umbrella monorepo (wardrobe_project) coordinating two independent submodules via git submodules
- Backend (FastAPI) single source of truth with two distinct API surfaces
- Mobile client (React Native) consuming public `/api/*` endpoints
- Admin SPA (React) consuming internal `/admin/*` endpoints with role enforcement
- Service-Repository pattern for all data access and business logic
- Stateless APIs with request/response validation at router layer

## Layers

**Router Layer (HTTP Boundary):**
- Purpose: Parse requests, validate contracts, route to services, handle errors
- Location: `wardrobe-backend/routers/*.py`
- Contains: Endpoint definitions, request validation schemas, error handling
- Depends on: Service layer, authentication dependencies, database session
- Used by: Mobile client (via axios), admin SPA (via axios), external systems

**Service Layer (Business Logic):**
- Purpose: Orchestrate domain logic, coordinate repositories, manage transactions
- Location: `wardrobe-backend/services/*.py`
- Contains: Recommendation engine logic, AI service orchestration, file processing, domain rules
- Depends on: Repositories, external APIs (Gemini, S3), utilities
- Used by: Routers, other services

**Repository Layer (Data Access):**
- Purpose: Encapsulate SQLAlchemy queries, provide testable data access
- Location: `wardrobe-backend/repositories/*.py`
- Contains: Query builders, model-specific accessors, lazy-loaded relationships
- Depends on: SQLAlchemy models, database session
- Used by: Services only

**Model Layer (Domain Objects):**
- Purpose: Define database schema and relationships
- Location: `wardrobe-backend/models/*.py`
- Contains: SQLAlchemy ORM definitions, columns, relationships, lifecycle hooks
- Depends on: SQLAlchemy, extensions.db
- Used by: Repositories, services for type annotations

**Mobile Client Layer (React Native):**
- Purpose: Render UI, manage user interactions, present data
- Location: `auxi/src/`
- Contains: Screens, components, navigation tree, theme
- Depends on: API services, authentication context, TanStack Query
- Used by: End users on iOS/Android

**Admin SPA Layer (React):**
- Purpose: Internal operational tools for PM/ops (user management, common items, ML config)
- Location: `wardrobe-backend/wardrobe-admin/src/`
- Contains: Dashboard pages, admin-only components, admin service layer
- Depends on: Admin API services, Ant Design, authentication context
- Used by: Operations team (admin role only on backend)

## Data Flow

**Mobile → Backend (Outfit Recommendation):**

1. User opens mobile app, navigates to Home
2. `HomeScreen` calls `recommendationService.getRecommendation(userPrefs, weather)`
3. Service → axios → `apiClient.ts` intercepts, adds JWT token
4. POST to `http://localhost:5001/api/v2/recommendation/start`
5. `routers/recommendation.py` endpoint receives, validates request
6. Calls `services/recommendation_service.py` → `recommendation_judge_service.py`
7. Services query repositories: `wardrobe_repository.get_items()`, `algorithm_config_repository.get_config()`
8. Repositories execute SQLAlchemy queries, return domain objects
9. Service applies recommendation logic (weather awareness, gender-specific, variation cycling)
10. Routers serialize outfit + session_id → JSON
11. Response travels back: 200 + outfit data + X-Request-Id, X-Response-Time headers
12. Mobile client displays outfit, stores session_id for `/next` calls

**Admin SPA → Backend (Common Items Management):**

1. Admin user logs in via `wardrobe-admin/src/pages/Login.tsx`
2. `authService.login()` calls `http://localhost:5001/api/login` (public endpoint, email/password)
3. Backend validates, returns access_token
4. Admin navigates to CommonItems page
5. `commonItemsService.fetch()` calls `http://localhost:5001/api/admin/common-items`
6. Request includes Authorization: Bearer token
7. `routers/admin/common_items.py` receives, checks `get_current_user` dependency
8. On backend, `deps/auth.py` validates JWT, fetches user, confirms `role == "admin"`
9. If authorized: Service queries `wardrobe_repository` with owner_id="SYSTEM"
10. Returns filtered list of SYS_* items
11. Admin edits, submits back to `POST /api/admin/common-items/<id>`
12. Service updates database, returns 200 + updated item

**Within Backend (Try-On with Gemini):**

1. Mobile: `tryOnService.generateHighRes(userBodyId, garmentIds)` → POST `/api/tryon/highres`
2. Router validates request, calls `services/tryon_service.py`
3. Service queries `body_repository.get_by_user_id(user_id)` → fetch body reference image from S3
4. Queries `wardrobe_repository.get_items(garment_ids)` → fetch garment images from S3
5. Calls `services/gemini_service.py` with multimodal prompt
6. Gemini generates composite image (10-20s)
7. Service uploads result to S3 via `s3_utils.upload_to_s3()`
8. Creates `TryOnImage` record in database
9. Returns presigned URL + job_id to mobile client

**State Management:**

- **Mobile**: TanStack Query 5 for server state (outfit cache, wardrobe items). `AuthContext` for user session.
- **Admin**: React Context for admin auth state. Ant Design Form for form state (not persisted).
- **Backend**: No state. SQLAlchemy session per request (dependency injection). JWT tokens for stateless auth.

## Key Abstractions

**Service-Repository Pattern:**
- Purpose: Separate business logic (service) from data access (repository)
- Examples: `services/wardrobe_service.py` ↔ `repositories/wardrobe_repository.py`
- Pattern: Service receives Session, injects Repository, calls repo methods, applies domain rules, returns serializable objects

**Recommendation Engine (Variation Cycling):**
- Purpose: Generate diverse outfit suggestions by cycling through 4 axes: SILHOUETTE → LAYERING → COLOR → NEW_ANCHOR
- Examples: `services/recommendation_service.py`, `services/recommendation_judge_service.py`
- Pattern: Service stores session_id (in-memory or Redis), tracks outfit_hash, varies constraints per `/next` call

**Common Items System:**
- Purpose: Centralized pool of system-curated items (owner_id="SYSTEM") for cloning into user wardrobes
- Examples: `models/wardrobe.py` (is_common_item flag), `routers/wardrobe.py` (/common-items endpoint), `commonItems/seeder.py`
- Pattern: Read-only public endpoint, cloning via `POST /wardrobe/common-items/<id>/clone`, creates user-owned copy

**Ephemeral File Manager:**
- Purpose: Temporary image storage with automatic TTL-based cleanup (no persistent user uploads)
- Examples: `utils/file_utils.py` context manager, `utils/validation.py` for MIME/size validation
- Pattern: With block auto-cleanup, manual try/finally fallback, background cleanup every 15 minutes

**JWT Token Management:**
- Purpose: Stateless authentication across both clients
- Examples: `utils/auth_utils.py` (generate_access_token, validate_refresh_token), `deps/auth.py` (get_current_user dependency)
- Pattern: Access token (15 min), refresh token (7 days), token stored in mobile Keychain, validated per request

**Admin Role Enforcement:**
- Purpose: Ensure only admin users can access `/admin/*` endpoints
- Examples: `routers/admin/` all check `user.role == "admin"`
- Pattern: `get_current_user` dependency validates + fetches, router checks role, returns 403 if denied

## Entry Points

**Backend FastAPI App:**
- Location: `wardrobe-backend/app.py`
- Triggers: `uvicorn app:app --reload --port 5001`
- Responsibilities: Lifespan management (startup/shutdown), middleware registration (CORS, request tracking), exception handlers, router registration, health/root endpoints

**Mobile Navigation Root:**
- Location: `auxi/src/navigation/AppNavigator.tsx`
- Triggers: App bootstrap from `index.tsx`
- Responsibilities: Conditional auth flow (logged in → Home + Wardrobe + Body + Settings, first login → onboarding flow, not logged in → AuthNavigator)

**Admin SPA Entry:**
- Location: `wardrobe-backend/wardrobe-admin/src/main.tsx`
- Triggers: Vite build, Wrangler deployment to Cloudflare
- Responsibilities: React root, Ant Design ConfigProvider theme setup, React Router setup (pages/)

**Auth Router (Mobile):**
- Location: `auxi/src/navigation/AuthNavigator.tsx`
- Triggers: When `user === null` in `AuthContext`
- Responsibilities: Login / Register screen stack

## Error Handling

**Strategy:** Centralized FastAPI exception handlers (app.py) + middleware request tracking (X-Request-Id, X-Response-Time)

**Patterns:**

- **HTTP Exceptions** (`StarletteHTTPException`): Return JSON with error message, status code, request_id
- **Validation Errors** (`RequestValidationError`): Return 400 with error details array
- **Unhandled Exceptions**: Log full traceback server-side, return generic 500 + request_id to client
- **Mobile Client**: axios interceptors log errors, services catch and re-throw with context
- **Admin SPA**: Ant Design message.error() for user feedback, console logs for debugging

## Cross-Cutting Concerns

**Logging:** 
- Backend: Python logging to stdout (level configurable via LOG_LEVEL env var)
- Mobile: console.log / console.error for development, suppressed in production
- Admin: console logs only (Cloudflare Pages no persistent log storage)

**Validation:**
- Backend: Pydantic schemas in `routers/`, utility validators in `utils/validation.py` (file MIME/size)
- Mobile: React Hook Form or manual validation in services before API call
- Admin: Ant Design Form validation rules, custom validators for edge cases

**Authentication:**
- Backend: JWT tokens (access + refresh), FastAPI Depends(get_current_user), role-based access
- Mobile: Token in Keychain, axios interceptor adds Authorization header
- Admin: Token in localStorage, axios interceptor adds Authorization header, React Context tracks user

**Rate Limiting:**
- Backend: `utils/rate_limiter.py` decorators on routers (auth 5/min, upload 10/min, processing 20/min, reads 60/min)
- Mobile: Client-side debouncing in components (no explicit rate limit header handling)
- Admin: Simple cooldowns on button clicks (e.g., form submit disabled while loading)

---

*Architecture analysis: 2025-05-08*
