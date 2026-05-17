# Auxi Codebase Summary

## Repository Topology

```
wardrobe_project/              ← Umbrella repo (git root)
├── auxi/                      ← Submodule: React Native mobile app
├── wardrobe-backend/          ← Submodule: FastAPI backend + admin SPA
│   └── wardrobe-admin/        ← Internal admin dashboard (NOT a submodule)
├── auxi-web/                  ← Marketing website (Astro)
├── scripts/                   ← Shared utilities (qa-boot.sh, qa-stop.sh)
├── docs/                      ← Project documentation (THIS LOCATION)
├── plans/                     ← Implementation plans + phase files
└── .claude/                   ← Agent + skill configurations
```

## Per-Repo Overview

### auxi/ (React Native Mobile)

**Purpose:** User-facing mobile app for wardrobe management and outfit recommendations.

**Language:** TypeScript 5.8 · React 19 · React Native 0.83.1

**Package Manager:** yarn

**Key Directories:**
- `src/screens/` — 15 screen components (Welcome, Auth, Home, Wardrobe, ItemDetail, Body, Settings, Try-On, etc.) + 4 onboarding variants
- `src/services/` — API clients (apiClient, auth, recommendation, wardrobe, item, favorite, try-on, body, weather)
- `src/components/` — Reusable components (atoms, layout, features, primitives)
- `src/navigation/` — React Navigation routing (AppNavigator, AuthNavigator, 7.x native-stack)
- `src/context/` — AuthContext (user, login, register, onboarding state)
- `src/theme/` — Design tokens, colors, typography
- `src/translations/` — i18n locales (i18next framework)
- `src/types/` — TypeScript definitions (navigation params, API schemas)
- `src/utils/` — Helpers (formatting, validation, device info)
- `maestro/` — QA test flows (YAML-based UI automation)
- `docs/` — Mobile-specific documentation (icons, MCP setup)

**Key Files:**
- `App.tsx` — Root entry point (AppNavigator, AuthContext provider)
- `src/services/apiClient.ts` — Axios base URL + interceptors (DEV: `http://localhost:5001/api`, PROD: Railway URL)
- `src/services/recommendationService.ts` — V05 recommendation API integration
- `src/services/authService.ts` — JWT management (login, register, token refresh)
- `src/navigation/AppNavigator.tsx` — **MANDATORY: register new screens here + types/navigation.ts**
- `package.json` — Dependencies (TanStack Query 5, React Navigation 7, Sentry, i18next)

**Screens (15 total):**
1. WelcomeScreen
2. LocationPermissionScreen
3. GenderPreferenceScreen (legacy)
4. StylePreferenceScreen (legacy)
5. PreferenceSeedScreen (new onboarding)
6. FitPreferenceScreen (new)
7. OutfitApprovalScreen (new)
8. OnboardingConfirmationScreen (new)
9. HomeScreen (current) + _HomeScreen (legacy, ~941 LOC, pending deletion)
10. WardrobeScreen
11. ItemDetailScreen
12. BodyScreen
13. SettingsScreen
14. LoginScreen
15. RegisterScreen
+ Try-On variants

**Code Stats:** ~11,531 LOC TypeScript + JSX

**Test Framework:** Jest (configured in `jest.config.js`)

**Linting:** ESLint (4 errors, 3 warnings, mostly in legacy `_HomeScreen.tsx`)

**Verification:**
```bash
npx tsc --noEmit              # TypeScript check (legacy errors expected)
yarn lint                      # ESLint (baseline: 4 errors, 3 warnings)
yarn ios:sim                   # iOS simulator smoke test
maestro test maestro/flows/... # Individual QA flow test
```

---

### wardrobe-backend/ (FastAPI Backend)

**Purpose:** Recommendation engine, user authentication, image processing, admin API, data persistence.

**Language:** Python 3.11 · FastAPI · SQLAlchemy 2.0

**Package Manager:** pip

**Key Directories:**
- `routers/` — HTTP endpoints grouped by feature (auth, wardrobe, upload, process, try-on, recommendation, v05_recommendation, v05_onboarding, v05_outcome, body, favorites, weather, admin/*)
- `services/` — Business logic (user service, wardrobe service, recommendation service, image service, etc.)
- `repositories/` — Database access layer (UserRepository, WardrobeRepository, etc.)
- `models/` — SQLAlchemy ORM models (User, WardrobeItem, Body, TryOnImage, Favorite, etc.)
- `schemas/` — Pydantic request/response schemas
- `middleware/` — Request lifecycle (X-Request-Id, response time, auth token extraction)
- `blueprints/` — Feature modules (recommendation engine, try-on generation)
- `utils/` — Helpers (file handling, validation, rate limiting, S3, auth utilities)
- `migrations/` — Alembic database migrations
- `tests/` — Unit + integration tests
- `scripts/` — One-off utilities (create_admin.py, seed_common_items.py)
- `docs/` — Backend documentation

**Key Files:**
- `app.py` — FastAPI factory + lifespan management
- `config.py` — Environment-based configuration
- `deps.py` — FastAPI dependency injection (get_db, get_current_user)
- `blueprints/recommendation/engine_v05.py` — V05 recommendation pipeline (6-layer, ~400 LOC)
- `blueprints/recommendation/v2_engine.py` — V2 stateful recommendation engine
- `services/gemini_service.py` — Google Gemini integration (background removal, try-on generation)
- `utils/file_utils.py` — EphemeralFileManager (temporary file handling with auto-cleanup)
- `utils/validation.py` — File/request validation (MIME types, size limits)
- `utils/rate_limiter.py` — Rate limiting decorator
- `API_DOCUMENTATION.md` — **MANDATORY: Full API contract (update when modifying routes)**

**Recommendation Engine (V05):**
```
Input: user_id, occasion, weather, time
  ↓
1. Pool generation (user's items + common items)
  ↓
2. Silhouette filtering (fit-aware ranking)
  ↓
3. Color harmonization (complementary/monochrome/analogous)
  ↓
4. Layering system (base → middle → outer)
  ↓
5. Footwear matching (style + formality)
  ↓
6. Accessory suggestion
  ↓
Output: outfit (5–7 items) + explanation
```

**Redis Integration:**
- Pool caching: 1-hour TTL per user
- Session tracking: active recommendation sessions
- Rate limit counters: requests per minute per user

**Database Models:**
- User, WardrobeItem, Body, TryOnImage, Favorite, RefreshToken, RecommendationLog, V05OutcomeEvent, V05OutfitEvalScore, AlgorithmConfig

**Authentication:**
- JWT Bearer tokens (15-min access, 7-day refresh)
- Argon2 password hashing
- `@require_auth` decorator + `get_current_user` dependency

**Deployment:**
- Docker image (Python 3.11-slim)
- Railway platform (production)
- Gunicorn 4 workers on port 5001
- PostgreSQL database (RDS)
- Redis for caching (Upstash or similar)

**Verification:**
```bash
python test_server.py                    # Automated e2e test runner (port 5002)
pytest                                   # All tests
pytest --cov=. --cov-report=html         # Coverage report
pytest -m unit                           # Unit tests only
pytest -m integration                    # Integration tests only
```

---

### wardrobe-admin/ (Admin SPA)

**Purpose:** Internal operations dashboard for admins to manage users, common items, ML config, and recommendation testing.

**Language:** TypeScript 5.9 · React 19 · Vite 7

**Package Manager:** npm

**Key Directories:**
- `src/pages/` — React Router pages (Dashboard, Users, UserDetail, CommonItems, BulkAutoTag, AlgorithmCockpit, RecommendationTest, RecommendationEvaluation, ValenRecommendation)
- `src/services/` — API clients (axios-based, calls `wardrobe-backend/routers/admin/*`)
- `src/context/` — AuthContext (admin user state)
- `src/components/` — Reusable UI components
- `src/utils/` — Helpers

**Stack:** React 19 · Vite 7 · TypeScript 5.9 · Tailwind CSS 4 · Ant Design 6 · TanStack Query 5 · React Router 7

**Key Files:**
- `vite.config.ts` — Vite bundler config
- `wrangler.jsonc` — Cloudflare Workers deployment config
- `worker.js` — Cloudflare Workers entry point

**Backend Pairing:**
- `wardrobe-backend/routers/admin/config.py` — `/admin/configs/*` (versioned recommendation config)
- `wardrobe-backend/routers/admin/common_items.py` — `/admin/common-items/*` (CRUD + AI tagging)
- `wardrobe-backend/routers/admin/tagger.py` — `/admin/common-items/auto-tag-all` (Gemini bulk tagging)
- `wardrobe-backend/routers/admin/users.py` — `/admin/users/*` (user management)
- `wardrobe-backend/routers/admin/simulation.py` — `/admin/simulation/*` (recommendation testing)

**Deployment:**
```bash
npm run build:prod     # Build for production backend URL
npm run deploy:prod    # Deploy to Cloudflare via Wrangler
```

---

### auxi-web/ (Marketing Site)

**Purpose:** Public marketing website for the Auxi app.

**Language:** TypeScript · Astro 6 · Tailwind CSS 4

**Package Manager:** pnpm

**Deployment:** Cloudflare Pages (https://auxi.app)

**Key Files:**
- `src/pages/` — Astro route components (index, styleguide)
- `src/layouts/` — Page templates
- `astro.config.mjs` — Astro configuration

---

## Data Flow for Key User Journeys

### 1. Upload Item → Get Recommendation → Try-On

```
Mobile App (auxi/)
  ├─ User uploads garment photo
  ├─ POST /api/upload/image
  │  └─ wardrobe-backend/routers/upload.py
  │     └─ Gemini background removal + auto-tagging
  │     └─ S3 upload (or ephemeral if temp)
  │     └─ Return WardrobeItem
  │
  ├─ User presses "Get Recommendation"
  ├─ GET /api/recommendation?occasion=casual&weather=sunny
  │  └─ wardrobe-backend/blueprints/recommendation/engine_v05.py
  │     ├─ Pool generation (Redis cache hit or rebuild)
  │     ├─ 6-layer pipeline (silhouette, color, layering, footwear, accessory)
  │     └─ Return outfit + explanation
  │
  ├─ User taps "Try-On"
  ├─ POST /api/tryon/highres (async job submission)
  │  └─ wardrobe-backend/services/gemini_service.py
  │     └─ High-res virtual try-on generation
  │     └─ Return job_id for polling
  │
  └─ GET /api/tryon/result/{job_id} (poll until ready)
     └─ Return presigned S3 URL (or base64 inline)
```

### 2. User Authentication & Token Refresh

```
Mobile App
  ├─ POST /api/auth/register (email, password)
  │  └─ wardrobe-backend/routers/auth.py
  │     └─ Hash password (Argon2), create User, issue tokens
  │
  ├─ Save tokens to react-native-keychain
  │  └─ accessToken (15 min)
  │  └─ refreshToken (7 days)
  │
  ├─ Subsequent requests: Authorization: Bearer {accessToken}
  │  └─ middleware/request_lifecycle.py extracts token into request.state
  │  └─ deps.get_current_user validates & fetches User
  │
  └─ Token expiry? POST /api/auth/refresh
     └─ Validate refreshToken
     └─ Issue new accessToken
```

### 3. Admin Updates Recommendation Config

```
Admin Dashboard (wardrobe-admin/)
  ├─ Admin navigates to AlgorithmCockpit page
  ├─ GET /admin/configs (fetch current versioned config)
  │  └─ wardrobe-backend/routers/admin/config.py
  │     └─ Return config_id, version, weights, thresholds
  │
  ├─ Admin tweaks axis weights (silhouette weight 0.4 → 0.5)
  ├─ POST /admin/configs (new version creation)
  │  └─ Backend records new config version
  │  └─ Redis cache invalidated for all users
  │
  ├─ Admin clicks "Promote to Active"
  ├─ PUT /admin/configs/{config_id}/promote
  │  └─ Sets this config as active
  │  └─ All future recommendations use new weights
  │
  └─ Mobile App (next recommendation request)
     └─ GET /api/recommendation (uses new config)
        └─ engine_v05.py reads active config from DB/cache
```

---

## Environment Variables

### Backend (.env)

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/wardrobe

# Auth
JWT_SECRET_KEY=<random-256-bit-hex>
JWT_ACCESS_TOKEN_EXPIRY=900  # 15 minutes
JWT_REFRESH_TOKEN_EXPIRY=604800  # 7 days

# Gemini AI
GOOGLE_STUDIO_KEY=<Google Cloud API key>

# S3/R2 (image storage)
AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>
AWS_S3_BUCKET=wardrobe-images
AWS_REGION=us-east-1

# Redis (caching)
REDIS_URL=redis://localhost:6379/0

# Sentry (error tracking)
SENTRY_DSN=https://...@sentry.io/...

# Email (optional)
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@auxi.app
SMTP_PASSWORD=<app-password>

# Environment
DEBUG=false
ENVIRONMENT=production
```

### Mobile (.env via react-native-config)

```bash
# API Base URL
API_BASE_URL=https://wardrobe-backend-production-c8d9.up.railway.app/api

# Sentry
SENTRY_DSN=https://...@sentry.io/...

# App Version
APP_VERSION=0.5.0
```

---

## Development Prerequisites

### Backend Setup

```bash
cd wardrobe-backend

# Python 3.11+
python --version  # Verify 3.11+

# Virtual environment
python -m venv .venv
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Create .env from .env.example
cp .env.example .env
# Edit .env with local DB, Redis, Gemini key

# Database initialization
alembic upgrade head

# Run server
uvicorn app:app --reload --port 5001
```

### Mobile Setup

```bash
cd auxi

# Node 18+
node --version

# Install dependencies
yarn install

# Start Metro bundler
yarn start

# In another terminal: launch iOS simulator
yarn ios:sim

# Or Android emulator
yarn android:emu
```

### Admin Dashboard Setup

```bash
cd wardrobe-backend/wardrobe-admin

npm install

# Dev server (port 5173)
npm run dev

# Production build (for Cloudflare)
npm run build:prod
npm run deploy:prod
```

---

## File Count & Code Metrics

| Repo | Language | File Type | Count | Notes |
|------|----------|-----------|-------|-------|
| **auxi/** | TypeScript/JSX | src/** | ~80 | Screens, services, components |
| **auxi/** | YAML | maestro/** | ~15 | QA test flows |
| **wardrobe-backend/** | Python | blueprints/, services/, routers/ | ~60 | API logic, ML pipeline |
| **wardrobe-backend/** | Python | tests/ | ~30 | Unit + integration tests |
| **wardrobe-admin/** | TypeScript/JSX | src/** | ~40 | Admin pages, services, components |
| **auxi-web/** | TypeScript/Astro | src/** | ~20 | Landing, styleguide |

---

## Key Integration Points

### Mobile ↔ Backend Contract
- **Base URL:** Backend running on `:5001/api` (dev) or Railway (prod)
- **Authentication:** Bearer token in Authorization header
- **Content-Type:** application/json
- **Request tracing:** X-Request-Id header (auto-generated by backend, echoed in response)
- **Contract source:** `API_DOCUMENTATION.md` in wardrobe-backend/

### Backend ↔ Admin Contract
- **Base URL:** Same backend, `/admin/*` routes
- **Authentication:** Bearer token (admin role enforced server-side)
- **Content-Type:** application/json

### External Dependencies
- **Gemini API** — Image extraction, virtual try-on, bulk tagging
- **PostgreSQL** — User data, wardrobe items, recommendations
- **Redis** — Pool caching, session tracking, rate limits
- **S3/R2** — Persistent garment image storage
- **Sentry** — Error tracking (mobile + backend)
- **Cloudflare** — Admin SPA + marketing site hosting

---

## CI/CD & Deployment

### Backend (Railway)
- Docker image built from `Dockerfile`
- Automatic deploy on main branch push
- Environment variables managed via Railway dashboard
- Gunicorn 4 workers on port 5001

### Mobile (TestFlight/Google Play)
- GitHub Actions CI (TypeScript check, lint, build)
- Manual promotion to TestFlight or Google Play
- Sentry release tracking

### Admin (Cloudflare)
- `npm run deploy:prod` uploads via Wrangler
- Workers hosting (edge runtime)

### Web (Cloudflare Pages)
- GitHub Actions CI
- Automatic deploy on main push
- Astro static generation

---

## How to Navigate the Codebase

1. **Adding a new mobile screen?**
   - Create component in `auxi/src/screens/`
   - Register in `auxi/src/types/navigation.ts` (AppStackParamList)
   - Add route to `auxi/src/navigation/AppNavigator.tsx`
   - Call the API via `src/services/` (never import axios directly)

2. **Adding a new API endpoint?**
   - Create router in `wardrobe-backend/routers/new_feature.py`
   - Use service/repository pattern (logic → services/, DB queries → repositories/)
   - Add Pydantic schema in `schemas/`
   - **Update `API_DOCUMENTATION.md` immediately**
   - Sync mobile's `apiClient` service

3. **Modifying recommendation engine?**
   - Edit `wardrobe-backend/blueprints/recommendation/engine_v05.py`
   - Test locally: `pytest tests/test_v05_engine.py`
   - Check latency doesn't exceed 8s (p95)
   - Admin can hot-swap config via AlgorithmCockpit

4. **Adding admin feature?**
   - Create page in `wardrobe-admin/src/pages/`
   - Wire API client calls in `src/services/`
   - Add backend route in `wardrobe-backend/routers/admin/`
   - Test against local backend, then deploy

---

## Notes for Developers

- **Never commit .env files or secrets** — Use .env.example for documentation
- **Run tests before push** — `python test_server.py` for backend, `yarn lint && npx tsc --noEmit` for mobile
- **Respect ownership boundaries** — mobile-dev owns auxi/, backend-dev owns wardrobe-backend/, tech-lead coordinates
- **Update API_DOCUMENTATION.md** — Contract drift kills integration; it's mandatory
- **testID discipline** — Every interactive element in mobile must have testID for Maestro automation
