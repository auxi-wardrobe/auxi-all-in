---
phase: 4
title: Mobile Context Inputs + Why UI + Analytics
status: planned
priority: P1
repos: [auxi]
dependencies: [1, 3]
---

# Phase 4: Mobile Context Inputs + Why UI + Analytics

## Overview

The mobile surface for both wedges: let the user set the manual context P1 can't sense
(mobility / activity / duration) via compact chips, and render P3's `explanation.factors[]`
as an expandable **"why"** affordance on the outfit card. Weather is auto (P1 `weatherService`);
these chips add the human context. Follows the Figma→RN + designer gate + analytics rules.

## Requirements

Functional:
- **Context chips** (reuse the existing `ContextChipsModal` pattern — same one MoodFeedbackSheet cloned; DON'T invent a new primitive):
  - `mobility`: walking / motorbike / car / transit
  - `activity`: office / presentation / wedding / cafe / date / travel / gym / casual
  - `duration`: short / full day / day→night
  - Optional + sticky per session; sensible default = unset (engine treats unset as no-op). Remember last choice locally (AsyncStorage), not sent as PII.
- Selecting chips re-issues the recommendation build with the enriched `intent` (P1 contract).
- **Why affordance** on the outfit card: collapsed shows `explanation.headline`; tap expands to the ranked `factors[]` (icon per `kind` + `text`). Tolerate missing `explanation` (old backend / cold-start → show headline only or nothing). Theme tokens only (no hex — `auxi-lint-tokens.sh` gate).
- i18n en/vi/fr for chip labels + factor-kind icons/labels (factor `text` itself is server-rendered — do not re-translate server copy; display as-is).

Non-functional:
- No layout shift when `explanation` absent; graceful when `factors:[]`.
- Accessibility: chips + why-toggle are real touch targets (≥44pt), VoiceOver labels (qa-ux gate).

## Analytics (REQUIRED — `.claude/rules/analytics-tracking-required.md`)

All via `src/services/analytics.ts`, literal names, snake_case, past tense, no PII:
- `context_set` — props: `mobility`, `activity`, `duration` (bounded enums only; omit unset). Fires on chip change that triggers a rebuild.
- `outfit_explanation_expanded` — props: `factor_kinds` (array of bounded kinds shown), `outfit_position`. NO factor `text` (could carry context specifics) — kinds only.
- Update `auxi/docs/analytics/mixpanel-tracking-plan.md` §5 (shipped) with both events + `file:line`; note funnel impact (§10) — feeds the "context → wear" conversion funnel.

## Related Code Files

- Modify: recommendation/home screen container (grep `auxi/src/screens/**` for the V05 build call site) — mount context chips, pass ctx.
- Reuse: `auxi/src/components/**/ContextChipsModal*` (or the shared chip grid MoodFeedbackSheet used) — new config, not new component.
- Create: `auxi/src/components/**/OutfitWhy*.tsx` — collapsed headline + expandable factor list (theme tokens, small, < 200 lines).
- Modify: outfit card component — slot the Why affordance.
- Modify: `auxi/src/services/*recommendation*.ts` — send context; type the `explanation` response.
- Modify: `auxi/src/services/analytics.ts` (+ event constants) — add the two events.
- Modify: i18n `en/vi/fr` — chip + factor-kind labels.
- Modify: `auxi/docs/analytics/mixpanel-tracking-plan.md`.

## Implementation Steps

1. **Types.** Add `explanation` + context fields to the RN recommendation types (match P1/P3 contract).
2. **Context chips.** Configure the existing chip modal/grid for mobility/activity/duration; persist last choice (AsyncStorage); on change → rebuild.
3. **Why UI.** `OutfitWhy` — headline collapsed, factors expanded; icon per kind; absent/empty tolerant; theme tokens only.
4. **Analytics.** Wire `context_set` + `outfit_explanation_expanded` through `analytics.ts`; bounded props only.
5. **i18n + lint.** en/vi/fr labels; `auxi-lint-tokens.sh` clean; `tsc --noEmit` + `yarn lint`.
6. **Docs.** Update tracking plan §5/§10.

## Success Criteria

- [ ] Setting `motorbike + full day` rebuilds and the returned outfit's why-panel cites comfort/weather.
- [ ] Why panel: collapsed headline, expand shows ≤3 factors with kind icons; absent `explanation` → no crash, no layout jump.
- [ ] `context_set` + `outfit_explanation_expanded` fire with bounded props, no PII, no free-text.
- [ ] Tracking plan updated (§5 + §10); event names literal, past tense.
- [ ] `auxi-lint-tokens.sh` clean; `tsc --noEmit` + `yarn lint` green; en/vi/fr present.
- [ ] Designer design-review PASS recorded (`auxi/docs/design-reviews/`) — new card affordance + chips (step 6.5 hard gate).

## Risk Assessment

- **Chip fatigue / friction** (adds a step before recommendation). Mitigation: all optional, sticky default, unset = no-op; never block the build on context.
- **Server copy re-translation drift.** Mitigation: factor `text` rendered server-side, displayed as-is; only kind labels/icons are client i18n.
- **Design drift.** Mitigation: reuse existing chip primitive; designer gate before PR.
- **PII via analytics.** Mitigation: bounded enums + kinds only; never ship activity/text specifics beyond the enum.
