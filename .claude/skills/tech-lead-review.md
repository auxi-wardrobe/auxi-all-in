---
name: tech-lead-review
description: "Procedural workflow for tech-lead Mode B (post-implementation code review). Six clean-code categories, severity-tagged findings, sign-off rule. Use when a dev agent has reported '→ next: tech-lead review' and the user dispatches you to review the diff."
---

# Tech Lead Review Playbook

You are running the post-implementation review on a dev agent's work. Your
job is to flag clean-code issues against a checklist and sign off (or
not) based on severity. You do NOT write the fix — you file findings and
hand back to the dev.

## Setup

1. **Identify the base branch.** Default: `main`. If the dev's branch
   targets a different base, use that.
   ```bash
   git merge-base HEAD main
   ```

2. **Get the diff.**
   ```bash
   git diff <base-sha>..HEAD
   ```

3. **Find the design doc** (Mode A output, if any). Look at:
   ```bash
   ls docs/*-design.md 2>/dev/null
   ```
   If a design doc matches the current feature, read it and cross-check
   the diff against it: did the dev implement what was specified?
   Anything extra? Anything missing?

## Clean-code checklist (six categories)

For each diff hunk, scan for issues in these six categories. Each
finding gets a severity tag (see definitions below).

### 1. Naming
- Names match what things DO (not how they're implemented)
- No `dataX`, `tempVar`, `result2`
- Verbs for functions, nouns for values
- Booleans read as questions: `isReady`, `hasItems`

### 2. Magic values
- Hardcoded strings/numbers that should be constants or config
- RN side: hex colors should be `theme.colors.X`, not `'#1A1A1A'`
- FastAPI side: timeouts, retry counts, page sizes — pull into module-level constants
- Exception: values that are clearly the value (e.g., `0`, `1`, `''`) — fine inline

### 3. Dead code
- Unused imports
- Unreachable branches (after early `return` / `throw`)
- Commented-out chunks (>2 lines)
- Leftover `console.log` / `print`
- `_HomeScreen`-style legacy duplicates that should have been removed in the migration

### 4. DRY violations (rule of three)
- 3+ near-identical blocks where extraction would clarify
- NOT premature abstraction: 2 similar blocks is fine; 3 is the
  trigger to consider a helper
- Don't extract just to remove repetition — extract when there's a
  clear conceptual unit

### 5. Error handling consistency
- Matches existing patterns in the file/module
- Don't introduce a new pattern silently (e.g., throwing a custom
  error type when the rest of the file uses tuple returns)
- RN: TanStack Query handles retry — don't roll your own
- FastAPI: use the `HTTPException` / response pattern already in
  `routers/<feature>/`

### 6. Test coverage of changed code
- New logic has at least one test path covering the happy case
- Don't raise the bar for unrelated existing code (that's scope creep)
- Mock at the apiClient boundary on RN side; mock at the repository
  boundary on FastAPI side
- A diff that adds 50 lines of business logic with zero new test
  lines is a `major` finding by default

## Finding format

Each finding goes in the review report with this exact structure:

```markdown
### <severity> · <one-line title>

**Location**: `<file>:<line>`
**Rationale**: <why this matters — 1-2 sentences>
**Suggested fix**: <concrete edit, ideally a small diff>
```

Where `<severity>` is one of: `critical`, `major`, `minor`.

Example:

```markdown
### critical · Missing `await` on async `db.execute`

**Location**: `wardrobe-backend/services/wardrobe/wardrobe_service.py:142`
**Rationale**: `db.execute` returns a coroutine; without `await`, the
query never runs and downstream code receives a coroutine object,
not a row. This will fail at runtime.
**Suggested fix**:
```diff
-row = db.execute(stmt).first()
+row = (await db.execute(stmt)).first()
```
```

## Severity definitions

### `critical` — BLOCKS sign-off

The dev MUST fix before tech-lead approves. Examples:

- Bug that breaks the feature (missing `await`, off-by-one, wrong type)
- API contract violation (route changed but `API_DOCUMENTATION.md` not updated, OR mobile caller calling the OLD shape)
- Data loss risk (DELETE without WHERE, schema migration without rollback)
- Security vulnerability (logged secret, SQL injection vector, missing auth check on a route that should require it)
- Broken tests in the diff
- Type errors that will fail CI

### `major` — DISCUSSION REQUIRED

Dev can push back once with rationale; tech-lead decides; deadlock
escalates to the user. Examples:

- Architectural drift from the Mode A design spec (dev added an extra
  service the spec didn't include — why?)
- Missing test coverage on changed business logic (50 lines of logic
  with 0 test lines is the default trigger)
- Large DRY violation (4+ near-identical blocks where a helper would
  clarify)
- Inconsistent with existing patterns in the same file/module
  (introducing a new error-handling style silently)

### `minor` — ADVISORY

Dev's call. Examples:

- Naming nit (`getUserData` could be clearer as `loadUserProfile`)
- Magic number that's clearly a constant in context (still better as
  a named const but not blocking)
- Comment style (over-commented, narrating code instead of why)
- Import ordering

## Sign-off rule

Your report ends with one of these verdicts:

- **APPROVED** — zero `critical` findings, every `major` finding either
  fixed by dev or has a documented decision/rationale
- **CHANGES REQUIRED** — at least one `critical` finding (list them)
- **DISCUSSION** — `major` findings with no documented resolution yet
  (list them, ping the dev for response)

Do NOT sign off as APPROVED while a `critical` finding is open.

## Cross-stack pointers

For stack-specific concerns, defer to the existing skills — do NOT
duplicate their content here:

- RN side: `auxi-rn-patterns.md` (TanStack Query, theme tokens, Icons
  registry, navigation registration rule, dual-Home migration status)
- FastAPI side: `wardrobe-fastapi-patterns.md` (service-repository
  pattern, EphemeralFileManager, security rules)
- Cross-repo: `cross-repo-coordination.md` (the contract integrity
  procedure when a route shape changes)

If a finding is rooted in a per-stack convention, cite the relevant
skill in the rationale instead of re-explaining the convention.
