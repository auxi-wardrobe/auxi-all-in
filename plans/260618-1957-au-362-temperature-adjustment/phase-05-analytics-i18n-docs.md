# Phase 05 — Analytics (6 events) + i18n + Tracking-Plan Doc

**Context:** [plan.md](plan.md) · rule `.claude/rules/analytics-tracking-required.md` · `auxi/src/services/analytics.ts` · doc `auxi/docs/analytics/mixpanel-tracking-plan.md`

## Overview
- **Priority:** P0 (feature is NOT "done" without events + doc update). **Status:** ☐. Folds into Phase 04 wiring.

## Key Insights
- All events go through `analytics.ts` `track(event, props)` (`:136`). Names = literal string constants. Dedup precedent: module-level `Set` (`trackRecommendationViewedOnce`, `:165`).
- No PII: use **bucket keys**, never raw user text; numbers unquoted; omit unknown props.

## Events (ticket §Analytics — use verbatim names for funnel continuity)
| Event | Fires when | Props |
|---|---|---|
| `temperature_modal_opened` | lightbulb → sheet opens | `{ override_active: bool }` |
| `temperature_option_selected` | radio selected | `{ option: bucketKey }` |
| `temperature_apply_clicked` | Apply tapped | `{ option: bucketKey }` |
| `temperature_override_active` | apply success, non-weather bucket | `{ bucket: bucketKey, rep_temp_c: number }` |
| `temperature_override_removed` | apply success, weather selected while override was active | `{ previous_bucket: bucketKey }` |
| `recommendation_generated_by_temperature` | build completes under an active override | `{ bucket: bucketKey, outfit_count: number }` |

- **Convention note:** rule prefers past-tense `object_verb`. `temperature_apply_clicked` is borderline (kept verbatim per ticket; flag to CEO if they'd rather `temperature_applied`). Others fit.
- Suppress duplicate `recommendation_generated_by_temperature` per outfit_hash via the existing dedup `Set` pattern if "Show another" re-emits.

## i18n — add to all 3 locales
`auxi/src/translations/{en-EN,fr-FR,vi-VN}.json` under `home.*`:
`temp_sheet_title`, `temp_sheet_subtitle`, `temp_use_current` (interpolates `{{temp}}`), `temp_28_40`, `temp_10_25`, `temp_0_7`, `temp_-10_0`, `temp_apply_cta`, `temp_cancel_cta`, `temp_error_recommend`, `temp_error_offline`, `temp_override_a11y`, plus a11y labels for the lightbulb (idle/active).

## Files to MODIFY
- `auxi/src/services/analytics.ts` — add 6 typed wrappers (or inline `track('temperature_…', {...})`), optional dedup for the generated event.
- `auxi/src/translations/en-EN.json`, `fr-FR.json`, `vi-VN.json` — keys above (3-locale parity).
- `auxi/docs/analytics/mixpanel-tracking-plan.md` — add the 6 events to §5 with `file:line`; note the temperature funnel in §10.

## Implementation Steps
1. Add event constants/wrappers in `analytics.ts`.
2. Call from Phase-04 transitions (open, select, apply, success-active, success-removed, generated).
3. Add i18n keys (en/fr/vi) — no hardcoded user-facing strings.
4. Update tracking-plan doc §5 + §10.

## Todo
- [ ] 6 events wired through analytics.ts (literal names, no PII)
- [ ] i18n keys in all 3 locales (parity)
- [ ] tracking-plan.md §5 + §10 updated
- [ ] Dedup on generated event if needed

## Success Criteria
Each ticket scenario emits its event with clean props; `mixpanel-tracking-plan.md` reflects all 6; no raw strings in components.

## Funnel impact (§10)
New funnel: `temperature_modal_opened → temperature_apply_clicked → temperature_override_active → recommendation_generated_by_temperature` — validates whether users actually use override vs stay on weather (ticket's stated analytics goal).
