# Git & Development Process Standards

Commit messages, pre-commit checks, secrets management, and deployment rules.

---

## Commit Message Format

**All repos:** Conventional Commits (https://www.conventionalcommits.org/)

```
<type>: <short description>

[optional body with details]

[optional footer with breaking changes or related issues]

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

### Types
- `feat` — New feature
- `fix` — Bug fix
- `refactor` — Code change (no feature, no bug)
- `docs` — Documentation only
- `test` — Adding or updating tests
- `chore` — Dependencies, config, maintenance
- `perf` — Performance improvement

### Examples

```bash
# Simple commit
git commit -m "feat: Add outfit recommendation context chips"

# With body (use HEREDOC for proper formatting)
git commit -m "$(cat <<'EOF'
feat: Implement V05 recommendation engine

Add 6-layer deterministic outfit pipeline:
1. Pool generation (user items + common)
2. Silhouette filtering
3. Color harmonization
4. Layering system
5. Footwear matching
6. Accessory suggestion

Performance: <8s p95 with Redis caching.
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

# Fix with issue reference
git commit -m "fix: Resolve token refresh race condition

Fixes AU-123"
```

### Rules
- **No AI references** unless co-authoring (then use footer)
- **Focus on "why"** not "what"
- **Reference Linear tickets** if applicable
- **Keep first line <50 characters**
- **Wrap body at 72 characters**

---

## Pre-Commit Checklist

**You MUST run these before pushing.**

### Mobile (auxi/)
```bash
npx tsc --noEmit              # TypeScript check (legacy errors expected)
yarn lint                      # ESLint (baseline: 4 errors, 3 warnings)
yarn test                      # Jest tests
```

### Backend (wardrobe-backend/)
```bash
python test_server.py           # Automated e2e tests (port 5002)
pytest                          # Unit + integration tests
pytest --cov=. --cov-report=html  # Coverage (aim for >80%)
```

### Admin (wardrobe-admin/)
```bash
npm run lint                   # ESLint + Prettier
npm run build                  # Production build check
npm run test                   # Jest tests
```

**CRITICAL:** Do NOT commit if tests fail. Fix the code, not the tests.

---

## Secrets & Environment Variables

### NEVER Commit
- `.env` files (local)
- `secrets.json` or `credentials.json`
- API keys, database passwords, JWT secrets
- OAuth tokens, personal access tokens

### DO Commit
- `.env.example` with placeholder values (shows structure)
- `.gitignore` (includes `*.env`)

### Example .env.example

```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/wardrobe

# Auth
JWT_SECRET_KEY=change_me_in_production

# Gemini
GOOGLE_STUDIO_KEY=your_api_key_here

# AWS
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
```

### .gitignore Pattern

```
# Environment
.env
.env.local
.env.production.local

# Secrets
secrets.json
credentials.json
*.pem
*.key

# Build artifacts
node_modules/
.venv/
__pycache__/
*.pyc

# IDE
.idea/
.vscode/
*.swp
```

---

## Pull Request Process

### PR Title
Same format as commit messages:
```
feat: Add user wardrobe management API
fix: Resolve token refresh race condition
```

### PR Description Template

```markdown
## Summary
Brief description of changes (1-3 sentences).

## Changes
- Bullet point 1
- Bullet point 2
- Include files modified

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] `python test_server.py` passes (backend)
- [ ] `npx tsc --noEmit && yarn lint` passes (mobile)
- [ ] Manual testing completed

## API Changes
- [ ] `API_DOCUMENTATION.md` updated (if applicable)

## Screenshots/Videos
(if UI-related or visual changes)

## Related Issues
Fixes #AU-123
```

### PR Checklist
- [ ] Branch is up to date with main
- [ ] All tests pass
- [ ] No merge conflicts
- [ ] Documentation updated
- [ ] Code review requested

---

## Branch Naming

**Format:** `<type>/<description>`

```
feature/auth-jwt-refresh        # New feature
fix/token-expiry-race           # Bug fix
refactor/recommendation-engine  # Code refactoring
docs/api-documentation          # Documentation
test/maestro-coverage           # Testing
chore/update-dependencies       # Maintenance

❌ WRONG:
- Auth (no slash)
- feature_auth (underscore)
- WIP-token-fix (WIP tag unnecessary)
```

---

## Git Workflow

### Start New Feature

```bash
git checkout main
git pull origin main
git checkout -b feature/new-feature
```

### Regular Workflow

```bash
# Make changes
git status
git add <specific-files>    # Don't use git add -A or .
git commit -m "feat: Description"

# Keep up to date
git pull origin main        # Or git pull --rebase
git push -u origin feature/new-feature
```

### Update Feature Branch with Main

```bash
git checkout main
git pull origin main
git checkout feature/new-feature
git merge main              # Or git rebase main
```

### Create PR

```bash
gh pr create --title "feat: Description" --body "$(cat <<'EOF'
## Summary
...
## Changes
...
EOF
)"
```

---

## Protected Operations

### NEVER Do Without Explicit Request
- `git push --force` (especially to main/master)
- `git reset --hard`
- `git commit --amend` on shared branches
- Direct push to main/master

### Safe Operations
- `git pull --rebase` on feature branches
- `git merge` from main to feature branch
- `git push` to feature branches

---

## Merge Strategy

**Primary:** Squash and merge (clean history)

**When to use:**
- Feature branch → main: Squash
- Hotfix → main: Merge commit (preserve history)
- Main → release branch: Merge commit

```bash
# Squash merge (preferred for features)
git checkout main
git merge --squash feature/my-feature
git commit -m "feat: My feature"

# Regular merge (for hotfixes)
git merge --no-ff hotfix/critical-bug
```

---

## Deployment Checklist

### Before Pushing to main

- [ ] All tests pass locally
- [ ] No console errors in dev
- [ ] API contract updated (if backend change)
- [ ] Code review completed
- [ ] PR description is clear

### Before Deploying to Production

- [ ] Tagged version (v0.5.1)
- [ ] CHANGELOG.md updated
- [ ] All CI checks pass
- [ ] Manual QA on staging
- [ ] Rollback plan documented

### Post-Deployment

- [ ] Monitor Sentry for errors
- [ ] Check key metrics (latency, error rate, uptime)
- [ ] Alert on-call engineer if issues detected

---

## Reverting Changes

### Revert a Commit

```bash
# Safe: Creates new commit that undoes changes
git revert <commit-hash>

# Then push
git push origin main
```

### Revert a Merge

```bash
# Revert the merge commit (mainline parent 1)
git revert -m 1 <merge-commit-hash>
```

### Force Reset (Only on Feature Branches)

```bash
# DANGEROUS - Only if you own the branch
git reset --hard <commit-hash>
git push -f origin feature/my-feature
```

---

## Conflict Resolution

### Merging Main Into Feature

```bash
# Pull latest main
git fetch origin
git rebase origin/main

# Resolve conflicts
# Edit conflicting files; remove conflict markers

# Mark as resolved
git add <resolved-file>

# Continue rebase
git rebase --continue

# Push (with force, since you've rewritten history)
git push -f origin feature/my-feature
```

### Merging Feature Into Main

```bash
git checkout main
git merge feature/my-feature

# If conflicts:
# 1. Edit conflicting files
# 2. git add <resolved-file>
# 3. git commit (no message needed for merge)
# 4. git push origin main
```

---

## Stashing Work

### Save Work in Progress

```bash
# Save with message
git stash push -m "WIP: feature description"

# List stashes
git stash list

# Apply and keep stash
git stash apply stash@{0}

# Apply and remove stash
git stash pop
```

---

## Code Review Guidelines

### For Reviewers

- Focus on: logic, security, performance, maintainability
- Request changes if: bugs, security issues, poor practices
- Approve if: code quality acceptable, tests passing, no red flags
- Comment on style only if inconsistent with standards

### For Authors

- Respond to all comments
- Mark conversations resolved after addressing
- Re-request review after updates
- Be open to feedback; it makes code better

---

## Release Process

### Version Numbering

**SemVer:** `MAJOR.MINOR.PATCH`

- `MAJOR` — Breaking changes (0.5.0 → 1.0.0)
- `MINOR` — Features (0.5.0 → 0.6.0)
- `PATCH` — Bug fixes (0.5.0 → 0.5.1)

### Creating a Release

```bash
# Update version in package.json / pyproject.toml
# Update CHANGELOG.md

git add package.json CHANGELOG.md
git commit -m "chore: v0.5.1 release"

# Tag
git tag -a v0.5.1 -m "Release v0.5.1"

# Push
git push origin main --follow-tags
```

### Update CHANGELOG.md

```markdown
## [0.5.1] - 2026-05-17

### Added
- Feature X

### Fixed
- Bug Y

### Changed
- Behavior Z

## [0.5.0] - 2026-05-11
...
```

---

## Useful Git Aliases

Add to `.gitconfig`:

```bash
[alias]
    st = status
    co = checkout
    br = branch
    cm = commit
    log-one = log --oneline -10
    last = log -1 HEAD
    unstage = reset HEAD --
    discard = checkout --
    amend = commit --amend --no-edit
```

Usage:
```bash
git st              # git status
git co -b feature/x # git checkout -b feature/x
git cm -m "msg"     # git commit -m "msg"
```

---

## Monitoring & Notifications

### Set Up Pre-Commit Hook (Optional)

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Run linting
npm run lint
if [ $? -ne 0 ]; then
  echo "Linting failed. Commit aborted."
  exit 1
fi

# Run tests
npm run test
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi

exit 0
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

### GitHub Actions CI/CD

Example workflow (`.github/workflows/ci.yml`):
```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm install
      - run: npm run lint
      - run: npm run test
```

---

## Emergency Procedures

### Critical Bug in Production

```bash
# 1. Create hotfix branch
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# 2. Fix the issue
# (make changes)

# 3. Commit with meaningful message
git commit -m "fix: Critical bug description"

# 4. Tag as patch version
git tag v0.5.1

# 5. Push
git push origin hotfix/critical-bug --follow-tags

# 6. Create PR, get reviewed, merge to main
# 7. Merge main back to dev (if dev branch exists)
```

### Deployed Wrong Version

```bash
# Identify last good commit
git log --oneline | head -10

# Revert to good state
git revert <bad-commit-hash>

# Or reset and force push (only for unreleased commits)
git reset --hard <good-commit-hash>
git push -f origin main
```
