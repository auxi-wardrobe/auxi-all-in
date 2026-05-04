# Wardrobe Project (Auxi)

Umbrella repo bundling the Auxi mobile app and its backend as git submodules,
plus a Claude Code agent/skill setup tailored to a small cross-functional
team (mobile dev, backend dev, tech lead, mobile QA).

## Submodules

| Path | Repo | Stack |
|---|---|---|
| `auxi/` | [ducga1998/auxi-mobile](https://github.com/ducga1998/auxi-mobile) | React Native 0.83 + TypeScript |
| `wardrobe-backend/` | [ducga1998/wardrobe-backend](https://github.com/ducga1998/wardrobe-backend) | FastAPI + SQLAlchemy + Gemini |

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

To dispatch an agent, ask Claude Code something like:

> "Use the mobile-dev agent to add a new wardrobe filter chip on HomeScreen."
