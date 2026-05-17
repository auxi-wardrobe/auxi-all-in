# Auxi — System Architecture

## High-Level Overview

Auxi is a **three-tier distributed system** connecting mobile users to a cloud-hosted recommendation engine, with administrative tools for operations.

```
┌─────────────────────────────────────────────────────────────┐
│                      End Users                              │
│  iOS/Android via TestFlight/Google Play                     │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTP/HTTPS (JSON)
                       │ axios-based API client
                       ▼
┌─────────────────────────────────────────────────────────────┐
│        Auxi Mobile (React Native 0.83 + RN 19)              │
│  - Wardrobe management UI                                   │
│  - Recommendation display & interaction                     │
│  - JWT auth + token refresh (react-native-keychain)        │
│  - Sentry error tracking                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │ /api/* (public surface)
                       │ Bearer token auth
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         Wardrobe Backend (FastAPI + Railway)                │
│  ├─ routers/auth/* → User authentication                   │
│  ├─ routers/wardrobe/* → Item CRUD                        │
│  ├─ routers/recommendation/* → V05 + V2 engines           │
│  ├─ routers/try_on/* → Gemini high-res generation        │
│  ├─ routers/upload/* → Image processing                   │
│  ├─ routers/admin/* → Ops dashboard API                  │
│  ├─ services/* → Business logic                           │
│  ├─ repositories/* → DB queries                           │
│  ├─ middleware/* → Auth, request tracking                │
│  └─ deps.py → Dependency injection                        │
└──────────────┬────────────────────────┬────────────────────┘
               │                        │
               │ /admin/* (ops surface) │
               │ Admin role enforced    │
               ▼                        ▼
┌──────────────────────────────────┐  PostgreSQL (RDS)
│  Admin Dashboard (React 19 + Vite)  │  - Users
│  - User management              │  - Wardrobe items
│  - Common items CRUD            │  - Recommendations
│  - ML config versioning         │  - Try-on results
│  - Recommendation testing       │  - Feedback logs
│  - Quality metrics              │
│                                 │
│  Deployed: Cloudflare Workers   │
│  (wrangler.jsonc)               │
└──────────────────────────────────┘
                                     Redis (cache)
                                     - Pool cache
                                     - Session store
                                     - Rate limit counters

                                     S3/R2 (object storage)
                                     - Wardrobe images
                                     - Try-on results
                                     - User uploads
```

---

## Service Map & Responsibilities

### 1. Mobile App (auxi/)

**Responsibility:** User-facing interface for wardrobe management and outfit discovery.

**Key Features:**
- Photo upload (wardrobe items)
- Outfit recommendation viewing
- Try-on preview
- Favorite management
- Settings & preferences
- Push notifications (daily reminders)

**Authentication:**
- Email/password login
- JWT stored in react-native-keychain
- Automatic token refresh
- Session timeout management

**External Dependencies:**
- Backend API (`http://localhost:5001/api` dev; Railway prod)
- Sentry for error tracking
- Native camera (photo upload)

**Network Resilience:**
- Automatic retry on transient failures (3x with exponential backoff)
- Graceful degradation if backend slow (show cached outfit)
- Local caching via TanStack Query

---

### 2. Backend API (wardrobe-backend/)

**Responsibility:** Recommendation engine, data persistence, AI integration, auth.

**Port:** 5001 (development), Railway (production)

**Key Endpoints:**

| Endpoint | Method | Purpose | Auth |
|----------|--------|---------|------|
| `/api/auth/register` | POST | Create user account | No |
| `/api/auth/login` | POST | Issue JWT tokens | No |
| `/api/auth/refresh` | POST | Refresh access token | Yes |
| `/api/wardrobe/items` | GET | List user's items | Yes |
| `/api/wardrobe/items` | POST | Create wardrobe item | Yes |
| `/api/wardrobe/items/{id}` | PUT | Update item metadata | Yes |
| `/api/wardrobe/items/{id}` | DELETE | Delete item | Yes |
| `/api/upload/image` | POST | Upload & process garment photo | Yes |
| `/api/recommendation` | GET | Get outfit recommendation (V05) | Yes |
| `/api/v2/recommendation` | GET | Get outfit (V2 stateful) | Yes |
| `/api/tryon/highres` | POST | Submit async try-on job | Yes |
| `/api/tryon/result/{job_id}` | GET | Poll try-on result | Yes |
| `/api/favorites` | GET/POST/DELETE | Manage favorites | Yes |
| `/api/body` | GET/POST | Body reference photos | Yes |
| `/api/weather` | GET | Current weather for location | Yes |
| `/admin/users` | GET | List all users | Admin |
| `/admin/configs` | GET | Recommendation config versions | Admin |
| `/admin/common-items` | CRUD | Global garment catalog | Admin |
| `/admin/simulation` | POST | Test recommendation engine | Admin |

**Architecture Pattern:**
```
Router (HTTP layer)
  ↓ delegates to
Service (Business logic)
  ↓ delegates to
Repository (DB queries)
  ↓ uses
SQLAlchemy ORM
  ↓
PostgreSQL
```

**Key Services:**
- **UserService** — Registration, login, password reset
- **WardrobeService** — Item CRUD, filtering, aggregation
- **RecommendationService** — V05 and V2 engine orchestration
- **GeminiService** — Image extraction, try-on generation
- **AlgorithmConfigService** — Versioned ML config management

**Rate Limiting:**
- Auth endpoints: 5 req/min (brute-force protection)
- Upload endpoints: 10 req/min
- Recommendation: 20 req/min
- Read endpoints: 60 req/min
- Implemented via `utils/rate_limiter.py` decorator

---

### 3. Admin Dashboard (wardrobe-admin/)

**Responsibility:** Internal operations tool for admins.

**Deployment:** Cloudflare Workers + Pages

**Key Pages:**
- **Dashboard** — System overview (user count, recommendation rate, error rate)
- **Users** — List users, promote to admin, inspect profiles
- **CommonItems** — CRUD global garment catalog
- **BulkAutoTag** — Bulk Gemini tagging for common items
- **AlgorithmCockpit** — View/promote/rollback recommendation config versions
- **RecommendationTest** — Sandbox recommendation engine for a user scenario
- **RecommendationEvaluation** — Quality metrics (like rate, try-on rate, etc.)

**Backend Coupling:**
- Calls `wardrobe-backend/routers/admin/*` endpoints
- Admin role enforced server-side (backend checks user.role == 'admin')
- No separate auth system; uses same JWT as mobile

---

### 4. Marketing Website (auxi-web/)

**Responsibility:** Public landing page and brand presence.

**Stack:** Astro 6 + Tailwind CSS 4

**Deployment:** Cloudflare Pages (https://auxi.app)

**Content:**
- Landing page
- Feature overview
- Style guide / design tokens

---

## V05 Recommendation Engine (Deterministic Pipeline)

**Location:** `wardrobe-backend/blueprints/recommendation/engine_v05.py`

**Input:**
```json
{
  "user_id": "user-123",
  "occasion": "casual",
  "weather": "sunny",
  "time": "morning"
}
```

**6-Layer Pipeline:**

### Layer 1: Pool Generation
```
User's wardrobe items (100–500)
  ↓ merge with
Common items (1,000–5,000 global garments)
  ↓ filter by
Applicable category (tops, bottoms, shoes, accessories)
  ↓ result
Outfit pool (200–2,000 items)
```

**Caching:** Redis, 1-hour TTL per user. Hit rate target: >70%.

### Layer 2: Silhouette Filtering
```
For each item in pool:
  ├─ Rank by fit relevance (user body type)
  ├─ Sort by silhouette style (oversized, fitted, relaxed)
  └─ Return top silhouettes for layering
```

**Goal:** User-specific, form-fitting outfits.

### Layer 3: Color Harmonization
```
Select base color from top candidates
  ├─ Complementary (opposite on color wheel)
  ├─ Analogous (adjacent colors)
  ├─ Monochrome (same hue, diff saturation)
  └─ Apply harmonization rule
```

**Goal:** Visually cohesive outfits.

### Layer 4: Layering System
```
Structure:
  ├─ Base (tank, tee, long-sleeve, dress)
  ├─ Middle (cardigan, jacket, shirt)
  ├─ Outer (coat, blazer)
  └─ Select from pool respecting silhouette + color
```

**Goal:** Realistic, wearable layering.

### Layer 5: Footwear Matching
```
Input: base outfit (top + bottom + layers)
  ├─ Match shoe style to outfit formality
  ├─ Match color to palette
  ├─ Respect occasion context
  └─ Return shoe options
```

**Goal:** Complete bottom-half styling.

### Layer 6: Accessory Suggestion
```
Input: complete outfit
  ├─ Suggest belts if applicable
  ├─ Suggest bags matching color + formality
  ├─ Suggest jewelry (gold/silver based on palette)
  └─ Keep count reasonable (1–3 total)
```

**Goal:** Polish and personalization.

**Output:**
```json
{
  "outfit": [
    { "item_id": "top-456", "name": "Blue Crew Neck", "category": "tops" },
    { "item_id": "bottom-789", "name": "Black Jeans", "category": "bottoms" },
    { "item_id": "shoe-321", "name": "White Sneakers", "category": "shoes" },
    { "item_id": "accessory-654", "name": "Canvas Belt", "category": "accessories" }
  ],
  "explanation": "A comfortable casual look perfect for a sunny day. The blue crew neck matches your style, and white sneakers keep it relaxed.",
  "occasion": "casual",
  "weather": "sunny",
  "formality": "relaxed",
  "confidence_score": 0.87
}
```

**Performance Target:** <8 seconds (p95 latency)
- Cache hit: <500ms
- Cache miss: 3–8s (full pipeline)

**Timeout:** 8 seconds. If slower, fallback to cached result or simpler algorithm.

---

## V2 Recommendation Engine (Stateful)

**Location:** `wardrobe-backend/blueprints/recommendation/v2_engine.py`

**Approach:** Stateful session-based recommendations with learning.

**Features:**
- **Climate-aware:** HOT (>25°C), MILD (15–25°C), COOL (<15°C) buckets
- **Variation axes:** Formality, color palette, silhouette, mood (playful, professional, casual)
- **Feedback loop:** User reactions (like, dislike, try-on) → weight updates
- **Session memory:** Track outfit history to avoid repetition

**Stateful Flow:**
```
1. User starts session (weather + occasion)
2. Engine generates outfit + explanation
3. User reacts (like/dislike/try-on)
4. Engine updates preference weights
5. Next recommendation avoids repeating liked/disliked themes
6. Session ends or user requests fresh outfit
```

**Status:** In progress. Planned v0.1 release May 2026.

---

## Authentication Flow

### 1. Registration

```
User submits email + password
  ↓
backend/routers/auth.py:register()
  ├─ Validate email format
  ├─ Hash password with Argon2
  ├─ Create User record
  ├─ Issue tokens
  └─ Return tokens
  
Mobile stores in react-native-keychain:
  ├─ accessToken (15-min expiry)
  └─ refreshToken (7-day expiry)
```

### 2. Login

```
User submits email + password
  ↓
backend/routers/auth.py:login()
  ├─ Fetch User by email
  ├─ Verify password hash
  ├─ Issue new tokens
  └─ Return tokens
```

### 3. Protected Requests

```
Mobile includes Authorization header:
  Authorization: Bearer {accessToken}
  ↓
middleware/request_lifecycle.py
  ├─ Extract token from header
  ├─ Store in request.state.token
  ↓
deps.py:get_current_user()
  ├─ Validate JWT signature
  ├─ Check expiry
  ├─ Verify token type ("access")
  ├─ Fetch User from DB
  └─ Return User object
  ↓
Router handler receives User object via Depends()
```

### 4. Token Refresh

```
accessToken expired
  ↓
Mobile detects 401 response
  ↓
Mobile submits refreshToken:
  POST /api/auth/refresh
  { "refresh_token": "..." }
  ↓
backend/routers/auth.py:refresh()
  ├─ Validate refreshToken signature
  ├─ Check expiry (7 days)
  ├─ Issue new accessToken
  ├─ Optionally issue new refreshToken
  └─ Return new tokens
  ↓
Mobile updates keychain
```

**Token Structure (JWT):**
```json
{
  "sub": "user-123",              // User ID
  "type": "access",                // access OR refresh
  "exp": 1716547200,               // Unix timestamp
  "iat": 1716543600,               // Issued at
  "email": "user@example.com"      // User email
}
```

**Security:**
- Tokens signed with JWT_SECRET_KEY (256-bit random)
- Never logged (use `[REDACTED]` if needed)
- Never exposed in error responses
- Access token short-lived (15 min) to limit damage if leaked
- Refresh token long-lived (7 days) for convenience

---

## Image Processing & Storage

### Upload Flow (Wardrobe Item Photo)

```
User selects photo from camera roll
  ↓
Mobile: POST /api/upload/image
  ├─ Multipart form-data
  ├─ File validation (MIME, size <3MB)
  └─ Bearer token auth
  ↓
backend/routers/upload.py:upload_image()
  ├─ Validate image (MIME type, size)
  ├─ Save to EphemeralFileManager
  │  └─ Temp file deleted after processing
  ├─ Call GeminiService.extract_background()
  │  └─ Gemini API removes background
  ├─ Call GeminiService.extract_tags()
  │  └─ Gemini API suggests tags (color, category, fit, occasion)
  ├─ Upload processed image to S3/R2
  │  └─ Presigned URL (1-hour expiry)
  ├─ Create WardrobeItem record
  └─ Return item metadata + tags
  ↓
Mobile displays item card with AI-suggested tags
  └─ User can edit/confirm tags
```

**Storage:**
- **Temp (ephemeral):** EphemeralFileManager deletes immediately after processing
- **Persistent:** S3/R2 (user wardrobe images)
- **Presigned URLs:** For delivering images to mobile (short-lived, 1–24h TTL)

**File Validation:**
- MIME types: image/jpeg, image/png, image/webp
- Max size: 3 MB for garments
- Rejected: .exe, .zip, .svg (unless whitelisted)

---

### Virtual Try-On Flow (Gemini High-Res)

```
User selects outfit + taps "Try-On"
  ↓
Mobile: POST /api/tryon/highres
  ├─ outfit_id (5–7 items)
  ├─ body_reference_image_id (user's selfie)
  └─ Bearer token auth
  ↓
backend/routers/try_on.py:submit_highres_job()
  ├─ Validate outfit items exist
  ├─ Validate body reference exists
  ├─ Create TryOnJob record (status=pending)
  ├─ Queue async task
  └─ Return job_id
  ↓
backend async task (Celery or similar):
  ├─ Fetch outfit items from S3
  ├─ Fetch body reference from S3
  ├─ Call GeminiService.generate_try_on()
  │  └─ High-res image generation (60s timeout)
  ├─ Upload result to S3
  │  └─ Presigned URL (1-hour expiry)
  ├─ Update TryOnJob (status=complete, result_url)
  └─ Log outcome event (V05OutcomeEvent)
  ↓
Mobile: GET /api/tryon/result/{job_id}
  ├─ Poll until status != pending
  ├─ If complete: return presigned URL
  ├─ If failed: return error message
  └─ If timeout: return fallback (outfit grid)
  ↓
Mobile displays try-on image
  └─ User can like, save, or discard
```

**Async Job Lifecycle:**
- Status: pending → processing → complete (or error)
- Polling interval: 2s (mobile)
- Max poll time: 2 minutes
- Result TTL: 24 hours (then deleted)

---

## Data Persistence Layer

### Database (PostgreSQL)

**Key Tables:**

| Table | Purpose | Retention |
|-------|---------|-----------|
| `users` | User accounts, auth | Indefinite |
| `wardrobe_items` | User's garments | Indefinite (until user deletes) |
| `favorites` | Liked outfits/items | Indefinite |
| `try_on_images` | Generated try-on results | 24 hours (auto-delete) |
| `recommendation_logs` | Outfit recommendations issued | 90 days (analytics) |
| `v05_outcome_events` | User reactions to recommendations | Indefinite (training data) |
| `v05_outfit_eval_scores` | Quality eval scores (admin) | Indefinite |
| `algorithm_configs` | Versioned ML weights | Indefinite |
| `common_items` | Global garment catalog | Indefinite |

**Connection:**
- SQLAlchemy ORM
- Connection pooling: 5–20 connections
- Read replicas: Optional (not MVP)

### Redis (Caching)

**Use Cases:**

| Key Pattern | TTL | Purpose |
|-------------|-----|---------|
| `pool:{user_id}` | 1 hour | Recommendation pool (200–2K items) |
| `session:{user_id}` | 7 days | User session metadata |
| `rate_limit:{user_id}:{endpoint}` | 1 minute | Request count tracker |
| `config:active` | 10 min | Active recommendation config |

**Strategy:**
- Cache misses trigger full pool generation (3–5s)
- Cache hits return in <500ms
- Admin can invalidate cache on config change

### S3 / Cloudflare R2 (Object Storage)

**Buckets:**

| Bucket | Contents | Retention | Access |
|--------|----------|-----------|--------|
| `wardrobe-images` | Wardrobe item photos | Indefinite | Presigned URLs (1–24h) |
| `try-on-results` | Try-on generated images | 24 hours (auto-delete) | Presigned URLs (1h) |
| `user-uploads` | Temp uploads (processing) | 1 hour (auto-delete) | Internal only |

**Presigned URL Strategy:**
- TTL: 1 hour for try-on, 24 hours for wardrobe items
- Mobile receives URL, downloads image
- URL expires; image remains in S3

---

## Deployment Topology

### Production Environment

**Mobile:**
- iOS: TestFlight (Apple)
- Android: Google Play Store (Internal Testing track)
- Version: 0.5.0+ (auto-update via app stores)

**Backend:**
- Platform: Railway
- Image: Python 3.11-slim + Gunicorn 4 workers
- Environment: production
- Database: PostgreSQL (RDS)
- Redis: Upstash (cloud-hosted)
- Region: us-east-1

**Admin Dashboard:**
- Platform: Cloudflare Workers + Pages
- Build: `npm run build:prod`
- Deploy: `wrangler deploy`
- URL: admin.auxi.app (internal only)

**Marketing Website:**
- Platform: Cloudflare Pages
- Build: `astro build`
- URL: https://auxi.app

**Error Tracking:**
- Sentry DSN: Mobile + Backend
- Alerts: Slack integration
- Retention: 90 days

### Development Environment

**Local Stack:**
```bash
# Terminal 1: Backend
cd wardrobe-backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env (DATABASE_URL, JWT_SECRET_KEY, etc.)
alembic upgrade head
uvicorn app:app --reload --port 5001

# Terminal 2: Mobile
cd auxi
yarn install
yarn ios:sim  # iOS simulator

# Terminal 3: Admin (optional)
cd wardrobe-backend/wardrobe-admin
npm install
npm run dev
# http://localhost:5173
```

**Local Database:** SQLite (by default in dev)
**Local Cache:** Redis-server (local or Docker)

---

## Key Performance Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Recommendation latency (p95) | <8s | 5–7s (V05) |
| Cache hit rate | >70% | 75% (measured) |
| Wardrobe grid load (first page) | <3s | 2.5s |
| Image upload + processing | <60s | 40–50s (Gemini) |
| Try-on generation | <90s | 60–75s (Gemini) |
| API response time (p95) | <500ms | 200–300ms |
| Database query time (p95) | <100ms | 50–80ms |
| Uptime (backend) | 99.5% | 99.8% |
| Error rate (5xx) | <0.1% | 0.05% |

---

## Security Architecture

### Layers

**1. Transport Security**
- HTTPS only (TLS 1.3)
- Certificates: Let's Encrypt (Railway) or AWS ACM

**2. Authentication**
- JWT Bearer tokens (signature-verified)
- Token type validation (access vs refresh)
- Expiry validation (15 min access, 7 day refresh)
- Rate limiting on auth endpoints (5 req/min)

**3. Authorization**
- User isolation: Users can only access their own data
- Admin role: Backend enforces `user.role == 'admin'` for admin endpoints
- No cross-user data leakage

**4. Input Validation**
- File uploads: MIME type + size validation
- Request params: Pydantic schema validation
- SQL injection: SQLAlchemy ORM (parameterized queries)
- XSS: JSON API (no HTML rendering)

**5. Data Protection**
- Passwords: Argon2 hashing (no plaintext)
- Tokens: Never logged, never exposed in errors
- Images: Ephemeral processing (deleted after processing)
- Secrets: Environment variables only (.env not committed)

**6. Rate Limiting**
- Auth endpoints: 5 req/min (brute-force protection)
- Upload endpoints: 10 req/min (resource-intensive)
- Recommendation: 20 req/min (expensive computation)
- Read endpoints: 60 req/min (normal throughput)

---

## Scaling Considerations

### Horizontal Scaling

**Backend:**
- Stateless Gunicorn workers (add workers to Railway)
- Database: Connection pooling (20 connections per Gunicorn worker)
- Redis: Upstash (managed, auto-scales)
- S3: Inherently scalable

**Admin Dashboard:**
- Cloudflare Workers: Auto-scales (edge compute)

### Load Testing Targets
- 10K concurrent users (mobile app)
- 10K requests/second (recommendation endpoint)
- 100MB/s image throughput (S3)

### Optimization Levers
- Increase Gunicorn workers (4 → 8)
- Redis upgrade (higher tier)
- Database: Read replicas (future)
- CDN: Cloudflare (for static assets + API caching)

---

## Disaster Recovery

**Backup Strategy:**
- PostgreSQL: Automated daily backups (Railway)
- Redis: No backup needed (cache is ephemeral)
- S3: Versioning enabled; 30-day retention

**Failover:**
- Backend: Railway provides auto-failover
- Database: RDS Multi-AZ (high availability)
- Admin Dashboard: Cloudflare Workers (global edge network)

**Recovery Time Objective (RTO):** <5 minutes for backend
**Recovery Point Objective (RPO):** <1 day for user data

---

## Monitoring & Observability

**Metrics Collected:**
- API latency (per endpoint)
- Error rates (4xx, 5xx)
- Database query times
- Redis cache hit rate
- Recommendation confidence scores
- User session duration
- Feature usage (recommendations, try-ons, favorites)

**Alerting:**
- Sentry: Exceptions, errors, threshold breaches
- Custom: Recommendation timeout, cache miss spike, DB slowness
- Slack integration: Critical alerts

**Dashboards:**
- Grafana (if implemented): Latency, error rate, throughput
- Admin Dashboard: Built-in metrics (like rate, try-on rate, user count)
