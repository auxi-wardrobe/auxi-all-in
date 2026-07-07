# Phase 07 — SeeThisOnMeScreen.tsx (P2)

**File:** `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx` · **757 → <300 target** · Severity 4/5 (healthiest of the 7)
**Status:** ⬜ todo

## Current problems
- 18 useState + 4 useRef in one component — hand-rolled step-flow state machine (`Step` union + 18 flags).
- Glued to background `tryOnGenerationStore`: mirror effect (L224–285) + rehydrate effect (L292–324) encode the same phase→step map **twice** (~90 lines of inline glue).
- `restartCapture` (355–383) manually resets ~14 setters — symptom of reducer-shaped state.
- 5 early-return screen shells (515–605) repeat `SafeAreaView`+`StomHeader`+body. `renderStepControls` (618–693) inline with per-step capture/validate closures.
- Good news: step views ALREADY extracted (StepSelfie/StepFullBody/StepBodyShape/StepReuseConfirm/OutfitPreview/GeneratingView + components.tsx); styles tiny (21 lines). Bloat is orchestration/state, not JSX. DS: only `PillButton` (legacy) vs `MButton`; `PhotoSourceSheet` in components.tsx still raw `Modal`.

## Extractions (new files)
1. **`useReducer` for flow state** — collapse 18 useState + `restartCapture` into one reducer with a `reset` action. Removes setter-spray + most state churn in the 14 useCallbacks. **~-30 + big clarity win**
2. `hooks/useTryOnStepSync.ts` — both effects (mirror + rehydrate) + their refs; dedups the phase→step map. **~-95**
3. `components/StomStepScreen.tsx` — step-shell router for the 5 early returns. **~-70**
4. `components/StomStepControls.tsx` — `renderStepControls` + capture/validate wiring via props. **~-75**
5. `stom-steps.ts` — `captureStepConfig` + `Step`/`CaptureStep` types (L59–95). **~-30**

## Steps
1. Introduce reducer for flow state (mechanical: setters → dispatch). Test each step transition on sim.
2. Extract `useTryOnStepSync` (mirror + rehydrate) — single phase→step map.
3. Extract step-shell router + step controls.
4. Move step config/types to `stom-steps.ts`.

## Success criteria
- Screen ~250–300 (< 200 achievable after reducer + all splits); each new file < 200.
- Full capture flow (selfie → full-body → body-shape → generating → preview → reuse-confirm) + background rehydrate behave identically. `track()` preserved.

## Risks
- Reducer migration is the riskiest (touches all 18 flags) — do it as its own commit, verify every transition + backgrounding/rehydrate before extracting hooks.
- `reuseFiredRef`/`rehydratedRef` guard once-only effects — preserve guard semantics in the hook.
