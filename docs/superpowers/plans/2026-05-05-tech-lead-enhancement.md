# Tech Lead Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance `.claude/agents/tech-lead.md` with two new modes (solution design pre-implementation + code review post-implementation) and severity-driven authority. Add a workflow convention that requires `mobile-dev` and `backend-dev` to end every turn with `→ next: tech-lead review`. Create a supporting skill `tech-lead-review.md` for the review checklist + finding format.

**Architecture:** All four files are markdown agent/skill manifests under `.claude/`. Edits are surgical: tech-lead.md gets two new sections + severity table appended after its existing body; mobile-dev.md and backend-dev.md get one new section (`## End-of-turn handoff to tech-lead`) appended after their existing `## Output style`; the new skill is a standalone file. No code changes elsewhere in the repo.

**Tech Stack:** Markdown with YAML frontmatter. Validation: Python `yaml.safe_load` for parse check, grep for required sections and cross-references.

**Spec:** `docs/superpowers/specs/2026-05-05-tech-lead-enhancement-design.md`

---

## File Structure

```
wardrobe_project/
├── .claude/
│   ├── agents/
│   │   ├── tech-lead.md       # MODIFY — append 2 new sections (Mode A spec template, Mode B procedure) + severity table
│   │   ├── mobile-dev.md      # MODIFY — append "## End-of-turn handoff to tech-lead" section
│   │   └── backend-dev.md     # MODIFY — append "## End-of-turn handoff to tech-lead" section (identical block)
│   └── skills/
│       └── tech-lead-review.md  # CREATE — review checklist, finding format, severity definitions, sign-off rule
```

Responsibilities:
- `tech-lead.md` — agent role/boundaries (existing scope preserved + Mode A + Mode B + severity)
- `tech-lead-review.md` — procedural detail for Mode B (kept out of the agent prompt to keep it tight)
- `mobile-dev.md` / `backend-dev.md` — append handoff convention without touching their existing content

---

## Task 1: Create `.claude/skills/tech-lead-review.md`

The new procedural skill. Done first because the tech-lead.md agent file (Task 2) references it by name — having the skill in place makes the agent's reference point real.

**Files:**
- Create: `.claude/skills/tech-lead-review.md`

- [ ] **Step 1: Verify the existing sibling skill as reference**

Run: `head -8 .claude/skills/auxi-qa-ui.md`
Expected: frontmatter with `name: auxi-qa-ui`, `description: ...`. Confirms the skill format we're following.

- [ ] **Step 2: Write the new skill file**

Create `.claude/skills/tech-lead-review.md` with this EXACT content. The OUTERMOST four-backtick fence below is plan formatting — do NOT include it in the file. The file's first line must be `---`, last line must be the end of the "Cross-stack pointers" section.

````markdown
---
name: tech-lead-review
description: Procedural workflow for tech-lead Mode B (post-implementation code review). Six clean-code categories, severity-tagged findings, sign-off rule. Use when a dev agent has reported "→ next: tech-lead review" and the user dispatches you to review the diff.
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
\`\`\`diff
-row = db.execute(stmt).first()
+row = (await db.execute(stmt)).first()
\`\`\`
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
````

- [ ] **Step 3: Validate YAML frontmatter parses**

Run:
```bash
python3 -c "
import yaml, sys
content = open('.claude/skills/tech-lead-review.md').read()
parts = content.split('---', 2)
if len(parts) < 3:
    sys.exit('Frontmatter delimiters missing')
fm = yaml.safe_load(parts[1])
required = ['name', 'description']
missing = [k for k in required if k not in fm]
if missing:
    sys.exit(f'Missing fields: {missing}')
print(f'OK: name={fm[\"name\"]}')
"
```
Expected: `OK: name=tech-lead-review`.

- [ ] **Step 4: Verify required body sections are present**

Run:
```bash
for section in "Setup" "Clean-code checklist" "Finding format" "Severity definitions" "Sign-off rule" "Cross-stack pointers"; do
  grep -q "^## $section" .claude/skills/tech-lead-review.md && echo "✓ $section" || echo "✗ MISSING: $section"
done
```
Expected: 6 ✓ lines.

- [ ] **Step 5: Verify the six clean-code categories all show up**

Run:
```bash
for cat in "Naming" "Magic values" "Dead code" "DRY violations" "Error handling consistency" "Test coverage of changed code"; do
  grep -q "^### .*$cat" .claude/skills/tech-lead-review.md && echo "✓ $cat" || echo "✗ MISSING: $cat"
done
```
Expected: 6 ✓ lines.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/tech-lead-review.md
git commit -m "feat(skills): add tech-lead-review for severity-tagged code review"
```

---

## Task 2: Enhance `.claude/agents/tech-lead.md`

Append two new sections (Mode A + Mode B with severity table) to the existing tech-lead agent file. Preserve everything that's already there — the existing scope (cross-repo contract, release sequencing, dispute resolution) is unchanged.

**Files:**
- Modify: `.claude/agents/tech-lead.md`

- [ ] **Step 1: Verify the existing tech-lead.md is what we expect**

Run: `head -10 .claude/agents/tech-lead.md`
Expected: frontmatter with `name: tech-lead`, `description: ...`, `tools: Read, Grep, Glob, Bash, Skill`. Body starts with "You are the tech lead for the Wardrobe project."

- [ ] **Step 2: Append the new sections**

Append the following content to `.claude/agents/tech-lead.md` (use `>>` redirection or open the file and add at the end). Place AFTER the existing "Output style" section. The OUTERMOST four-backtick fence below is plan formatting — do NOT include it in the file.

````markdown

## Mode A — Solution design (pre-implementation)

Triggered when the user says something like "tech-lead, design the
solution for X" before any implementation begins.

Output: a markdown spec at `docs/<feature-slug>-design.md` (or inline
in the conversation if tiny — say <30 lines). Sections:

1. **Problem statement** — one paragraph
2. **API surface** — endpoints, request/response shapes, error codes
   (`n/a` if mobile-only)
3. **Data shapes** — types/interfaces touched, schemas added/changed
4. **File plan** — explicit list of files in EACH repo, one-line
   responsibility per file
5. **Integration points** — where existing code is called, called by,
   or replaced
6. **Risks to watch** — security, performance, contract drift, data
   integrity
7. **Out of scope** — what we're explicitly NOT doing this iteration
8. **Verification** — commands, tests, smoke flow that prove correctness

For features touching ONLY one repo (no contract change), sections 4
and 8 are mandatory; others can be `n/a`. For features touching BOTH
repos, all 8 sections are required and the cross-repo coordination
skill kicks in.

The spec is a CONTRACT between you and the dev agents. They implement
against it. You review against it in Mode B.

## Mode B — Code review (post-implementation)

Triggered when a dev agent reports `→ next: tech-lead review` and the
user dispatches you.

Procedure:

1. Identify the base — usually `main`. Override if dev specified
   otherwise.
2. Get the diff: `git diff <base>..HEAD`.
3. If a Mode A spec exists at `docs/<feature-slug>-design.md`,
   cross-check the diff against it: implemented what was specified?
   Anything extra? Anything missing?
4. Run the six-category checklist (see `tech-lead-review` skill —
   naming, magic values, dead code, DRY violations, error handling
   consistency, test coverage of changed code).
5. File findings with severity tags (`critical` / `major` / `minor`).
6. Sign off if zero `critical` findings AND every `major` finding is
   either fixed or has a documented decision.

For procedural detail (finding format, severity examples per stack,
the sign-off rule), follow the `tech-lead-review` skill.

## Severity-driven authority

| Severity | Examples | Authority |
|---|---|---|
| `critical` | Bug, contract violation, data loss risk, security vulnerability, broken tests, type errors | **BLOCKS sign-off.** Dev MUST fix. |
| `major` | Architectural drift from spec, missing test coverage on changed code, large DRY violation, inconsistent with existing patterns | **Discussion required.** Dev pushes back once with rationale; you decide; deadlock escalates to user. |
| `minor` | Naming nit, isolated magic number, comment style | **Advisory.** Dev's call. |

You assign severity. The dev can dispute by replying once with
rationale. After that, you decide — or escalate to the user if you're
deadlocked.

## Trigger convention

`mobile-dev` and `backend-dev` end every turn with:

```
→ next: tech-lead review
   (skip if: <one-line justification — quick fix / typo / doc-only>)
```

The "skip if" line is optional; when present, it's the dev's
RECOMMENDATION to skip the review for trivial work. The user decides
whether to dispatch you. Default expectation: review happens for any
non-trivial code change.

This is a workflow discipline, not a Claude Code hook. If the user
ever wants real automation, the upgrade path is a `Stop` hook in
`.claude/settings.json` — but that's deferred until needed.
````

- [ ] **Step 3: Validate the file still parses as YAML+markdown**

Run:
```bash
python3 -c "
import yaml, sys
content = open('.claude/agents/tech-lead.md').read()
parts = content.split('---', 2)
if len(parts) < 3:
    sys.exit('Frontmatter delimiters missing')
fm = yaml.safe_load(parts[1])
print(f'OK: name={fm[\"name\"]}, tools={len(fm[\"tools\"].split(\",\"))} items')
"
```
Expected: `OK: name=tech-lead, tools=5 items` (frontmatter unchanged: Read, Grep, Glob, Bash, Skill).

- [ ] **Step 4: Verify both old and new sections are present**

Run:
```bash
for section in "What you own" "What you do NOT do" "How you work" "Submodule discipline" "When to escalate" "Output style" "Mode A" "Mode B" "Severity-driven authority" "Trigger convention"; do
  grep -q "^## $section" .claude/agents/tech-lead.md && echo "✓ $section" || echo "✗ MISSING: $section"
done
```
Expected: 10 ✓ lines (6 existing + 4 new).

- [ ] **Step 5: Verify cross-reference to the new skill**

Run:
```bash
grep -c "tech-lead-review" .claude/agents/tech-lead.md
```
Expected: at least `2` (Mode B body + the procedural-detail pointer).

- [ ] **Step 6: Verify severity table renders (3 rows + header + delimiter = 5 `|` lines)**

Run:
```bash
awk '/^## Severity-driven authority/,/^## /' .claude/agents/tech-lead.md | grep -c "^|"
```
Expected: `5` (header row, delimiter row, 3 severity rows).

- [ ] **Step 7: Commit**

```bash
git add .claude/agents/tech-lead.md
git commit -m "feat(agents): add Mode A + Mode B + severity authority to tech-lead"
```

---

## Task 3: Append the handoff section to mobile-dev.md and backend-dev.md

Same block, appended to both files' end (after their existing `## Output style` section).

**Files:**
- Modify: `.claude/agents/mobile-dev.md`
- Modify: `.claude/agents/backend-dev.md`

- [ ] **Step 1: Verify both files end with `## Output style`**

Run:
```bash
tail -1 .claude/agents/mobile-dev.md
tail -1 .claude/agents/backend-dev.md
```
The last meaningful line of each should be from the "Output style" section. If a different section now ends each file, STOP — read the file fully and adjust the insertion point. The plan assumes the existing layout where `## Output style` is the last `##` heading.

- [ ] **Step 2: Append the handoff block to `mobile-dev.md`**

Append the following content to `.claude/agents/mobile-dev.md` (use `>>` redirection or open the file and add at the end). The OUTERMOST four-backtick fence below is plan formatting — do NOT include it in the file.

````markdown

## End-of-turn handoff to tech-lead

Every end-of-turn report MUST end with this exact two-line block as
the FINAL output:

```
→ next: tech-lead review
   (skip if: <one-line justification — quick fix / typo / doc-only>)
```

Rules:

- The first line is mandatory and verbatim.
- The "skip if" line is OPTIONAL. Include it ONLY when you want to
  recommend skipping the review for a trivial change (one-line
  README typo, lockfile bump, formatter pass). Otherwise omit the
  parenthetical entirely.
- A "skip if" justification is a RECOMMENDATION, not a decision. The
  user decides whether to dispatch tech-lead. Don't skip yourself —
  that's not your call.

Reason this exists: the team uses tech-lead Mode B (post-implementation
code review) as a discipline. The handoff line is the workflow signal.
See `.claude/agents/tech-lead.md` "Mode B" and "Trigger convention"
sections for what tech-lead does with it.
````

- [ ] **Step 3: Append the SAME handoff block to `backend-dev.md`**

Append IDENTICAL content (the same markdown block from Step 2) to
`.claude/agents/backend-dev.md`. The block must be byte-identical
across the two files — diff them after to confirm.

- [ ] **Step 4: Verify both files have the new section**

Run:
```bash
for f in .claude/agents/mobile-dev.md .claude/agents/backend-dev.md; do
  grep -q "^## End-of-turn handoff to tech-lead" "$f" && echo "✓ $f has section" || echo "✗ MISSING in $f"
done
```
Expected: 2 ✓ lines.

- [ ] **Step 5: Verify the appended blocks are byte-identical between the two files**

Run:
```bash
# Extract the new section from each file and diff them
diff \
  <(awk '/^## End-of-turn handoff to tech-lead/,EOF' .claude/agents/mobile-dev.md) \
  <(awk '/^## End-of-turn handoff to tech-lead/,EOF' .claude/agents/backend-dev.md) \
  && echo "✓ blocks match" || echo "✗ blocks differ"
```
Expected: `✓ blocks match`.

- [ ] **Step 6: Verify YAML frontmatter still parses (no accidental edits up top)**

Run:
```bash
python3 -c "
import yaml
for path in ['.claude/agents/mobile-dev.md', '.claude/agents/backend-dev.md']:
    parts = open(path).read().split('---', 2)
    fm = yaml.safe_load(parts[1])
    print(f'✓ {path}: name={fm[\"name\"]}')
"
```
Expected:
```
✓ .claude/agents/mobile-dev.md: name=mobile-dev
✓ .claude/agents/backend-dev.md: name=backend-dev
```

- [ ] **Step 7: Verify the literal handoff line is in both**

Run:
```bash
for f in .claude/agents/mobile-dev.md .claude/agents/backend-dev.md; do
  grep -F '→ next: tech-lead review' "$f" >/dev/null && echo "✓ $f has trigger line" || echo "✗ $f MISSING trigger line"
done
```
Expected: 2 ✓ lines.

- [ ] **Step 8: Commit**

```bash
git add .claude/agents/mobile-dev.md .claude/agents/backend-dev.md
git commit -m "feat(agents): require '→ next: tech-lead review' handoff in dev agents"
```

---

## Task 4: End-to-end sanity check

Final pass — confirm the four files compose correctly.

**Files:** none modified, just verification.

- [ ] **Step 1: All 4 target files exist and are non-empty**

Run:
```bash
for f in \
  .claude/agents/tech-lead.md \
  .claude/agents/mobile-dev.md \
  .claude/agents/backend-dev.md \
  .claude/skills/tech-lead-review.md; do
  [ -s "$f" ] && echo "✓ $f ($(wc -l < $f) lines)" || echo "✗ MISSING or EMPTY: $f"
done
```
Expected: 4 lines starting with `✓`. tech-lead.md should have grown ~70 lines (existing ~75 + new ~70 ≈ 145). The new skill should be ~155 lines.

- [ ] **Step 2: All YAML frontmatter is valid across all 4 files**

Run:
```bash
python3 -c "
import yaml
for path in [
    '.claude/agents/tech-lead.md',
    '.claude/agents/mobile-dev.md',
    '.claude/agents/backend-dev.md',
    '.claude/skills/tech-lead-review.md',
]:
    parts = open(path).read().split('---', 2)
    fm = yaml.safe_load(parts[1])
    print(f'✓ {path}: name={fm[\"name\"]}')
"
```
Expected: 4 ✓ lines with the right names.

- [ ] **Step 3: Cross-references resolve**

Run:
```bash
# tech-lead.md mentions the new skill
grep -q "tech-lead-review" .claude/agents/tech-lead.md && echo "✓ tech-lead → skill ref" || echo "✗ broken tech-lead → skill ref"

# Both dev agents mention the trigger line
grep -q "tech-lead review" .claude/agents/mobile-dev.md && echo "✓ mobile-dev → trigger" || echo "✗ missing trigger in mobile-dev"
grep -q "tech-lead review" .claude/agents/backend-dev.md && echo "✓ backend-dev → trigger" || echo "✗ missing trigger in backend-dev"

# tech-lead.md mentions Mode A and Mode B explicitly
grep -q "## Mode A" .claude/agents/tech-lead.md && echo "✓ Mode A section" || echo "✗ Mode A missing"
grep -q "## Mode B" .claude/agents/tech-lead.md && echo "✓ Mode B section" || echo "✗ Mode B missing"

# tech-lead.md severity table has all three severity levels mentioned in body text
for sev in critical major minor; do
  grep -q "$sev" .claude/agents/tech-lead.md && echo "✓ severity $sev mentioned" || echo "✗ severity $sev MISSING"
done

# Skill has the six categories
for cat in Naming "Magic values" "Dead code" "DRY violations" "Error handling consistency" "Test coverage of changed code"; do
  grep -qF "$cat" .claude/skills/tech-lead-review.md && echo "✓ category: $cat" || echo "✗ category MISSING: $cat"
done
```
Expected: 14 ✓ lines (1 + 2 + 2 + 3 + 6).

- [ ] **Step 4: Existing tech-lead scope preserved (no regression)**

Run:
```bash
# These existing sections must STILL be in tech-lead.md after the edit
for section in "What you own" "What you do NOT do" "How you work" "Submodule discipline" "When to escalate to the user" "Output style"; do
  grep -q "^## $section" .claude/agents/tech-lead.md && echo "✓ preserved: $section" || echo "✗ REGRESSED: $section MISSING"
done
```
Expected: 6 ✓ lines. If any are missing, the edit clobbered existing content — STOP and reapply, preserving everything above the new sections.

- [ ] **Step 5: Git tree clean, branch on track**

Run:
```bash
git status --short -- .claude/ docs/superpowers/
git log --oneline -5
git branch --show-current
```
Expected:
- `git status` for the touched paths shows nothing (all committed)
- `git log` shows 3 new commits (skill, tech-lead, dev agents) on top of the spec commit (`6b5621b`)
- branch is `feat/tech-lead-enhancement`

- [ ] **Step 6: Manual smoke (out-of-band, document only — cannot automate)**

Tell the user:

> The tech-lead enhancement is now installed. To smoke-test it, in a
> Claude Code session with the umbrella repo open:
>
> 1. **Mode A test**: ask "Use the tech-lead agent to design the
>    solution for adding a 'Favorites' tab to the wardrobe screen."
>    Expect: tech-lead produces a markdown spec covering all 8 sections
>    (or `n/a` for inapplicable ones since it's mobile-only).
>
> 2. **Trigger convention test**: dispatch mobile-dev to do any small
>    change. Expect: mobile-dev's end-of-turn output ends with
>    `→ next: tech-lead review` (with optional `(skip if: ...)` if the
>    change is trivial).
>
> 3. **Mode B test**: after mobile-dev finishes, ask "Use the tech-lead
>    agent to review the diff." Expect: severity-tagged findings,
>    a verdict line at the end (APPROVED / CHANGES REQUIRED / DISCUSSION).
>
> 4. **Severity authority test**: feed the dev a deliberately broken
>    change (e.g., missing await on an async call). Expect: tech-lead
>    flags it `critical` and refuses to sign off until fixed.
>
> If step 1 fails (agent doesn't seem to know about Mode A), check that
> `## Mode A` is present in `.claude/agents/tech-lead.md` (Step 4 of
> Task 2 verifies this).

This step is documentation-only — no shell commands to run.

---

## Acceptance criteria (from the spec)

Cross-check after Task 4:

1. ✅ User says *"tech-lead, design the solution for X"* → tech-lead has the Mode A section telling it to produce an 8-section markdown spec (Task 2 Step 4 verifies the Mode A section).
2. ✅ mobile-dev / backend-dev end every turn with `→ next: tech-lead review` (Task 3 Step 7 verifies the literal line in both files; Task 4 Step 3 cross-checks).
3. ✅ Tech-lead's review report has every finding tagged with severity (the new skill's "Finding format" section enforces it; verified by Task 1 Step 4).
4. ✅ A `critical` finding genuinely blocks (severity table in tech-lead.md says "BLOCKS sign-off"; sign-off rule in the skill enforces "Do NOT sign off as APPROVED while a critical finding is open").
5. ✅ A `major` finding starts a back-and-forth (severity table: "Discussion required. Dev pushes back once with rationale; you decide; deadlock escalates to user").
6. ✅ A `minor` finding is advisory (severity table: "Advisory. Dev's call.").
7. ✅ Existing tech-lead scope (contract integrity, release sequencing) preserved — verified by Task 4 Step 4 (regression check on 6 pre-existing sections).
