# Overnight Autopilot — Night Plan (2026-06-13 02:03 → 08:00)

Goal (user, VN): re-scan all Linear cycles, find everything that needs doing, work until 8am,
full authority, self-decide planning. User asleep — no questions.

## Board snapshot (Auxi team, cycle 13 active Jun 7–21; 30 issues, 8 done)

- **In Progress (5):** AU-261, AU-253, AU-259(CEO question), AU-254, AU-285 — large UAC specs.
- **In Review (7):** AU-314, AU-318, AU-298, AU-80, AU-286, AU-288, AU-289.
- **Todo active (cycle 13):** features AU-340/320/332/330/331/87/328/327/316/301/307; CEO motion docs AU-333–339, AU-300.
- **Backlog active:** keystone bugs AU-326/323/321/322 (red-main), AU-162, contract drift AU-255/256/324/257, + older stale granular tasks.

## Live git/PR reality (vs stale memory)
- auxi origin/main @ 60175866 (AU-318 #65 merged; #66 swipe-deck merged). Open PR: only #54 (old).
- backend origin/main @ 69e9a44 (#93 migration heads). **Zero open backend PRs.**
- Local submodule checkouts BOTH dirty + off-main → never touch; all work via worktrees from origin/main.

## Plan (self-decided, priority order)
1. **Sweep** — reconcile In Review/In Progress; close verified-merged, comment stale. ≤10 writes.
2. **Turn main GREEN (keystone)** — fix AU-322, AU-321, AU-323, AU-326. Unblocks every gate. → PRs.
3. **Backend bug autopilot** — AU-255, AU-256, AU-324 contract drift. → PRs.
4. **Feature ticket** if time — AU-316 or AU-330.

One ticket in flight at a time. Worktree per ticket from origin/main. Never auto-merge. Never deploy.
Each ticket → PR + Linear → In Review for human merge. Dispatch log appended per autopilot skill.
