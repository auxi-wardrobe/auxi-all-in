---
name: cross-repo-coordination
description: How to coordinate changes across the auxi (RN) and wardrobe-backend (FastAPI) submodules. Use when planning a feature that crosses the HTTP boundary, sequencing a release, or pinning submodule HEADs in this umbrella repo.
---

# Cross-Repo Coordination

The umbrella repo `wardrobe_project/` exists for one reason: keeping the
HTTP contract between `auxi/` (mobile) and `wardrobe-backend/` (API)
honest. This skill is the playbook.

## The contract

```
auxi (axios via src/services/apiClient.ts)
   │
   ▼ HTTP, base URL hardcoded "http://localhost:5001/api"
   │
wardrobe-backend (FastAPI)
   ▲
   │
   └── source of truth: API_DOCUMENTATION.md
```

Rules:
- The doc is the contract. No codegen, no shared SDK. Whoever changes a
  route updates the doc in the same edit.
- Mobile callers MUST match what the doc says — not what the developer
  remembers.
- Breaking changes are sequenced: backend deploys first, mobile pins to
  the new submodule HEAD second, mobile ships third.

## Feature-flow checklist

When you get a feature that touches both repos:

1. **Read both `CLAUDE.md` files**: umbrella, `auxi/`, `wardrobe-backend/`.
2. **Decide the API surface first** — endpoint(s), request shape, response
   shape, error codes, rate limits. Write it as a markdown spec the
   backend-dev and mobile-dev can both read.
3. **Backend implements first**, including:
   - Router/service/repo
   - Tests (`pytest -m unit`, `-m integration`)
   - `API_DOCUMENTATION.md` updated in the same PR
   - `python test_server.py` green
4. **Mobile implements second**, against the documented contract:
   - `src/services/<feature>.ts` matching the doc
   - TanStack Query hooks
   - Screens
   - `npx tsc --noEmit` clean (legacy errors aside)
5. **Umbrella update**: bump submodule HEADs in `wardrobe_project/`, commit
   with `chore: bump submodules`.

## Submodule operations

```bash
# pull latest from each submodule's tracked branch
git submodule update --remote --merge

# inspect what changed
git submodule status
git -C auxi log --oneline -5
git -C wardrobe-backend log --oneline -5

# pin new HEADs in umbrella
git add auxi wardrobe-backend
git commit -m "chore: bump submodules to <date>"
```

To clone fresh:

```bash
git clone --recurse-submodules <umbrella-url>

# or after a non-recursive clone
git submodule update --init --recursive
```

## Breaking-change protocol

If a backend route changes shape (rename field, drop endpoint, change
status code), it's a contract break. Treat it as a release event:

1. Backend dev opens a PR with the new shape AND the doc update.
2. Tech-lead reviews the contract diff. Mobile-dev signs off that the
   change is consumable.
3. Backend ships to staging.
4. Mobile-dev opens a PR matching the new contract.
5. Backend ships to prod.
6. Mobile ships next release with submodule HEAD pinned to the new
   backend.

Out-of-order = users on old mobile builds hit a 404 / 422. Don't.

## Hardcoded URL caveat

`http://localhost:5001/api` is hardcoded in `auxi/src/services/apiClient.ts`
and `auxi/src/services/auth.ts`. This is a known TODO from `auxi/CLAUDE.md`.
Don't propagate the pattern. The fix (move to `react-native-config` /
`.env`) is an explicit follow-up — coordinate before doing it ad-hoc.

## When you're tech-lead reviewing

Look for:
- A change in `wardrobe-backend/routers/**/routes.py` without a matching
  diff in `wardrobe-backend/API_DOCUMENTATION.md` → REJECT.
- A new endpoint in mobile `src/services/*.ts` that isn't documented in
  `API_DOCUMENTATION.md` → REJECT, ask backend-dev.
- Submodule HEAD bumps in umbrella that point to unmerged commits → ASK.
- Migrations that drop or rename columns → ESCALATE to user.

## Quick links

- Umbrella conventions: `CLAUDE.md`
- Mobile conventions: `auxi/CLAUDE.md`
- Backend conventions: `wardrobe-backend/CLAUDE.md`
- API contract: `wardrobe-backend/API_DOCUMENTATION.md`
- Models: `wardrobe-backend/MODELS_DOCUMENTATION.md`
