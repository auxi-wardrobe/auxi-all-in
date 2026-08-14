# Phase 04 — QA + design gates

**Owner:** qa-ui → designer → qa-mobile · **Priority:** P1 · **Status:** pending · **Effort:** 2h
**Blocked by:** phase 03.

## Context links

- Canonical workflow: umbrella `CLAUDE.md` → "Figma → mobile UI workflow" (steps 5–8)
- Hard gate rule: `.claude/rules/design-review-required.md`
- iOS build rule: `.claude/rules/ios-build-workflow-required.md` (never rebuild unilaterally —
  Metro/Simulator/watchman are shared machine singletons across concurrent sessions)

## Gate sequence (in order — each blocks the next)

| # | Gate | Owner | Output | Blocking? |
|---|---|---|---|---|
| 5 | `./scripts/auxi-lint-tokens.sh` clean | mobile-dev | terminal green | yes |
| 6 | qa-ui **Compare mode** Pass 2+3 (code vs Figma + sim screenshot) | qa-ui | audit note | yes |
| 6.5 | **designer** 8-lens review — HARD GATE | designer | `auxi/docs/design-reviews/2026-08-XX-usage-limit-sheet.md` | yes, FAIL blocks PR |
| 7 | qa-mobile smoke on sim (mobile-mcp exploratory) | qa-mobile | pass/fail + logs | yes |
| — | qa-ux heuristic pass (recommended, see below) | qa-ux | `auxi/docs/qa-findings/` | advisory |
| 8 | PR with template checklist green | mobile-dev | PR | — |

**qa-ux is strongly recommended here even though it is not in the canonical sequence**: this is a
*fake* paywall. The failure mode is a user believing they've been blocked or charged. That is a
comprehension problem, which is qa-ux's lens, not qa-ui's.

## Backend verification (runs independently, before the mobile gates)

1. `cd wardrobe-backend && pytest tests/test_usage_endpoint.py`
2. `cd wardrobe-backend && python test_server.py` — full e2e, must be green
3. tech-lead sign-off on the `API_DOCUMENTATION.md` diff

## Mobile verification commands

```bash
cd auxi && npx tsc --noEmit          # clean (legacy _HomeScreen.tsx errors expected)
cd auxi && yarn lint                 # no new errors beyond the 4/3 baseline
./scripts/auxi-lint-tokens.sh        # no hex / font drift
cd auxi && yarn jest src/services/__tests__/usageLimit.test.ts
```

Full-stack smoke (umbrella gate — real HTTP, never mocked): `./scripts/qa-boot.sh`, backend on
`:5001`, app against it.

## End-to-end scenarios qa-mobile must run

1. **See-on-me threshold** — free account, complete 2 renders → sheet appears after the 2nd.
2. **Upgrade → NotifyMe** — tap Upgrade, land on NotifyMe, tap "Notify me", confirmed state shows.
3. **Dismiss path** — swipe/tap dismiss, user returns to the try-on result unharmed.
4. **No-nag** — repeat the same action; no second sheet.
5. **Cross-feature** — trigger a different feature in the same session; sheet appears again.
6. **Fail-open** — stop the backend, repeat the action; success UI unchanged, no sheet, no error.
7. **Premium bypass** — flip the user's `is_premium` in the DB; no sheet at any threshold.
8. **Kill-switch** — `PAYWALL_MVP_ENABLED = false`; nothing renders, no request fires.
9. **Cold start** — app relaunches cleanly with the new route registered (nav-registration smoke).

## Analytics verification (qa-mobile + business-analyst)

- Mixpanel live view shows all 5 events with correct `feature` values.
- Property audit: no URLs, no item ids, no free text, no email — counts and the feature key only.
- Funnel `usage_limit_gate_shown → usage_limit_upgrade_tapped → notify_me_viewed → notify_me_tapped`
  registers a run-through.
- `auxi/docs/analytics/mixpanel-tracking-plan.md` updated (a PR without this is incomplete per
  `.claude/rules/analytics-tracking-required.md`).

## PR checklist (`.github/PULL_REQUEST_TEMPLATE.md`)

- [ ] Figma URL with frame node-id (`4444-26066`)
- [ ] Extraction artifact path
- [ ] qa-ui review-extraction PASS (phase 02)
- [ ] qa-ui Compare PASS
- [ ] `auxi-lint-tokens.sh` clean
- [ ] designer design-review PASS (step 6.5)
- [ ] qa-mobile verify id / sim screenshot
- [ ] `API_DOCUMENTATION.md` updated + tech-lead sign-off (backend PR)
- [ ] `mixpanel-tracking-plan.md` updated

## Rollback plan (per phase)

| Phase | Revert | Blast radius |
|---|---|---|
| 03 | flip `PAYWALL_MVP_ENABLED = false` (no deploy needed if already shipped false, else one JS release) | none — no sheet, no requests |
| 02 | revert the component/screen commits; the nav route is additive | none — nothing links to it once 03 is off |
| 01 | flip backend `PAYWALL_MVP_ENABLED=false` env → all `limit_reached: false`; or drop the router | none — read-only additive endpoint, no schema change |

Order matters on rollback: **disable the mobile gate first**, then the backend. Reverse of the ship
order (backend first, mobile second).

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| Designer FAIL late in the cycle | M×M | designer is a known hard gate; budget a fix loop; the sheet reuses on-system `MBottomSheet` so drift risk is low |
| Sim rebuild disrupts other concurrent CC sessions | M×H | follow `.claude/rules/ios-build-workflow-required.md`; hot-reload only; never run `ios:clean` unilaterally |
| Mobile ships before backend | L×H | fail-open makes it harmless, but enforce backend-first in the release note |
| Threshold semantics wrong → wrong demand data | M×H | resolve the operator question BEFORE qa (see phase-01/03 unresolved) |

## Success criteria

All 9 scenarios pass, designer PASS recorded, Mixpanel funnel confirmed live, both docs updated.

## Next steps

Post-merge: hand the funnel to `business-analyst` to build the AU-442 demand dashboard. The real
IAP/entitlement work referenced in the ticket comment stays out of scope and remains a separate
future ticket (a real paywall already exists dark at `auxi/src/screens/UpgradeScreen.tsx` — that is
the natural starting point when it is revived).
