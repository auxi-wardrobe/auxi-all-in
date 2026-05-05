# Wardrobe Project (Auxi)

Umbrella repo bundling the Auxi mobile app and its backend as git submodules,
plus a Claude Code agent/skill setup tailored to a small cross-functional
team (mobile dev, backend dev, tech lead, mobile QA).

## Submodules

| Path | Repo | Stack |
|---|---|---|
| `auxi/` | [ducga1998/auxi-mobile](https://github.com/ducga1998/auxi-mobile) | React Native 0.83 + TypeScript |
| `wardrobe-backend/` | [ducga1998/wardrobe-backend](https://github.com/ducga1998/wardrobe-backend) | FastAPI + SQLAlchemy + Gemini |

The backend submodule also houses **`wardrobe-admin/`** — an internal admin dashboard
(React 19 + Vite + TypeScript + Ant Design) used by ops/PM to manage users, common
items, recommendation experiments, and ML config. See [Admin dashboard](#admin-dashboard) below.

## Clone

```bash
git clone --recurse-submodules <this-repo-url>
cd wardrobe_project
```

If you've already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Develop

```bash
# Backend (terminal 1)
cd wardrobe-backend
pip install -r requirements.txt
uvicorn app:app --reload --port 5001

# Mobile (terminal 2)
cd auxi
yarn install
yarn ios:sim
```

## QA boot (one-shot)

For QA sessions that need both backend and mobile up at once:

```bash
./scripts/qa-boot.sh    # brings up backend, Metro, iOS sim, prints checklist
./scripts/qa-stop.sh    # tears it down (sim stays open)
```

Logs land in `logs/backend.log` and `logs/metro.log` — attach them to any
bug report per `auxi-qa-test.md`. PIDs are tracked in `logs/pids.txt`.

First run takes ~2 minutes (creates the backend `.venv/` and runs `pip
install`). Subsequent runs are ~30-60s.

The script is idempotent — re-running kills any existing listeners on
:5001 and :8081 before starting fresh.

## Admin dashboard

`wardrobe-backend/wardrobe-admin/` is a self-contained React SPA that talks to
the same FastAPI backend (`routers/admin/*`). It's not a git submodule — it
lives as a normal subdirectory inside the `wardrobe-backend` repo.

**Stack:** React 19 · Vite 7 · TypeScript 5.9 · Tailwind 4 · Ant Design 6 · TanStack Query 5 · React Router 7 · axios. Deployed to Cloudflare via Wrangler.

**Pages** (`src/pages/`):

| Page | Purpose |
|---|---|
| `Dashboard` | Landing — system overview |
| `Users` / `UserDetail` | User management, role/admin promotion, profile inspection |
| `CommonItems` | CRUD on the global garment catalog (the items recommended to all users) |
| `BulkAutoTag` | Bulk-tag common items via Gemini (calls `POST /admin/common-items/auto-tag-all`) |
| `AlgorithmCockpit` | Versioned ML config — promote/rollback recommendation parameters |
| `RecommendationTest` | Run the recommendation engine against a user/scenario without persisting results |
| `RecommendationEvaluation` | Score recommendation quality across users/sessions |
| `ValenRecommendation` | Specific Valentine's-themed recommendation experiment |

All routes are protected by `ProtectedRoute` + `AuthContext` — login required, admin role enforced server-side.

**Backend pairing.** The admin SPA is paired with `wardrobe-backend/routers/admin/`:

- `routers/admin/config.py` — versioned recommendation config (`/admin/configs`, promote/rollback)
- `routers/admin/common_items.py` — CRUD on `common_items` table + AI gender classification
- `routers/admin/tagger.py` — bulk auto-tagging via Gemini
- `routers/admin/users.py` — user list + promote-to-admin
- `routers/admin/simulation.py` — recommendation testing
- `routers/admin/models.py` — model registry

To create the first admin user against a local backend:

```bash
cd wardrobe-backend
python scripts/create_admin.py admin@example.com <password>
```

(The script promotes an existing user to `admin` role, or creates one if missing. Source: `wardrobe-backend/scripts/create_admin.py`.)

**Run locally** (assumes the backend is already up on `:5001`):

```bash
cd wardrobe-backend/wardrobe-admin
npm install
npm run dev    # Vite dev server, http://localhost:5173 by default
```

Build & deploy to Cloudflare (production backend at `wardrobe-backend-production-c8d9.up.railway.app`):

```bash
npm run build:prod   # bundles with VITE_API_URL pointing to prod
npm run deploy:prod  # wrangler deploy
```

The admin app's own README (currently the default Vite template — replace when touching) lives at `wardrobe-backend/wardrobe-admin/README.md`. Worker entry: `worker.js`. Wrangler config: `wrangler.jsonc`.

## Working with submodules

```bash
# Update both submodules to latest tracked-branch HEAD
git submodule update --remote --merge

# Pin the new HEADs in this repo
git add auxi wardrobe-backend
git commit -m "chore: bump submodules"

# Push a submodule's local work
cd auxi
git push origin main
cd ..
```

## Claude Code setup

This repo ships with role-scoped agents and skills under `.claude/`. See
[CLAUDE.md](CLAUDE.md) for the agent matrix and the two-repo contract rules.

- `mobile-dev` — works inside `auxi/` only
- `backend-dev` — works inside `wardrobe-backend/` only
- `tech-lead` — cross-repo coordination, design review, release planning
- `qa-mobile` — mobile testing and regression
- `qa-ui` — visual fidelity QA (alignment, icons, typography, colors), sweep + Figma compare modes

To dispatch an agent, ask Claude Code something like:

> "Use the mobile-dev agent to add a new wardrobe filter chip on HomeScreen."
