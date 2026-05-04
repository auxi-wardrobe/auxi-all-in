---
name: auxi-qa-test
description: Mobile QA workflow for the Auxi RN app — unit tests with Jest, deterministic UI flows via mobile-mcp + WebDriverAgent on iOS sim, and the bug-report format. Use when verifying features in auxi/ or filing findings.
---

# Auxi Mobile QA Playbook

You are verifying an iOS-first React Native app. Your job is to produce
evidence — not to fix bugs.

## Test pyramid

| Layer | Tooling | When |
|---|---|---|
| Unit | Jest | Pure logic, hooks, services with mocked apiClient |
| Snapshot | Jest + react-test-renderer | Stable layouts |
| UI integration | mobile-mcp + WebDriverAgent on iOS sim | User flows |
| Manual smoke | `yarn ios:sim` | Pre-release, exploratory, visual review |

## Critical regression flows

Verify these every release. Each gets a screenshot at the assertion point.

1. **Auth**: register → login → kill app → reopen → still logged in (Keychain).
2. **Onboarding**: Welcome → LocationPermission → preference flow → first
   home screen with a recommendation rendered. ⚠️ `auxi/CLAUDE.md` flags
   this as a live migration — confirm with mobile-dev which entry path is
   active (legacy `GenderPreference→StylePreference` vs new
   `PreferenceSeed→FitPreference→OutfitApproval→OnboardingConfirmation`).
3. **Home recommendations**: outfit loads, context chips
   (occasion/weather/time) re-trigger fetch, favorite + try-on actions
   reach the backend.
4. **Wardrobe**: 4-column grid, category filters, photo upload, item edit.
5. **Body photos**: upload, list, delete.
6. **Settings**: daily reminders toggle, style direction edit, preference
   reset.

## Running deterministic UI tests

Reference: `auxi/docs/MOBILE_MCP_MAC_IOS_SIM.md`.

```bash
xcrun simctl list devices
xcrun simctl boot "iPhone 15"
cd auxi && yarn ios:sim         # build + run on the booted sim
```

Then drive via mobile-mcp. Capture per assertion:
- Screenshot
- Network log (request status, headers, payload)
- Action log (what tapped, in what order, with what input)

## Jest patterns

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

## Bug report format

Save under `auxi/docs/qa-findings/YYYY-MM-DD-<slug>.md`:

```markdown
# <Short title>

**Severity**: blocker | critical | major | minor
**Repro rate**: X/N attempts
**Build**: <commit sha or branch>
**Device**: iOS Simulator <iPhone model + OS>

## Steps
1. ...
2. ...

## Expected
<what should happen>

## Actual
<what happened — paste console.error excerpt, screenshot path, network status>

## Suspected area
<file:line if you can localize, otherwise "unknown">

## Routing
- mobile-dev (UI/state)  ← if frontend
- backend-dev (API)      ← if 5xx or contract drift
```

Severity guidance:
- **blocker**: app crashes, can't progress through critical flow
- **critical**: feature broken but workaround exists
- **major**: visible regression, no workaround needed
- **minor**: cosmetic, edge case, low impact

## Verification commands

```bash
cd auxi
npx tsc --noEmit            # type baseline (legacy _HomeScreen errors are expected)
yarn lint                   # baseline: 4 errors + 3 warnings
yarn test                   # jest
yarn test --coverage        # with coverage report
yarn ios:sim                # iOS smoke
```

If you can't run a command in your session (e.g., simulator not
available), say so explicitly. Do not fabricate "passed" results.

## Sign-off rule

A flow is "verified" only if you have:
1. The exact build SHA or branch under test,
2. Evidence — screenshot OR test output OR log excerpt,
3. A repro rate (e.g., "5/5 passed"),
4. The device/sim spec.

If any of those is missing, the verification is incomplete. Say so.
