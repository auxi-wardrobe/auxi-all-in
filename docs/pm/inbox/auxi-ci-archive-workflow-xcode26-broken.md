# auxi CI: `archive` workflow fails on every PR — Xcode 26 missing on runner

**Source**: AU-318 finalize sweep (2026-06-12) — observed identical fail on PR #60 and #62
**Severity**: Major (CI signal dead for all auxi PRs) — route to devops

## Failure

Workflow step "Select Xcode 26":
```
sudo xcode-select -s /Applications/Xcode_26.app
xcode-select: error: invalid developer directory '/Applications/Xcode_26.app'
```
Fails in ~20s on every PR (runs 27361976179 / 27365956814). Pre-existing — NOT
introduced by AU-318; distinct from the red-main test baselines (AU-321/322/323).

## Ask

devops: pin an Xcode version that exists on the GitHub macOS runner image
(`ls /Applications | grep Xcode` in a debug step, or use `maxim-lobanov/setup-xcode`),
or drop the archive job until TestFlight automation needs it.
