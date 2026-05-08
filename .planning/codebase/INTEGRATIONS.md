# External Integrations

**Analysis Date:** 2026-05-08

---

## APIs & External Services

### Google Gemini (AI/ML)

**Purpose:** Garment image segmentation, metadata extraction, high-res virtual try-on generation, outfit decision reasoning

**SDK/Client:** `google-genai` 0.2.0+ (via LangChain)

**Auth:**
- Env var: `GOOGLE_STUDIO_KEY` (required)
- Method: API key header authentication

**Model Configuration:**
- Main model: `GEMINI_MODEL` (default: `gemini-2.0-flash`)
- Image-specific: `GEMINI_IMAGE_MODEL` (default: `gemini-2.0-flash`)
- Timeout: `GEMINI_TIMEOUT_SECONDS` (default: 60)

**Integrations:**
- `blueprints/tryon/gemini_service.py` — GeminiService, GeminiTryOnService, GeminiJobManager
- `routers/process.py` — garment extraction endpoint (`POST /process/extract`)
- `routers/tryon.py` — high-res try-on (`POST /tryon/highres`)
- `blueprints/decision/engine.py` — outfit reasoning + variation explanations
- `commonItems/gemini_tagger.py` — automated common item tagging

**Rate Limits:**
- Extraction & try-on: 5 req/min
- Decision engine: 20 req/min

**Fallback:** If not configured, endpoints return 503 with descriptive error

---

### Google Gemini - Alternative LLMs (LangChain)

**Purpose:** Multi-agent outfit reasoning (chat feature), intent detection

**SDKs:**
- `langchain-google-genai` 1.0.0+ — Gemini integration
- `langchain-groq` 0.1.0+ — Groq (`llama-3.3-70b-versatile`) as default
- `langchain-openai` 0.1.0+ — OpenAI (future)

**Auth:**
- Gemini: `GOOGLE_STUDIO_KEY`
- Groq: `GROQ_API_KEY` (optional, if switching from Gemini)
- OpenAI: `OPENAI_API_KEY` (optional, future)

**Config:**
- `LLM_MODEL` — active model (default: `llama-3.3-70b-versatile` via Groq)
- Set to `gemini-1.5-flash` + `GOOGLE_STUDIO_KEY` to use Gemini

**Integrations:**
- `blueprints/chat/agent.py` — multi-agent chat orchestration via LangGraph
- `routers/chat.py` — chat endpoint (`POST /api/v1/chat/send`)
- Multi-agent nodes: user intent, context fetching, decision logic, response generation

**Rate Limits:**
- Chat: `CHAT_RATE_LIMIT_PER_HOUR` (default: 100)
- Session TTL: `CHAT_SESSION_TTL_HOURS` (default: 1)

---

## Data Storage

### PostgreSQL (Production Database)

**Purpose:** User profiles, wardrobe items, outfit history, session state

**Connection:** Environment variable `DATABASE_URL` (e.g., `postgresql://user:pass@host/dbname`)

**Client:** SQLAlchemy 2.0.0+ ORM with psycopg2 driver

**Migrations:** Alembic for schema management

**Fallback (Development):** SQLite `wardrobe.db`

---

### Redis

**Purpose:** Rate limiting, chat session state, recommendation session tracking, temporary job results

**Connection:** `REDIS_URL` (default: `redis://localhost:6379/0`)

**Client:** `redis` 5.0.1

**Test Mock:** `fakeredis` 2.20.0+ (in-memory mock for testing)

**Usage:**
- `utils/rate_limit.py` — rate limit checks and counter increments
- `utils/recommendation_session.py` — session state for recommendation flows
- `utils/chat_state.py` — chat message history and session context
- `utils/decision_state.py` — outfit decision session state

---

### AWS S3 (Persistent Image Storage)

**Purpose:** Store wardrobe item images, try-on results, body reference photos (long-term retention)

**Bucket:** `wardrobe-backend` (default, configurable)

**SDK/Client:** `boto3` 1.34.0 with botocore error handling

**Auth:**
- `S3_ACCESS_KEY` (env var)
- `S3_SECRET_KEY` (env var)

**Configuration:**
- `S3_REGION` (default: `us-east-1`)
- `S3_ENDPOINT_URL` (optional, for S3-compatible services like CloudFlare R2)
- `S3_PUBLIC_DOMAIN` (optional, CDN domain for public URLs, e.g., `*.r2.dev`)
- `S3_URL_EXPIRATION` (default: 30 days in seconds)

**CloudFront Integration (optional):**
- `CLOUDFRONT_KEY_PAIR_ID` — for signed URLs (private distribution)
- `CLOUDFRONT_PRIVATE_KEY` — PEM-encoded key or path

**Integrations:**
- `utils/s3_utils.py` — S3Manager, upload_to_s3(), delete_from_s3(), get_presigned_url()
- `routers/upload.py` — wardrobe item upload
- `routers/tryon.py` — try-on result storage
- `commonItems/upload_pngs_to_r2.py` — batch upload common item images

**Ephemeral vs. Persistent:**
- **Ephemeral**: Temp processing files (deleted after 30 min) via `EphemeralFileManager` in `/tmp/wardrobe_temp/`
- **Persistent**: User wardrobe items, body photos, try-on results → S3

---

### Cloudflare D1 (Emerging, Experimental)

**Purpose:** Serverless database alternative for Cloudflare Workers deployment

**SDK:** `sqlalchemy-cloudflare-d1` 0.3.8 (experimental)

**Status:** Included in requirements but not currently active (PostgreSQL is primary)

**Config Key:** (none yet; reserved for future Workers migration)

---

## File Storage

### Local Ephemeral Storage

**Location:** `/tmp/wardrobe_temp/` (configurable via `TEMP_DIR`)

**Purpose:** Temporary processing of uploaded images (segmentation, resizing, etc.)

**TTL:** `TEMP_FILE_TTL_MINUTES` (default: 30), auto-cleanup runs every 15 minutes

**Manager:** `EphemeralFileManager` context manager (auto cleanup on exit)

**Upload Limits:**
- Regular images: 3 MB (configurable `MAX_UPLOAD_SIZE_MB`)
- Selfies: 5 MB
- Thumbnails: 500 KB
- Allowed MIME types: `image/jpeg`, `image/png`, `image/webp` (no GIF animated)

**Security:**
- Generated filenames (UUID-based, no user-supplied names)
- Validated MIME type + file size before saving
- Auto-deleted regardless of success/failure

---

## Authentication & Identity

### JWT (Custom Implementation)

**Provider:** Custom (no external auth provider)

**Token Generation:**
- Created on login (`POST /api/v1/auth/login`)
- Issued with user ID, email, role embedded

**Token Storage:**
- **Mobile (RN)**: React Native Keychain (hardware-backed when available)
- **Admin SPA**: localStorage (browser)

**Token Validation:**
- `PyJWT` library with `HS256` algorithm
- Secret: `JWT_SECRET_KEY` (env var, required in production)
- Access token expiry: 15 minutes
- Refresh token expiry: 7 days
- Token type claim: `access` or `refresh` (validated on decode)

**Interceptors:**
- **Mobile** (`src/services/apiClient.ts`): axios request interceptor fetches token from Keychain, adds `Authorization: Bearer <token>`
- **Admin SPA** (`src/services/api.ts`): axios request interceptor retrieves from localStorage, adds bearer token

**Middleware:**
- `middleware/request_lifecycle.py` — extracts bearer token from `Authorization` header into `request.state`
- `Depends(get_current_user)` — FastAPI dependency that validates JWT and returns User

**Password Security:**
- Hashed with Argon2 via `argon2-cffi` 23.1.0
- Minimum 8 characters

**No External Providers:** No OAuth (Google, Apple, GitHub), no SAML, no OIDC

---

## Monitoring & Observability

### Request ID Tracking

**Generator:** `middleware/request_lifecycle.py` auto-generates UUID if missing

**Propagation:** Exposed on every response via `X-Request-Id` header

**Use Cases:** Error logging, request tracing, debugging

### Response Time Tracking

**Header:** `X-Response-Time` (e.g., `"15.23ms"`)

**Generator:** Middleware calculates elapsed time between request start and response

### Error Responses

**Format:** `{ "error": "Human-readable message", "request_id": "UUID" }`

**Details:** Never leak stack traces in production; log full trace server-side only

### Logging

**Framework:** Python `logging` module (implicit via FastAPI/Uvicorn)

**Level:** Configurable via `LOG_LEVEL` env var (default: `INFO`)

**Feedback Logs:**
- Directory: `FEEDBACK_LOG_DIR` (default: `logs/feedback/`)
- Purpose: Store anonymized user feedback on outfit recommendations

**Secret Handling:** Tokens never logged; use `[REDACTED]` placeholder

---

### Error Tracking & Alerts

**Status:** Not detected in codebase

**Recommendation:** Consider Sentry, Rollbar, or similar for production

---

## CI/CD & Deployment

### Backend Hosting

**Current:** Railway (per `wrangler.jsonc` build command: `wardrobe-backend-production-c8d9.up.railway.app`)

**Alternative:** Self-hosted with Uvicorn/Gunicorn on any Python-supporting platform

**Database Migration:** Alembic-managed (run `alembic upgrade head` on deploy)

### Admin SPA Deployment

**Platform:** Cloudflare Workers (edge-deployed static SPA)

**Build & Deploy Tool:** Wrangler 2 (`npm run deploy`, `npm run deploy:prod`)

**Build Process:**
1. TypeScript compilation
2. Vite bundling (tree-shaking, minification)
3. Inject `VITE_API_URL` environment variable
4. Deploy `dist/` directory to Cloudflare

**Commands:**
- `npm run build` — development build (API: `http://localhost:5001`)
- `npm run build:prod` — production build (API: `https://wardrobe-backend-production-c8d9.up.railway.app`)
- `npm run deploy` — deploy current build
- `npm run deploy:prod` — build + deploy in one step

**Routing:** SPA fallback enabled (`force-trailing-slash`, `single-page-application` mode)

### Mobile App Deployment

**iOS:** App Store (requires provisioning profile, certificates)

**Android:** Google Play (requires keystore)

**Build Tools:** React Native CLI, EAS Build (if used via Expo, not detected)

**No CI/CD detected:** Manual builds or local GitHub Actions (not in repo)

---

## Environment Configuration

### Required Env Vars for Full Operation

**Core:**
- `DATABASE_URL` — PostgreSQL connection (production)
- `GOOGLE_STUDIO_KEY` — Gemini API key
- `JWT_SECRET_KEY` — JWT signing secret
- `REDIS_URL` — Redis connection

**S3 Storage:**
- `S3_ACCESS_KEY`
- `S3_SECRET_KEY`
- `S3_BUCKET` (default: `wardrobe-backend`)
- `S3_REGION` (default: `us-east-1`)

**Optional:**
- `S3_ENDPOINT_URL` — S3-compatible service (e.g., CloudFlare R2)
- `S3_PUBLIC_DOMAIN` — CDN domain for public URLs
- `CLOUDFRONT_KEY_PAIR_ID`, `CLOUDFRONT_PRIVATE_KEY` — for signed CloudFront URLs
- `GROQ_API_KEY` — Groq LLM (if switching from default)
- `OPENAI_API_KEY` — OpenAI (future)

**Feature Flags:**
- `CHAT_ENABLED` (default: true)
- `CHAT_STREAMING_ENABLED` (default: true)
- `RATE_LIMIT_ENABLED` (default: true)
- `USE_REMBG` (default: false; background removal disabled)

**Upload & Processing:**
- `MAX_UPLOAD_SIZE_MB` (default: 3)
- `TEMP_DIR` (default: `/tmp/wardrobe_temp`)
- `TEMP_FILE_TTL_MINUTES` (default: 30)

---

### Secrets Location & Management

**Development:**
- `.env` file (git-ignored)
- Not committed to repo
- Template: `.env.example`

**Production:**
- Environment variables set via Cloudflare Workers, Railway, or deployment platform
- `.env.production` — production-specific overrides (if needed)
- Secrets managed via platform dashboards or `wrangler secret set`

**No integrated secret manager:** Vault, AWS Secrets Manager, etc. not configured

---

## Webhooks & Callbacks

### Incoming Webhooks

**Status:** Not detected

**Reserved:** Chat streaming callbacks could be added

### Outgoing Webhooks

**Status:** None detected

**Reserved:** Event notifications (item added, outfit liked, etc.) for future integrations

---

## Third-Party Integrations (Detected in Config but Not Active)

### Celery (Async Job Queue)

**Status:** Commented out in `requirements.txt` (line 64)

**Purpose:** For future long-running tasks (batch tagging, image processing)

**Not Active:** Synchronous endpoints currently (Gemini try-on uses async jobs in Redis)

---

### MCP (Model Context Protocol)

**SDK:** `fastmcp` 0.1.0

**Purpose:** LLM tooling, function calling for Gemini (emerging standard)

**Status:** Dependency included but integration not fully visible in codebase (likely in agent setup)

---

### Cloudflare Workers Runtime

**SDK:** `workers-py` (dev dependency in `pyproject.toml`)

**Purpose:** Potential serverless Python execution on Cloudflare

**Status:** Reserved for future Workers migration (D1 database is part of this effort)

**Current:** Not active; backend runs on Railway or self-hosted

---

## Data Flow Summary

```
Mobile (auxi)
  ↓ axios → http://localhost:5001/api/v1/*
Backend (FastAPI)
  ├─ Auth: JWT via PyJWT
  ├─ User/Item data: PostgreSQL via SQLAlchemy
  ├─ Session state: Redis
  ├─ Image processing: Gemini API
  ├─ File storage: S3 (boto3)
  ├─ Chat: LangGraph + LangChain (Groq/Gemini LLM)
  └─ Response: JSON + X-Request-Id header

Admin SPA (wardrobe-admin)
  ↓ axios → http://localhost:5001/api/*
Backend (same as above)
  ├─ Auth: same JWT, localStorage
  ├─ Data: PostgreSQL
  ├─ Deployment: Cloudflare Workers (static SPA)
  └─ API URL: Environment-injected at build time
```

---

## Integration Checklist for New Developers

- [ ] Set `GOOGLE_STUDIO_KEY` for Gemini features (extraction, try-on, decision engine)
- [ ] Set `DATABASE_URL` for PostgreSQL (SQLite used in dev if not set)
- [ ] Set `JWT_SECRET_KEY` for token signing
- [ ] Set `REDIS_URL` for rate limiting and session state
- [ ] Set `S3_*` vars for persistent image storage
- [ ] Mobile API base: `http://localhost:5001/api` (hardcoded in `apiClient.ts`)
- [ ] Admin SPA API base: injected from `wrangler.jsonc` build command
- [ ] Test backend with `python test_server.py` before mobile smoke test
- [ ] Verify Maestro `testID` attributes on all interactive elements before QA sign-off

---

*Integration audit: 2026-05-08*
