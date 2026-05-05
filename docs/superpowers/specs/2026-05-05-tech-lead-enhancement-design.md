# Tech Lead Enhancement — Design

**Date**: 2026-05-05
**Owner**: duncan
**Status**: Approved, ready for implementation plan

## Goal

Extend the existing `.claude/agents/tech-lead.md` agent so it owns two new responsibilities in addition to its current scope (cross-repo contracts, release sequencing, dispute resolution):

1. **Mode A — Solution design (pre-implementation)**: when invoked at the start of a feature, tech-lead produces a short markdown spec that mobile-dev and backend-dev implement against. Architecture clarity up front avoids drift later.
2. **Mode B — Code review (post-implementation)**: when invoked after a dev agent finishes, tech-lead reviews the diff against the design (if any) and a clean-code checklist, files findings with severity tags.

Plus a workflow convention for triggering Mode B: mobile-dev and backend-dev end every turn with `→ next: tech-lead review`. The user (or main thread) sees that line and dispatches tech-lead.

The trigger is a discipline, not a Claude Code hook — opt-in by reading the line, with the dev allowed to recommend skipping for trivial work (one-line typos, doc-only edits) as long as it justifies why.

## Files to touch

```
.claude/
├── agents/
│   ├── tech-lead.md            # MODIFY — add Mode A + Mode B + severity authority
│   ├── mobile-dev.md           # MODIFY — add end-of-turn handoff line
│   └── backend-dev.md          # MODIFY — add end-of-turn handoff line
└── skills/
    └── tech-lead-review.md     # CREATE — code-review checklist + finding format
```

The existing `.claude/skills/cross-repo-coordination.md` stays as-is — it covers the contract integrity work the tech-lead already does, which is unchanged. The new skill is purely about the code-review and solution-design procedures.

## Mode A — Solution design (pre-implementation)

Triggered when the user says something like *"tech-lead, design the solution for X"* before any implementation work begins.

Output: a markdown spec at `docs/<feature-slug>-design.md` (or inline in the conversation if tiny — say <30 lines). Contents:

1. **Problem statement** — one paragraph.
2. **API surface** — endpoints, request/response shapes, error codes. If the change is mobile-only, "API surface: none" is acceptable.
3. **Data shapes** — types/interfaces touched, schemas added/changed.
4. **File plan** — explicit list of files in EACH repo that will be created or modified, with one-line responsibility per file.
5. **Integration points** — where existing code is being called, called by, or replaced.
6. **Risks to watch** — security (auth, PII), performance (N+1, blocking calls), contract (mobile/backend drift), data integrity (migrations, race conditions).
7. **Out of scope** — what we're explicitly NOT doing in this iteration.
8. **Verification** — how we know the implementation is correct (commands, tests, smoke flow).

The spec is a CONTRACT between tech-lead and the dev agents. Devs implement against it. Tech-lead reviews against it in Mode B.

For features that touch ONLY one repo (no contract change), the spec can be lightweight — sections 4 and 8 are mandatory, others can be one-line `n/a`.

For features that touch BOTH repos, all 8 sections are required; the cross-repo coordination skill kicks in.

## Mode B — Code review (post-implementation)

Triggered when a dev agent reports `→ next: tech-lead review` and the user (or main thread) dispatches tech-lead.

Procedure:

1. Identify the base — usually `main`, but the dev's branch may target a different base. `git merge-base HEAD main` is the default; tech-lead can override if dev specified a different base.
2. Read the diff: `git diff <base>..HEAD`.
3. If a Mode A spec exists at `docs/<feature-slug>-design.md`, cross-check the diff against it: did the dev implement what was specified? Anything extra? Anything missing?
4. Run the review checklist (see new skill). Six categories of clean-code concerns; each finding gets a severity tag.
5. File findings as a single review report, structured by severity.
6. Sign off if zero `critical` findings AND every `major` finding is either fixed or has a documented decision/rationale.

## Severity-driven authority (controller-approved)

| Severity | Examples | Authority |
|---|---|---|
| `critical` | Bug that will break the feature, contract violation (API doc out of sync with route), data loss risk, security vulnerability (e.g., logged secret, SQL injection vector), broken tests, type errors that will fail CI | **BLOCKS sign-off.** Dev MUST fix before tech-lead approves. |
| `major` | Architectural drift from the Mode A spec, missing test coverage on changed code, large DRY violation (3+ near-identical blocks where a helper would clarify), inconsistent with existing patterns in the same file/module | **Discussion required.** Dev can push back once with rationale; tech-lead decides; deadlock escalates to the user. |
| `minor` | Naming nit, magic number that's clearly a constant, comment style, ordering of imports | **Advisory.** Dev's call. |

Tech-lead assigns severity. Dev can dispute by replying once with rationale. After that, tech-lead decides — or escalates if deadlocked.

## Trigger convention (workflow, not hook)

`mobile-dev.md` and `backend-dev.md` end-of-turn output is updated to ALWAYS include this exact block as the FINAL line(s) of every report:

```
→ next: tech-lead review
   (skip if: <one-line justification — quick fix / typo / doc-only>)
```

Rules:

- The first line is mandatory and verbatim.
- The "skip if" line is OPTIONAL. If the dev wants to recommend skipping, they include it with a one-line justification. Otherwise, omit the parenthetical.
- A "skip if" justification is a RECOMMENDATION, not a decision. The user / main thread still chooses whether to dispatch tech-lead. The default expectation is that review happens for any non-trivial code change.

This is a discipline, not automation. No Claude Code hook is added. If the user finds themselves manually dispatching tech-lead every single time and wants automation, the upgrade path to a Stop hook in `.claude/settings.json` is straightforward — but it's deferred until that signal exists.

## New skill: `.claude/skills/tech-lead-review.md`

Procedural companion. Six sections:

1. **Setup** — locate base SHA, get diff, find Mode A design doc if present
2. **Clean-code checklist** — six categories with concrete examples:
   - **Naming** — clear, accurate, matches what the thing does (not how it's implemented)
   - **Magic values** — hardcoded strings/numbers that should be named constants or pulled from theme/config
   - **Dead code** — unused imports, unreachable branches, commented-out chunks, leftover console.log
   - **DRY violations** — 3+ near-identical blocks where extraction would clarify (NOT premature abstraction; the rule of three)
   - **Error handling consistency** — matches existing patterns in the file/module (don't introduce a new pattern silently)
   - **Test coverage of changed code** — new logic has at least one test path; not raising the bar for unrelated existing code
3. **Finding format** — markdown:
   ```
   ### <Severity> · <one-line title>
   **Location**: `<file>:<line>`
   **Rationale**: <why this matters — 1-2 sentences>
   **Suggested fix**: <concrete edit, ideally a small diff>
   ```
4. **Severity definitions** — concrete per-stack examples for critical / major / minor (RN side: hardcoded `#1A1A1A` instead of `theme.colors.text` is `minor` if isolated, `major` if it's a pattern across 5 files; FastAPI side: missing `await` on an async call is `critical`).
5. **Sign-off rule** — zero critical, all majors discussed/resolved.
6. **Cross-stack pointers** — directs tech-lead to existing skills `auxi-rn-patterns.md` and `wardrobe-fastapi-patterns.md` for stack-specific concerns; doesn't duplicate them.

## Updates to dev agent files

`.claude/agents/mobile-dev.md` and `.claude/agents/backend-dev.md` get one new section appended (after their existing "Output style" or equivalent end-of-turn section):

```markdown
## End-of-turn handoff to tech-lead

Every end-of-turn report MUST end with:

\`\`\`
→ next: tech-lead review
   (skip if: <one-line justification — quick fix / typo / doc-only>)
\`\`\`

The "skip if" line is optional — include it only when you want to recommend
skipping the review for a trivial change. Otherwise, omit the parenthetical.

The user decides whether to dispatch tech-lead based on this line. Don't
skip yourself — that's not your call.
```

Both agent files get the same block, verbatim. No other changes to either dev agent.

## Composition with existing agents

| Trigger | Sequence |
|---|---|
| New feature kickoff | user → tech-lead (Mode A) → mobile-dev / backend-dev → dev's `→ next: tech-lead review` → tech-lead (Mode B) → sign-off |
| Bug fix from QA | qa-mobile / qa-ui finding → mobile-dev / backend-dev → dev's `→ next: tech-lead review` → tech-lead (Mode B) → sign-off |
| Quick fix (typo, formatter) | dev does it → end report has `→ next: tech-lead review (skip if: doc typo)` → user dispatches tech-lead OR moves on |
| Contract change | tech-lead (Mode A spec includes API surface) → backend-dev → mobile-dev → tech-lead (Mode B reviews both diffs against spec) |

## Out of scope (deliberately)

- **Real Claude Code hooks** — opted out per controller decision. Workflow convention only.
- **Stack-specific style guides** — those live in `auxi-rn-patterns.md` and `wardrobe-fastapi-patterns.md` already. The tech-lead-review skill REFERENCES them, doesn't duplicate them.
- **Performance review** — different specialty (RN perf is mobile-dev's, backend perf is backend-dev's).
- **Security audit** — `security-review` skill at the harness level handles this. Tech-lead flags obvious issues (secrets in source, SQL injection vectors) as `critical` but does not run the full security audit.
- **Auto-merge / auto-approve** — tech-lead's sign-off is a verbal go/no-go, not a GitHub mechanism. The user merges PRs.
- **Replacing the existing tech-lead role** — the existing scope (cross-repo contract, release sequencing, dispute resolution) is preserved. Modes A and B are added on top.

## Acceptance criteria

The work is "useful" when, in real day-to-day flow:

1. User says *"tech-lead, design the solution for X"* → tech-lead produces a markdown spec with all 8 sections (or `n/a` for sections that don't apply to one-repo features).
2. mobile-dev or backend-dev finishes work → their report ALWAYS ends with `→ next: tech-lead review` (with optional `skip if:` justification).
3. User dispatches tech-lead post-implementation → tech-lead's review report has every finding tagged with severity (critical / major / minor).
4. A `critical` finding genuinely blocks: tech-lead refuses to sign off until it's fixed.
5. A `major` finding starts a back-and-forth: dev pushes back with rationale OR fixes it; tech-lead decides; deadlock escalates to the user.
6. A `minor` finding is advisory: dev decides whether to address.
7. The existing tech-lead scope (contract integrity, release sequencing) is preserved — no regression on those responsibilities.

## Open questions

None — all resolved during brainstorming:
- Single agent (enhance existing tech-lead) — A
- Workflow convention (no hooks) — B
- Severity-driven authority — C
