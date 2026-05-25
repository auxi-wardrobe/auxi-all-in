---
id: WAR-PR-004
type: chore
title: "[Task] tech-lead agent: Mode A solution design + Mode B code review"
state: Done
priority: P2
labels: [type:chore, area:tooling, role:tech-lead, source:pr]
source_pr: https://github.com/ducga1998/auxi-all-in/pull/5
source_repo: wardrobe_project (umbrella)
author: ducga1998
merged_at: 2026-05-05T10:08:21Z
created: 2026-05-05
---

## Context

The existing `tech-lead` agent owned cross-repo contracts, release
sequencing, and dispute resolution — but had no formal pre-implementation
spec mode and no enforced post-implementation review pass. Dev agents
shipped without a consistent quality gate.

## What shipped

Two new responsibilities on top of the existing tech-lead scope:

- **Mode A — Solution design (pre-implementation)**: when invoked at the
  start of a feature, tech-lead produces a markdown spec with 8
  sections (problem / API surface / data shapes / file plan / integration
  points / risks / out of scope / verification) that mobile-dev and
  backend-dev implement against.
- **Mode B — Code review (post-implementation)**: when invoked after a
  dev agent finishes, tech-lead diffs the branch, cross-checks against
  the Mode A spec (if any), runs a 6-category clean-code checklist, and
  files findings tagged with severity.

Workflow trigger: dev agents end every turn with `→ next: tech-lead
review` (with optional `(skip if: ...)` justification for trivial work).

Severity-driven authority:
- `critical` — BLOCKS sign-off (bugs, contract violations, data loss,
  security, broken tests, type errors).
- `major` — Discussion required; deadlock escalates to user.
- `minor` — Advisory.

## Files touched

- `.claude/skills/tech-lead-review.md` (NEW) — 6-category checklist +
  finding format + severity definitions + sign-off rule.
- `.claude/agents/tech-lead.md` — appends Mode A, Mode B, severity table,
  trigger convention. Existing 6 sections preserved unchanged.
- `.claude/agents/mobile-dev.md` + `.claude/agents/backend-dev.md` —
  byte-identical "End-of-turn handoff to tech-lead" section appended.

## Acceptance criteria

- [x] Mode A section instructs the agent to produce an 8-section markdown
      spec.
- [x] Both dev agents end every turn with literal `→ next: tech-lead
      review` line.
- [x] tech-lead-review skill's Finding format requires every finding to
      be severity-tagged.
- [x] `critical` finding genuinely blocks sign-off.
- [x] `major` triggers discussion; deadlock escalates to user.
- [x] `minor` is advisory.
- [x] Existing tech-lead 6 sections preserved unmodified.
- [x] DRY threshold consistent at 3+ across the skill checklist + severity
      examples.

## Out of scope

- Claude Code hook automation — discipline-based trigger only.
- Tooling to enforce the trigger line at protocol level.

## Notes

Built via subagent-driven-development: 4 tasks. Spec at
`docs/superpowers/specs/2026-05-05-tech-lead-enhancement-design.md`.
