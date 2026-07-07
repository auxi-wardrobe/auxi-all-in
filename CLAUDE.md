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
    │   ├── devops.md                  # ops/infra: Railway, Cloudflare, DB, secrets, releases
    │   ├── qa-mobile.md               # mobile QA on auxi/, executes Maestro
    │   ├── qa-ui.md                   # visual fidelity, authors Maestro YAML
    │   ├── qa-ux.md                   # UX heuristic + a11y review
    │   ├── pm.md                      # senior PM, owns Linear tickets
    │   ├── designer.md                # post-code design-system craft gate (step 6.5)
    │   └── business-analyst.md        # product analytics on Mixpanel (EU) — funnels, dashboards, diagnostics
    └── skills/                        # role-specific workflows
        ├── auxi-rn-patterns.md
        ├── wardrobe-fastapi-patterns.md
        ├── cross-repo-coordination.md
        ├── auxi-qa-test.md
        ├── auxi-qa-ui.md              # visual QA + Maestro authoring
        ├── auxi-qa-ux.md              # UX heuristic review playbook
        ├── figma-design-extraction.md # read Figma thoroughly
        ├── figma-to-rn-workflow.md    # implement Figma → RN faithfully
        ├── linear-pm-workflow.md      # PM ticket lifecycle
        ├── linear-sweep.md            # autopilot Phase 1 — scheduled board sweep (daily 09:00 cloud routine)
        └── linear-autopilot.md        # autopilot Phase 2 — ticket→PR pipeline (dev→gates→review→QA→PR)
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
| `tech-lead` | both repos (read-mostly) | Contract changes, breaking migrations, design reviews, release decisions (when/what — devops executes) |
| `devops` | ops/infra files both repos · gated executor | Railway deploys + env/secret drift, prod↔local DB sync, Cloudflare/wrangler deploys + DNS/CORS, observability (Sentry/Railway metrics), release execution. Refuses app code |
| `qa-mobile` | `auxi/` (read + test runs) | iOS/Android smoke, regression, mobile-mcp UI verification |
| `qa-ui` | `auxi/` (read-only on src) · Figma-fluent | Visual fidelity sweeps, Figma-vs-actual diff, alignment/icon/typography/color/overflow bugs |
| `qa-ux` | `auxi/` (read-only on src) | UX heuristic + a11y review — Nielsen's 10, mobile patterns, state coverage, IA, touch targets, contrast, VoiceOver, Dynamic Type. Findings only, no fix code |
| `designer` | `auxi/` (read-only on src) · Figma-fluent | Post-code design-system craft gate (step 6.5) — token tier, motion language, color semantics, header/footer/layout, cross-screen consistency, component states. Findings only, HARD GATE (FAIL blocks PR), routes fixes → mobile-dev, taste → CEO |
| `pm` | Linear board (project-wide) | New US, subtask splits, status sweeps, verified close |
| `business-analyst` | Mixpanel (Auxi EU project) · read-mostly | Build a funnel/dashboard, analyze drop-off, diagnose a conversion problem, read what the data says. Verifies events are tracked before funnelling, distinguishes correlation/causation. Creates dashboards/metrics; never writes app code or changes tracking (routes that → mobile-dev) |

**Figma note**: the designer is the CEO. `mobile-dev` is wired for the
Figma MCP and follows two skills together — `figma-design-extraction`
(read the file thoroughly) and `figma-to-rn-workflow` (implement
faithfully + verify on simulator). `qa-ui` also has Figma MCP access
for compare mode (design-vs-actual diff). Don't shortcut these for
visual work.

## Mobile MCP tool grants (tiers)

When granting `mcp__mobile-mcp__*` tools to an agent, pick the **smallest
tier that fits the role**. Don't bulk-grant.

| Tier | Use case | Agent | Tools |
|---|---|---|---|
| **Read-only screenshot** | Visual fidelity compare · design-system craft review | `qa-ui`, `designer` | `launch_app`, `take_screenshot`, `save_screenshot`, `list_available_devices`, `list_elements_on_screen`, `click_on_screen_at_coordinates` |
| **Navigate + screenshot** | UX heuristic walks | `qa-ux` | Read-only + `swipe_on_screen`, `press_button`, `get_screen_size`, `list_apps`, `open_url` |
| **Full exploratory** | Smoke verify, ticket close-out | `qa-mobile` | Navigate + `type_keys`, `terminate_app`, `get_crash`, `list_crashes` |

`mobile-dev` does NOT have mobile-mcp — it writes code; sim verify hands
off to `qa-mobile`, `qa-ui`, or `designer`. `designer` carries the same
read-only screenshot tier as `qa-ui` (+ Figma MCP) to view the rendered
screen for its craft review. `tech-lead`, `backend-dev`, `devops`, `pm`
never need mobile-mcp. `devops` instead carries Railway + Cloudflare +
Sentry MCP grants — same "smallest tier that fits" rule applies (it gets
read + common-mutate Railway tools; destructive deletes are withheld to
force escalation).

Setup + health: `auxi/docs/MOBILE_MCP_MAC_IOS_SIM.md`.
Pre-flight: `./scripts/mcp-doctor.sh` (called best-effort by `qa-boot.sh`).
Version pinned in `.mcp.json` at project root — don't unpin.

## Figma → mobile UI workflow (canonical)

The CEO is the designer. Drift between Figma and shipped UI is the #1 quality
issue this project has. The workflow below is enforced — skipping any step
defeats the gate.

```
1. mobile-dev gets a Figma URL
   ↓
2. mobile-dev invokes `figma-design-extraction` skill
   → produces extraction note + saves to plans/<plan>/figma-extraction-<screen>.md
   ↓
3. mobile-dev auto-dispatches qa-ui (review-extraction mode)
   → audit note vs Figma, Pass 1 ONLY (no code yet)
   → PASS / FAIL / ESCALATE
   ↓
4. If PASS → mobile-dev invokes `figma-to-rn-workflow` skill
   → Phase 0 verifies artifact + qa-ui review status
   → Phase 1-7 implement
   ↓
5. `./scripts/auxi-lint-tokens.sh` clean (no hex/font drift)
   ↓
6. qa-ui Compare mode Pass 2+3 (code vs Figma, sim screenshot)
   ↓
6.5 designer design-review — HARD GATE (after qa-ui Compare PASS, before qa-mobile)
   → 8-lens product-experience pass: design-system → motion → hierarchy → color → states → cross-screen → native-feel → recommendation (+ journey continuity)
   → PASS / FAIL (blocks PR) / ESCALATE (taste → CEO)
   → findings to auxi/docs/design-reviews/<date>-<screen>.md
   ↓
7. qa-mobile smoke verify on sim (mobile-mcp exploratory)
   ↓
8. PR with template checklist all green → merge
```

**Supporting skills:**
- `figma-design-extraction` — pull Figma structure + tokens + variants
- `figma-to-rn-workflow` — Phase 0 artifact gate + 7-phase impl
- `figma-theme-sync` — diff Figma vars vs `auxi/src/theme/theme.ts` (token drift)
- `figma-icons-sync` — export missing SVGs with `currentColor` convention
- `figma-code-connect-setup` — map Figma component → RN primitive in inspector
- `auxi-rn-patterns` — primitives-first rule, screen registration, services
- `auxi-figma-audit` — 3-pass Compare mode audit (post-code)
- `auxi-design-review` — designer's 8-lens product-experience pass (step 6.5 hard gate); rule
  `design-review-required.md`; design-system docs in `auxi/docs/design-system/`

**Supporting scripts:**
- `./scripts/auxi-lint-tokens.sh` — hex literal + font family drift check
- `./scripts/mcp-doctor.sh` — sim + WDA + mobile-mcp health-check
- `./scripts/qa-boot.sh` — full stack boot + best-effort MCP doctor

**PR template** (`.github/PULL_REQUEST_TEMPLATE.md`) enforces:
- Figma URL with frame node-id
- Extraction artifact path
- qa-ui review-extraction PASS
- `auxi-lint-tokens.sh` clean
- designer design-review PASS (step 6.5 hard gate)
- Sim screenshot / qa-mobile verify ID

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
