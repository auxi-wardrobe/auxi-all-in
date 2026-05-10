---
name: auxi-qa-test
description: Mobile QA execution playbook for the Auxi RN app — runs Maestro flows on the local iOS simulator, runs Jest unit tests, parses output into a structured pass/fail report. Use when executing existing flows in auxi/maestro/flows/ or running the regression suite. Does NOT author flows (use auxi-qa-ui for that).
---

# Auxi Mobile QA Execution Playbook

Local-only deterministic execution. No cloud, no screenshots, no LLM
reasoning over images. Maestro reads `testID` / `accessibilityLabel` /
text and either matches or it doesn't. Pass/fail is binary.

## Prerequisites (one-time setup)

```bash
# 1. Maestro CLI (Homebrew)
brew tap mobile-dev-inc/tap
brew install maestro
maestro --version       # confirm install
```

If `maestro` isn't on PATH after install, add `~/.maestro/bin` to PATH.

## Per-session boot

```bash
# From umbrella repo root
./scripts/qa-boot.sh
```

That script ensures: backend on :5001, Metro on :8081, iOS simulator
booted with the auxi app installed. Maestro talks to whatever sim is
booted — `qa-boot.sh` does that part.

Sanity check before running flows:

```bash
xcrun simctl list devices booted | grep iPhone
xcrun simctl listapps booted | grep -i auxi
```

If either is empty, re-run `qa-boot.sh`.

## Running flows

```bash
cd auxi

# Single flow
maestro test maestro/flows/home/swipe.yaml

# All flows in a directory
maestro test maestro/flows/home/

# Pass env vars (credentials, etc.)
maestro test maestro/flows/auth/login.yaml \
  -e QA_EMAIL=qa-test@auxi.app \
  -e QA_PASSWORD='QaTest!2026'

# JUnit-style report (machine-parsable)
maestro test maestro/flows/home/ \
  --format junit \
  --output ../logs/maestro/home.xml

# Save debug output (hierarchy + per-step state) on failures
maestro test maestro/flows/home/swipe.yaml \
  --debug-output ../logs/maestro/home-swipe-debug
```

The debug-output directory contains, per failing step:
- `hierarchy.json` — full view tree at the moment of the failed assertion
- `state.json` — Maestro's internal state, including selectors tried

These are the primary artefacts for filing a bug — they tell you exactly
which selector didn't match and what was on screen instead.

## Reading the output

Successful run:
```
✅ Flow Passed: home/swipe.yaml
  ✅ launchApp
  ✅ assertVisible (id=home-screen-root)
  ✅ swipe (direction=UP)
  ...
```

Failed run:
```
❌ Flow Failed: home/swipe.yaml at step 12
  assertVisible (id=home-mode-pill-power) — element not found within 5s
  Run logs: ~/.maestro/tests/<run-id>/
  Hierarchy at failure: ../logs/maestro/home-swipe-debug/step-12-hierarchy.json
```

Exit code: 0 = pass, non-zero = fail. Use this for scripting / CI gating
locally if needed.

## Jest (unit / integration)

Maestro covers UI flows. Jest covers everything else: pure logic, hooks,
service modules with mocked apiClient.

```bash
cd auxi
yarn test                       # one-shot
yarn test --coverage            # with coverage report
yarn test path/to/file.test.ts  # single file
yarn test --watch               # local TDD loop
```

File location: `auxi/__tests__/<name>.test.ts` for top-level, or colocated
`__tests__/` next to the unit-under-test.

```typescript
// auxi/src/hooks/__tests__/useRecommendation.test.ts
import { renderHook, waitFor } from '@testing-library/react-hooks';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useRecommendation } from '../useRecommendation';

jest.mock('../../services/recommendation', () => ({
  recommendationApi: {
    get: jest.fn().mockResolvedValue({ data: { id: 'r1', items: [] } }),
  },
}));

function wrapper({ children }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>;
}

it('fetches recommendation on mount', async () => {
  const { result } = renderHook(() => useRecommendation(), { wrapper });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toEqual({ id: 'r1', items: [] });
});
```

Mock at the apiClient boundary, not deep inside hooks. Don't snapshot
randomized content (recommendations vary on each call).

## Critical regression suite (run every release)

Stored under `auxi/maestro/flows/`:

| # | Flow | Purpose |
|---|---|---|
| 1 | `auth/login.yaml` | login persists across relaunch |
| 2 | `auth/register.yaml` | fresh email lands on onboarding |
| 3 | `onboarding/full.yaml` | Welcome → preferences → first home recommendation |
| 4 | `home/swipe.yaml` | vertical sheet swipe + index advance |
| 5 | `home/modes.yaml` | safe / power / creative pill cycle |
| 6 | `home/heart.yaml` | heart toggle + saved state |
| 7 | `home/pin.yaml` | pin + clear pin |
| 8 | `wardrobe/grid.yaml` | 4-col grid + filter |
| 9 | `body/photos.yaml` | upload, list, delete |
| 10 | `settings/preferences.yaml` | reminders, style direction, reset |

Quick command to run the whole suite:

```bash
cd auxi
maestro test maestro/flows/ \
  --format junit \
  --output ../logs/maestro/regression-$(date +%Y%m%d-%H%M).xml \
  --debug-output ../logs/maestro/regression-debug-$(date +%Y%m%d-%H%M)
```

## Bug-report format

Save under `auxi/docs/qa-findings/YYYY-MM-DD-<slug>.md`:

```markdown
# <Short title>

**Severity**: blocker | critical | major | minor
**Repro rate**: X/N runs of the same flow
**Build**: <commit sha or branch>
**Device**: iOS Simulator <iPhone model + OS>
**Failing flow**: `auxi/maestro/flows/<path>.yaml`
**Failing step**: line N — `<assertion>`

## Maestro log excerpt
\`\`\`
<paste the failing step output verbatim>
\`\`\`

## Hierarchy snapshot
`logs/maestro/<flow>-debug/step-N-hierarchy.json`

## Suspected area
`auxi/src/<file>.tsx:<line>`

## Routing
- mobile-dev (UI/state)  ← if a selector is missing or screen state is wrong
- backend-dev (API)      ← if the flow saw a 5xx / contract drift
- qa-ui (flow author)    ← if the flow itself is wrong
```

Severity:
- **blocker**: app crashes, or critical flow can't complete (auth, onboarding, home)
- **critical**: regression on a primary flow with no workaround
- **major**: regression on a secondary flow OR primary flow with workaround
- **minor**: edge case, low-traffic surface

## Sign-off rule

A flow is "verified" only when:
1. The exact build SHA / branch is recorded.
2. Maestro exited 0.
3. The repro rate is recorded (e.g., "3/3 runs passed").
4. The device/sim spec is recorded.

If the sim isn't available in this session, say so. Don't fabricate.

## What this skill does NOT do

- Author Maestro YAML — that's `auxi-qa-ui`.
- Edit `auxi/src/**` — that's `mobile-dev`.
- Visual fidelity / Figma compare / pixel diff — out of scope. Visual
  intent is mobile-dev's responsibility during `figma-to-rn-workflow`.
- Take screenshots and reason about them. The QA loop is selector-based.

## End-of-turn summary

Always end with:

```
Maestro: N flows · M pass · K fail
Jest: T tests · P pass · F fail · coverage C%
Findings filed: L (→ <agent>)
```
