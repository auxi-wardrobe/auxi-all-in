# Analytics Tracking — Required For Every New Feature

> **Rule:** When designing or building any new feature, screen, or significant user interaction in the mobile app, Mixpanel tracking events are part of the deliverable. A feature isn't "done" until the events are wired AND the tracking plan doc is updated.

## When this applies

- Any new screen, route, modal, sheet, or bottom-tab
- Any new user-action handler — tap, swipe, gesture, form submit, toggle, picker
- Any new conversion / funnel step (sign-up, save, share, purchase, settle-on-recommendation)
- Any new error / failure surface the user can recover from
- Any change to an existing handler that changes WHEN or WHY the underlying action fires

If you find yourself writing a new `onPress` / `onChange` / `useMutation.onSuccess` / `useFocusEffect`, you are almost certainly looking at a tracking site. Don't skip it.

## When this doesn't apply

- Pure UI / visual changes (animation tuning, color, layout) with no new interaction
- Refactors that preserve behavior
- Internal hooks / utilities with no user-facing trigger
- Backend-only work (FastAPI / `wardrobe-backend`) — backend has its own observability concerns
- `wardrobe-admin` SPA — separate Mixpanel project, separate convention

## Authoritative source of truth

**`auxi/docs/analytics/mixpanel-tracking-plan.md`** — every shipped event lives in §5, every spec'd-but-gap lives in §6, suggested funnels live in §10. Read it before naming a new event. Update it when you ship one.

## Workflow integration

### Design / planning phase

Before implementation, include in the spec or plan:

1. **List the new user interactions** introduced by the feature.
2. **Name each event** — `object_verb`, `snake_case`, **past tense** (`outfit_favorited`, never `favoriteOutfit` or `outfit-favorited`).
3. **Define the properties** — `snake_case` keys, lowercase string values, numbers/booleans unquoted. Omit a property entirely when its value is unknown (never `null` / `undefined` / `""`).
4. **Check for collisions** against the existing taxonomy in §5 — re-use existing names where the action is the same.
5. **State the funnel impact** — which funnel does this event belong to? If it doesn't fit an existing funnel, propose one.

### Implementation phase

- Every `track()` call goes through `src/services/analytics.ts` only. Never call `mixpanel.track` directly.
- Event names are **literal string constants**. No template literals. No `track(\`${verb}_${noun}\`)`. No dynamic names.
- For repeat-suppressed events (e.g. `outfit_recommendation_viewed`), use the existing dedup helper pattern (`trackRecommendationViewedOnce`) or extend it. Don't reinvent.
- **No PII in properties:**
  - URL imports → `url_domain` (hostname only), not the raw URL
  - Free-text user input → segment by `mode: 'custom'` only, **do not** ship the text as a `value` property (truncation is not enough — names, emails, addresses can fit in 100 chars)
  - Errors → sanitized snake_case codes (`invalid_credentials`, `weak_password`, `network_error`), never raw error messages
  - Identifiers → use internal DB ids, never email / phone / social handle
- If the event needs a hook point that doesn't exist yet (no CTA, no save button, no submit step), **don't fake it**. Skip the wiring, log it in tracking plan §6 as a gap with the re-wire condition.

### Doc update (mandatory)

Update `auxi/docs/analytics/mixpanel-tracking-plan.md`:

- New shipped event → add to the matching §5 subsection with `file:line` + properties
- Event spec'd but un-wired due to absent UI/API → add to §6 with the precise condition that would unblock it
- New funnel introduced or extended → mention in §10

## What "done" means

A feature PR is incomplete if any of these are true:

- A new interactive handler ships with no `track()` call and no §6 gap entry
- An event name is dynamic / template-literal'd
- An event property contains free-text user input, raw URL, or other PII
- `auxi/docs/analytics/mixpanel-tracking-plan.md` wasn't updated
- The tracking doesn't fit a funnel and you didn't say why

If you're using a sub-agent (mobile-dev, backend-dev, etc.) to implement, include the tracking requirement in the dispatch prompt. The agent should not have to re-derive the rule from scratch.

## Why

CEO uses Mixpanel funnels to make product calls. Drift between shipped behavior and tracked behavior is the #1 source of decision-debt on this project. The cost of adding a `track()` call inside an existing handler is ~1 minute. The cost of not having the data when you need to read a funnel two months from now is much higher.

## Related

- `auxi/docs/analytics/mixpanel-tracking-plan.md` — the taxonomy
- `auxi/src/services/analytics.ts` — the single integration seam
- `plans/260616-0950-mixpanel-comprehensive-instrumentation/spec.md` — the baseline established 2026-06-16
- `plans/reports/mobile-dev-260616-0950-mixpanel-instrumentation.md` — delivery report covering the baseline rollout
