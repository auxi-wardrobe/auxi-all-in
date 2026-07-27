# PR Review Sweep — 2026-07-27 (scheduled, tech-lead)

## Outcome
Sweep completed on the reachable repo. **Slack delivery to `C0BC2122GHM` is BLOCKED** — see Blocker below. This report is the durable record; the Slack summary below is ready to post the moment the connector is stable.

## Scope limitation (org enumeration blocked)
Session is hard-scoped to `auxi-wardrobe/auxi-all-in`. Org-wide discovery is disabled:
- `gh repo list auxi-wardrobe` → HTTP 403 (GraphQL disabled for session)
- `gh api orgs/auxi-wardrobe/repos` → HTTP 403 ("sessions are bound to their configured repositories")
- `gh api repos/.../pulls` → 403 ("GitHub access is not enabled for this session")

Only `auxi-all-in` could be swept, via the GitHub MCP tools (`list_pull_requests`, `pull_request_read`). Widening the Claude GitHub App scope to the org is required for a true full-org sweep.

## Bot identity
`ducga1998` (via `get_me`).

## PRs found (3 open, non-draft) — all already reviewed at current HEAD
No new commits on any PR since the last sweep → the standing bot review still applies; re-posting would be a byte-identical duplicate (step-2 "no double work / no spam"), so no new reviews posted this run.

| PR | Title | Author | HEAD | Last bot review @ HEAD | Verdict |
|----|-------|--------|------|------------------------|---------|
| #36 | docs: audit findings on background removal pipeline (AU-408) | ducga1998 (bot) | e539e67 | ✓ COMMENTED (clean) | Ready to merge — needs human approval (bot authored, can't self-approve) |
| #32 | docs: root-cause investigation, build-around linen short outfit bug | ducga1998 (bot) | 4ba0206 | ✓ COMMENTED (clean) | Ready to merge — needs human approval (bot authored) |
| #31 | chore: bump backend for tryon push notifications | 0xduc98 | 44c9ffb | ✓ COMMENTED (MAJOR) | Needs changes — two-repo contract drift |

### #31 finding (MAJOR, standing)
Submodule bump `wardrobe-backend` → `6fd35c9` (backend PR #133, try-on push notifications) ships **zero mobile changes** — classic two-repo drift signal. Before merge, confirm backend #133 updated `API_DOCUMENTATION.md` and is push-only/additive (no changed public `/api` route) OR the paired `auxi` client sync merged. Not verifiable from this repo-scoped session.

## Ready-to-post Slack summary (channel C0BC2122GHM, mrkdwn)
```
*🤖 PR review sweep — 2026-07-27*

⚠️ Scope: session bound to `auxi-wardrobe/auxi-all-in` only — org-wide repo enumeration disabled (403 on GraphQL + org REST). Only `auxi-all-in` swept; other org repos unreachable. Widen Claude GitHub App scope for a full-org sweep.

All 3 open non-draft PRs already carry a tech-lead review on current HEAD (no new commits → not re-reviewed, no duplicate comments). Status:

*✅ Ready to merge — please merge:*
• auxi-all-in#36 — docs: audit findings on background removal pipeline (AU-408) — clean, docs-only — https://github.com/auxi-wardrobe/auxi-all-in/pull/36
• auxi-all-in#32 — docs: root-cause investigation for build-around linen short outfit bug — clean, docs-only — https://github.com/auxi-wardrobe/auxi-all-in/pull/32
(both authored by review-bot `ducga1998` → can't self-approve, each needs one human approval)

*🔧 Needs changes:*
• auxi-all-in#31 — chore: bump backend for tryon push notifications — MAJOR: backend submodule bump w/ zero mobile changes; confirm backend #133 updated API_DOCUMENTATION.md and is push-only/additive (or paired auxi sync merged) — https://github.com/auxi-wardrobe/auxi-all-in/pull/31

*⏭️ Skipped (already reviewed at HEAD, no new commits):* 3
```

## Blocker
Two Slack MCP servers attached:
- `Slack` (capital, stable, user U08HFKEDVS5) → `slack_send_message` to C0BC2122GHM returns `channel_not_found` (different workspace / app not installed there).
- `slack` (lowercase, hosts C0BC2122GHM) → chronically flapping; reconnects then drops within the same turn, so no load→call cycle completes.

Message not delivered to Slack this run. Retry when the lowercase `slack` connector stabilizes, or fix which workspace hosts C0BC2122GHM.

## Hard rules honored
No code pushed, no PR merged/closed, no reviews duplicated. Only read + (attempted) Slack post.
