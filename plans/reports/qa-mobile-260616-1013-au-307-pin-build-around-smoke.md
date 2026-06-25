---
ticket: AU-307
date: 2026-06-16
agent: qa-mobile
status: BLOCKED
---

## TL;DR

AU-307 Maestro flow `tests/maestro/au-307/primary-pin.yaml` **cannot execute end-to-end** on the local sim — blocked at boot step (`ensure-home.yaml`) by a **shared auth infrastructure regression unrelated to AU-307**. The legacy single-screen Login (`auth-email-input` / `auth-login-submit`) referenced by `maestro/flows/_shared/login.yaml` no longer exists; the app now boots into a 3-step Welcome → Email → Signin flow with completely different testIDs (`welcome-cta-email`, `email-input-field`, `email-submit-button`, `signin-password-input`, `signin-submit`). Maestro never reaches the AU-307 surface.

Reducer Jest suite is green (21/21). The AU-307 testIDs the flow asserts on (`home-tile-pin-*`, `pin-confirm-modal-*`, `home-pin-generating-header`, `home-tile-skeleton-*`, `pin-generation-error`, `pin-fallback-notice`, `home-swipe-deck`) all exist in `HomeScreen.tsx`, `PinConfirmModal.tsx`, `PinGenerationError.tsx`, `PinFallbackNotice.tsx` — so the flow YAML is sound and would likely pass once the upstream login flow is repaired.

Exploratory mobile-mcp smoke also blocked: tried to manually drive Welcome→Email→Signin with `qa-test@auxi.app / QaTest!2026`, got `INVALID_CREDENTIALS` from BE. Registered fresh `au307-qa@auxi.app`, hit `EMAIL_NOT_VERIFIED` gate. BE is connected to remote Postgres (local `wardrobe.db` is empty, 0 users), so no SQLite workaround.

## Verification scope

- Maestro: `tests/maestro/au-307/primary-pin.yaml` → FAIL at boot (auth regression, not AU-307)
- Maestro: `tests/maestro/au-307/replace-pin.yaml` → SKIPPED (state dependency on primary-pin)
- Maestro: `tests/maestro/au-307/error-retry.yaml` → SKIPPED per instructions (no `V05_BUILD_FORCE_ERROR`)
- Exploratory mobile-mcp smoke (5 scenarios) → BLOCKED at sign-in step (no usable account)
- Jest: `src/hooks/__tests__/usePinReducer.test.ts` → PASS 21/21 in 0.254 s

## Maestro results

| Flow | Result | Duration | Failure step |
|---|---|---|---|
| `primary-pin.yaml` | FAIL | ~10s | `runFlow: ../../../maestro/flows/_shared/ensure-home.yaml` → `assertVisible: home-screen-root` (login sub-flow gate `auth-email-input` not matched; not actually on Login screen — on new Welcome screen) |
| `replace-pin.yaml` | SKIPPED | — | Depends on primary-pin reaching pinned state |
| `error-retry.yaml` | SKIPPED | — | BE has no force-error flag (per instructions) |

Maestro log:
```
Run ../../../maestro/flows/_shared/ensure-home.yaml...
  Launch app "com.auxi2026.app"... COMPLETED
  Run ./login.yaml when id: auth-email-input is visible...
  Run ./login.yaml when id: auth-email-input is visible... SKIPPED
  Assert that id: home-screen-root is visible... FAILED
Run ../../../maestro/flows/_shared/ensure-home.yaml... FAILED
```

Debug artifacts: `/tmp/maestro-au307/primary-pin-debug/.maestro/tests/2026-06-16_101406`

## Manual smoke

| Scenario | Result | Notes |
|---|---|---|
| Generating header disappears after pin completes | BLOCKED | Could not authenticate to reach Home |
| Unpin tap (direct UNPIN, no modal) | BLOCKED | Could not authenticate to reach Home |
| ItemDetail "Build around this" CTA | BLOCKED | Could not authenticate to reach Home |
| SYSTEM tile pin badge hidden | BLOCKED | Could not authenticate to reach Home |
| Guest auth wall on pin tap | BLOCKED | Could not sign out (never signed in) |

Sim landing state captured: `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots/au-307-auth-block-260616-1018.png` (shows `Email hoặc mật khẩu không đúng` from manual sign-in attempt).

## Bugs found

### BUG-1: Shared Maestro auth flow not updated for new Welcome → Signin entry point (CRITICAL — blocks ALL Maestro flows that boot to Home)

- **Files**:
  - `auxi/maestro/flows/_shared/login.yaml` (legacy `auth-email-input` / `auth-login-submit`)
  - `auxi/maestro/flows/_shared/ensure-home.yaml` (gates login on `auth-email-input` visibility)
- **Repro**:
  1. Boot fresh sim with auxi app installed (no keychain auth)
  2. Run any Maestro flow that calls `runFlow: ../_shared/ensure-home.yaml`
  3. Observe: app boots to Welcome screen (`welcome-cta-email`, `welcome-cta-google`, `welcome-cta-apple`), not Login (`auth-email-input`)
  4. `ensure-home.yaml` SKIPs login (gate not visible), then fails `assertVisible: home-screen-root`
- **Actual flow now**:
  - Welcome screen testIDs: `welcome-lang-link`, `welcome-cta-google`, `welcome-cta-apple`, `welcome-cta-email`, `welcome-legal-text`
  - Email screen testIDs: `email-back-button`, `email-input-label`, `email-input-field`, `email-submit-button`
  - Signin screen testIDs: `signin-back`, `signin-heading`, `signin-email-readonly`, `signin-password-input`, `signin-password-toggle-show`, `signin-submit`
- **Routing**: `qa-ui` (flow author) to update `_shared/login.yaml` for the new 3-step flow. `mobile-dev` is not on the hook — the screens carry stable testIDs already.
- **Impact**: not just AU-307. Every flow that uses `_shared/ensure-home.yaml` or `_shared/login.yaml` is currently broken. Worth a sweep.
- **Severity**: BLOCKER for Maestro regression suite, MAJOR for AU-307 sign-off (forces manual-only verification).

### BUG-2: QA test account `qa-test@auxi.app / QaTest!2026` does not authenticate against local BE (MAJOR — blocks manual smoke)

- `POST /api/login` returns `INVALID_CREDENTIALS` for `qa-test@auxi.app / QaTest!2026`
- `POST /api/auth/email-precheck` returns `{"provider":"password"}` (account exists with password provider) — so password drift or hash incompatibility
- Local `auxi/wardrobe-backend/wardrobe.db` has 0 users (BE is wired to remote Postgres via `DATABASE_URL`)
- Fresh registration via `POST /api/register` works but lands on `EMAIL_NOT_VERIFIED`; no obvious dev-bypass exposed
- **Routing**: `devops` / `backend-dev` — either reset the qa-test account password on the remote DB to `QaTest!2026`, OR add an `is_verified=true` SQL fixture to seed via the Maestro README's documented `UPDATE users SET …` pattern, OR document a `DEV_AUTO_VERIFY=true` env knob.
- **Impact**: same hard block — can't manually verify AU-307 surface without a working credential.
- **Severity**: BLOCKER for any end-to-end QA on this BE.

## Selector issues (if any)

None found in the AU-307 flow itself. All testIDs the flow asserts on are present in source:
- `home-screen-root`, `home-swipe-deck`, `home-pin-generating-header` → `src/screens/HomeScreen.tsx`
- `home-tile-pin-*-0`, `home-tile-pin-*-set`, `home-tile-skeleton-*` → `src/screens/HomeScreen.tsx`
- `pin-confirm-modal-root`, `pin-confirm-modal-title`, `pin-confirm-modal-image`, `pin-confirm-modal-cancel`, `pin-confirm-modal-confirm` → `src/components/features/PinConfirmModal.tsx`
- `pin-generation-error` → `src/components/features/PinGenerationError.tsx`
- `pin-fallback-notice` → `src/components/features/PinFallbackNotice.tsx`

The `home-tile-pin-.*-0` regex pattern with `index: 0` is the documented convention in the flow header and matches the dynamic `outfit.outfitHash`-keyed testIDs in `HomeScreen.tsx`. Once the auth gate is unblocked, this flow is expected to run cleanly.

## Jest results

```
Test Suites: 1 passed, 1 total
Tests:       21 passed, 21 total
Snapshots:   0 total
Time:        0.254 s
```

All 21 `usePinReducer` cases green, including: `CONFIRM_PIN`, `UNPIN`, `GENERATE_SUCCESS`, `GENERATE_FAILURE` (with fallback notice), `RETRY`, `CONFIRM_PIN_FROM_DETAIL`, `AUTH_REQUIRED`, and atomic replace semantics.

## Unresolved questions

1. Who owns the `_shared/login.yaml` migration to the new 3-step Welcome→Email→Signin flow — `qa-ui` (flow authoring) or `mobile-dev` (testID stability)? Recommend `qa-ui`.
2. Is `qa-test@auxi.app / QaTest!2026` supposed to work against the local Railway-backed BE (the `:5001` instance) or only against `:5002` (the `test_server.py` fixture instance referenced in `maestro/flows/onboarding/v05.yaml`)?
3. Does the new flow break the entire Maestro regression suite (`home/swipe.yaml`, `wardrobe/grid.yaml`, `body/photos.yaml`, `settings/preferences.yaml`, `auth/uac-happy-signin.yaml`) the same way? Worth a follow-up sweep dispatch.
4. Should the AU-307 Maestro flow be re-attempted on `:5002` test-server instead of `:5001` Railway-backed BE? `:5002` is described as the e2e fixture instance — would have a seeded verified test account.
5. Is there a developer-only "skip auth" or "seed dev user" path the team uses for ad-hoc verification? If yes, document it in `tests/maestro/au-307/README.md` so future QA runs aren't blocked the same way.

## Suggested next steps

- **Highest priority**: `qa-ui` rewrites `_shared/login.yaml` against the new Welcome→Email→Signin selectors. This unblocks the entire Maestro suite, not just AU-307.
- **Parallel**: `devops` or `backend-dev` confirms/repairs the QA test account credentials on the remote DB used by `:5001`, and documents the canonical local QA bring-up.
- **Then**: re-dispatch this same AU-307 smoke job once both are repaired. The flow YAML is already correct.
