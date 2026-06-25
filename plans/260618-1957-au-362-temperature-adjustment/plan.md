# AU-362 — Outfit Temperature Adjustment & Temperature-Aware Recommendation

- **Ticket:** [AU-362](https://linear.app/duncan-1/issue/AU-362/uac-outfit-temperature-adjustment-and-temperature-aware-outfit) (Auxi, status Todo, Low) · branch `duc2820/au-362-uac-outfit-temperature-adjustment-temperature-aware-outfit`
- **Figma:** [node 3906-8765](https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=3906-8765) — 3 frames: Home(weather) · Outfit Temperature sheet · Home(override)
- **Repos:** `auxi/` (primary). `wardrobe-backend/` optional (Phase 07, deferred).

## Goal
Lightbulb on Home → "Outfit Temperature" bottom sheet of temp ranges. Applying a range re-generates the outfit using a **temperature override** instead of live weather; header swaps the weather icon for an override indicator. "Use current weather" clears the override.

## Key architectural decision — MOBILE-ONLY MVP
Backend `engine_v05` already derives clothing from the **client-sent** `weather.temp_c` (`engine_v05.py` `_climate_bucket`: `>28 HOT · ≥20 WARM · ≥15 MILD · <15 COOL`), and the V05 session cache reuses that temp for `/try_another` ("Show another"). So an override = **send the bucket's representative `temp_c`** in the existing `BuildRecommendationInput.weather.temp_c`. No new endpoint, no schema change, **no API contract change → no tech-lead sign-off needed**. Phase 07 (a semantic `temp_c_override` field + finer cold bands) is an OPTIONAL enhancement, deferred unless Decision D1/D3 require it.

## Decisions to confirm (CEO/product) — see each phase
- **D1 — bucket → temp_c mapping.** Figma buckets (`28–40 · 10–25 · 0–7 · -10–0`) don't align with backend bands and have gaps (nothing 25–28°C, 7–10°C). Plan default: send **midpoint** (`33 · 18 · 4 · -5`). `10–25` spanning COOL→WARM is lossy. *(Phase 02)*
- **D2 — coldest buckets collapse.** `0–7` and `-10–0` both → backend `COOL` (<15) ⇒ identical outfits. Accept as ticket's "same outfit" edge case (MVP) **or** add finer backend cold bands (Phase 07). *(Phase 02/07)*
- **D3 — persistence.** Ticket "Gaps" says *persist for session/day, reset next day*. Plan default: AsyncStorage, date-stamped, expires next calendar day. *(Phase 02)*
- **D4 — override indicator icon + header label.** Need the icon asset from Figma; display the **selected bucket label** (Figma's `10 - 35°C` mock is inconsistent — ignore). *(Phase 01/04)*

## Phases
| # | File | Scope | Status |
|---|------|-------|--------|
| 01 | [phase-01-figma-extraction-and-review.md](phase-01-figma-extraction-and-review.md) | mobile-dev extracts Figma 3906-8765; qa-ui review-extraction PASS (steps 2–3) | ☐ |
| 02 | [phase-02-state-and-bucket-mapping.md](phase-02-state-and-bucket-mapping.md) | `temperatureBuckets.ts` config + `useTemperatureOverride` hook (state, mapping, session/day persistence) | ☐ |
| 03 | [phase-03-temperature-sheet-component.md](phase-03-temperature-sheet-component.md) | `TemperatureOverrideSheet` (Modal clone of ContextChipsModal) — radios, Apply/Cancel, loading, inline error | ☐ |
| 04 | [phase-04-home-integration.md](phase-04-home-integration.md) | Lightbulb trigger, header indicator swap, Apply→refetch, loading/error, concurrency guard, edge cases | ☐ |
| 05 | [phase-05-analytics-i18n-docs.md](phase-05-analytics-i18n-docs.md) | 6 Mixpanel events, i18n in 3 locales, update tracking-plan doc | ☐ |
| 06 | [phase-06-verification-and-pr.md](phase-06-verification-and-pr.md) | token-lint + tsc/lint + qa-ui Compare + **designer gate (6.5)** + qa-mobile smoke + PR | ☐ |
| 07 | [phase-07-optional-backend-override-field.md](phase-07-optional-backend-override-field.md) | OPTIONAL/deferred — `temp_c_override` field + finer cold bands (only if D1/D2/D3 demand) | ☐ |

## Dependencies
01 → (02 ∥ 03) → 04 → 05 → 06. 07 independent (gated by decisions, off the MVP critical path).

## Cross-repo / rule gates (mandatory)
- Figma→RN workflow steps 2–6.5 enforced (extraction → qa-ui review → impl → token-lint → qa-ui Compare → **designer hard gate**).
- Analytics rule: 6 events + `auxi/docs/analytics/mixpanel-tracking-plan.md` updated *(Phase 05)*.
- Design-review rule: `designer` PASS recorded before PR *(Phase 06)*.
