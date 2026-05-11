# Phase 3 — Wave 2: RemixButton + AxisChip Components

## Context Links

- Parent plan: `plan.md`
- UX spec: `docs/pm/remix-feature-plan.md` §4 (button states, chip text, animation)
- Existing primitives: `auxi/src/components/primitives/FigmaPrimitives.tsx` (`PillButton`, `TopIconButton` — match style)
- Theme tokens: `auxi/src/theme/theme.ts`
- Convention: `auxi/CLAUDE.md` "testID on every interactive element"
- DESIGN-02 status: pending Viet's assets — scaffold with placeholders if not landed

## Overview

**Priority**: P1
**Status**: pending
**Description**: Build the two presentational components in isolation. No HomeScreen integration yet (Wave 3). Both components stateless except for animation; props-driven so Wave 3 can wire them without further component edits.

## Requirements

- REMIX-ME-02 (RemixButton CTA)
- REMIX-ME-05 (AxisChip hint label)
- REMIX-ME-07 (button states: default / loading / cooldown / disabled)

## Architecture

```
HomeScreen (Wave 3 wires these)
   │
   ├─► <RemixButton
   │       state="default" | "loading" | "cooldown" | "disabled"
   │       onPress={remix}
   │       onLongPress={openAxisSheet}      ← Wave 4 wires this
   │       testID="home-remix-button"
   │   />
   │
   └─► <AxisChip
           axis={lastAxis}                  ← from useRemix hook
           visible={chipVisible}            ← Wave 3 controls timing
           onAutoFadeComplete={...}
           testID="home-axis-chip"
       />
```

**No state in components beyond Animated.Value for chip fade.** Wave 3 owns the visibility timer via state above the components.

## Related Code Files

**Create**:
- `auxi/src/components/features/RemixButton.tsx` (≤120 lines)
- `auxi/src/components/features/AxisChip.tsx` (≤100 lines)

**Modify**: none

**Delete**: none

---

## Implementation Steps

### Task 2.1 — `RemixButton.tsx`

**Wave**: 2 · **Estimated**: 50 min · **Parallel-eligible**: Yes
**Files touched**:
- CREATE: `auxi/src/components/features/RemixButton.tsx`

**Steps**:
1. Define props:
   ```ts
   interface Props {
     state: 'default' | 'loading' | 'cooldown' | 'disabled';
     onPress: () => void;
     onLongPress?: () => void;
     testID?: string;
   }
   ```
2. Use `TouchableOpacity` (matches `PillButton` pattern in `FigmaPrimitives.tsx`).
3. State → visual mapping (per UX spec §4.1):
   - `default`: label "Remix" + cyclone icon, action color, enabled.
   - `loading`: ActivityIndicator (small, white), label hidden, disabled (debounce).
   - `cooldown`: label "Remixing...", disabled, ~70% opacity.
   - `disabled`: greyed out (`figmaSurfaceSoft` bg, `figmaTextMuted` fg), disabled. Used when wardrobe < 5 items per layer (Wave 5 wires this).
4. Long-press: `delayLongPress={400}`. If `onLongPress` undefined, no-op. Wave 4 will provide handler.
5. Press feedback: `activeOpacity={0.82}`. Hardcoded haptic call deferred — `react-native-haptic-feedback` not in deps; flag in Risk register.
6. Default `testID`: `home-remix-button`. State-suffixed when in saved/cooldown state per `auxi/CLAUDE.md` testID rule:
   - `home-remix-button` (default/disabled)
   - `home-remix-button-loading`
   - `home-remix-button-cooldown`
7. accessibilityLabel: "Remix outfit" (default), "Remixing outfit" (loading/cooldown). Differs from testID per `auxi/CLAUDE.md`.
8. Use theme tokens only — NO literal hex (per CLAUDE.md "Don't add more").
9. Cyclone icon: if `assets/icons/icon_cyclone.svg` doesn't exist, use a Unicode glyph "⟳" or a placeholder `<View style={{width:18,height:18}}/>` and document the asset gap in inline TODO. Designer (Viet) provides via DESIGN-02.

**Acceptance**:
- All 4 states render distinctly (eyeballed via Storybook-equivalent: a temp screen rendering each state — optional, time-permitting).
- testID always defined, suffix flips per state.
- 0 literal hex colors.
- Long-press fires after 400ms hold.

**Verify**:
```bash
cd auxi && npx tsc --noEmit 2>&1 | grep "RemixButton" | grep "error"
# 0 errors
```

---

### Task 2.2 — `AxisChip.tsx`

**Wave**: 2 · **Estimated**: 45 min · **Parallel-eligible**: Yes
**Files touched**:
- CREATE: `auxi/src/components/features/AxisChip.tsx`

**Steps**:
1. Define props:
   ```ts
   interface Props {
     axis: VariationAxis | null;        // from useRemix
     visible: boolean;
     onAutoFadeComplete?: () => void;
     testID?: string;
   }
   ```
2. Import `VariationAxis` from `services/v05Api.ts`.
3. Define mapping (per UX spec §4.2):
   ```ts
   const AXIS_LABEL: Record<VariationAxis, string> = {
     SILHOUETTE: 'New top',
     LAYERING: 'New layer',
     COLOR: 'New color',
     NEW_ANCHOR: 'Full remix',
   };
   ```
4. Color intensity per spec:
   - SILHOUETTE / LAYERING → neutral (`figmaSurfaceSoft` bg, `figmaTextPrimary` fg)
   - COLOR → accent (`figmaAction` bg, `white` fg)
   - NEW_ANCHOR → bold (`figmaText` bg, `white` fg, 700 weight)
5. Animation (Animated API, `useNativeDriver: true`):
   - Mount or `visible→true`: opacity 0→1 + translateY 8→0 over 200ms (slide-up + fade).
   - 3000ms timer after visible-on: opacity 1→0 over 200ms; on complete, fire `onAutoFadeComplete` callback so parent can null out `lastAxis`.
   - `visible→false` (parent override): immediate fade-out 200ms.
6. Cleanup: `useEffect` returns timer-clear on unmount or axis change.
7. testID: `home-axis-chip`. When visible: `home-axis-chip-{axis-lowercase}` (e.g., `home-axis-chip-silhouette`) so Maestro can assert which axis is showing.
8. accessibilityLabel: full text e.g., "Outfit changed: New top".
9. Use `pointerEvents="none"` so chip doesn't block taps on RemixButton beneath.

**Acceptance**:
- 4 axis values render with correct text + color tier.
- Animation runs at 200ms slide-up, 3000ms display, 200ms fade-out (verified in iOS sim eyeball).
- Auto-fade callback fires after 3.2s total.
- Returns null when `axis === null`.

**Verify**:
```bash
cd auxi && npx tsc --noEmit 2>&1 | grep "AxisChip" | grep "error"
# 0 errors
```

---

## Todo List

- [ ] 2.1 Create `RemixButton.tsx` (50m)
- [ ] 2.2 Create `AxisChip.tsx` (45m)
- [ ] Wave 2 verify: `npx tsc --noEmit` returns 0 new errors

## Success Criteria

- Both components compile and export from `src/components/features/`.
- Both components renderable in isolation (a throwaway sandbox screen optional).
- testIDs follow `<feature>-<element>-<state>` convention from `auxi/CLAUDE.md`.
- Zero theme violations (no literal hex).

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Viet's DESIGN-02 assets late → cyclone icon + final colors not in hand | M | L | Scaffold with Unicode glyph + theme tokens. Visual swap is one-line `<IconCyclone/>` import + color token edits. |
| Animated API + native driver conflicts with `pointerEvents="none"` on Android | L | L | Test both platforms in iOS sim first; if Android shows ghost-tap issue, drop native driver for opacity-only animation. |
| Haptic feedback library not installed | L | L | Document in TODO comment; defer to post-launch nice-to-have (REMIX-ME spec doesn't require haptic). |
| 3-second auto-fade collides with rapid Remix taps (chip from tap N still showing when N+1 lands) | M | M | Wave 3 task 3.4 contract: parent re-keys chip on every new `lastAxis` value via `key={lastAxis + serialId}`. Force remount = clean re-animate. |

## Security Considerations

- Pure presentational components; no PII, no network, no storage. N/A.

## Next Steps

- Wave 3 blocked by completion of both Wave 1 and Wave 2.
- If DESIGN-02 lands during/after Wave 2, the only edit needed is icon import + color token swap — no logic change.
