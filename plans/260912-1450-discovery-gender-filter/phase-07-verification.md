# Phase 07 — Verification gates

**Repo:** both · **Owner:** qa-mobile · **Effort:** 1h
**Status:** pending · **Blocked by:** 04, 05, 06

## Umbrella gates (root `CLAUDE.md` §Verification gates)

1. Backend: `cd auxi-backend && python test_server.py` (full e2e on :5002)
2. Mobile: `cd auxi-mobile && npx tsc --noEmit && yarn lint`
3. Admin SPA: `cd auxi-backend/wardrobe-admin && npx tsc -b && npm run build`
4. Smoke: backend on :5001, mobile running against it — **real HTTP, not mocks**.
   The root CLAUDE.md is explicit: shipping mobile against a mocked backend is
   exactly the contract drift the umbrella exists to prevent. This feature is
   unmockable anyway — the whole behaviour lives in a server-side SQL filter.

## Fixture the smoke test needs

Via the admin SPA, six PUBLISHED servable outfits:

| Title | gender | Purpose |
|---|---|---|
| `QA men A`, `QA men B` | `M` | Menswear cohort |
| `QA women A` | `W` | Womenswear cohort |
| `QA unisex A` | `U` | Unisex-tagged |
| `QA legacy A` | `null` | NULL-is-universal regression |
| `QA draft` | `M`, **DRAFT** | Must never appear |

Three test users, each onboarded through the real V05 flow (do **not** hand-edit
`user_metadata` — onboarding is the write path under test):
Menswear, Womenswear, Mixed. Plus one fresh signup that skips onboarding.

## Test matrix

| # | User | Expect |
|---|---|---|
| T1 | Menswear | Feed = `QA men A`, `QA men B`, `QA legacy A`. No `W`, no `U`, no DRAFT |
| T2 | Womenswear | Feed = `QA women A`, `QA legacy A` |
| T3 | Mixed | Feed = all five PUBLISHED, no DRAFT |
| T4 | No onboarding | Feed = all five PUBLISHED (degrades open, not empty) |
| T5 | Menswear | A trend tag used only on `QA women A` is absent from the filter chip row |
| T6 | Menswear | Deep-link `QA women A` by id → detail **opens** (not 404) — asserts plan.md §Decisions |
| T7 | Menswear, all `M` + `legacy` unpublished | Empty state renders; `discovery_feed_empty` fires **once** with `wardrobe_gender: "M"` |
| T8 | Menswear | Season filter with no matches → empty grid, `discovery_feed_empty` does **not** fire |
| T9 | Any | "See on me" from an in-feed outfit still works (≤4 garments — AU-457 D2 unchanged) |
| T10 | Any | Save-to-wardrobe from an outfit item still works |

T9/T10 are regression checks: this feature touched the feed query, not the
try-on or clone paths, and must not have disturbed them.

## Admin-side checks

| # | Expect |
|---|---|
| A1 | Publish button disabled + tooltip on a gender-less DRAFT |
| A2 | Coverage banner names Womenswear when `W` count is 0 and `untagged` is 0 |
| A3 | Clearing gender to "Not set" persists as `null`; badge reads `All` |
| A4 | Setting every outfit to "Not set" restores the full feed for all cohorts (the documented kill-switch) |

## Mixpanel check

`mixpanel-macgie` MCP **failed to connect in the authoring session**
(`AUTH_HEADER_REJECTED`, HTTP 401 — stale bearer token). Either fix that server's
token first, or verify the two events in the Mixpanel UI / via the
`business-analyst` agent:

- `discovery_feed_viewed` shows `wardrobe_gender` on re-focus events.
- `discovery_feed_empty` appears with a `wardrobe_gender` breakdown and **no**
  `null` property values.

Do not sign this phase off on "the code looks right" — the whole point of
phase 06 is observability, and an event that doesn't land in Mixpanel is a
no-op.

## iOS build discipline

`.claude/rules/ios-build-workflow-required.md` applies. Phase 06 is a JS-only
change → **Fast Refresh**. Do not kill Metro, `watchman watch-del-all`,
`pod install`, or `yarn ios:clean` — Metro `:8081`, the Simulator and watchman
are ONE shared machine singleton and the CEO runs several sessions at once.
`yarn ios:doctor` (read-only) first if the bundle looks stale. Escalation ladder,
cheapest first: reload → `yarn start:reset` → (only with explicit confirmation)
`yarn ios:clean`.

## Todo

- [ ] All four umbrella gates green
- [ ] Fixture created through the admin SPA
- [ ] Three cohorts onboarded through the real V05 flow (no hand-edited metadata)
- [ ] T1–T10 pass
- [ ] A1–A4 pass
- [ ] Both analytics events verified landing in Mixpanel
- [ ] No native rebuild, no shared-singleton disruption
- [ ] Report written to `plans/reports/qa-mobile-260912-1450-discovery-gender-filter.md`

## Success criteria

Every row of both matrices passes against a live backend, both events land in
Mixpanel, and no gate was skipped or worked around. A failing test gets fixed
and re-run (`.claude/rules/development-rules.md`) — never silenced, never
xfailed, never "known issue, shipping anyway".

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| Metadata hand-edited to fake a cohort → the real onboarding write path never gets tested | **H**×H | Explicit todo: onboard through the flow. This is the single link the whole feature depends on |
| T7 run by unpublishing outfits and forgetting to re-publish → CEO's board left broken | M×M | Re-publish as the last step of T7; A4 double-checks the board is whole |
| Mixpanel MCP still 401s and the events go unverified | **H**×M | Fall back to the Mixpanel UI or `business-analyst`; do not skip the check |
| Smoke run against mocks because the fixture is fiddly | M×H | Gate 4 is unmockable by construction — the behaviour is a server-side SQL filter |

## Next steps

On green: PR per `.github/PULL_REQUEST_TEMPLATE.md`. Note in the PR that the
Figma/qa-ui/designer rows are N/A with the plan.md §Workflow deviation reason —
do not tick them as passed. File the two spun-off tickets: the
`useDiscoveryOutfits` missing-`offset` cache-key bug (phase 06), and backfilling
a gender onto the legacy published outfits (a CEO curation task).
