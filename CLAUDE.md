# Wardrobe Project — Umbrella Repo

> Personal-wardrobe + AI outfit recommender ("Auxi"). Two-repo monorepo via git submodules.

## Repo Layout

```
wardrobe_project/                      # ← this repo (umbrella)
├── auxi/                              # submodule → ducga1998/auxi-mobile
│   └── React Native 0.83 + TS 5 mobile app
├── wardrobe-backend/                  # submodule → ducga1998/wardrobe-backend
│   ├── FastAPI + SQLAlchemy + Gemini
│   └── wardrobe-admin/                # internal admin SPA (NOT a submodule)
│       └── React 19 + Vite + TS + Ant Design + Tailwind
│       └── deployed to Cloudflare via Wrangler
└── .claude/
    ├── agents/                        # role-scoped agents
    │   ├── mobile-dev.md              # works in auxi/ only · Figma-fluent
    │   ├── backend-dev.md             # works in wardrobe-backend/ only
    │   ├── tech-lead.md               # cross-repo, contracts & architecture
    │   ├── qa-mobile.md               # mobile QA on auxi/
    │   └── pm.md                      # senior PM, owns Linear tickets
    └── skills/                        # role-specific workflows
        ├── auxi-rn-patterns.md
        ├── wardrobe-fastapi-patterns.md
        ├── cross-repo-coordination.md
        ├── auxi-qa-test.md
        ├── figma-design-extraction.md # read Figma thoroughly
        ├── figma-to-rn-workflow.md    # implement Figma → RN faithfully
        └── linear-pm-workflow.md      # PM ticket lifecycle
```

**Rule of thumb**: dev agents are sandboxed to their own repo. Cross-repo work
(API contract changes, breaking schema migrations, release planning) goes
through `tech-lead`.

## Two-Repo Contract

The mobile app talks to the backend over a single HTTP boundary:

```
auxi (RN)            ──► axios (apiClient.ts)        ──►  wardrobe-backend FastAPI
wardrobe-admin (SPA) ──► axios (services/*)          ──►       :5001/api    +     /admin/*
                                                          (admin role enforced server-side)
```

There are two clients hitting the same backend:
- **`auxi/`** — public surface (`/api/*`), end-user mobile flows
- **`wardrobe-backend/wardrobe-admin/`** — internal ops surface (`/admin/*`), admin role required, used by PM/ops to manage users + common items + ML config + recommendation experiments

`auxi/` is the submodule under contract review. `wardrobe-admin/` is internal — its API (`routers/admin/*`) doesn't go through the same drift-prevention process as the public `/api`. When admin endpoints change, ping the admin's React maintainer directly; there's no auxi consumer to break.

When backend endpoints change in `wardrobe-backend/routers/**/routes.py`:
1. Backend dev updates `wardrobe-backend/API_DOCUMENTATION.md` (mandatory).
2. Tech-lead reviews the diff and signs off on contract changes.
3. Mobile dev syncs the corresponding `auxi/src/services/*.ts` client.

There is **no shared SDK**, no codegen — the API doc is the contract. Don't
let drift accumulate: whoever changes a route on either side is on the hook
to file a follow-up issue for the other side.

## Quick Start

```bash
# Clone with both submodules
git clone --recurse-submodules <umbrella-url> wardrobe_project
cd wardrobe_project

# If already cloned without --recurse-submodules
git submodule update --init --recursive

# Run backend (separate shell)
cd wardrobe-backend
uvicorn app:app --reload --port 5001

# Run mobile (separate shell, iOS sim)
cd auxi
yarn install
yarn ios:sim
```

### Updating submodules

```bash
# Pull latest commits on each submodule's tracked branch
git submodule update --remote --merge

# Pin to current submodule HEADs
git add auxi wardrobe-backend
git commit -m "chore: bump submodules"
```

## Stacks at a glance

| Repo | Stack | Package mgr | Test runner |
|---|---|---|---|
| `auxi` | RN 0.83 · React 19 · TS 5.8 · TanStack Query 5 · React Navigation 7 | yarn | jest |
| `wardrobe-backend` | Python 3.9+ · FastAPI · SQLAlchemy · Gemini · S3 | pip | pytest |

## Agents — when to use which

| Agent | Scope | Use when |
|---|---|---|
| `mobile-dev` | `auxi/` only · Figma-fluent | RN screens from Figma, navigation, services, theme, i18n |
| `backend-dev` | `wardrobe-backend/` only | FastAPI routers, services, repos, models, migrations |
| `tech-lead` | both repos (read-mostly) | Contract changes, breaking migrations, design reviews, release coordination |
| `qa-mobile` | `auxi/` (read + test runs) | iOS/Android smoke, regression, mobile-mcp UI verification |
| `qa-ui` | `auxi/` (read-only on src) · Figma-fluent | Visual fidelity sweeps, Figma-vs-actual diff, alignment/icon/typography/color/overflow bugs |
| `pm` | Linear board (project-wide) | New US, subtask splits, status sweeps, verified close |

**Figma note**: the designer is the CEO. `mobile-dev` is wired for the
Figma MCP and follows two skills together — `figma-design-extraction`
(read the file thoroughly) and `figma-to-rn-workflow` (implement
faithfully + verify on simulator). `qa-ui` also has Figma MCP access
for compare mode (design-vs-actual diff). Don't shortcut these for
visual work.

The agents are NOT generic — they refuse work outside their scope and route
to the right teammate. See each agent's frontmatter for hard boundaries.

## Verification gates (umbrella-level)

Before claiming a feature is done end-to-end:
1. Backend: `cd wardrobe-backend && python test_server.py` (full e2e on :5002)
2. Mobile: `cd auxi && npx tsc --noEmit && yarn lint`
3. Smoke: backend running on :5001, run mobile against it (real HTTP, not mocks).

If you're tempted to ship mobile changes against a mocked backend, **don't** —
the contract drift is exactly what this umbrella repo exists to prevent.

## Per-repo CLAUDE.md (authoritative)

The umbrella's role is coordination only. Repo-specific conventions live in:
- `auxi/CLAUDE.md` — RN conventions, navigation registration rule, dual-Home migration status
- `wardrobe-backend/CLAUDE.md` — service-repository pattern, EphemeralFileManager, security rules

When those conflict with anything here, the per-repo file wins.
