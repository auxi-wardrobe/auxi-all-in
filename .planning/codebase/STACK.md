# Technology Stack

**Analysis Date:** 2026-05-08

## Overview

Three-unit monorepo: mobile app (React Native), FastAPI backend, internal admin SPA (React + Vite). All units communicate over HTTP with bearer token auth.

---

## UNIT 1: Mobile App (`auxi/`)

### Languages & Runtime

**Primary:**
- TypeScript 5.8 — all new code, strict mode
- JavaScript/JSX — legacy support only

**Runtime:**
- Node.js ≥20 (required, see `package.json` engines)
- React Native 0.83.1

**Package Manager:**
- **yarn** (preferred over npm; see scripts in `package.json`)
- Lockfile: `yarn.lock`

### Frameworks & Libraries

**Core Framework:**
- React Native 0.83.1 — native mobile framework for iOS and Android
- React 19.2.0 — component library

**Navigation:**
- `@react-navigation/native` 7.1.28 — stack-based routing
- `@react-navigation/native-stack` 7.12.0 — native stack navigator
  - All screens **must** be registered in `src/types/navigation.ts` `AppStackParamList` AND `src/navigation/AppNavigator.tsx` (mandatory)

**HTTP & API:**
- axios 1.13.5 — HTTP client via `src/services/apiClient.ts` (base: `http://localhost:5001/api`)
- React Native Keychain 10.0.0 — secure JWT token storage
- Token stored as generic password, retrieved on every request via interceptor (`src/services/apiClient.ts`)

**Server State Management:**
- TanStack React Query 5.90.21 — async data fetching, caching, and synchronization
  - No Redux, Zustand, or MobX (Query handles server state; AuthContext handles user state)

**UI & Native Bindings:**
- `react-native-svg` 15.15.2 — vector graphics
- `react-native-svg-transformer` 1.5.3 — SVG import as React components
- `react-native-image-picker` 8.2.1 — camera/gallery photo selection
- `react-native-geolocation-service` 5.3.1 — GPS location
- `react-native-safe-area-context` 5.5.2 — safe area insets (notch/home indicator handling)
- `react-native-screens` 4.23.0 — native stack optimization
- `react-native-toast-message` 2.3.3 — toast notifications

**Localization:**
- i18next (referenced in `CLAUDE.md`) — copy and locales in `src/translations/`

### Development & Build

**Compiler & Tooling:**
- Babel 7.25.x with `@react-native/babel-preset` 0.83.1
- Metro bundler (via React Native CLI)
- TypeScript compiler 5.8.3 with strict mode

**Linting & Formatting:**
- ESLint 8.19.0 with `@react-native/eslint-config` 0.83.1
- Prettier 2.8.8 (configured for React Native conventions)
- No auto-fix hooks (code review before commit)

**Testing:**
- Jest 29.6.3 — unit test runner
- `react-test-renderer` 19.2.0 — React component testing
- Maestro (external, YAML-driven) — deterministic UI testing via `testID` selectors

### Configuration Files

**Development:**
- `tsconfig.json` — extends `@react-native/typescript-config`
- `package.json` — scripts: `android`, `ios`, `ios:sim`, `lint`, `start`, `test`
- `.nvmrc` — not present (Node ≥20 required manually)

**Environment:**
- **Hardcoded API base**: `http://localhost:5001/api` in `src/services/apiClient.ts` (TODO: externalize)
- Android emulator: `http://10.0.2.2:5001/api`
- iOS simulator: `http://localhost:5001/api`

### Commands

```bash
yarn install                # Install dependencies
yarn ios:sim               # Launch iOS simulator + app
yarn android              # Run on Android device/emulator
yarn start                # Start Metro bundler
yarn lint                 # ESLint check
yarn test                 # Jest tests
npx tsc --noEmit         # Type check (from umbrella)
```

---

## UNIT 2: Backend (`wardrobe-backend/`)

### Languages & Runtime

**Primary:**
- Python 3.9+ (3.12+ for production, per `pyproject.toml`)
  - Type hints required throughout
  - PEP 8 style

**Runtime & Server:**
- FastAPI 0.109.0+ — async web framework
- Uvicorn 0.27.0+ — ASGI server
- Gunicorn 21.2.0+ — production WSGI wrapper

**Package Manager:**
- pip
- Lockfile: `requirements.txt` (all deps), `requirements-minimal.txt` (Phase 1 core only)
- Alternative: `pyproject.toml` (development-only support for workers-py)

### Frameworks & Libraries

**Web Framework:**
- FastAPI 0.109.0+ — async REST API, automatic OpenAPI docs
- python-multipart 0.0.6 — multipart form parsing for file uploads
- python-dotenv 1.0.0 — environment variable loading
- pydantic 2.0.0+ — request/response validation
- pydantic-settings 2.0.0+ — config management
- email-validator 2.1.0 — email validation

**Database & ORM:**
- SQLAlchemy 2.0.0+ — ORM for SQLite/PostgreSQL
- Alembic 1.12.0 — schema migrations
- Flask-SQLAlchemy 3.1.1 — Flask compatibility layer (legacy support)
- psycopg2-binary 2.9.9+ — PostgreSQL driver
- sqlalchemy-cloudflare-d1 0.3.8 — Cloudflare D1 adapter (emerging)

**Authentication & Security:**
- PyJWT 2.8.0 — JWT token creation/validation
- Argon2-cffi 23.1.0 — password hashing
- cryptography 41.0.0 — encryption utilities

**Caching & Session:**
- redis 5.0.1 — in-memory cache for rate limiting, session storage
- fakeredis 2.20.0+ — testing mock

**Image Processing:**
- Pillow 10.3.0 — image manipulation (resize, crop, format)
- opencv-python-headless 4.8.1+ — computer vision utilities
- numpy 1.26.0 — numerical arrays for image data
- scikit-learn 1.5.0 — K-means clustering for color extraction
- scipy 1.13.0 — scientific computing

**LLM & AI Integration:**
- Google Gemini API (SDK: `google-genai` 0.2.0+)
  - Text-to-image generation (virtual try-on)
  - Image analysis (garment extraction metadata)
  - Multimodal reasoning (outfit decisions)
- LangGraph 0.0.40+ — multi-agent orchestration (chat feature)
- LangChain 0.1.0+ — LLM abstractions
  - `langchain-google-genai` 1.0.0+ — Gemini integration
  - `langchain-groq` 0.1.0+ — Groq integration (alternative LLM)
  - `langchain-openai` 0.1.0+ — OpenAI integration (future)
  - `langchain-core` 0.1.0 — base interfaces

**Cloud Storage:**
- boto3 1.34.0 — AWS S3 client (persistent wardrobe images, try-on results)
- botocore — S3 error handling

**HTTP & External APIs:**
- requests 2.31.0 — synchronous HTTP for external API calls (data fetching, webhooks)

**API Documentation:**
- Flasgger 0.9.7.1 — auto-generated Swagger docs (optional, legacy)

**MCP & Workers:**
- fastmcp 0.1.0 — Model Context Protocol server (LLM tooling)
- workers-py (dev dependency via `pyproject.toml`) — Cloudflare Workers Python runtime

### Testing

**Test Framework:**
- pytest 7.4.3 — test runner
- pytest-cov 4.1.0 — coverage reporting
- pytest-mock 3.12.0 — mocking fixtures

**Test Markers:**
- `@pytest.mark.unit` — isolated logic tests (fast)
- `@pytest.mark.integration` — API endpoint tests (slower, uses DB)
- `@pytest.mark.slow` — skip with `-m "not slow"` (image processing)

**Fixtures:**
- `tests/conftest.py` — shared fixtures: `client`, `auth_headers`, `mock_redis`, `mock_gemini`

### Configuration Files

**Environment & Startup:**
- `config.py` — configuration classes (Development, Production, Testing) loaded from `.env`
- `.env` — local secrets (DATABASE_URL, GOOGLE_STUDIO_KEY, S3_*, etc.)
- `.env.example` — template for required variables
- `.env.production` — production overrides

**Database:**
- SQLite (development): `wardrobe.db`
- PostgreSQL (production): via `DATABASE_URL=postgresql://...`

**Storage:**
- Ephemeral temp: `/tmp/wardrobe_temp/` (TTL: 30 min default, auto-cleanup)
- AWS S3 bucket: `wardrobe-backend` (default), configurable
- CloudFlare R2 (S3-compatible): via `S3_ENDPOINT_URL`

**Redis:**
- URL: `redis://localhost:6379/0` (default), via `REDIS_URL`
- Use cases: rate limiting, session state, recommendation session tracking

### Environment Variables

**Critical:**
- `DATABASE_URL` — PostgreSQL connection string
- `GOOGLE_STUDIO_KEY` — Google Gemini API key (required for extraction, try-on, decision engine)
- `S3_ACCESS_KEY`, `S3_SECRET_KEY` — AWS credentials
- `JWT_SECRET_KEY` — token signing secret
- `REDIS_URL` — cache/session store

**Gemini & LLM:**
- `GEMINI_MODEL` — model ID (default: `gemini-2.0-flash`)
- `GEMINI_IMAGE_MODEL` — image-specific model (default: `gemini-2.0-flash`)
- `GEMINI_TIMEOUT_SECONDS` — API timeout (default: 60)
- `LLM_MODEL` — default LLM (default: `llama-3.3-70b-versatile`)
- `OPENAI_API_KEY` — OpenAI alternative
- `GROQ_API_KEY` — Groq alternative

**Storage & Limits:**
- `MAX_UPLOAD_SIZE_MB` — max file size (default: 3)
- `TEMP_DIR` — temp file directory
- `TEMP_FILE_TTL_MINUTES` — auto-cleanup TTL (default: 30)
- `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT_URL` — S3 config
- `S3_PUBLIC_DOMAIN` — CDN domain (e.g., `*.r2.dev`)

**Rate Limiting & Chat:**
- `RATE_LIMIT_ENABLED` — boolean (default: true)
- `CHAT_ENABLED` — enable chat feature (default: true)
- `CHAT_STREAMING_ENABLED` — streaming responses (default: true)
- `CHAT_RATE_LIMIT_PER_HOUR` — limit (default: 100)
- `CHAT_SESSION_TTL_HOURS` — session duration (default: 1)

### Commands

```bash
pip install -r requirements.txt        # Install all dependencies
pip install -r requirements-minimal.txt # Phase 1 core only

uvicorn app:app --reload --port 5001   # Dev (watch mode)
uvicorn app:app --workers 4 --port 5001 # Prod (4 workers)

pytest                                 # Run all tests
pytest -m unit                        # Fast unit tests only
pytest --cov=. --cov-report=html      # Coverage report
python test_server.py                 # Full e2e test suite on :5002
```

---

## UNIT 3: Admin SPA (`wardrobe-backend/wardrobe-admin/`)

### Languages & Runtime

**Primary:**
- TypeScript ~5.9.3 — all components and services
- JSX/TSX — React component syntax

**Runtime:**
- Node.js ≥18 (implicit via package manager)
- Browser (ES2020+)

**Package Manager:**
- npm (lockfile: `package-lock.json`)
- Note: umbrella uses yarn for mobile, npm for admin SPA

### Frameworks & Libraries

**Core Framework:**
- React 19.2.0 — UI components
- React DOM 19.2.0 — browser rendering
- Vite 7.3.1 — build tool (instant HMR, fast production build)

**Routing & Navigation:**
- react-router-dom 7.13.0 — client-side routing (`/`, `/login`, report pages, etc.)

**HTTP & API:**
- axios 1.13.5 — HTTP client via `src/services/api.ts`
- Base URL: `import.meta.env.VITE_API_URL || 'http://localhost:5001'` (environment-injected at build time)
- Token stored in localStorage, retrieved via interceptor

**Server State Management:**
- TanStack React Query 5.90.21 — async data fetching, mutation handling, refetching

**UI Components & Styling:**
- Ant Design (antd) 6.3.0 — professional UI component library
- Ant Design X 1.2.0 (not detected in package.json; referenced in user memory)
- Tailwind CSS 4.1.18 — utility-first styling
- `@tailwindcss/postcss` 4.1.18 — CSS processing
- `@tailwindcss/typography` 0.5.19 — prose styling
- Lucide React 0.564.0 — icon library (alternative to Phosphor)
- `@phosphor-icons/react` 2.1.10 — icon set
- classnames 2.5.1 — conditional class binding
- PostCSS 8.5.6 — CSS transformation
- Autoprefixer 10.4.24 — vendor prefix injection

**Data Visualization:**
- Recharts 3.7.0 — composable React chart library (bar, line, pie, area)

**Content:**
- react-markdown 10.1.0 — render markdown as React components

**Fonts:**
- `@fontsource/space-grotesk` 5.2.10 — system font (Space Grotesk)

### Development & Build

**Build Tool:**
- Vite 7.3.1 — lightning-fast build, HMR, optimized production bundle
- `@vitejs/plugin-react` 5.1.1 — JSX/Fast Refresh support

**Type Checking & Linting:**
- TypeScript 5.9.3 — strict type checking
- ESLint 9.39.1 with `eslint-plugin-react-hooks` and `eslint-plugin-react-refresh`
- TypeScript ESLint support: `@typescript-eslint/*` 8.48.0

**Deployment:**
- Cloudflare Workers via Wrangler 2 (implied)
- Deployed as single-page application (Wrangler config: `html_handling: "force-trailing-slash"`, SPA routing)

### Configuration Files

**Build & Development:**
- `vite.config.ts` — minimal Vite config with React plugin
- `tsconfig.json` — extends base config
- `tsconfig.app.json` — app-specific TypeScript config
- `tsconfig.node.json` — Vite config TypeScript
- `postcss.config.js` — PostCSS processors (Tailwind, Autoprefixer)
- `tailwind.config.js` — Tailwind configuration
- `eslint.config.js` — ESLint rules

**Deployment:**
- `wrangler.jsonc` — Cloudflare Workers config
  - `compatibility_date: "2024-03-20"`
  - Assets: `./dist` directory
  - SPA routing: `not_found_handling: "single-page-application"`
  - Build: injects `VITE_API_URL` environment variable
  - **Production build command**: `VITE_API_URL=https://wardrobe-backend-production-c8d9.up.railway.app npm run build`

**Environment:**
- `import.meta.env.VITE_API_URL` — backend API URL (Vite runtime constant, NOT changeable at runtime)
- Default: `http://localhost:5001`
- Set at build time in `wrangler.jsonc` build command
- `.env` files not used (Vite uses compile-time substitution)

### Commands

```bash
npm install                    # Install dependencies
npm run dev                    # Vite dev server (localhost:5173)
npm run build                  # Production build to ./dist
npm run build:prod             # Production build with production API URL
npm run deploy                 # Deploy to Cloudflare Workers
npm run deploy:prod            # Build & deploy with prod API
npm run preview                # Local preview of production build
npm run preview:cloudflare     # Preview via Wrangler
npm run lint                   # ESLint check
```

---

## Cross-Unit Communication

```
Mobile (auxi/)
  ├─ axios via src/services/apiClient.ts
  └─> wardrobe-backend :5001/api/* (public endpoints)

Admin SPA (wardrobe-admin/)
  ├─ axios via src/services/api.ts
  └─> wardrobe-backend :5001/api/* (public)
       + /admin/* (admin role enforced server-side)

Both clients:
  ├─ Token: JWT stored (Keychain on RN, localStorage on web)
  ├─ Auth: Bearer token on every request via interceptor
  └─ No shared SDK — API_DOCUMENTATION.md is the contract
```

---

## Key Platform Requirements

**Development:**
- **Mobile**: iOS 13.4+ or Android 7.0+, Simulator/Emulator
- **Backend**: Python 3.9–3.12 (3.13 has rembg/mediapipe compatibility issues)
- **Admin**: Node.js ≥18, modern browser (ES2020+)

**Production:**
- **Mobile**: App Store (iOS), Google Play (Android)
- **Backend**: Railway (current hosting per config comments), or self-hosted with Uvicorn/Gunicorn
- **Admin**: Cloudflare Workers (static site + SPA routing)

---

*Stack analysis: 2026-05-08*
