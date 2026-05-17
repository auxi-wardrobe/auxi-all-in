# Auxi — Code Standards & Conventions

This document defines coding standards across all three Auxi codebases (mobile, backend, admin). Repo-specific standards are in `{repo}/CLAUDE.md` and override this document when they conflict.

---

## Quick Navigation

| Topic | Purpose | Location |
|-------|---------|----------|
| **General Principles** | YAGNI, KISS, DRY, file size rules | [general-principles.md](./general-principles.md) |
| **File Naming** | kebab-case, language conventions, self-documenting names | [file-naming.md](./file-naming.md) |
| **Mobile (React Native)** | testID discipline, navigation registration, service layer, theme tokens, TanStack Query | [mobile-standards.md](./mobile-standards.md) |
| **Backend (FastAPI)** | Router→Service→Repository pattern, ephemeral files, API docs, Pydantic schemas | [backend-standards.md](./backend-standards.md) |
| **Admin (React)** | TanStack Query, React Router 7, protected routes, AuthContext | [admin-standards.md](./admin-standards.md) |
| **Commits & Process** | Conventional commits, pre-commit checks, secrets management | [git-and-process.md](./git-and-process.md) |
| **Performance & Testing** | Optimization targets, test structure, coverage goals | [performance-and-testing.md](./performance-and-testing.md) |

---

## Core Principles (Across All Repos)

**YAGNI** — You Aren't Gonna Need It. Don't over-engineer; build for today's requirements.

**KISS** — Keep It Simple, Stupid. Clarity beats cleverness.

**DRY** — Don't Repeat Yourself. Extract common patterns into reusable modules.

**File Size Management** — Keep individual code files under 200 lines (comments + code). Split larger files into focused modules.

---

## Key Rules (Summary)

### Mobile (auxi/)
- ✅ **testID on EVERY interactive element** — Maestro QA depends on it (format: `<feature>-<element>-<state>`)
- ✅ **Register new screens in TWO places** — `src/types/navigation.ts` + `src/navigation/AppNavigator.tsx`
- ✅ **Service-layer-only API calls** — Never import axios directly from screens
- ✅ **No Redux/Zustand** — TanStack Query + AuthContext only
- ✅ **Theme tokens** — No hardcoded hex colors; use `src/theme/theme.ts`

### Backend (wardrobe-backend/)
- ✅ **Router → Service → Repository pattern** — HTTP concerns / business logic / DB queries separated
- ✅ **API_DOCUMENTATION.md is the contract** — Update immediately when modifying routes
- ✅ **Ephemeral file handling** — Use `EphemeralFileManager` for temp files; delete after processing
- ✅ **Bearer token + dependency injection** — `@require_auth` decorator + `get_current_user` dependency
- ✅ **Pydantic schemas for all I/O** — Request/response validation always

### Admin (wardrobe-admin/)
- ✅ **TanStack Query for server state** — No Redux
- ✅ **React Router 7 patterns** — Client-side routing, protected routes
- ✅ **AuthContext for user state** — Login/logout/admin role validation

### All Repos
- ✅ **Conventional commits** — `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- ✅ **Run tests before push** — `python test_server.py` (backend), `yarn lint && npx tsc --noEmit` (mobile)
- ✅ **Never commit secrets** — Use `.env.example` for documentation

---

## File Ownership & Per-Repo CLAUDEs

**Authoritative per-repo standards:**
- `auxi/CLAUDE.md` — RN conventions, navigation registration, dual-HomeScreen status, verification gates
- `wardrobe-backend/CLAUDE.md` — Service-repository pattern, ephemeral file manager, auth rules, testing

**When conflict:** Per-repo CLAUDE.md wins.

---

**Start with:** [general-principles.md](./general-principles.md) for philosophy, then jump to your repo-specific guide (mobile-standards.md, backend-standards.md, or admin-standards.md).
