---
name: auxi-launch-notify
description: Announce a successful auxi TestFlight launch on three surfaces — GitHub Release, Linear comment, CHANGELOG.md. Use when the deploy skill auto-chains here after upload success, OR when the user says "announce build N", "post release notes", "launch notify", "thông báo build N", "post changelog cho build N". Each surface is idempotent — re-running is safe.
---

# Auxi → launch notification

Owned by the umbrella `pm` agent. Fires after `release-testflight.sh` exits 0 with a successful upload. Writes three artifacts so the team knows a new build is live.

## When to use

- Deploy skill auto-chained here after upload success (signal: `release-metadata.env` exists in archive dir)
- User says: "announce build N", "post release notes for build N", "launch notify", "thông báo build N", "viết changelog cho build mới"
- Manual re-run after fixing a failed surface (re-runs are safe — each surface checks-then-writes)

## When NOT to use

- Build hasn't been uploaded yet — run `auxi-deploy-testflight` first
- Public App Store release (different surfaces — separate skill, future)
- Backend / Railway deploys (different repo, separate skill)
- Hotfix to a build already announced — edit the existing release/comment manually, don't re-run

## Inputs (env var contract)

Source these from `${TMPDIR:-/tmp}/auxi-archive/release-metadata.env` written by `release-testflight.sh`, or set manually:

| Var | Required | Example | Source |
|---|---|---|---|
| `BUILD_NUMBER` | yes | `3` | pbxproj after bump |
| `MARKETING_VERSION` | yes | `1.0` | pbxproj `MARKETING_VERSION` |
| `TAG` | yes | `v1.0-build3` | constructed `v${MV}-build${BN}` |
| `DELIVERY_UUID` | yes | `e5df3f7f-...` | parsed from altool output |
| `COMMIT_SHA` | yes | `08142d2` | `git rev-parse HEAD` |
| `BRANCH` | yes | `chore/ship-infra-and-env` | `git branch --show-current` |
| `LINEAR_TICKET` | no | `AU-249` | resolved from branch / commit footer / default |
| `DRY_RUN` | no | `1` | print plan, do not write |
| `SKIP_GH` / `SKIP_LINEAR` / `SKIP_CHANGELOG` | no | `1` | retry-only-one-surface escape hatches |

Fail loud if any required var is empty.

## Linear ticket resolution

Priority order (first match wins):

1. `LINEAR_TICKET` env var
2. Conventional commit footer `Refs: AU-XXX` on $COMMIT_SHA (`git show -s --format=%B $COMMIT_SHA | grep -oE 'Refs: [A-Z]+-[0-9]+'`)
3. Branch name pattern `*/AU-XXX-*` or `*/au-XXX-*` (case-insensitive grep)
4. Default `AU-249` (current V05 epic)

Print the resolved ticket before posting so user can spot wrong routing.

## Pre-resolution (run BEFORE Surface 1, 2, 3)

```bash
set -euo pipefail

# Validate key file exists + non-empty before any Linear surface
[ -s ~/.linear/api_key ] || { echo "FATAL: ~/.linear/api_key missing or empty"; exit 1; }

# Resolve previous tag once — both Surface 2 (commit list) and Surface 3 (changelog) need it
PREV_TAG=$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || echo "")
echo "Previous tag: ${PREV_TAG:-<none, first release>}"
```

## Surface 1 — GitHub Release

```bash
REPO=auxi-wardrobe/auxi-mobile

# Idempotence: skip if release already exists
if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  echo "✓ GH release $TAG already exists — skipping creation"
  RELEASE_URL=$(gh release view "$TAG" -R "$REPO" --json url --jq .url)
else
  # `--generate-notes` builds notes from commits between previous tag and this one.
  # `--notes` is intentionally OMITTED here — passing both causes `--notes` to win
  # and we'd lose the auto-generated commit log. Add custom prefix via a second
  # `gh release edit --notes-file` step if needed.
  if ! gh release create "$TAG" -R "$REPO" \
        --title "TestFlight $TAG" \
        --generate-notes \
        > /tmp/gh-release.out 2>/tmp/gh-release.err; then
    cat /tmp/gh-release.err >&2
    echo "FATAL: gh release create failed (auth, network, or rate limit)" >&2
    exit 1
  fi
  RELEASE_URL=$(grep -m1 'https://github.com/' /tmp/gh-release.out | head -1)
fi
echo "GH Release: $RELEASE_URL"
```

If `gh` not authenticated → fail with instruction to run `gh auth login`.

## Surface 2 — Linear comment on $LINEAR_TICKET

Linear's `issue(id:)` accepts both the human identifier (`AU-249`) and the UUID — verified empirically. We use the identifier directly.

**Idempotence check first**: query last 10 comments; skip if any body contains `$TAG`.

```bash
LINEAR_KEY=$(cat ~/.linear/api_key)

# Build BODY first (one place) — multiline markdown with auto-generated commit list
COMMITS=$(git log --pretty='- %s' "${PREV_TAG:+$PREV_TAG..}$TAG" 2>/dev/null | head -20 || true)
BODY=$(cat <<EOF
🚀 **$TAG đã lên TestFlight**

- **Release:** $RELEASE_URL
- **Delivery UUID:** \`$DELIVERY_UUID\`
- **Commit:** [\`$COMMIT_SHA\`](https://github.com/auxi-wardrobe/auxi-mobile/commit/$COMMIT_SHA) (branch: \`$BRANCH\`)
- **Backend:** Railway production

**Changes** (auto-generated):
$COMMITS

Apple processing ~5–30 phút. Build sẽ hiện ở App Store Connect → TestFlight tab. Internal testers nhận mail tự động sau khi assign group.
EOF
)

# Duplicate check — set -e protects us from silent failure (eg ticket not found → null comments → traceback)
EXISTS=$(curl -sS --fail https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_KEY" -H "Content-Type: application/json" \
  -d "{\"query\":\"query { issue(id: \\\"$LINEAR_TICKET\\\") { comments(first: 10) { nodes { body } } } }\"}" \
  | TAG="$TAG" python3 -c "import json,sys,os; d=json.load(sys.stdin)['data']['issue']; print(any(os.environ['TAG'] in c['body'] for c in (d or {'comments':{'nodes':[]}})['comments']['nodes']))")

if [ "$EXISTS" = "True" ]; then
  echo "✓ Linear comment for $TAG already exists on $LINEAR_TICKET — skipping"
  COMMENT_URL="<existing>"
else
  # Pass BODY via env to avoid all shell/python quoting hazards (backticks, quotes, newlines)
  PAYLOAD=$(TICKET="$LINEAR_TICKET" BODY="$BODY" python3 -c "
import json, os
print(json.dumps({
  'query': 'mutation(\$id: String!, \$body: String!) { commentCreate(input: {issueId: \$id, body: \$body}) { success comment { url } } }',
  'variables': {'id': os.environ['TICKET'], 'body': os.environ['BODY']}
}))")
  RESULT=$(curl -sS --fail https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_KEY" -H "Content-Type: application/json" \
    --data-binary "$PAYLOAD")
  COMMENT_URL=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['commentCreate']['comment']['url'])")
  echo "Linear: $COMMENT_URL"
fi
```

Note: BODY passes through env vars (`TICKET=... BODY=... python3 -c '...'`) — NEVER inline into the python source. Backticks, quotes, and newlines in commit messages would otherwise break the literal string.

## Surface 3 — CHANGELOG.md

```bash
CL=auxi/CHANGELOG.md

# Bootstrap if missing (don't block the launch — create with placeholder)
if [ ! -f "$CL" ]; then
  cat > "$CL" <<EOF
# Changelog

All notable changes documented per [Keep a Changelog](https://keepachangelog.com/). Versioned as \`v<marketing>-build<N>\` to match TestFlight.

## [Unreleased]
EOF
  echo "✓ Bootstrapped CHANGELOG.md"
fi

# Idempotence: skip if $TAG section already present
if grep -q "^## \[$TAG\]" "$CL"; then
  echo "✓ CHANGELOG already has $TAG — skipping"
else
  TODAY=$(date -u +%Y-%m-%d)
  # PREV_TAG resolved in Pre-resolution step above
  RANGE="${PREV_TAG:+$PREV_TAG..}$TAG"
  # BSD-sed compatible: extended regex via -E, no escaped group/?
  STRIP_PREFIX='-E s/^[a-z]+(\([^)]*\))?: */- /'
  FEAT=$(git log --pretty='%s' "$RANGE" | grep -E '^feat(\(|:)' | sed $STRIP_PREFIX || true)
  FIX=$(git log --pretty='%s' "$RANGE" | grep -E '^fix(\(|:)' | sed $STRIP_PREFIX || true)
  CHANGED=$(git log --pretty='%s' "$RANGE" | grep -E '^(refactor|perf|chore)(\(|:)' | sed $STRIP_PREFIX || true)

  # Build the section
  SECTION="## [$TAG] - $TODAY"$'\n'
  [ -n "$FEAT" ] && SECTION="$SECTION"$'\n### Added\n'"$FEAT"$'\n'
  [ -n "$FIX" ] && SECTION="$SECTION"$'\n### Fixed\n'"$FIX"$'\n'
  [ -n "$CHANGED" ] && SECTION="$SECTION"$'\n### Changed\n'"$CHANGED"$'\n'

  # Insert after '## [Unreleased]' header via env-passed string (no heredoc interpolation hazard)
  SECTION="$SECTION" CL="$CL" python3 <<'EOF_PY'
import os, pathlib
p = pathlib.Path(os.environ['CL'])
text = p.read_text()
marker = '## [Unreleased]\n'
insert = os.environ['SECTION'] + '\n'
idx = text.find(marker)
if idx >= 0:
    end = idx + len(marker)
    p.write_text(text[:end] + '\n' + insert + text[end:])
else:
    p.write_text(text.rstrip() + '\n\n' + insert)
EOF_PY
  echo "✓ Inserted $TAG section into CHANGELOG.md"
fi
```

## Commit + push CHANGELOG

```bash
cd auxi
if ! git diff --quiet CHANGELOG.md; then
  git add CHANGELOG.md
  git commit -m "docs(changelog): record $TAG launch

Auto-generated by auxi-launch-notify after TestFlight upload of $TAG.
Delivery UUID: $DELIVERY_UUID"

  # Try direct push; if branch-protected, fall back to opening a PR.
  # Capture exit status (set -e would otherwise abort before we can branch).
  set +e
  git push origin "$BRANCH" > /tmp/push.log 2>&1
  PUSH_RC=$?
  set -e
  if [ $PUSH_RC -ne 0 ]; then
    if grep -qE "protected branch|GH006|protected by branch rules" /tmp/push.log; then
      # Branch off current HEAD into a release-notes branch, then push + PR.
      # The commit is already on HEAD; create branch pointing here.
      NOTES_BRANCH="release-notes/$TAG"
      git branch "$NOTES_BRANCH" HEAD
      git push -u origin "$NOTES_BRANCH"
      gh pr create --base main --head "$NOTES_BRANCH" \
        --title "docs(changelog): $TAG launch" \
        --body "Auto-opened by auxi-launch-notify because main is protected. Merge when convenient — content is just the auto-generated CHANGELOG entry."
      # Restore original branch state by resetting the local main pointer
      git reset --hard "origin/$BRANCH"
    else
      cat /tmp/push.log >&2
      echo "FATAL: push failed for unknown reason — investigate" >&2
      exit 1
    fi
  fi
fi
```

## Summary output (always print at end)

```
==============================================
Launch notification — $TAG complete
==============================================
GH Release   : $RELEASE_URL
Linear       : $COMMENT_URL  (ticket: $LINEAR_TICKET)
CHANGELOG    : <last commit URL or "skipped — no change">
==============================================
```

## Dry-run mode

If `DRY_RUN=1`, print what each surface WOULD do and exit. No `gh` create, no Linear POST, no git commit. Useful for testing the skill itself.

## Failure decision tree

| Failure | Diagnosis | Action |
|---|---|---|
| `gh release create` returns "release already exists" | Race condition or re-run | OK, fetch URL via `gh release view`, continue |
| `gh: not authenticated` | Token missing | Tell user: `gh auth login` |
| Linear API returns 401 | Key expired/wrong | Tell user to regenerate at https://linear.app/settings/api |
| Linear API returns 429 | Rate limit | Wait 60s and retry once; if still 429, skip Linear surface, report |
| Linear ticket not found | Wrong AU-XXX | Tell user the resolved ticket + branch name; ask for correct ID |
| `git push` rejected (protected branch) | main is gated | Fall back to PR (above) |
| CHANGELOG.md insert produces malformed output | python3 regex edge case | Print the file head + tail, ask user to manually fix |
| `release-metadata.env` missing | Deploy skill didn't write it, or running standalone | Require all env vars on command line; print which ones are missing |

Each surface should be independently retryable via `SKIP_<OTHER>=1`. After fixing one surface, re-run with the rest skipped.

## Anti-patterns

- ❌ Don't post Linear comment without idempotence check — duplicate noise per re-run
- ❌ Don't overwrite an existing GH release's notes — annotation, not replacement
- ❌ Don't commit CHANGELOG straight to main if branch protected — fallback to PR
- ❌ Don't run if `DELIVERY_UUID` is empty — means upload didn't actually finish
- ❌ Don't run for non-TestFlight artifacts (Railway deploy, App Store public release) — separate skill
- ❌ Don't bury failures — surface each in summary so user knows what to retry
- ❌ Don't trust local commit history alone — `gh release create --generate-notes` queries the server's view

## Auto-chain contract (with `auxi-deploy-testflight`)

Deploy skill, on upload success, writes `$ARCHIVE_DIR/release-metadata.env`:
```
BUILD_NUMBER=3
MARKETING_VERSION=1.0
TAG=v1.0-build3
DELIVERY_UUID=e5df3f7f-cd7d-4ee1-8af4-cb70b6b7ff8e
COMMIT_SHA=08142d2
BRANCH=chore/ship-infra-and-env
```

Then deploy skill instructs Claude to invoke this skill, which sources the file via `set -a; source $ARCHIVE_DIR/release-metadata.env; set +a`. If file missing, fall back to manual var collection from current git state.

## Related artifacts

- `auxi/scripts/release-testflight.sh` — upstream caller
- `.claude/skills/auxi-deploy-testflight.md` — auto-chain origin
- `.claude/agents/pm.md` — agent that owns this skill (Phase 4 of plan)
- `auxi/CHANGELOG.md` — target file (bootstrapped on first run if missing)
- `auxi/plans/260512-1410-pm-launch-notify-skill/` — design + open risks
