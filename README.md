# Auxi — Personal Wardrobe + AI Outfit Recommender

Auxi is an AI-powered personal wardrobe management system that helps users organize their clothing and get contextual outfit recommendations. Built with React Native (mobile), FastAPI (backend), and powered by Google Gemini for virtual try-on and image intelligence.

## Architecture Overview

Auxi is an **umbrella repository** bundling the mobile app and backend as git submodules, with a shared admin dashboard for operations.

| Repo | Stack | Purpose | Status |
|---|---|---|---|
| `auxi/` (submodule) | React Native 0.83 · React 19 · TypeScript 5.8 | User-facing mobile app (iOS/Android) | Production |
| `wardrobe-backend/` (submodule) | FastAPI · SQLAlchemy · PostgreSQL · Gemini | Recommendation engine + auth + uploads | Production |
| `wardrobe-admin/` (in backend) | React 19 · Vite 7 · Ant Design 6 · TailwindCSS 4 | Internal ops dashboard (Cloudflare) | Production |
| `auxi-web/` | Astro 6 · TailwindCSS 4 | Marketing site (Cloudflare Pages) | Production |

## Clone & Setup

```bash
# Clone with submodules
git clone --recurse-submodules <repo-url> wardrobe_project
cd wardrobe_project

# If already cloned without --recurse-submodules
git submodule update --init --recursive
```

## Develop

**Terminal 1 — Backend:**
```bash
cd wardrobe-backend
pip install -r requirements.txt
uvicorn app:app --reload --port 5001
```

**Terminal 2 — Mobile (iOS simulator):**
```bash
cd auxi
yarn install
yarn ios:sim
```

## QA Boot (one-shot)

For full-stack QA sessions:

```bash
./scripts/qa-boot.sh    # Brings up backend, Metro, iOS sim
./scripts/qa-stop.sh    # Tears it down
```

Logs: `logs/backend.log`, `logs/metro.log`. First run: ~2 minutes; subsequent: ~30–60s.

## Admin Dashboard

The internal ops dashboard is **not a git submodule**—it lives at `wardrobe-backend/wardrobe-admin/`.

**Stack:** React 19 · Vite 7 · TypeScript 5.9 · Tailwind 4 · Ant Design 6.

**Pages:**
- Dashboard — System overview
- Users / UserDetail — Manage users, promote to admin
- CommonItems — CRUD global garment catalog
- BulkAutoTag — Bulk Gemini tagging
- AlgorithmCockpit — ML config versioning
- RecommendationTest — Engine sandbox
- RecommendationEvaluation — Quality scoring

**Run locally** (assumes backend on `:5001`):
```bash
cd wardrobe-backend/wardrobe-admin
npm install
npm run dev    # http://localhost:5173
```

**Create first admin user:**
```bash
cd wardrobe-backend
python scripts/create_admin.py admin@example.com <password>
```

**Deploy to Cloudflare:**
```bash
npm run build:prod
npm run deploy:prod
```

## Submodule Workflow

```bash
# Update both to latest tracked-branch HEAD
git submodule update --remote --merge

# Pin new HEADs in umbrella repo
git add auxi wardrobe-backend
git commit -m "chore: bump submodules"

# Push a submodule's work
cd auxi
git push origin main
cd ..
```

## Agent Matrix

This repo ships with **role-scoped agents** in `.claude/agents/`. Dispatch via Claude Code:

| Agent | Scope | Use for |
|---|---|---|
| `mobile-dev` | `auxi/` only | RN screens, navigation, services, theme |
| `backend-dev` | `wardrobe-backend/` only | FastAPI routers, services, database migrations |
| `tech-lead` | Both (read-mostly) | Contract changes, breaking migrations, design reviews, releases |
| `qa-mobile` | `auxi/` + test runs | Smoke, regression, Maestro execution |
| `qa-ui` | `auxi/` (read-only) | Visual fidelity, Figma comparison, alignment/icons/typography |
| `qa-ux` | `auxi/` (read-only) | UX heuristics, a11y review (Nielsen's 10, state coverage) |
| `pm` | Linear board (project-wide) | Tickets, roadmap, verified close |

Example dispatch:
> "Use the mobile-dev agent to add a wardrobe filter chip on HomeScreen."

## Key Files

**Mobile (`auxi/`):**
- `src/services/` — API clients (apiClient, auth, wardrobe, recommendation, try-on, etc.)
- `src/screens/` — Screen components (15 screens + onboarding variants)
- `src/navigation/AppNavigator.tsx` — Navigation registration (MUST update when adding screens)
- `src/theme/theme.ts` — Design tokens (no hardcoded hex)
- `maestro/flows/` — Maestro QA test definitions

**Backend (`wardrobe-backend/`):**
- `routers/` — HTTP endpoints (auth, wardrobe, upload, try-on, recommendation, admin)
- `services/` — Business logic (user service, wardrobe service, recommendation engines)
- `blueprints/recommendation/engine_v05.py` — V05 deterministic recommendation pipeline
- `API_DOCUMENTATION.md` — Full API contract (MUST update when modifying routes)
- `test_server.py` — Automated e2e test runner

**Admin (`wardrobe-admin/`):**
- `src/pages/` — React Router pages
- `src/services/` — API clients
- `src/context/AuthContext.tsx` — Auth state

## Verification Gates

Before claiming work done end-to-end:

1. **Backend:** `cd wardrobe-backend && python test_server.py` ✓
2. **Mobile:** `cd auxi && npx tsc --noEmit && yarn lint` ✓
3. **Smoke:** Backend on `:5001`, real HTTP requests from mobile ✓

**Never ship mobile changes against a mocked backend** — contract drift is why this umbrella exists.

## Key Conventions

### Mobile (`auxi/`)
- **testID on every interactive element** — Format: `<feature>-<element>-<state>` (e.g., `home-mode-pill-safe`). Maestro depends on this.
- **No Redux/Zustand** — TanStack React Query covers server state; AuthContext covers user state.
- **Service-layer-only API calls** — Never import axios directly from screens.
- **SVG icons** — `import Icon from '../assets/icons/icon_foo.svg'` then render as `<Icon width={20} height={20} />`.
- **Theme tokens** — No hex literals; use `theme.ts` colors.

### Backend (`wardrobe-backend/`)
- **Router → Service → Repository pattern** — Keep HTTP concerns in routers, business logic in services, DB queries in repositories.
- **Ephemeral file handling** — Use `EphemeralFileManager` for temp files; delete after processing.
- **Bearer auth + dependency injection** — `@require_auth` decorator + `get_current_user` dependency.
- **API_DOCUMENTATION.md is the contract** — Update immediately when modifying routes.

### Admin (`wardrobe-admin/`)
- **TanStack Query for server state** — No Redux.
- **React Router 7 patterns** — Client-side routing with protected routes.
- **ProtectedRoute + AuthContext** — All routes require login; admin role enforced server-side.

## Current Development Focus

**Branch:** `feat/v05-eval-official-rubric-au259`  
**Milestone:** V05 recommendation engine improvements (Phase 0 ✓, Phase 1 LLM diversifier 🚧)

Recent completed:
- Sentry integration (mobile + backend)
- Deploy automation (launch-notify skill)
- Figma audit tooling
- "Try Another" batch refresh (AU-252)

Upcoming:
- V05 phase 1 LLM diversifier
- Modal wire-up refinement
- Feedback model integration

## Per-Repo Documentation

Repo-specific conventions override anything here:
- `auxi/CLAUDE.md` — RN conventions, navigation registration, dual-HomeScreen status
- `wardrobe-backend/CLAUDE.md` — Service-repository pattern, ephemeral file manager, auth rules

See `docs/` for full technical documentation.
