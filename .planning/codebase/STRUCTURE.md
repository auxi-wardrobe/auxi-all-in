# Codebase Structure

**Analysis Date:** 2025-05-08

## Directory Layout

```
wardrobe_project/                                # Umbrella monorepo
├── auxi/                                        # Submodule: React Native mobile app
│   ├── src/
│   │   ├── screens/                             # 15+ screen components
│   │   ├── services/                            # API clients (apiClient, auth, wardrobe, etc.)
│   │   ├── components/                          # UI components (atoms, layout, features)
│   │   ├── navigation/                          # React Navigation stacks
│   │   ├── context/                             # AuthContext for session
│   │   ├── types/                               # TypeScript types (navigation, auth, models)
│   │   ├── theme/                               # Centralized theme tokens
│   │   ├── translations/                        # i18n locales (i18next)
│   │   ├── assets/                              # SVG icons, images
│   │   └── utils/                               # Helper functions
│   ├── maestro/                                 # QA testing flows (Maestro YAML)
│   ├── docs_agent/                              # Backend API reference docs
│   ├── package.json                             # yarn workspaces, dependencies
│   └── __tests__/                               # Jest tests
├── wardrobe-backend/                            # Submodule: FastAPI backend
│   ├── app.py                                   # FastAPI factory, lifespan, middleware, routes
│   ├── settings.py                              # Configuration (env vars)
│   ├── database.py                              # SQLAlchemy engine, session, Base
│   ├── routers/                                 # HTTP layer
│   │   ├── auth.py                              # POST /api/register, /api/login, /api/refresh
│   │   ├── wardrobe.py                          # GET/POST /api/wardrobe/items, /common-items
│   │   ├── recommendation.py                    # POST /api/v2/recommendation/start, /next
│   │   ├── v05_recommendation.py                # V05 recommendation endpoints
│   │   ├── tryon.py                             # POST /api/tryon/lowres, /api/tryon/highres
│   │   ├── body.py                              # POST/GET /api/bodies (body reference images)
│   │   ├── upload.py                            # POST /api/upload/image (image processing)
│   │   ├── decision.py                          # POST /api/v1/decision (reasoning engine)
│   │   ├── feedback.py                          # POST /api/feedback (user feedback logs)
│   │   ├── favorites.py                         # POST /api/favorites (heart/pin)
│   │   ├── process.py                           # POST /api/process/segment, /thumbnail
│   │   ├── chat.py                              # Chat-related endpoints
│   │   ├── v05_onboarding.py                    # V05 onboarding endpoints
│   │   ├── admin/                               # Admin-only router
│   │   │   └── common_items.py                  # GET/POST /api/admin/common-items
│   │   └── __init__.py                          # Router registration
│   ├── services/                                # Business logic layer
│   │   ├── wardrobe_service.py                  # Wardrobe CRUD, cloning, categorization
│   │   ├── recommendation_service.py            # Recommendation orchestration
│   │   ├── recommendation_judge_service.py      # Variation cycling, outfit scoring
│   │   ├── tryon_service.py                     # Try-on workflow (lowres/highres)
│   │   ├── body_service.py                      # Body reference management
│   │   ├── llm_service.py                       # Gemini API integration
│   │   ├── fashion_ai_service.py                # AI-powered fashion reasoning
│   │   ├── ai_service.py                        # General AI service
│   │   ├── config_service.py                    # Algorithm config management
│   │   ├── tryon_history_service.py             # Try-on result history
│   │   ├── v05_onboarding_service.py            # V05 onboarding flow
│   │   ├── v05_wardrobe_clone_service.py        # V05 starter wardrobe cloning
│   │   ├── queue_service.py                     # Background job queue
│   │   └── __init__.py
│   ├── repositories/                            # Data access layer
│   │   ├── wardrobe_repository.py               # Wardrobe item queries
│   │   ├── body_repository.py                   # Body reference queries
│   │   ├── recommendation_log_repository.py     # Recommendation log queries
│   │   ├── tryon_repository.py                  # Try-on result queries
│   │   ├── algorithm_config_repository.py       # Algorithm config queries
│   │   └── __init__.py
│   ├── models/                                  # SQLAlchemy ORM layer
│   │   ├── user.py                              # User model (id, email, password, role, metadata)
│   │   ├── token.py                             # RefreshToken model
│   │   ├── wardrobe.py                          # WardrobeItem model (garments, common items)
│   │   ├── body.py                              # BodyPhoto model (reference images)
│   │   ├── recommendation_log.py                # RecommendationLog (audit trail)
│   │   ├── tryon.py                             # TryOnImage model (results, job tracking)
│   │   ├── algorithm_config.py                  # AlgorithmConfig model (ML params)
│   │   ├── decision.py                          # Decision model (reasoning logs)
│   │   ├── favorite.py                          # Favorite model (hearts, pins)
│   │   ├── compositor.py                        # Compositor state (lowres try-on)
│   │   ├── loader.py                            # Loader utilities
│   │   ├── pose_detection.py                    # Pose detection results
│   │   ├── segmentation.py                      # Segmentation masks
│   │   ├── warping.py                           # Warping transforms
│   │   └── __init__.py
│   ├── schemas/                                 # Pydantic request/response models
│   │   ├── auth.py                              # LoginRequest, RegisterRequest, TokenResponse
│   │   ├── wardrobe.py                          # ItemCreateRequest, ItemResponse
│   │   ├── recommendation.py                    # RecommendationRequest, OutfitResponse
│   │   ├── tryon.py                             # TryOnRequest, TryOnResponse
│   │   ├── body.py                              # BodyCreateRequest, BodyResponse
│   │   ├── common.py                            # MessageResponse, PaginatedResponse
│   │   └── __init__.py
│   ├── middleware/                              # ASGI middleware
│   │   └── request_lifecycle.py                 # Request ID tracking, response timing
│   ├── deps/                                    # FastAPI dependencies
│   │   ├── auth.py                              # get_current_user, get_admin_user
│   │   ├── database.py                          # get_db
│   │   └── __init__.py
│   ├── utils/                                   # Shared utilities
│   │   ├── auth_utils.py                        # hash_password, JWT generation/validation
│   │   ├── file_utils.py                        # EphemeralFileManager, file operations
│   │   ├── s3_utils.py                          # S3 upload/download
│   │   ├── image_utils.py                       # Image resizing, encoding
│   │   ├── validation.py                        # MIME/size validators
│   │   ├── rate_limiter.py                      # Rate limiting decorator
│   │   └── __init__.py
│   ├── tests/                                   # Pytest test suite
│   │   ├── conftest.py                          # Fixtures (client, auth_headers, mocks)
│   │   ├── test_app.py                          # Integration tests
│   │   ├── test_auth_unit.py                    # Auth unit tests
│   │   ├── test_auth_integration.py             # Auth flow tests
│   │   ├── test_wardrobe.py                     # Wardrobe CRUD tests
│   │   └── ...
│   ├── commonItems/                             # System common items seeder
│   │   ├── seeder.py                            # Generate SYS_* items
│   │   └── data/                                # Common item definitions
│   ├── docs/                                    # Architecture docs
│   │   ├── RECOMMENDATION_ENGINE_ARCHITECTURE.md
│   │   └── RECOMMENDATION_SIMULATE_JUDGE_ARCHITECTURE.md
│   ├── migrations/                              # Alembic database migrations
│   ├── wardrobe-admin/                          # Admin SPA (nested, NOT a submodule)
│   │   ├── src/
│   │   │   ├── pages/                           # Admin pages/routes
│   │   │   │   ├── Login.tsx                    # Admin login
│   │   │   │   ├── Dashboard.tsx                # Overview
│   │   │   │   ├── Users.tsx                    # User management
│   │   │   │   ├── CommonItems.tsx              # Common items CRUD
│   │   │   │   ├── AlgorithmCockpit.tsx         # ML config
│   │   │   │   ├── V05RecommendationTester.tsx  # Test V05 engine
│   │   │   │   ├── BulkAutoTag.tsx              # Batch item processing
│   │   │   │   └── ...
│   │   │   ├── services/                        # Admin API clients
│   │   │   │   ├── api.ts                       # Axios instance with admin auth
│   │   │   │   ├── authService.ts               # Admin login/logout
│   │   │   │   ├── commonItemsService.ts        # Common items API calls
│   │   │   │   ├── algorithmService.ts          # Config fetch/update
│   │   │   │   ├── recommendationService.ts     # Recommendation testing
│   │   │   │   └── ...
│   │   │   ├── components/                      # Shared admin components
│   │   │   │   ├── MarkdownEditor.tsx           # Rich text editing
│   │   │   │   ├── layout/                      # Layout wrapper
│   │   │   │   └── ...
│   │   │   ├── context/                         # AuthContext for admin session
│   │   │   ├── types/                           # TypeScript interfaces
│   │   │   ├── App.tsx                          # Router setup (pages)
│   │   │   ├── main.tsx                         # React root
│   │   │   └── ...
│   │   ├── index.html                           # SPA entry
│   │   ├── vite.config.ts                       # Vite build config
│   │   ├── package.json                         # npm dependencies
│   │   └── wrangler.toml                        # Cloudflare Pages config
│   ├── API_DOCUMENTATION.md                     # Authoritative endpoint reference
│   ├── MODELS_DOCUMENTATION.md                  # ORM model reference
│   ├── CLAUDE.md                                # Backend conventions & rules
│   ├── app.py                                   # FastAPI entry point
│   ├── requirements.txt                         # Python dependencies
│   └── test_server.py                           # Automated E2E test runner
├── .claude/                                     # Umbrella-level agent configuration
│   ├── agents/                                  # Role agents (mobile-dev, backend-dev, tech-lead, qa-mobile, qa-ui, qa-ux, pm)
│   └── skills/                                  # Role-specific workflows
├── .planning/codebase/                          # GSD documentation (this file)
├── docs/pm/                                     # Product management docs (Linear tracking)
└── logs/                                        # Log files
```

## Directory Purposes

**auxi/ (Mobile App - React Native):**
- Purpose: End-user iOS/Android application for outfit recommendations and wardrobe management
- Contains: React Native screens, TypeScript services, navigation tree, theme, translations
- Key files: `src/screens/HomeScreen.tsx`, `src/services/apiClient.ts`, `src/navigation/AppNavigator.tsx`
- Technology: React Native 0.83, React 19, TypeScript 5, TanStack Query 5, React Navigation 7, yarn

**wardrobe-backend/ (FastAPI Backend):**
- Purpose: Central backend API serving both mobile and admin clients
- Contains: HTTP routers, business logic services, data repositories, ORM models, validation
- Key files: `app.py` (entry), `routers/`, `services/`, `models/`
- Technology: Python 3.9+, FastAPI, SQLAlchemy, Gemini API, S3

**wardrobe-backend/wardrobe-admin/ (Admin SPA):**
- Purpose: Internal operations dashboard for PM/ops (user management, ML config, testing tools)
- Contains: React pages, admin-specific API clients, Ant Design components
- Key files: `src/pages/`, `src/services/`, `src/App.tsx`
- Technology: React 19, TypeScript, Vite, Ant Design 5, Tailwind CSS, Cloudflare Pages deployment

## Key File Locations

**Entry Points:**

- **Backend API**: `wardrobe-backend/app.py` — FastAPI factory with middleware, exception handlers, lifespan
- **Mobile App**: `auxi/src/index.tsx` → `AppNavigator.tsx` (conditional routing based on AuthContext)
- **Admin SPA**: `wardrobe-backend/wardrobe-admin/src/main.tsx` → `App.tsx` (Ant Design + React Router)

**Configuration:**

- **Backend Settings**: `wardrobe-backend/settings.py` (env-based config: LOG_LEVEL, CORS_ORIGINS, DB_URL, GEMINI_MODEL)
- **Backend Database**: `wardrobe-backend/database.py` (SQLAlchemy engine, session factory, Base declarative)
- **Mobile API Config**: `auxi/src/services/apiClient.ts` (BASE_URL hardcoded to localhost:5001/api, TODO: externalize)
- **Admin API Config**: `wardrobe-backend/wardrobe-admin/src/services/api.ts` (axios with admin auth interceptor)
- **Theme**: `auxi/src/theme/theme.ts` (centralized color, typography, spacing tokens)

**Core Logic:**

- **Authentication**: `wardrobe-backend/routers/auth.py` → `services/` → `utils/auth_utils.py`
- **Recommendation**: `wardrobe-backend/routers/recommendation.py` → `services/recommendation_judge_service.py` (variation cycling)
- **Try-On**: `wardrobe-backend/routers/tryon.py` → `services/tryon_service.py` + `services/llm_service.py` (Gemini integration)
- **Wardrobe**: `wardrobe-backend/routers/wardrobe.py` → `services/wardrobe_service.py` (CRUD, cloning, categorization)
- **Mobile Navigation**: `auxi/src/navigation/AppNavigator.tsx` (conditional first-login vs. home flow)
- **Mobile Home**: `auxi/src/screens/HomeScreen.tsx` (recommendation display, TanStack Query)

**Testing:**

- **Backend Unit/Integration**: `wardrobe-backend/tests/` (pytest, conftest.py fixtures)
- **Backend E2E**: `wardrobe-backend/test_server.py` (automated test suite on :5002)
- **Mobile Tests**: `auxi/__tests__/` (Jest, React Testing Library)
- **Maestro QA**: `auxi/maestro/flows/` (YAML test flows, Maestro runner)

## Naming Conventions

**Files:**

- **Backend routers**: `snake_case.py` (e.g., `recommendation.py`, `v05_onboarding.py`)
- **Backend services**: `snake_case.py` ending in `_service.py` (e.g., `recommendation_service.py`)
- **Backend repositories**: `snake_case.py` ending in `_repository.py` (e.g., `wardrobe_repository.py`)
- **Backend models**: `snake_case.py` singular (e.g., `user.py`, `wardrobe.py`)
- **Mobile screens**: `PascalCase.tsx` (e.g., `HomeScreen.tsx`, `WardrobeScreen.tsx`)
- **Mobile components**: `PascalCase.tsx` in subdirectories by type (e.g., `components/atoms/Button.tsx`)
- **Mobile services**: `camelCase.ts` (e.g., `apiClient.ts`, `recommendationService.ts`)
- **Admin pages**: `PascalCase.tsx` in `pages/` (e.g., `Dashboard.tsx`, `CommonItems.tsx`)
- **Admin services**: `camelCase.ts` ending in `Service.ts` (e.g., `commonItemsService.ts`)

**Directories:**

- **Functional domains**: `snake_case/` (e.g., `recommendation/`, `tryon/`, `wardrobe/`)
- **Feature groupings**: `PascalCase/` in mobile (e.g., `screens/`, `components/`)
- **Layer groupings**: `snake_case/` universally (e.g., `routers/`, `services/`, `models/`)

**Types/Interfaces:**

- **Backend Pydantic schemas**: `PascalCase` (e.g., `RecommendationRequest`, `OutfitResponse`)
- **Mobile TypeScript types**: `PascalCase` (e.g., `User`, `AuthResponse`, `WardrobeItem`)
- **Admin TypeScript types**: `PascalCase` (e.g., `CommonItem`, `AdminUser`)

**API Endpoints:**

- **Route naming**: kebab-case paths (e.g., `/api/v2/recommendation/start`, `/api/common-items`)
- **Admin routes**: prefixed with `/api/admin/` (e.g., `/api/admin/common-items`, `/api/admin/users`)

## Where to Add New Code

**New Feature (Mobile):**

- **Screens**: Add `src/screens/NewFeatureScreen.tsx`, register route in `src/types/navigation.ts` AppStackParamList, add stack screen in `src/navigation/AppNavigator.tsx`
- **Services**: Create `src/services/newFeatureService.ts` wrapping axios via `apiClient`
- **Components**: Add to `src/components/features/` if feature-specific, or `src/components/atoms/` if reusable
- **Tests**: Add `__tests__/screens/NewFeatureScreen.test.tsx` matching screen filename

**New Feature (Backend - Public API):**

- **Router**: Create `wardrobe-backend/routers/new_feature.py` with endpoint(s), add to `routers/__init__.py`
- **Service**: Create `wardrobe-backend/services/new_feature_service.py` with business logic
- **Repository**: If new domain entity, create `wardrobe-backend/repositories/new_entity_repository.py`
- **Model**: Create `wardrobe-backend/models/new_entity.py` (SQLAlchemy ORM)
- **Schema**: Create request/response Pydantic models in `wardrobe-backend/schemas/new_feature.py`
- **Tests**: Add `wardrobe-backend/tests/test_new_feature.py` (unit + integration)
- **Documentation**: Update `wardrobe-backend/API_DOCUMENTATION.md` with endpoint details

**New Feature (Admin SPA):**

- **Page**: Create `wardrobe-backend/wardrobe-admin/src/pages/NewPage.tsx`
- **Service**: Create `wardrobe-backend/wardrobe-admin/src/services/newPageService.ts` for API calls
- **Routing**: Add route in `src/App.tsx` (React Router config)
- **Components**: Add admin-specific components in `src/components/`

**New Utility:**

- **Backend**: Add to `wardrobe-backend/utils/` with single responsibility (e.g., `new_utils.py`)
- **Mobile**: Add to `auxi/src/utils/` (e.g., `dateFormatter.ts`, `validator.ts`)

## Special Directories

**wardrobe-backend/commonItems/:**
- Purpose: System-curated wardrobe items (owner_id="SYSTEM") seeding and management
- Generated: No, manually curated
- Committed: Yes, JSON/CSV definitions in `data/`
- Usage: `seeder.py` populates database on startup or manual execution

**auxi/maestro/:**
- Purpose: QA automation flows written in Maestro YAML (deterministic UI testing)
- Generated: Authored by `qa-ui` agent from Figma designs
- Committed: Yes, YAML files
- Usage: `maestro test maestro/flows/<feature>/<name>.yaml` (requires JAVA_HOME)

**wardrobe-backend/migrations/:**
- Purpose: Alembic database schema migrations
- Generated: Yes, via `alembic revision --autogenerate`
- Committed: Yes, version control required
- Usage: `alembic upgrade head` in production deployment

**auxi/docs_agent/:**
- Purpose: Auto-generated backend API reference (consumed by mobile dev)
- Generated: Yes, from backend API_DOCUMENTATION.md
- Committed: Yes
- Usage: Reference docs for service implementation

**wardrobe-backend/docs/:**
- Purpose: Architecture and design docs (recommendation engine, try-on flow)
- Generated: No, manually maintained
- Committed: Yes
- Usage: Team reference, implementation guides

---

*Structure analysis: 2025-05-08*
