# CEO Mixpanel Dashboard — User Journey Monitor

**Date:** 2026-06-16
**Audience:** CEO (single reader)
**Window:** Last 30 days (rolling)
**Goal:** One Mixpanel board, 8 charts, readable in 30 seconds. Shows whether the funnel Login → Onboarding → Home engagement → Retention is healthy and which step needs attention.
**Source events:** All 85 events from `auxi/docs/analytics/mixpanel-tracking-plan.md` §5 (post 2026-06-16 instrumentation rollout).

## 0. Pre-flight checklist (must be true before charts will be meaningful)

These gate whether the dashboard will show real data. Currently the auxi app is wired but consent-gated, so production data isn't flowing yet.

- [ ] **PROD Mixpanel project + token** in `auxi/src/config/analytics.ts` (`PROD_TOKEN` is empty today)
- [ ] **Consent UI shipped** — mechanism exists (`grantAnalyticsConsent`), but no UI yet → `track()` is a no-op until QA grants consent manually
- [ ] **Simplified ID Merge ON** in Mixpanel project settings (one-way decision; cannot change retroactively)
- [ ] **Lexicon descriptions** added for each event + property listed in §5
- [ ] **Data Standards: enforce snake_case** turned on
- [ ] **Event Approval** turned on (gate any new event additions through review)
- [ ] **Timezone** set to Asia/Saigon (or whatever the CEO reads from)

Once these are true, give it ~1 week of real traffic before reading numbers as anything but a smoke test.

## 1. Reading frame

The board is grouped into **4 rows**, matching the RAE framework (already documented in `mixpanel-tracking-plan.md` §1) + retention:

| Row | Frame | What it answers |
|---|---|---|
| 1 | **Reach** (top of funnel) | Are people entering the app? Where do they come from? |
| 2 | **Activation** | Do they make it through onboarding? |
| 3 | **Engagement** | Once activated, do they hit the value moment? |
| 4 | **Retention** | Do they come back? |

Each chart has a **green/amber/red threshold** so the CEO can read "good/bad" at glance without computing ratios.

## 2. Board layout (8 charts)

```
┌──────────────────────────┬──────────────────────────────────────┐
│ 1. New users (30d) #     │ 2. Sign-up funnel  (with method)    │
│    Big number + Δ vs 30d │                                      │
├──────────────────────────┴──────────────────────────────────────┤
│ 3. Onboarding funnel  (8 steps end-to-end)                      │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│ 4. Onboarding step drop-off  (bar chart by step_name)           │
│                                                                  │
├──────────────────────────┬──────────────────────────────────────┤
│ 5. Value-moment rate %   │ 6. Reco engagement funnel           │
│    (activated → favorite)│    (recommendation_viewed→favorited)│
├──────────────────────────┼──────────────────────────────────────┤
│ 7. Try-on adoption %     │ 8. D7 retention cohort table        │
│    (activated → try_on)  │    (favorite → return within 7d)    │
└──────────────────────────┴──────────────────────────────────────┘
```

## 3. Charts (detail)

### Chart 1 — New users (30d)

| Field | Value |
|---|---|
| **Question** | How many new accounts in the last 30 days? Is growth accelerating or decelerating? |
| **Insight type** | Insights → "Number" view |
| **Event** | `sign_up_completed` |
| **Aggregation** | Unique users |
| **Time** | Last 30 days |
| **Compare** | vs previous 30 days (show `% change`) |
| **Breakdown** | none |
| **Filter** | none |
| **Target / threshold** | Set after 2 weeks of real traffic (baseline). Alert: -20% WoW. |

### Chart 2 — Sign-up funnel

| Field | Value |
|---|---|
| **Question** | Of users who start sign-up, what % complete it? Where do they fall off? |
| **Insight type** | Funnels |
| **Steps** | 1) `sign_up_started` → 2) `sign_up_submitted` → 3) `sign_up_completed` |
| **Breakdown** | `method` (`email` / `google` / `apple`) |
| **Time** | Last 30 days |
| **Conversion window** | 1 day (a sign-up that takes longer than that is a different intent) |
| **Target** | **Green ≥ 70%** completion across all methods · **Amber 50-70%** · **Red < 50%** |
| **Interpretation** | If `sign_up_started → sign_up_submitted` drop is big → password creation friction. If `sign_up_submitted → sign_up_completed` drop → email verification friction. |

### Chart 3 — Onboarding funnel (end-to-end)

| Field | Value |
|---|---|
| **Question** | Of new users, what % complete onboarding? Which step loses them? |
| **Insight type** | Funnels |
| **Steps** | 1) `sign_up_completed` → 2) `welcome_continued` → 3) `location_permission_granted` OR `location_permission_denied` (group as "permission resolved") → 4) `wardrobe_direction_selected` → 5) `fit_preference_selected` → 6) `style_selected` (any) → 7) `onboarding_generated` → 8) `onboarding_completed` |
| **Breakdown** | none (keep clean for CEO read) |
| **Time** | Last 30 days |
| **Conversion window** | 1 day |
| **Target** | **Green ≥ 80%** end-to-end · **Amber 60-80%** · **Red < 60%** |
| **Interpretation** | Each step's drop is visible. Permission step is historically the biggest drop on mobile apps — watch it. |

### Chart 4 — Onboarding step drop-off (bar)

| Field | Value |
|---|---|
| **Question** | At which onboarding step do users abandon? (faster read than Chart 3) |
| **Insight type** | Insights → Bar chart |
| **Event** | `onboarding_step_viewed` |
| **Aggregation** | Unique users |
| **Breakdown** | `step_name` |
| **Sort** | by `step_index` ascending (so bars read left-to-right in step order) |
| **Time** | Last 30 days |
| **Read pattern** | Bars should monotonically decrease left → right. A **gap > 15%** between adjacent bars = a drop-off worth investigating. |

### Chart 5 — Value-moment rate (%)

| Field | Value |
|---|---|
| **Question** | What % of activated users hit the value moment (favorite an outfit) within 7 days? |
| **Insight type** | Funnels |
| **Steps** | 1) `onboarding_completed` → 2) `outfit_favorited` |
| **Conversion window** | 7 days |
| **Time** | Last 30 days |
| **Breakdown** | none (or `wardrobe_direction` if you want to see which cohort lands hardest) |
| **Target** | **Green ≥ 40%** D7 value-moment rate · **Amber 25-40%** · **Red < 25%** |
| **Interpretation** | This is the single most important KPI on the board. If this drops, the product isn't landing — investigate Chart 6 (reco quality) next. |

### Chart 6 — Recommendation engagement funnel

| Field | Value |
|---|---|
| **Question** | Of outfits served, what % get favorited? Are recommendations landing? |
| **Insight type** | Funnels |
| **Steps** | 1) `outfit_recommendation_viewed` → 2) `outfit_favorited` |
| **Conversion window** | 30 minutes (same session) |
| **Time** | Last 30 days |
| **Breakdown** | `source` (`feed` vs `refine`) — does refine improve the favorite rate? |
| **Target** | **Green 5-15%** per-outfit favorite rate · **Amber 3-5%** · **Red < 3%** · **Suspicious ≥ 30%** (likely over-count) |
| **Interpretation** | < 3% = recommendations not landing, raise to product. ≥ 30% = check the `outfit_recommendation_viewed` dedup helper is wired correctly. |

### Chart 7 — Try-on adoption (%)

| Field | Value |
|---|---|
| **Question** | Of activated users, what % start a try-on? Is the killer feature being discovered? |
| **Insight type** | Funnels |
| **Steps** | 1) `onboarding_completed` → 2) `try_on_started` |
| **Conversion window** | 14 days (try-on requires body photos which takes effort — give it time) |
| **Time** | Last 30 days |
| **Breakdown** | none |
| **Target** | **Green ≥ 25%** · **Amber 10-25%** · **Red < 10%** |
| **Interpretation** | Low = the entry point (favourite → "See on me") is buried. Currently the only entry is via favourites; once a Home-level "See on me" CTA ships (gap §6.2 of tracking plan), this should rise. |

### Chart 8 — D7 retention cohort

| Field | Value |
|---|---|
| **Question** | Of users who hit the value moment, what % come back the next 7 days? |
| **Insight type** | Retention (cohort table) |
| **Cohort definition** | "Did" `outfit_favorited` |
| **Return event** | "Did" any of: `outfit_favorited` OR `try_on_started` OR `outfit_recommendation_viewed` (engagement signals, not just session opens) |
| **Bucket** | Daily, 7-day return window |
| **Time** | Last 30 days (cohort start), 7 days post (return) |
| **Target** | **Green D7 ≥ 30%** · **Amber 15-30%** · **Red < 15%** |
| **Interpretation** | Read across the row: D1 should be ~50-60%, D7 ~25-35%, plateau by D14. A flat-line near zero at D7 = product doesn't stick. |

## 4. Mixpanel UI — click-by-click (per chart)

All steps assume you're logged into mixpanel.com → auxi (EU) project → **Dashboards** section. Create a new board called **"Auxi · CEO View"** before adding charts.

### Build the board

1. **Dashboards** (left nav) → **+ New Board** → name `Auxi · CEO View` → set Time → `Last 30 days` → Save.
2. Open the new board → **+ Add Chart** for each chart below.

### Chart 1 — New users (30d) · Number

1. **+ Add Chart** → **Insights**.
2. Event picker (left) → search `sign_up_completed` → click.
3. Set measurement to **Unique users**.
4. Right rail: View → **Number**.
5. Compare → toggle **Compare to previous period** (30d prior).
6. Title → `New users (30d)`.
7. **Save to Auxi · CEO View** → place in Row 1 left.

### Chart 2 — Sign-up funnel

1. **+ Add Chart** → **Funnels**.
2. Step 1: `sign_up_started`. Step 2: `sign_up_submitted`. Step 3: `sign_up_completed`.
3. Conversion window (top right of funnel builder) → **1 day**.
4. Breakdown → property → `method`.
5. Time → Last 30 days.
6. Title → `Sign-up funnel · by method`.
7. Save → Row 1 right.

### Chart 3 — Onboarding funnel

1. **+ Add Chart** → **Funnels**.
2. Steps in order:
   - `sign_up_completed`
   - `welcome_continued`
   - **Group**: `location_permission_granted` **OR** `location_permission_denied` (click "+" inside the step to add an OR'd event)
   - `wardrobe_direction_selected`
   - `fit_preference_selected`
   - `style_selected`
   - `onboarding_generated`
   - `onboarding_completed`
3. Conversion window → 1 day.
4. No breakdown.
5. Title → `Onboarding funnel (end-to-end)`.
6. Save → Row 2 (full width).

### Chart 4 — Onboarding step drop-off

1. **+ Add Chart** → **Insights**.
2. Event → `onboarding_step_viewed`. Measurement → Unique users.
3. Breakdown → property → `step_name`.
4. View → **Bar chart**.
5. Sort → set to `step_index` ascending. (If Mixpanel UI doesn't allow custom sort on a chart, sort alphabetically and rename steps in Lexicon to start with index digits — e.g., `01_welcome`, `02_location_permission` — for free left-to-right order.)
6. Title → `Onboarding step drop-off`.
7. Save → Row 2 below funnel.

### Chart 5 — Value-moment rate

1. **+ Add Chart** → **Funnels**.
2. Step 1: `onboarding_completed`. Step 2: `outfit_favorited`.
3. Conversion window → **7 days**.
4. View → **Number** (overall conversion %).
5. Title → `Value-moment rate (7d post-activation)`.
6. Save → Row 3 left.

### Chart 6 — Recommendation engagement funnel

1. **+ Add Chart** → **Funnels**.
2. Step 1: `outfit_recommendation_viewed`. Step 2: `outfit_favorited`.
3. Conversion window → **30 minutes** (top-right of funnel builder → custom → 30m).
4. Breakdown → property on step 1 → `source`.
5. Title → `Reco → favorite (by source)`.
6. Save → Row 3 right.

### Chart 7 — Try-on adoption

1. **+ Add Chart** → **Funnels**.
2. Step 1: `onboarding_completed`. Step 2: `try_on_started`.
3. Conversion window → **14 days**.
4. View → **Number**.
5. Title → `Try-on adoption (14d post-activation)`.
6. Save → Row 4 left.

### Chart 8 — D7 retention cohort

1. **+ Add Chart** → **Retention**.
2. **Cohort event** → `outfit_favorited`.
3. **Return event** → add three with OR: `outfit_favorited`, `try_on_started`, `outfit_recommendation_viewed`.
4. Period → **Day** (bucket).
5. Return window → 7 periods.
6. Time → Last 30 days.
7. Title → `D7 retention · post-value-moment`.
8. Save → Row 4 right.

### Polish the board

- For each chart, set the colored threshold annotation (Mixpanel: **chart → "..." → Color thresholds**) per the green/amber/red ranges in §3.
- Set the **board default time window** to "Last 30 days" so individual charts inherit (override per chart only if explicitly different — Chart 1 compare-to-previous still works on top of this).
- Pin board to favorites for the CEO's account.
- Optional: enable **Email digest weekly** (Monday 9am) so the CEO gets a snapshot in their inbox without opening Mixpanel.

## 5. How the CEO reads this board (30-second routine)

1. **Glance Row 1** — Is the new-user count moving the right way? (Number + Δ tells the story.)
2. **Glance Row 2** — Is the bar chart's left-to-right slope steep? Any gap > 15% between adjacent bars is a step worth fixing.
3. **Glance Row 3** — Are the value-moment number and the reco-favorite rate green? Red on either means the recommendation engine isn't landing.
4. **Glance Row 4** — Is D7 retention ≥ 30%? If no, product doesn't stick yet.

Total time: ≤ 30 seconds. If everything is green, close the tab. If anything is red, screenshot it and ping the product team.

## 6. What's not on this board (intentional)

- Mood-feedback funnel — too detailed for CEO view. Belongs on a future Product board.
- Refine chip distribution — same.
- Wardrobe-grow funnel (item-add) — useful for the wardrobe team, not CEO.
- Settings-tab events — debugging / support team concern, not CEO.
- Sign-in funnel (returning user) — folded into "new users" + retention. Add a dedicated chart only if churn-back-in becomes a thesis.
- `screen_viewed` heatmap — interesting for product design, not CEO.

These all have events shipping today; just not surfaced on this board. A separate "Product Deep-Dive" board can be planned later if/when needed.

## 7. Refresh + alert cadence

| Cadence | Action |
|---|---|
| **Daily** | Mixpanel computes; no manual refresh needed. |
| **Weekly Monday 9am** | Mixpanel email digest sends a snapshot PDF to CEO. |
| **Monthly review** | Walk the board with product + dev. Adjust thresholds based on the last 30 days. |
| **Alert** | Set Slack alert (Mixpanel → Alerts) on Chart 5 dropping below 25% over 7d. The other charts: visual check on the weekly digest is enough. |

## 8. Iteration roadmap (not in this PR)

Once the CEO board is stable and read regularly (~1 month from go-live), add:

- **Cohort by acquisition source** — when paid marketing starts, segment Chart 5 by acquisition channel
- **Mode-chip engagement** (once AU-221 mode-selector UI ships) — see if Safe/Power/Creative chips correlate with favorite rate
- **Try-on outcome funnel** — `try_on_completed → try_on_outcome_saved → try_on_outcome_shared` (when save/share UI ships per AU-346)
- **Churn predictor** — users who hit value moment then go silent for 14 days; trigger re-engagement push

## 9. Setup time estimate

- Mixpanel project + token + ID merge + Lexicon (one-time): **2-3 hours** ops work
- Build the 8 charts in UI (this plan): **45-60 minutes** following click-by-click
- Threshold colors + alerts: **20 minutes**
- Weekly digest setup: **5 minutes**

**Total: ~half a day end-to-end**, assuming consent UI is already shipped and there's at least 7 days of real traffic.

## 10. Open questions

1. **Consent UI shape** — first-run modal or Settings toggle? Affects what % of events actually land (a modal blocks all flows until answered; a toggle defaults off, meaning most users will be silent). Product decision pending.
2. **PROD token** — who creates the prod Mixpanel project + pastes token into `auxi/src/config/analytics.ts`? Devops or me as Mobile dev? Either way, blocker until done.
3. **Sign-in funnel for returning users** — worth a chart on this CEO board, or strictly Product-team concern? Currently not included.
4. **Push retention vs in-product retention** — Chart 8 measures in-product return. If push notifications drive comebacks, we'd want a separate "open-from-push" event (not currently tracked). Add to backlog?
5. **CEO's preferred Slack channel for alerts** — where should the Chart-5-red alert post? `#exec` / `#product` / DM?
6. **Mobile platform split (iOS vs Android)** — the super-property `platform` is set. Worth a top-level chart breakdown, or fold into the existing charts as filter-on-demand? Current plan: filter-on-demand to keep board clean.
