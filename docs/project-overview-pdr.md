# Auxi — Product Overview & Product Development Requirements

## Product Vision

**Problem:** Users struggle to organize their personal wardrobe and repeatedly wear the same outfits, missing outfit combinations.

**Solution:** Auxi is an AI-powered personal wardrobe management system that:
1. Digitizes a user's clothing through photo uploads
2. Intelligently tags garments (color, category, style, occasion)
3. Generates contextual outfit recommendations based on weather, time, occasion, and style
4. Enables virtual try-on via AI-generated images
5. Learns user preferences through feedback

**Vision:** Be the daily go-to app that makes getting dressed faster, more creative, and more confident.

---

## Target Users & Use Cases

### Primary Users
- **Fashion-conscious individuals** (18–50) who want to maximize wardrobe utility
- **Busy professionals** seeking daily outfit inspiration without decision fatigue
- **Occasional travelers** wanting to pack efficiently for trips
- **Sustainability-minded users** wanting to wear more of what they own

### Key Use Cases
1. **Daily outfit discovery** — "What should I wear today?" given weather, occasion, time
2. **Wardrobe audit** — "Do I have enough pieces?" and "Which items go together?"
3. **Travel packing** — "What 5 items create the most outfits for this trip?"
4. **Style refinement** — "Try-on different combinations before wearing"
5. **Occasion-specific** — "Build an outfit for a date/meeting/casual hangout"

---

## Feature Inventory

### Core Features (Shipped)

#### 1. Authentication & Onboarding
- Email/password signup + login
- JWT-based auth with refresh tokens
- Keychain-secured token storage (iOS)
- Preference onboarding: gender, style direction, body type
- Welcome tour + style quiz

#### 2. Wardrobe Management
- Photo upload + AI background removal (Gemini)
- Automatic garment detection (color, category, fit, occasion)
- Item tagging (manual + AI-assisted)
- Wardrobe grid (15 items/screen, filterable by category)
- Edit metadata (color, fit, occasions, style tags)
- Favorite items for quick access
- Item deletion

#### 3. Recommendation Engine (V05 — Deterministic)
- **6-layer pipeline:**
  1. Pool generation (user's wardrobe + common items)
  2. Silhouette axis filtering (fit-conscious ranking)
  3. Color harmonization (complementary/monochrome/analogous)
  4. Layering system (base → middle → outer)
  5. Footwear matching (style + formality)
  6. Accessory suggestion (belts, scarves, jewelry)
- **Context awareness:** weather, time of day, occasion
- **Redis caching** (1h TTL) for pool reuse
- **8-second recompose timeout** for fast UI response
- **Axis-based customization** (user can tweak silhouette, color, layering)

#### 4. Recommendation Engine (V2 — Stateful)
- Weather-aware session management
- Climate buckets: HOT, MILD, COOL
- Variation axes for outfit diversity
- User feedback integration (like/dislike/try-on)

#### 5. Virtual Try-On
- Gemini high-resolution image generation (outfit rendered on body model)
- Async job processing (submit → poll for result)
- Presigned S3 URLs for ephemeral result delivery
- Garment layering visualization

#### 6. Body Reference
- User provides selfie for fit context
- Guides try-on accuracy
- Privacy-first (no storage, ephemeral processing)

#### 7. Weather Integration
- Real-time weather fetch (location-based)
- Climate-aware recommendation filtering
- Temperature, humidity, precipitation context

#### 8. Settings & Personalization
- Daily reminder toggle + custom time
- Style direction reset
- Preference reset (re-onboard)
- Dark/light theme
- Language support (i18next framework)

### Admin Features (Shipped)

#### 1. User Management
- View all users + usage stats
- Promote users to admin role
- User profile inspection
- Ban/deactivate accounts

#### 2. Common Items Catalog
- CRUD for global garment catalog (default items shown to all users)
- Bulk AI tagging via Gemini gender classification
- Category, color, fit, occasion metadata
- Search + filter

#### 3. Algorithm Configuration
- Versioned ML config (weights, thresholds)
- Promote/rollback recommendation parameters
- A/B test setup per user segment
- Real-time config hot-swap

#### 4. Recommendation Testing
- Run engine on user/scenario without persisting
- Debug recommendation pipeline
- Axis weight exploration
- Pool composition inspection

#### 5. Evaluation & Metrics
- Recommendation quality scoring across users
- Engagement metrics (like rate, try-on rate, time-to-outfit)
- Session analysis (pool size, recompose counts)
- Performance monitoring (recompose latency, cache hit rate)

---

## Product Requirements

### Functional Requirements

**Mobile App:**
- FR-1: Users can securely log in with email/password
- FR-2: Users can upload garment photos and auto-tag them
- FR-3: Users can view wardrobe grid (filterable by category)
- FR-4: Users can get AI-powered outfit recommendations
- FR-5: Users can customize recommendations by axis (silhouette, color, etc.)
- FR-6: Users can virtual try-on an outfit (high-res AI generation)
- FR-7: Users can favorite outfits/items and see history
- FR-8: Users can see real-time weather and occasion context
- FR-9: Users can reset preferences or request a new outfit
- FR-10: Users receive daily reminder notifications (opt-in)

**Backend:**
- FR-11: V05 recommendation engine executes in <8 seconds for 95th percentile
- FR-12: Redis pool caching reduces recompose latency to <500ms for cache hits
- FR-13: Gemini image processing (background removal, try-on) completes in <60s
- FR-14: Authentication tokens are properly scoped (access vs refresh)
- FR-15: Rate limiting prevents abuse (10 req/min for uploads, 60 req/min for reads)

**Admin Dashboard:**
- FR-16: Admins can view/search user list and detailed profiles
- FR-17: Admins can manage common items catalog
- FR-18: Admins can version and rollback recommendation config
- FR-19: Admins can run recommendation tests on user scenarios
- FR-20: Admins can view recommendation quality metrics

### Non-Functional Requirements

**Performance:**
- NF-1: Outfit recommendation <8 seconds for 95th percentile
- NF-2: Wardrobe grid load <3 seconds
- NF-3: Item upload + processing <60 seconds (Gemini + S3)
- NF-4: Virtual try-on generation <90 seconds
- NF-5: Cache hit rate >70% for recommendation pools (Redis TTL 1h)

**Scalability:**
- NF-6: Support 100K concurrent users (mobile app)
- NF-7: Handle 10K requests/second at peak
- NF-8: Horizontal scaling via Gunicorn workers (4–8 per instance)

**Reliability:**
- NF-9: 99.5% uptime SLA (backend)
- NF-10: Graceful fallback if Gemini API is slow (use cached results)
- NF-11: Automatic retry logic for transient failures (S3, Gemini)
- NF-12: Request tracing via X-Request-Id header

**Security:**
- NF-13: Passwords hashed with Argon2
- NF-14: JWT tokens validated (signature + expiry + type)
- NF-15: File uploads validated (MIME type, size <3MB)
- NF-16: User images deleted immediately after processing (ephemeral)
- NF-17: Rate limiting prevents brute-force attacks

**Data Privacy:**
- NF-18: User wardrobe images deleted 48 hours after upload (if not saved)
- NF-19: Try-on results ephemeral (short-lived presigned URLs, <1h)
- NF-20: No analytics on wardrobe content; only aggregate usage metrics

---

## Success Metrics & KPIs

| Metric | Target | Reasoning |
|--------|--------|-----------|
| **Daily Active Users (DAU)** | 10K by Q3 | Measure engagement and traction |
| **Wardrobe Completion Rate** | >60% of users upload ≥5 items | Adoption depth |
| **Recommendation Like Rate** | >50% of recommendations liked | Quality signal |
| **Try-On Conversion** | >20% of recommendations → try-on | Feature engagement |
| **Repeat Recommendation Rate** | >10% of users repeat last outfit | Relevance |
| **Session Frequency** | 3+ sessions/week among active users | Habit formation |
| **Time-to-Outfit (mean)** | <2 min from "get recommendation" → outfit viewed | UX delight |
| **Recommendation Latency (p95)** | <8 seconds | Performance threshold |
| **Cache Hit Rate** | >70% | Cost efficiency |
| **User Retention (30-day)** | >40% | Stickiness |

---

## Current Status & Version Notes

### Latest Version
**v0.5.0** (2026-05-17)

**Shipped:**
- ✅ V05 deterministic recommendation engine (6-layer pipeline)
- ✅ Gemini integration (background removal, high-res try-on)
- ✅ Redis pool caching
- ✅ Admin dashboard (full Cloudflare deployment)
- ✅ Sentry error tracking (mobile + backend)
- ✅ "Try Another" batch refresh (AU-252)
- ✅ Weather integration
- ✅ JWT auth + refresh tokens
- ✅ Wardrobe CRUD + AI tagging

**In Progress:**
- 🚧 V05 Phase 1: LLM-based outfit diversifier (vary explanations)
- 🚧 V05 feedback model (user reactions → weight updates)
- 🚧 Modal wire-up refinement (UX polish)

**Planned:**
- 📋 V2 stateful recommendation engine (climate-aware sessions)
- 📋 Eval harness + official rubric (quality benchmarking)
- 📋 Performance optimization (Redis key strategy)
- 📋 i18n expansion (Vietnamese, Korean, Spanish)

### Platform Status
| Platform | Status | Notes |
|----------|--------|-------|
| iOS | ✅ Production (TestFlight) | RN 0.83.1, Sentry, push notifications |
| Android | ✅ Production (Google Play track) | Parity with iOS |
| Backend | ✅ Production (Railway) | Python 3.11, Gunicorn 4 workers |
| Admin | ✅ Production (Cloudflare Workers) | React SPA, real-time config management |
| Web | ✅ Marketing (Cloudflare Pages) | Astro 6, landing + styleguide |

### Known Limitations
- **Legacy HomeScreen duplication** — `HomeScreen.tsx` (current) and `_HomeScreen.tsx` (legacy, ~941 LOC) coexist pending migration decision
- **API config hardcoded** — Backend URL in `apiClient.ts` should be externalized (queued, not started)
- **Feedback loop incomplete** — User reactions not yet fed back to recommendation weights

---

## Technical Debt & Roadmap

### High Priority
1. **HomeScreen migration** — Delete `_HomeScreen.tsx` after new onboarding fully verified
2. **API config externalization** — Move backend URL to `.env` / react-native-config
3. **Eval harness completion** — Official rubric + automated quality benchmarking
4. **Modal wire-up refinement** — Polish remaining UX rough edges (AU-252)

### Medium Priority
1. **V2 stateful recommendation engine** — Climate-aware session management with learning
2. **Performance optimization** — Redis key strategy, batch pool generation
3. **i18n expansion** — Vietnamese, Korean, Spanish translations
4. **Offline support** — Cache recommendations for offline outfit browsing

### Low Priority
1. **Social features** — Share outfits, get feedback from friends
2. **Seasonal wardrobe management** — Archive off-season items
3. **Trend integration** — Pull trending colors/silhouettes from fashion data
4. **Sustainability scoring** — Track frequency-of-wear, suggest underutilized items

---

## Success Criteria for Current Phase

**V05 Phase 1 (in progress):**
- [ ] LLM diversifier generates 3+ distinct outfit explanations per recommendation
- [ ] Explanation quality scores >0.7 on eval rubric (5-point scale)
- [ ] Latency does not exceed 12s (p95) with LLM diversifier enabled
- [ ] User feedback loop integrated (like/dislike → logs recorded for training)
- [ ] Modal wire-up complete (all context chips, buttons responsive)

**Phase 0 (completed 2026-05-11):**
- [x] V05 recommendation engine shipped with 6-layer pipeline
- [x] Sentry error tracking operational
- [x] Admin dashboard live on Cloudflare
- [x] "Try Another" batch refresh (AU-252) merged
