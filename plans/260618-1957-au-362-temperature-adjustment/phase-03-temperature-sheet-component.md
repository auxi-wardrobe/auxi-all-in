# Phase 03 — TemperatureOverrideSheet Component

**Context:** [plan.md](plan.md) · pattern `auxi/src/components/features/ContextChipsModal.tsx` · skill `figma-to-rn-workflow`

## Overview
- **Priority:** P0. **Status:** ☐. **Depends on:** Phase 01 PASS (+ Phase 02 config for bucket list).
- Presentational bottom sheet. Owns its open/close animation + local pending selection; receives buckets + active key, emits `onApply(bucketKey)` / `onCancel`.

## Key Insights
- App uses **RN `Modal` + `Animated.View` slide-up**, NOT `@gorhom/bottom-sheet`. Clone `ContextChipsModal.tsx` (Modal, backdrop tap dismiss, `slideAnim`, `SHEET_WIDTH = min(screenW-16, 414)`) and `MoodFeedbackSheet.tsx` (motion via `theme/motion.ts`).
- Tokens only — `ds.*`/`theme.colors.*`, `theme.typography.aliases.*`, `theme.motion.*`. No raw hex (token-lint gate).

## Requirements (maps to ticket scenarios)
- Radio list from `TEMPERATURE_BUCKETS`; **pre-select** `activeBucketKey` on open (ticket: "Reopen after override → previously selected pre-selected"; default `weather`).
- Selecting a radio updates **pending** selection; **Apply enabled** only when a selection exists (always true since one is pre-selected — enable on change vs initial).
- **Loading state:** Apply disabled + spinner, radios disabled (ticket "Loading State").
- **Inline error** slot: *"Unable to update outfit recommendations. Please try again."* / offline: *"No internet connection. Please try again."* — sheet stays open, selection retained, Apply re-enabled (ticket "Error Handling").
- Cancel / backdrop → close, no apply, no request.

## Props (illustrative)
```ts
interface TemperatureOverrideSheetProps {
  visible: boolean;
  activeBucketKey: TemperatureBucketKey;
  liveTempC: number;                 // for "Use current weather (XX°C)" label
  isApplying: boolean;
  errorKey?: 'recommend_failed' | 'offline' | null;
  onApply: (key: TemperatureBucketKey) => void;
  onCancel: () => void;
}
```

## Files to CREATE
- `auxi/src/components/features/TemperatureOverrideSheet.tsx` (≤200 lines; extract a `TemperatureRadioRow` sub-component if needed).

## Implementation Steps
1. Scaffold from `ContextChipsModal` (Modal + backdrop + animated container + safe-area bottom).
2. Header: title + subtitle (i18n). Body: map buckets → radio rows; `weather` row label injects `liveTempC`.
3. Footer: Apply (primary, `isApplying` → spinner/disabled) + Cancel (text).
4. Inline error banner above footer when `errorKey` set.
5. Wire motion (open/close asymmetry via `motion.ts`), reduce-motion fallback (designer gate checks this).

## Todo
- [ ] Component created, tokens only (token-lint clean)
- [ ] Pre-selects active bucket; pending-selection local state
- [ ] Loading + inline-error states implemented
- [ ] Reduce-motion fallback present
- [ ] testIDs on radios + Apply + Cancel (for qa-ui/qa-mobile)

## Success Criteria
Renders all 5 options with correct pre-selection, Apply/Cancel behave, loading/error states match ticket, no raw hex/zIndex/motion literals.

## Risks
- Forgetting reduce-motion branch / one-duration-for-open+close → **designer hard-gate FAIL**. Build it in now.
