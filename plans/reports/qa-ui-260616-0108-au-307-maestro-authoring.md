# qa-ui — AU-307 Maestro flow authoring

Status: **DONE_WITH_CONCERNS**
Mode: Maestro (authoring only — no execution)
Worktree: `/Users/nguyenminhduc/dev/wardrobe_project/worktrees/wt-au-307-fe`
Branch: `duc2820/au-307-uac-pin-item-build-around-outfit`

## Files created

| Path | Purpose |
|---|---|
| `tests/maestro/pin-build-around.yml` | Top-level orchestrator; `runFlow` calls A → B → C |
| `tests/maestro/au-307/primary-pin.yaml` | Sub-flow A — cold Home → pin → confirm → generate → success |
| `tests/maestro/au-307/replace-pin.yaml` | Sub-flow B — replace pin → confirm → generate → success (depends on A's end state) |
| `tests/maestro/au-307/error-retry.yaml` | Sub-flow C — pin → forced BE error → Retry (requires BE force-error precondition) |
| `tests/maestro/au-307/README.md` | Preconditions, selector inventory, open questions, run recipes |

All four YAMLs use `appId: com.auxi2026.app` (matches existing `maestro/config.yaml` + every flow under `maestro/flows/`).

Sub-flows reuse the existing `_shared/ensure-home.yaml` via relative `runFlow: ../../../maestro/flows/_shared/ensure-home.yaml` (relative path verified). This means flows pay zero login cost on subsequent runs (Keychain reuse), per the README's `ensure-home` convention.

## Path deviation from existing convention

Existing Maestro flows live under `maestro/flows/<feature>/<name>.yaml`. Spec §4.1 + phase-07 explicitly require `tests/maestro/pin-build-around.yml`, and the user prompt pinned the path. I honoured the spec path. Two parallel layouts now coexist:

- `maestro/flows/` — pre-AU-307 flows (auth, home/swipe, wardrobe, onboarding)
- `tests/maestro/` — AU-307

Worth a tech-lead decision later about consolidating. Not in scope for this ticket.

## testIDs targeted (full list)

All present in the worktree, verified by grep:

| Selector | File:line | Notes |
|---|---|---|
| `auth-email-input` | (`AuthScreen`) | via `ensure-home` → `login.yaml` |
| `home-screen-root` | (`HomeScreen`) | via `ensure-home` |
| `home-swipe-deck` | `HomeScreen.tsx:1810` | deck root |
| `home-pin-generating-header` | `HomeScreen.tsx:1771` | "Generating" status header |
| `home-tile-pin-.*-0` (regex) | `HomeScreen.tsx:2300-2304` | unpinned pin badge on flatTileIndex 0 |
| `home-tile-pin-.*-1` (regex) | same | unpinned pin badge on flatTileIndex 1 |
| `home-tile-pin-.*-set` (regex) | same | pinned-state suffix `-set` |
| `home-tile-skeleton-.*` (regex) | `HomeScreen.tsx:2259` | per-slot skeleton |
| `pin-confirm-modal-root` | `PinConfirmModal.tsx:120` |  |
| `pin-confirm-modal-title` | `PinConfirmModal.tsx:143` |  |
| `pin-confirm-modal-image` | `PinConfirmModal.tsx:129` |  |
| `pin-confirm-modal-cancel` | `PinConfirmModal.tsx:152` |  |
| `pin-confirm-modal-confirm` | `PinConfirmModal.tsx:163` |  |
| `pin-generation-error` | `PinGenerationError.tsx:38` |  |
| `pin-generation-error-retry` | `PinGenerationError.tsx:44` |  |
| `pin-fallback-notice` | `PinFallbackNotice.tsx:21` | negative assert only in A/B |

Listed in spec but **not exercised** by the 3 default flows (deferred to follow-up flows, documented in README §Selectors NOT exercised):

- `pin-confirm-modal-scrim` — backdrop dismiss path
- `pin-tooltip-unpin` — timing-sensitive first-3 tooltip
- `pin-item-unavailable-notice` — needs PINNED_ITEM_GONE injection
- `pin-guest-banner` / `pin-guest-signin-cta` — needs signed-out precondition
- `skeleton-tile` (the default testID inside `SkeletonTile.tsx:30`) — currently overridden by per-slot `home-tile-skeleton-<cellKey>-<index>` everywhere it's mounted
- `item-detail-mix-btn` — ItemDetail entry flow; warrants a separate `au-307-item-detail-build-around.yaml`

## testID gaps flagged (NOT added by qa-ui — mobile-dev's call)

None blocking. Two cosmetic stabilization opportunities, both proposed in the README's §Open questions:

1. **Slot-indexed pin badge alias** — proposed: `home-tile-pin-slot-0`, `home-tile-pin-slot-1`. Today's hash-keyed testID forces regex + `index: 0`, same pattern as `wardrobe/item-detail-open.yaml`. Not blocking — the regex works.
2. **Slot-indexed skeleton alias** — proposed: `home-tile-skeleton-slot-0`. Same rationale.

Neither is required for the 3-flow default to pass. Filing these as a follow-up nit with `mobile-dev` (or rolling into the `wardrobe/item-detail-open.yaml` cleanup ticket).

## Open questions (escalate)

### Q1 — BE error injection for sub-flow C **(BLOCKING for `error-retry.yaml`)**

Phase-07 assumes `V05_BUILD_FORCE_ERROR=true` env flag on `wardrobe-backend`. Grep on `wardrobe-backend/` confirms **no such flag exists**. Decision needed from `backend-dev`:

- **Option A (preferred):** add env flag checked at top of `services/v05_build_service.py::build_v05_for_user()` + `try_another_v05_for_user()`. Raises → 500. Default off, gate in CI.
- **Option B:** Maestro `mockServer` intercept on `/api/v05/recommendation/*`. Heavier setup.
- **Option C:** ship sub-flow C as known-blocked; document; manual smoke only.

Until decided, `error-retry.yaml` will fail loudly on
`extendedWaitUntil visible: pin-generation-error` against a healthy BE — that IS the desired behaviour (loud failure on broken precondition beats silent skip).

Recommended: file a one-line BE ticket for Option A so PR-FE-polish can ship green.

### Q2 — Layout convention drift (`tests/maestro/` vs `maestro/flows/`)

Spec says `tests/maestro/`, existing flows live at `maestro/flows/`. Not blocking AU-307. Suggest tech-lead pick one and migrate the other in a separate housekeeping ticket.

## Boundaries respected

- No git ops performed.
- No `maestro test` execution attempted.
- No yarn / ios builds.
- No source code edits (read-only on `src/**`).
- No testIDs added (gaps filed back to mobile-dev only).

## Hand-off

Ready for `qa-mobile` to execute the suite once BE PR #104 is merged AND the backend force-error decision (Q1) is resolved. If Q1 lands as Option A, no YAML changes needed — just toggle the env flag during sub-flow C execution.

## Unresolved questions

- Q1 above (BE force-error mechanism) — needs `backend-dev` + `pm` decision.
- Q2 above (path convention) — needs `tech-lead` opinion, non-blocking.
