---
phase: 5
title: Mobile Sync
status: completed
priority: P2
effort: 0.5d
dependencies:
  - 4
---

# Phase 5: Mobile Sync

## Overview
`mobile-dev` syncs `auxi/` to the deprecated-axis contract. Expected tiny: mobile never
built axis chips; `axis` is only sent when a caller passes it (HomeScreen does not).
Admin tester (`wardrobe-admin`) sends `axis: null` → no change needed there.

## Requirements
- Functional: app never sends `axis`; tolerates `variation_axis: null`; no UI regression
  on Home swipe / "Show another" / refine / mode change flows.
- Non-functional: `npx tsc --noEmit` + `yarn lint` clean; no new deps.

## Architecture
Contract source: `wardrobe-backend/docs/v05-try-another-mobile-contract.md` (updated in
Phase 4). Changes confined to `auxi/src/services/v05Api.ts` types + dead-code removal.

## Related Code Files
- Modify: `auxi/src/services/v05Api.ts`
  - ~L345-360: mark `V05_VARIATION_AXES` / `VariationAxis` deprecated; delete if no
    importer outside the service (grep first)
  - ~L653-660: drop `axis` from `TryAnotherInput` construction (`params.axis` plumbing)
  - Types: `TryAnotherResponse.variation_axis` → `VariationAxis | null` (or remove if
    unread — grep `variation_axis` across `auxi/src/`)
- Verify-only: `auxi/src/screens/HomeScreen.tsx` (no axis usage expected)

## Implementation Steps
1. Grep `axis|variation_axis|V05_VARIATION_AXES` in `auxi/src/` — inventory readers/senders.
2. Remove sender plumbing + deprecate/delete types per inventory.
3. `cd auxi && npx tsc --noEmit && yarn lint` (baseline `_HomeScreen.tsx` noise allowed).
4. Smoke vs real local backend on :5001 (umbrella gate — no mocks): cold start 1 build,
   3+ swipes hit try_another, each outfit visibly different from all prior, no crash on
   `variation_axis: null`. Hand to `qa-mobile` for sim verify.

## Success Criteria
- [ ] No `axis` field in any outgoing try_another payload (network inspect)
- [ ] tsc + lint clean; qa-mobile smoke pass ID recorded
- [ ] Follow-up filed if any unexpected `variation_axis` reader was found (blocks the
      Phase 4 field-removal follow-up)

## Risk Assessment
- Hidden reader of `variation_axis` in UI copy/telemetry → step 1 grep catches; field
  stays nullable until follow-up confirms zero readers.
