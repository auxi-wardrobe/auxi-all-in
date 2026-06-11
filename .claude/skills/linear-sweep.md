---
name: linear-sweep
description: Autonomous Linear board sweep for the Wardrobe project — closes verified In Review tickets, pings stale In Progress work, escalates rot. Phase 1 of the Linear Autopilot. Use on a schedule (daily heartbeat), when the user says "sweep", "quét board", "dọn linear", or after a PR merge to reconcile ticket states. Idempotent — safe to re-run.
---

# Linear Sweep — the heartbeat

You are acting as the project's PM doing a board sweep. You only read,
comment, and transition ticket states. You NEVER touch code, never create
tickets, never reopen Done, never close anything in Todo/Backlog.

Companion skill: `linear-pm-workflow` (ticket schema, comment voice,
verification gates). This skill automates its "Sweep behavior" +
"Verification gate before closing" sections.

## Auth

Primary: Linear MCP tools (`mcp__claude_ai_Linear__*`). If not surfaced,
fall back to GraphQL via `~/.linear/api_key` (same pattern as
`auxi-launch-notify`):

```bash
[ -s ~/.linear/api_key ] || { echo "FATAL: no Linear key and no MCP"; exit 1; }
LINEAR_KEY=$(cat ~/.linear/api_key)
curl -sS --fail https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_KEY" -H "Content-Type: application/json" \
  -d '{"query":"query { issues(filter: {team: {name: {eq: \"Auxi\"}}, state: {type: {in: [\"started\"]}}}, first: 50) { nodes { identifier title updatedAt state { name } assignee { name } comments(first: 5) { nodes { body createdAt } } attachments { nodes { url title } } } } }"}'
```

If neither works: STOP and report. Never fabricate ticket states.

## Scope of one sweep

Fetch non-archived issues in states **In Progress** and **In Review** only
(team Auxi). Todo/Backlog/Done/Canceled are out of scope.

## Rules (apply in order, per ticket)

| # | Condition | Action |
|---|---|---|
| R1 | In Review + linked PR **merged** + evidence complete (see gate below) | Move → **Done** + closing comment |
| R2 | In Review + PR merged but evidence incomplete | Comment exactly what's missing. Do NOT close |
| R3 | In Review + PR open / no PR | If no sweep comment in 72h: comment current PR state. Else skip |
| R4 | In Progress + no activity (comments or updates) > 3 days | Ping comment "No activity for N days — still in flight?" |
| R5 | In Progress + no activity > 5 days | Escalate: add to "needs attention" list in final report (and Slack-notify if channel configured) |

### Evidence gate for R1 (from linear-pm-workflow — do not shortcut)

- PR linked on ticket (attachment or comment) AND `gh pr view <url> --json state,mergedAt` shows `MERGED`.
- Every AC checkbox in the description is ticked, OR the closing evidence
  comment explains why N/A.
- `area:mobile` tickets: a qa sign-off comment (screenshot or flow result)
  exists.
- If `gh` is unavailable (cloud run): a PR-merged signal must exist in
  ticket comments/attachments metadata; otherwise treat as R2 and say so.

Closing comment template:

```
🤖 [sweep] All AC met. PR <url> merged (<sha>). Evidence: <one line per gate item>. Closing.
```

## Idempotence + anti-spam (hard rules)

- EVERY comment this skill posts starts with `🤖 [sweep]`.
- Before posting, read the ticket's last 5 comments. If a `🤖 [sweep]`
  comment with the same rule intent exists within 24h (72h for R3) — skip.
- Max **10 write actions** (comments + transitions) per sweep run. If more
  qualify, act on the oldest first and list the rest in the report.
- `DRY_RUN=1`: print the action table, write nothing.

## Output (always, even when 0 actions)

```
| ID | Title | State | Last activity | Rule | Action taken |
|----|-------|-------|---------------|------|--------------|
```

Followed by **Needs attention** (R5 escalations + anything ambiguous).
When run interactively, print to the user. When run scheduled, this is the
run summary.

## Hard stops

- Never close a ticket whose PR is not merged. "Dev said done" ≠ done.
- Never transition Todo/Backlog/Done/Canceled tickets.
- Never edit ticket descriptions, labels, assignees, or priorities.
- Ambiguous evidence → R2 comment, never R1 close. When in doubt, don't.
