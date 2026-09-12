---
title: "Discovery gender targeting — admin picks M/W/U, feed filters by onboarding direction"
description: "Adds discovery_outfits.gender; the public feed filters it against the user's persisted user_metadata.wardrobe_direction using the AU-305 canonical rule. Admin SPA gains a gender picker + coverage warning."
status: in-progress
priority: P2
effort: 9h
branch: claude/optimistic-tesla-kny91x
tags: [discovery, gender, au-457-followup, cross-repo, backend, mobile, admin-spa]
created: 2026-09-12
---

# Discovery gender targeting

Admin tags each Discovery outfit `M | W | U`. A user who onboarded as Menswear
sees only `M` outfits; Womenswear only `W`; Mixed sees all. Builds on AU-457
(`plans/260827-2205-au-457-discovery/`), which shipped Discovery without any
gender dimension.

## Verified facts this plan rests on (do not re-derive)

| Fact | Evidence |
|---|---|
| Onboarding direction IS persisted server-side | `routers/v05_onboarding.py` writes `user_metadata["wardrobe_direction"]` = `Menswear\|Womenswear\|Mixed` + commits. Read back by `services/admin_user_recommendation_profile.py::_extract_onboarding` |
| `users.gender` is a DEAD column — never use it | prod values `{NULL×13, MASCULINE×1, UNISEX×1, "male"×1}`; engine keys on the `M\|W\|U` payload (`plans/reports/backend-dev-260531-1439-v05-dress-blastradius.md:52`) |
| The gender visibility rule already exists and is STRICT | `utils/gender_scoring.py::is_item_visible_to_wardrobe` (AU-305): `M`→item must carry `M`; `W`→must carry `W`; `U`→union of any valid tag; unknown pref→no filter |
| `is_item_visible_to_wardrobe` normalizes the onboarding vocabulary directly | `_PREF_TO_WARDROBE_GENDER` maps `MENSWEAR→M`, `WOMENSWEAR→W`, `MIXED→U` |
| Alembic head | `mergediscdflt` (revises `clonesrc1a2b` + `defaultitem1a2`). **Re-verify with `alembic heads` before writing the migration** — this is the documented two-heads trap |
| Item cap is 1..4 | `MAX_TRYON_GARMENTS` via `services/discovery_admin_service.py` |

WAR-V05-FU-05 ("persist wardrobe_direction on User") is **not a blocker** — its
premise is stale. The metadata write landed with the onboarding-picks-persistence
fix. No User model change, no User migration.

## Resolved decisions (CEO, 2026-09-12)

1. **Strict per-gender, not inclusive.** A Menswear user does NOT see `U`
   outfits. This matches AU-305 verbatim, so the rule is reused, not forked.
2. **`U` (Mixed) is a union wardrobe** — sees `M`, `W` and `U`. This is AU-305's
   explicit carve-out ("strict `U ∈ tags` would empty whole categories") and is
   NOT re-litigated here. Consequence the CEO accepted: strictness is
   asymmetric — it bites M and W users, never Mixed users.
3. **Server-side derivation.** The client sends no gender. Zero mobile service
   change; the filter cannot be spoofed or lost on reinstall.
4. **No user-facing override chip.** Feed is implicitly filtered. No new UI on
   the mobile side, so no designer 6.5 gate (see §Workflow deviation).

## Decisions this plan makes (flagged for CEO reversal)

- **`gender IS NULL` = visible to everyone.** Mirrors `season` NULL = all-season
  in the same model. Chosen because AU-305's "empty tags are never visible"
  applied to NULL here would blank the entire live feed for every onboarded user
  the moment the migration lands. Publishing a NEW outfit requires a gender
  (phase 03 gate), so NULL only ever means "legacy row". See phase-01 §Risk.
- **The deep-link detail route is NOT gender-filtered.** `GET
  /api/discovery/outfits/{id}` resolves regardless of the viewer's direction. A
  user who deliberately taps a shared link gets the outfit; filtering is a feed
  curation concern, not access control. 404-ing it would break the social-share
  feature AU-457 exists for. The CEO asked for "discovery page" filtering only.
- **`GET /api/discovery/trend-tags` IS gender-filtered.** Otherwise the chip row
  offers tags that return an empty grid for this user.

## Phases

| # | Phase | Repo | Owner | Effort | Blocked by | Status |
|---|---|---|---|---|---|---|
| 01 | [Model + migration + rule helper](phase-01-backend-model-migration.md) | backend | backend-dev | 1.5h | — | **done** `44e5109` |
| 02 | [Feed filter (repo/service/router)](phase-02-backend-feed-filter.md) | backend | backend-dev → tech-lead | 2h | 01 | **done** `44e5109` · tech-lead sign-off OUTSTANDING |
| 03 | [Admin API + publish gate + API doc](phase-03-backend-admin-api.md) | backend | backend-dev | 1.5h | 01 | **done** `44e5109` |
| 04 | [Backend tests](phase-04-backend-tests.md) | backend | tester | 1.5h | 02, 03 | **done** `44e5109` — 1837 pass, 0 regressions |
| 05 | [Admin SPA picker + coverage badge](phase-05-admin-spa.md) | admin SPA | backend-dev | 1.5h | 03 | **done** `717bee0` |
| 06 | [Mobile analytics + tracking doc](phase-06-mobile-analytics.md) | auxi | mobile-dev | 1h | 02 signed off | **done** `df361c0` |
| 07 | [Verification gates](phase-07-verification.md) | both | qa-mobile | 1h | 04, 05, 06 | **BLOCKED** — needs simulator + live backend + working Mixpanel MCP |

**Delivery report:** `plans/reports/delivery-260912-1450-discovery-gender-filter.md`

**Shipped deviation:** Mixed is a **union** wardrobe (sees M/W/U), not strict
as answered — AU-305 already resolved this case in code and forking it would
leave two contradictory gender rules. One-line revert documented in the
report. M and W remain strict, as asked.

Parallel: 02 ∥ 03 (after 01). 05 ∥ 06 (after their blockers). 04 after 02+03.

## Cross-repo contract gate

Phase 02 changes the `GET /api/discovery/outfits` response envelope (adds
`applied_gender`) and its filtering behaviour. Per root `CLAUDE.md`
"Two-Repo Contract": backend updates `API_DOCUMENTATION.md` (phase 03),
**tech-lead signs off before phase 06 starts**.

## Workflow deviation — READ FIRST

Root `CLAUDE.md` mandates the Figma→RN gate chain. This plan ships **no new
mobile UI** (decision 4 — filtering is invisible; the existing
`DiscoveryFeedStates` empty state already covers a zero-result feed), so
`figma-design-extraction` / qa-ui Compare / designer 6.5 do not apply
(`.claude/rules/design-review-required.md` §"When this doesn't apply" — no
visual surface). The admin SPA is explicitly outside the auxi design system.
Phase 06 is analytics-only. If phase 06 grows a visual element, the gate chain
re-applies.

## Content-coverage risk (the real product risk of strict filtering)

Strict `M`/`W` means a cohort with no matching published outfits gets an **empty
Discovery feed**, silently. With 100% of today's outfits landing on NULL
(=universal) nothing breaks on day one, but the first `W`-only curation batch
blanks Discovery for every Menswear user. Mitigations, all in scope:

- Admin list page shows a per-gender PUBLISHED count + warns when any of M/W/U
  is zero (phase 05).
- `discovery_feed_empty` analytics event fires on a zero-result unfiltered feed,
  carrying `wardrobe_gender` (phase 06) — makes the blackout visible in Mixpanel
  instead of in a support ticket.

## Release order

backend 01→03 deploy → admin 05 deploy → CEO tags existing outfits → mobile 06
ships. Runtime kill-switch: set every outfit's `gender` to NULL (universal) via
the admin SPA — no deploy needed.

## Out of scope

- Backfilling a gender onto the existing published outfits (a CEO curation task,
  not code — the migration deliberately leaves them NULL/universal).
- Any change to `users.gender` or to WAR-V05-FU-05.
- A curated trend-tag vocabulary (still free-form, unchanged from AU-457).
- Gender-filtering the deep-link detail route (see §Decisions).
