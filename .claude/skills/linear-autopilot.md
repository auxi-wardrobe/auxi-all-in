---
name: linear-autopilot
description: Ticket→PR pipeline for the Wardrobe project — picks an eligible Linear ticket, drives it through dev → gates → review → QA → PR → In Review with one agent dispatched at a time, then stops for human merge. Phase 2 of the Linear Autopilot. Use when the user says "autopilot", "chạy ticket AU-XXX", "process next ticket", or to batch N tickets sequentially.
---

# Linear Autopilot — ticket → PR

You (the main session) are the orchestrator. You own Linear state, git,
gates, and PR. Subagents do exactly ONE job each and are dispatched
exactly ONCE per ticket (except the bounded gate-retry below). Linear is
the only state store — every transition gets a `🤖 [autopilot]` comment.

**Never run two tickets concurrently. Never auto-merge. Never deploy.**

## Eligibility (intake gate — check ALL before touching anything)

1. Ticket is non-archived, state Todo or Backlog (or user named it explicitly).
2. AC is testable. No AC / vague product prose → comment what's missing,
   label `needs-human`, SKIP. Do not invent AC.
3. **No overlap**: parent or sibling tickets In Progress / In Review that
   touch the same screens/services, in-flight branches (`git branch -a`)
   or open PRs covering the same files → comment the conflict, SKIP.
4. Not auth/payments/DB-migration/architecture work → `needs-human`, SKIP.
5. Area resolvable to exactly one repo: `auxi/` or `wardrobe-backend/`.
   Cross-repo → needs pm split first, SKIP with comment.

A SKIP is a successful outcome — comment why, pick the next ticket.

## Pipeline (strict order, one ticket at a time)

| Step | Actor | Action |
|---|---|---|
| 1. Intake | orchestrator | Eligibility above. Move → In Progress, comment scope + plan |
| 2. Workspace | orchestrator | Worktree from **origin/main** (NOT current checkout), branch = Linear `gitBranchName` |
| 3. Implement | `mobile-dev` OR `backend-dev` (one dispatch) | Code per AC inside the worktree. Returns DONE/BLOCKED + files + summary |
| 4. Gates | orchestrator (Bash, deterministic) | See gate table. Fail → re-dispatch dev with the failure log, **max 2 retries**, then PARK |
| 5. Review | `code-reviewer` (one dispatch) | Diff-only review. CRITICAL finding → PARK. Minor → record for PR body |
| 6. QA | mobile only: `qa-mobile` (one dispatch) | Smoke the changed flow on sim. Sim unavailable → mark `qa: pending-sim` in PR + ticket, continue |
| 7. Ship | orchestrator | Commit (conventional + `Refs: AU-XXX` footer), push, `gh pr create` titled with ticket id + body `Fixes AU-XXX` + evidence. Move → In Review, comment PR URL + evidence |
| 8. Stop | — | Human merges. `linear-sweep` closes the ticket after merge |

PARK = comment exact reason + evidence on the ticket, move back → Todo,
label `needs-human`, clean up nothing (leave worktree for the human), and
move on to the next ticket. Never loop on a parked ticket.

### Gate table (objective — agent opinion is not a gate)

| Area | Commands (all must pass) |
|---|---|
| backend | `cd <worktree> && pytest -m unit` · `pytest -m integration` · `python test_server.py` · `API_DOCUMENTATION.md` updated if any route changed |
| mobile | `cd <worktree> && npx tsc --noEmit` · `yarn lint` (baseline preserved) · `yarn test` · `../scripts/auxi-lint-tokens.sh` |

## Worktree discipline

```bash
cd <repo-submodule> && git fetch origin
git worktree add <umbrella>/worktrees/wt-<au-id> -b <gitBranchName> origin/main
# ... pipeline runs inside worktrees/wt-<au-id> ...
# after PR pushed:
git worktree remove <umbrella>/worktrees/wt-<au-id>   # only on success; PARK keeps it
```

`worktrees/` lives at the umbrella root (already gitignored) so subagents
stay inside the project's permitted directories.

One worktree per ticket, named by ticket id — never share, never reuse.

## Comment templates (all start with 🤖 [autopilot])

- Intake: `🤖 [autopilot] Picked up. Area: <repo>. Plan: <1-2 lines>. Branch: <name>.`
- Park: `🤖 [autopilot] Parked: <reason>. Evidence: <log/snippet>. Needs human.`
- Ship: `🤖 [autopilot] PR <url> open. Gates: <list, all green>. Review: <verdict>. QA: <result|pending-sim>. → In Review. Merge to close.`

## Dispatch log (mandatory — eval + audit trail)

Append one line per step to `plans/reports/autopilot-log-<date>.md`:

```
| AU-XXX | step | agent | start | end | status |
```

This is how "no agent re-called, no overlap" is verified after the fact.

## Hard stops

- Max 2 gate retries per ticket; retry counts in the dispatch log.
- One ticket in flight at a time; finish (ship or PARK) before the next.
- Subagents never touch Linear, git push, or PRs — orchestrator only.
- Dev agent edits ONLY inside its worktree. Anything else = PARK.
- Figma-bound mobile work follows `figma-design-extraction` →
  `figma-to-rn-workflow` inside step 3 (the dev agent's own skills) — the
  autopilot does not shortcut the extraction gate.

## Related

- `linear-sweep` — closes tickets after merge (Phase 1)
- `linear-pm-workflow` — ticket schema + comment voice
- `auxi-launch-notify` — release announcement chain (Phase 3)
