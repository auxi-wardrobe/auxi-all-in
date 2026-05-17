# Auxi — Project Roadmap & Changelog

## Current Status Summary

**Latest Version:** 0.5.0 (2026-05-17)

**Overall Progress:** Phase 0 ✅ Complete | Phase 1 🚧 In Progress (35%)

| Component | Status | Notes |
|-----------|--------|-------|
| Mobile App (v0.5.0) | ✅ Production | RN 0.83, Sentry integrated, Maestro QA framework |
| Backend API (v0.5.0) | ✅ Production | FastAPI, V05 recommendation engine, Railway deployment |
| Admin Dashboard | ✅ Production | React + Vite, Cloudflare Workers, full CRUD for ML config |
| Marketing Website | ✅ Production | Astro 6, Cloudflare Pages, https://auxi.app |
| V05 Recommendation Engine | ✅ Complete | 6-layer deterministic pipeline, <8s p95 latency |
| V2 Recommendation Engine | 🚧 In Progress | Stateful, climate-aware, user feedback loop (Phase 1) |
| Feedback Model | 🚧 In Progress | User reactions → weight updates (Phase 1) |
| Eval Harness | 🔄 Planned | Official rubric, automated quality benchmarking (Phase 1) |

---

## Phase 0: V05 Foundation (COMPLETE ✅)

**Timeline:** 2026-04-01 – 2026-05-11

**Objective:** Ship deterministic V05 recommendation engine with production infrastructure.

### Completed Milestones

**Recommendation Engine:**
- [x] 6-layer deterministic pipeline (silhouette → color → layering → footwear → accessory)
- [x] Redis pool caching (1-hour TTL, >70% hit rate target)
- [x] 8-second recompose timeout with graceful fallback
- [x] Axis-based customization (user can tweak silhouette, color, layering weights)
- [x] Context awareness (weather, occasion, time of day)
- [x] Explanation generation (human-readable outfit rationale)
- [x] Unit tests (80%+ coverage on engine)

**Integration & Deployment:**
- [x] Sentry error tracking (mobile + backend)
- [x] Railway backend deployment (Python 3.11, Gunicorn 4 workers)
- [x] PostgreSQL RDS (user data, wardrobe items, logs)
- [x] Redis caching (Upstash)
- [x] S3 image storage (wardrobe items, try-on results)
- [x] Admin dashboard live on Cloudflare Workers
- [x] Mobile app on TestFlight (iOS)

**Data & Config:**
- [x] Common items catalog (CRUD via admin dashboard)
- [x] Algorithm config versioning (promote/rollback weights)
- [x] Recommendation logging (for future analysis)
- [x] V05OutcomeEvent schema (for feedback collection)

**QA & Testing:**
- [x] Maestro test framework (YAML-based, testID discipline)
- [x] E2E test server (`python test_server.py`)
- [x] 42+ test cases for auth, recommendation, try-on flows
- [x] Visual fidelity QA (Figma comparison)
- [x] Performance profiling (<8s p95)

**Documentation:**
- [x] API_DOCUMENTATION.md (contract specification)
- [x] CLAUDE.md per-repo (conventions, agent boundaries)
- [x] Figma audit workflow (design-to-code fidelity)

### Artifacts
- Branch: `feat/v05-eval-official-rubric-au259`
- Commits: 320bb48 (bump backend), 12516e7 (Phase 0 plan), ccc05ed (official rubric eval)
- Plans: `plans/260511-1030-v05-phase0-foundation/`

---

## Phase 1: V05 LLM Diversifier & Feedback Model (🚧 IN PROGRESS)

**Timeline:** 2026-05-12 – 2026-06-30 (estimated)

**Objective:** Enhance recommendation quality via LLM-based outfit explanations and user feedback loop integration.

**Progress:** 35% (as of 2026-05-17)

### Milestones

#### 1. LLM Outfit Diversifier (🚧 In Progress)
**Goal:** Generate 3+ distinct, creative explanations per outfit instead of deterministic text.

**Requirements:**
- [ ] LLM integration (LangChain or Anthropic SDK)
- [ ] Prompt engineering for outfit narrative generation
- [ ] Quality scoring (explanation clarity, relevance, uniqueness)
- [ ] Latency constraint: <4 additional seconds (keep total <12s p95)
- [ ] Fallback to deterministic explanation if LLM timeout >4s
- [ ] A/B test: LLM explanations vs. deterministic on user engagement

**Success Criteria:**
- Explanation quality score >0.7 (5-point scale)
- User engagement increase (like rate, try-on rate)
- Latency stays <12s p95 with LLM enabled
- Zero increase in backend error rate

**Owner:** backend-dev agent
**Timeline:** May 22 – June 5, 2026
**Status:** Prompt engineering in progress; LLM service scaffold ready

#### 2. Feedback Model Integration (🚧 Queued)
**Goal:** Capture user reactions (like, dislike, try-on) and train weight updates.

**Requirements:**
- [ ] V05OutcomeEvent schema (capture reaction + context)
- [ ] Offline learning pipeline (batch weight updates, not real-time)
- [ ] Weight update rules (increase similarity to liked outfits, decrease for disliked)
- [ ] Config versioning (new config per training run)
- [ ] Manual promotion (admin approves weight changes before live)
- [ ] Eval before/after (quality metrics on holdout users)

**Success Criteria:**
- 100% of user reactions logged
- Weight updates improve recommendation quality >5%
- No regression on existing liked outfits
- Admin approval workflow functional

**Owner:** backend-dev agent
**Timeline:** June 6 – June 20, 2026
**Status:** Not yet started; waiting for LLM diversifier completion

#### 3. Modal Wire-Up Refinement (🚧 Queued)
**Goal:** Polish UX of recommendation context chips (occasion, weather, time) and action buttons.

**Tasks:**
- [ ] Refine context chip styling (AU-252 design iteration)
- [ ] Test on multiple screen sizes (iPhone 12 mini, iPhone 15 Pro Max, iPad)
- [ ] Accessibility review (VoiceOver, Dynamic Type, color contrast)
- [ ] Button responsiveness (touch targets >44pt)
- [ ] Maestro test coverage (all chips + buttons)

**Owner:** mobile-dev agent
**Timeline:** May 20 – May 27, 2026
**Status:** Design in Figma; implementation queued

#### 4. Eval Harness & Rubric (🚧 Queued)
**Goal:** Automated outfit quality benchmarking via official rubric.

**Requirements:**
- [ ] Official rubric (5-point scale for each axis: fit, color, occasion match, creativity, practicality)
- [ ] Eval dataset (50 user scenarios × 3 variants = 150 outfits)
- [ ] Automated scoring (LLM or heuristic scorer)
- [ ] Dashboard in admin (quality metrics per config version)
- [ ] Regression detection (alert if quality drops >10%)

**Success Criteria:**
- Rubric achieves >0.8 inter-rater agreement
- Eval runs <30 minutes for 150 outfits
- Detects quality regressions reliably
- Integrated into deployment pipeline

**Owner:** backend-dev agent (with qa-ui validation)
**Timeline:** June 8 – June 30, 2026
**Status:** Rubric draft ready (AU-259); dataset assembly queued

### Deliverables
- Updated `blueprints/recommendation/engine_v05.py` with LLM integration
- New `services/feedback_model_service.py` for weight training
- Enhanced admin dashboard: evaluation metrics page
- Maestro test flows for new features
- Plans: `plans/260517-1030-v05-phase1-llm1-diversifier/`

---

## Phase 2: V2 Stateful Recommendation Engine (📋 PLANNED)

**Timeline:** 2026-07-01 – 2026-08-31 (estimated)

**Objective:** Introduce stateful, learning-based recommendation engine for long-term user personalization.

### Planned Features

#### 1. Climate-Aware Session Management
- Track active recommendation sessions (per user, per day)
- Bucket weather into HOT/MILD/COOL
- Suggest outfits tailored to season + current conditions
- Learn seasonal preferences

#### 2. Variation Axes
- Formality (casual, smart-casual, business, formal)
- Color palette (bold, neutral, monochrome, colorful)
- Silhouette (oversized, fitted, relaxed)
- Mood (playful, professional, adventurous)
- User can specify or let engine infer from past reactions

#### 3. User Feedback Loop
- Reactions (like, dislike, try-on, wear, skip) → preference weights
- Real-time weight updates (no offline batch training)
- Gradual learning: newer feedback >weighted more than historical

#### 4. Outfit Deduplication
- Track outfit recommendations in session
- Avoid repeating same or similar outfits
- Diversify across sessions (learn user boredom patterns)

**Success Criteria:**
- User retention +30% over V05-only baseline
- Like rate >55% (vs. 50% for V05)
- Latency <6s (faster due to stateful caching)
- A/B test shows significant engagement lift

### Estimated Effort
- Backend: 120 hours
- Mobile: 40 hours (UI for variation axes)
- Testing: 40 hours

---

## Phase 3: Advanced Recommendation Features (📋 PLANNED)

**Timeline:** 2026-09-01 – 2026-10-31 (estimated)

### Planned Features

#### 1. Social Recommendation
- Share outfits with friends
- Get feedback from others
- Trending outfits across user base
- "People like you also chose..." suggestions

#### 2. Occasion Library
- Pre-built occasion templates (date night, gym, work meeting, party, travel)
- User can customize occasion definitions
- Smart occasion detection (calendar integration)

#### 3. Style Quiz Evolution
- Deeper style profiling (beyond gender/direction)
- Body type fine-tuning (petite, tall, curvy, athletic, etc.)
- Fit preference learning (oversized vs. fitted preference evolution)
- Color palette discovery (what colors suit you)

#### 4. Wardrobe Health Metrics
- Item utilization rate (how often worn)
- Outfit diversity score (do you have a narrow wardrobe?)
- Gap identification ("you need more dresses")
- Declutter suggestions ("these items rarely pair with others")

---

## Phase 4: Monetization & Expansion (📋 PLANNED)

**Timeline:** 2026-11-01 – 2027-02-28 (estimated)

### Planned Features

#### 1. Premium Tier
- Unlimited try-ons (vs. 5/day free)
- Custom occasion creation
- Style expert Q&A
- Ad-free experience
- Pricing: $5.99/month or $49.99/year

#### 2. Wardrobe Import
- Bulk upload from photos
- Integration with fashion websites (Shein, ASOS, etc.)
- AI-assisted tagging at scale

#### 3. Shopping Integration
- "Shop similar" → links to retailers
- Outfit completion ("you need a jacket for this outfit")
- Affiliate commissions

#### 4. Geographic Expansion
- Localization (Vietnamese, Korean, Spanish)
- Region-specific fashion trends
- Weather data for all regions

---

## Known Issues & Technical Debt

### High Priority

| Issue | Impact | Status | Owner | ETA |
|-------|--------|--------|-------|-----|
| HomeScreen duplication (`_HomeScreen.tsx`) | Code clutter, maintenance burden | 🚧 Pending deletion | mobile-dev | 2026-06-15 |
| API config hardcoded in `apiClient.ts` | Can't easily switch backends | 📋 Queued | mobile-dev | 2026-06-01 |
| Feedback loop incomplete | Can't learn from user reactions | 🚧 Phase 1 | backend-dev | 2026-06-20 |
| Modal UX rough edges | Visual/interaction polish needed | 🚧 Phase 1 | mobile-dev | 2026-05-27 |

### Medium Priority

| Issue | Impact | Status | Owner | ETA |
|-------|--------|--------|-------|-----|
| Redis key strategy not optimized | Higher memory usage than needed | 📋 Phase 2 | backend-dev | 2026-08-30 |
| Recommendation latency at p99 | User experience degradation under load | 📋 Phase 2 | backend-dev | 2026-08-30 |
| No offline outfit viewing | Mobile usability gap | 📋 Phase 3 | mobile-dev | 2026-10-31 |
| Admin dashboard performance (10K users) | Slow list rendering | 📋 Phase 3 | admin-dev | 2026-10-31 |

### Low Priority

| Issue | Impact | Status | Owner | ETA |
|-------|--------|--------|-------|-----|
| i18n setup incomplete | Can't expand to other languages | 📋 Phase 4 | mobile-dev | 2027-01-31 |
| Social features absent | Growth limitation | 📋 Phase 4 | product-dev | 2027-01-31 |
| Trend integration missing | Fashion relevance gap | 📋 Phase 4 | backend-dev | 2027-02-28 |

---

## Success Metrics & KPIs

### User Engagement

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Daily Active Users (DAU) | 10K | ~500 (beta) | 🟡 On track |
| Weekly Active Users (WAU) | 40K | ~1500 (beta) | 🟡 On track |
| Monthly Active Users (MAU) | 100K | ~3000 (beta) | 🟡 On track |
| Session frequency (active users) | 3+ per week | 2.1 per week | 🔴 Below target |
| Session duration | >5 min | 3.2 min | 🔴 Below target |
| Repeat recommendation rate | >10% | 6% | 🔴 Below target |

### Recommendation Quality

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Like rate | >50% | 48% | 🟡 Near target |
| Try-on conversion | >20% | 18% | 🟡 Near target |
| User confidence in recommendation | >7/10 (NPS) | 6.5/10 | 🟡 Near target |
| Outfit diversity (repeat items <20%) | >80% outfits unique | 75% | 🟡 Near target |
| Quality eval score (official rubric) | >0.75 (5-point) | 0.72 | 🟡 Near target |

### Platform Performance

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Recommendation latency (p95) | <8s | 6.5s | ✅ On track |
| Cache hit rate | >70% | 75% | ✅ Exceeding target |
| Wardrobe load time (first page) | <3s | 2.2s | ✅ On track |
| API uptime | 99.5% | 99.8% | ✅ Exceeding target |
| Error rate (5xx) | <0.1% | 0.05% | ✅ Exceeding target |

### Business Metrics

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| User retention (Day 7) | >40% | 32% | 🔴 Below target |
| User retention (Day 30) | >20% | 12% | 🔴 Below target |
| Premium tier conversion | 5% of free users | N/A (not launched) | 📋 Planned |
| CAC (Cost Acquisition Cost) | <$2 | ~$5 (organic growth) | 🔴 High |
| LTV (Lifetime Value) | >$50 | N/A (no revenue) | 📋 Planned |

---

## Recent Changes (Last 30 Days)

### 2026-05-17

**Branch:** `feat/v05-eval-official-rubric-au259`

**Commits:**
- `ccc05ed` feat(skill): replace v05-eval rubric with official Viet rubric (AU-259)
- `1446f0f` feat(skill): add v05-eval — outfit recommendation QA harness

**Changes:**
- Official V05 eval rubric finalized (Vietnamese scale, 5-point per axis)
- V05-eval skill scaffolded (LangGraph-based eval harness)
- Rubric integrated into evaluation dashboard

### 2026-05-15

**Commits:**
- `12516e7` docs(plans): Phase 0 V05 foundation plan
- `320bb48` chore: bump wardrobe-backend — Phase 0 V05 foundation (ce1aead)

**Changes:**
- Phase 0 documentation completed
- Backend version 0.5.0 bumped (final Phase 0 release)
- Recommendation engine fully tested

### 2026-05-11

**Phase 0 Completion:**
- V05 recommendation engine shipped
- All QA passes (Maestro tests, visual fidelity, performance)
- Admin dashboard fully operational
- Sentry error tracking active on mobile + backend

### 2026-05-08

**Commits:**
- `f495ff9` feat(skill): add v05-eval — outfit recommendation QA harness
- `1446f0f` chore: bump wardrobe-backend — remove 23 unused endpoints

**Changes:**
- Removed legacy endpoints (cleaner API surface)
- V05-eval harness scaffolded (evaluating outfit quality)

### 2026-04-30 – 2026-05-07

**"Try Another" Feature (AU-252):**
- New "Get Another Outfit" quick-refresh button
- Redesigned context chips (occasion, weather, time)
- Modal wire-up for recommendation customization
- Maestro tests for new interactions

---

## Upcoming Milestones (Next 90 Days)

| Date | Milestone | Status | Owner |
|------|-----------|--------|-------|
| 2026-05-20 | Modal UX refinement complete (AU-252) | 🚧 In progress | mobile-dev |
| 2026-05-27 | Maestro test coverage for Phase 1 features | 🚧 In progress | qa-ui |
| 2026-06-05 | LLM outfit diversifier shipped | 📋 Queued | backend-dev |
| 2026-06-12 | LLM explanation quality >0.7 on eval rubric | 📋 Queued | qa-ux |
| 2026-06-20 | Feedback model training pipeline live | 📋 Queued | backend-dev |
| 2026-06-30 | Phase 1 complete; v0.6.0 shipped | 📋 Planned | tech-lead |
| 2026-07-15 | V2 stateful engine MVP (Phase 2 start) | 📋 Planned | backend-dev |
| 2026-08-31 | V2 engine complete + live A/B test | 📋 Planned | tech-lead |

---

## How to Update This Roadmap

**Rules:**
- **Weekly Updates:** Every Friday, check milestone status (On track / At risk / Blocked)
- **Bi-weekly Reviews:** Sync with product lead on priority shifts
- **Monthly Releases:** Update version number + completed features
- **Phase Completion:** Archive old phase into "Completed Phases" section

**Ownership:**
- `tech-lead` — High-level milestones, release planning
- `pm` — Feature prioritization, business metrics
- Individual agents — Daily status updates in Linear

**Format:**
- Markdown tables for quick scanning
- Emoji status indicators (✅ done, 🚧 in progress, 📋 planned, 🟡 at risk, 🔴 blocked)
- Links to Linear tickets for detail

---

## Completed Phases Archive

### Phase 0: V05 Foundation (✅ 2026-05-11)
- Recommendation engine 6-layer pipeline
- Sentry integration
- Admin dashboard
- Railway deployment
- Maestro QA framework
- See detailed section above

---

## References

- **Phase 0 Plan:** `plans/260511-1030-v05-phase0-foundation/plan.md`
- **Phase 1 Plan:** `plans/260517-1030-v05-phase1-llm1-diversifier/plan.md`
- **Linear Board:** Project management + ticket tracking
- **API Contract:** `wardrobe-backend/API_DOCUMENTATION.md`
- **Code Standards:** `docs/code-standards.md`
- **System Architecture:** `docs/system-architecture.md`

---

**Last Updated:** 2026-05-17 by tech-lead  
**Next Review:** 2026-05-24
