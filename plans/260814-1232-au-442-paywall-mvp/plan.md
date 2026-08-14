---
title: "AU-442 — Soft Paywall MVP (quota-triggered upgrade sheet)"
description: "Show a bottom sheet when a free user crosses a per-feature usage threshold; Upgrade → Notify-me page; Mixpanel-only demand gauge, no real IAP."
status: pending
priority: P2
effort: 14h
branch: kai/feat/au-442-paywall-mvp
tags: [monetization, paywall, mobile, backend, analytics, figma]
created: 2026-08-14
---

# AU-442 — Soft Paywall MVP

**Goal:** measure demand for Macgie+ by showing a *fake* paywall bottom sheet when a free user
crosses one of three usage thresholds, then a "Notify me" follow-up page. Mixpanel is the
deliverable — no StoreKit, no RevenueCat purchase, no entitlement enforcement.

**Thresholds (free tier, `used >= limit`):** See-on-me ≥ 2 · wardrobe items ≥ 51 · enhance-photo ≥ 31.
**Reset cadence (user-corrected 2026-08-14):** See-on-me and enhance-photo reset **daily** (calendar
day, UTC) — matches the Figma sheet copy ("today's limit" / "come back tomorrow"). Wardrobe items is a
**lifetime storage cap, never reset**.
**Counting rule:** a cache-hit try-on re-serve (no new AI render) does **NOT** count toward the
See-on-me quota — only genuine renders do.

**Figma:** https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Macgie?node-id=4444-26066&m=dev

## Headline research finding (drives the whole design)

Two of the three counters have **durable server-side sources today**; none is available to the
client. The existing `ai:daily:*` Redis cap (`wardrobe-backend/deps/ai_usage.py:20`) is an
*ephemeral, fail-open* spend guard and is **not** reusable as a durable per-feature free-tier quota
(no premium bypass, no per-feature limits, 2-day TTL) — even though it happens to share the daily
granularity now. → build ONE read-only endpoint `GET /api/me/usage` that computes all three from
existing tables and returns the limits as config.
Full source-by-source trace in [phase-01](./phase-01-backend-usage-endpoint.md#key-insights).

**Post-clarification schema delta:** the daily-reset requirement means `beautify_attempts`
(a lifetime running counter, no per-event timestamp) can no longer answer "uses today" —
phase 01 now adds a small `beautify_attempt_events` log table. See-on-me stays on `tryon_images`
(already timestamped) but gains a `cache_hit` column so re-serves can be excluded. Wardrobe items
is untouched (still a plain lifetime `COUNT`, never reset).

**Also found:** a real RevenueCat paywall already exists but ships dark
(`auxi/src/screens/UpgradeScreen.tsx:165`, kill-switch `auxi/src/screens/SettingsScreen.tsx:69`).
AU-442 must NOT route into it — the sheet's "Upgrade" goes to the new Notify-me page.

## Phases

| # | Phase | Owner | Effort | Status | Blocked by |
|---|---|---|---|---|---|
| 01 | [Backend usage endpoint](./phase-01-backend-usage-endpoint.md) | backend-dev (+ tech-lead sign-off) | 3h | pending | — |
| 02 | [Figma extraction + UI](./phase-02-figma-extraction-and-ui.md) | mobile-dev | 5h | pending | — (parallel with 01) |
| 03 | [Trigger wiring + analytics](./phase-03-trigger-wiring-and-analytics.md) | mobile-dev | 4h | pending | 01, 02 |
| 04 | [QA + design gates](./phase-04-qa-and-gates.md) | qa-ui / designer / qa-mobile | 2h | pending | 03 |

Phases 01 and 02 are file-disjoint (backend vs `auxi/`) → run in parallel.

## Key decisions locked here

1. **Server-computed quota.** One endpoint, three counters, limits in env config. Rationale + the
   rejected alternatives (client-side AsyncStorage counters; three ad-hoc endpoints) in phase-01.
2. **Trigger fires AFTER a successful action**, at the existing success-analytics site — never as a
   pre-flight block. The MVP paywall must not prevent anyone from using the app.
3. **One reusable gate**, mirroring `useAiLimitGate` + `AiLimitSheet`
   (`auxi/src/hooks/useAiLimitGate.ts:40`) — not three bespoke sheets.
4. **"Upgrade" navigates to a new `NotifyMe` screen**, not `UpgradeScreen`. The real paywall stays
   behind its kill-switch.
5. ~~Once per feature per app session~~ **(reversed 2026-08-14, user-corrected):
   shows every time the trigger fires while `limit_reached` is true for that
   feature — no per-session suppression.** The original "survey, not a nag"
   framing turned out to undercount real demand signal; see
   `auxi/src/services/usageLimit.ts`.

## Cross-repo contract

Phase 01 adds a public `/api/*` endpoint → **tech-lead sign-off required** before mobile consumes
it, and `wardrobe-backend/API_DOCUMENTATION.md` must be updated in the same PR (umbrella
CLAUDE.md "Two-Repo Contract").

## Rollback

Ship behind `PAYWALL_MVP_ENABLED` (mobile const, same pattern as `SHOW_UPGRADE_PAYWALL`). Flip false
→ no sheet, no navigation, endpoint goes unused but harmless. Backend endpoint is read-only and
additive; deleting it breaks nothing else.

## Unresolved questions

Operator semantics, cache-hit counting, and reset cadence (corrected to daily) are now **locked**
(see top of this file).
Remaining open items: is `NotifyMe` a full screen or a sheet state (depends on the Figma frame,
phase 02 to resolve/escalate); should the sheet also be reachable passively from Settings (assumed
no — strictly threshold-triggered).
