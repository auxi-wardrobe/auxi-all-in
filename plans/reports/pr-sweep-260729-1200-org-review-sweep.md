# PR Review Sweep — 2026-07-29

Bot account: `ducga1998`. Run: scheduled tech-lead PR sweep.

## Scope limitation (important)
Session is bound to `auxi-wardrobe/auxi-all-in` only. Org-wide repo discovery
is disabled for this session:
- `gh repo list auxi-wardrobe` → HTTP 403 (GraphQL disabled; PR-review ops only)
- `gh api orgs/auxi-wardrobe/repos` → HTTP 403 (sessions bound to configured repos)
- `gh api repos/.../pulls` → HTTP 403 (use GitHub MCP tools)

So only `auxi-all-in` was swept via the GitHub MCP tools. **Other org repos
were NOT reachable this run.** GitHub MCP (`mcp__github__*`) works fine for the
scoped repo.

## Worklist (open, non-draft PRs on auxi-all-in)
All three were already reviewed by the bot at their EXACT current head SHA
(no new commits since) → no duplicate reviews posted this run.

| PR | Author | Head | Last bot review @ head | Standing verdict |
|----|--------|------|------------------------|------------------|
| #36 | ducga1998 (bot) | e539e67 | e539e67 (COMMENTED) | Clean, docs-only, no contract impact. Ready to merge — needs human approval (author is bot, can't self-approve). |
| #32 | ducga1998 (bot) | 4ba0206 | 4ba0206 (COMMENTED) | Clean, docs-only, no contract impact. Ready to merge — needs human approval (author is bot). |
| #31 | 0xduc98 | 44c9ffb | 44c9ffb (COMMENTED) | NEEDS CHANGES — MAJOR: two-repo contract-sync unverified. Backend #133 bump ships zero mobile changes; confirm `API_DOCUMENTATION.md` updated + #133 push-only/additive (or paired `auxi` client sync merged) before pointer lands. |

No approvals possible this run: #36/#32 are bot-authored (self-approval forbidden);
#31 has an open MAJOR finding. Correct per "only approve genuinely clean PRs."

## Slack summary — BLOCKED (delivery failure)
Target channel `C0BC2122GHM`.
- Lowercase `slack` MCP connector (the one attached for this task) flapped
  continuously for ~1h — disconnected in the window between loading its tool
  and calling it, across ~6 attempts. Never stayed up.
- Capital-`S` `mcp__Slack__slack_send_message` → `channel_not_found`
  (that app is installed on a different workspace than `C0BC2122GHM`).

Summary NOT delivered to Slack. Message that should be posted:

---
*🤖 PR review sweep — 2026-07-29*

_Scope note: session bound to `auxi-wardrobe/auxi-all-in` only — org-wide repo
discovery disabled, so only that repo was swept. Other org repos not reachable
this run._

*✅ Ready to merge — please merge:*
• auxi-all-in#36 — docs: audit findings on background removal pipeline (AU-408) — clean, needs a human approval (author is the review bot) — https://github.com/auxi-wardrobe/auxi-all-in/pull/36
• auxi-all-in#32 — docs: root-cause investigation for build-around linen short outfit bug — clean, needs a human approval (author is the review bot) — https://github.com/auxi-wardrobe/auxi-all-in/pull/32

*🔧 Needs changes:*
• auxi-all-in#31 — chore: bump backend for tryon push notifications — MAJOR: two-repo contract-sync unverified (confirm backend #133 updated API_DOCUMENTATION.md + is push-only/additive, or paired auxi client sync merged) — https://github.com/auxi-wardrobe/auxi-all-in/pull/31

*⏭️ Skipped (already reviewed at current head, no new commits):* 3
---

## Unresolved questions
- Is the org-wide sweep intended to work from this repo-scoped session? Current
  GitHub access can only reach `auxi-all-in`. If org-wide coverage is required,
  the Claude GitHub App needs org-level scope (or the sweep must run per-repo).
- Slack channel `C0BC2122GHM` is unreachable: the stable Slack app is on the
  wrong workspace, and the correct connector is unstable. Needs the `slack`
  connector fixed or the channel/app aligned to one workspace.
