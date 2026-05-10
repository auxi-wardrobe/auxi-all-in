---
id: WAR-PR-003
type: chore
title: "[Task] Add qa-ui agent for visual fidelity QA on mobile"
state: Done
priority: P2
labels: [type:chore, area:tooling, role:tech-lead, source:pr]
source_pr: https://github.com/ducga1998/auxi-all-in/pull/4
source_repo: wardrobe_project (umbrella)
author: ducga1998
merged_at: 2026-05-05T08:54:00Z
created: 2026-05-05
---

## Context

The existing `qa-mobile` agent owns functional flows — login, navigation,
service calls. There was no role-scoped agent for visual fidelity QA
(alignment, spacing, icons, typography, colors, layout overflow). A
2026-05-05 sweep failed to log in, pivoted to source-code analysis, and
shipped 63 findings with screenshots for only 6 — fake QA. This PR adds
a sibling agent with hard guardrails against that failure mode.

## What shipped

- `.claude/agents/qa-ui.md` — agent manifest, 22 tools (6 base + 4 Figma
  MCP + 12 mobile-mcp), read-only on `auxi/src/**`. Two operating modes:
  sweep (without Figma) and compare (with Figma URL).
- `.claude/skills/auxi-qa-ui.md` — workflow skill: setup, login-blocker
  recipe, sweep procedure, compare procedure, finding template, severity
  guidance, sign-off rule.
- Umbrella `CLAUDE.md` agents table + Figma note + `README.md` Claude
  Code setup list updated.

## Behavioral guardrails baked into the prompt

- "Runtime screenshot required for EVERY finding" — code-inferred
  findings are not visual findings.
- "Drive the UI, never pivot to code-only" — if blocked, escalate.
- Login-blocker recipe (`mobile_type_keys` per-character, Sign Up flow,
  QA test account) with explicit "if all three fail, escalate".

## Acceptance criteria

- [x] YAML frontmatter parses on both files.
- [x] 22 tools listed, no forbidden ones (Edit, NotebookEdit, mobile
      install/terminate/uninstall).
- [x] Required body sections present in both files.
- [x] Cross-references resolve (agent ↔ skill, both → findings dir,
      both → `mobile_type_keys`).
- [x] CLAUDE.md table has exactly 1 `qa-ui` row, README has exactly 1
      bullet.

## Out of scope

- Replacing `qa-mobile` (functional flows still owned there).
- CI integration for visual diff.

## Notes

Built via subagent-driven-development: 4 tasks, fresh implementer + spec
reviewer + code quality reviewer per task, all APPROVED.
