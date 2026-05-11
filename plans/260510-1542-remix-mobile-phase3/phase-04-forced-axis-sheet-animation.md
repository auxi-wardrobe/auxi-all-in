# Phase 3 — Wave 4: Forced-Axis Sheet + Chip Animation Polish

## Context Links

- Parent plan: `plan.md`
- UX spec: `docs/pm/remix-feature-plan.md` §2.3 (forced-axis sheet)
- Wave 2 outputs: `RemixButton` (already accepts `onLongPress` prop), `AxisChip`
- Wave 3 outputs: HomeScreen wired to `useRemix`
- Existing modal pattern: `auxi/src/components/features/ContextChipsModal.tsx` (mirror its bottom-sheet approach)
- React Native: no `react-native-bottom-sheet` in deps — use `Modal` + slide-up View (matches ContextChipsModal pattern)

## Overview

**Priority**: P2 (descope candidate per ROADMAP)
**Status**: pending
**Description**: Add long-press → forced-axis bottom sheet. User picks Top/Layer/Color/Full → sends `force_variation_axis` to `/next`. Polish AxisChip animation timing if Wave 3 left rough edges.

**Descope note**: If Phase 1 or Phase 2 slipped past 5/12 EOD, this entire wave is the FIRST cut. RemixButton long-press becomes no-op; auto-cycle still works.

## Requirements

- REMIX-ME-04 (long-press → forced-axis sheet)
- REMIX-ME-05 (AxisChip animation polish)

## Architecture

```
HomeScreen
   │
   ├─► <RemixButton
   │       onLongPress={openAxisPicker}    ← NEW in Wave 4
   │   />
   │
   └─► <ForcedAxisSheet
           visible={axisPickerOpen}
           onSelect={(axis) => { remix({ force: axis }); close(); }}
           onClose={close}
       />
```

**Sheet content** (4 axis options as tappable rows):
- "Top" → SILHOUETTE
- "Layer" → LAYERING
- "Color" → COLOR
- "Full remix" → NEW_ANCHOR

## Related Code Files

**Create**:
- `auxi/src/components/features/ForcedAxisSheet.tsx` (≤140 lines)

**Modify**:
- `auxi/src/screens/HomeScreen.tsx` — wire long-press + sheet visibility state
- (Optional) `auxi/src/components/features/AxisChip.tsx` — only if Wave 3 polish flagged a timing bug

**Delete**: none

---

## Implementation Steps

### Task 4.1 — Create `ForcedAxisSheet.tsx`

**Wave**: 4 · **Estimated**: 60 min · **Parallel-eligible**: Yes (with 4.2 if it touches AxisChip only)
**Files touched**:
- CREATE: `auxi/src/components/features/ForcedAxisSheet.tsx`

**Steps**:
1. Define props:
   ```ts
   interface Props {
     visible: boolean;
     onSelect: (axis: VariationAxis) => void;
     onClose: () => void;
     testID?: string;
   }
   ```
2. Use `Modal` from `react-native` with `transparent={true}`, `animationType="slide"` (or custom Animated translation for parity with ContextChipsModal).
3. Layout (mirror `ContextChipsModal.tsx` for consistency):
   - Backdrop: `Pressable` with semi-transparent black `bg`, `onPress={onClose}`.
   - Sheet container: bottom-anchored `View`, white bg, `borderTopRadius: 20`, padding 24.
   - Title: "Remix what?" (theme.typography.aliases.archivoSection or equivalent).
   - 4 option rows as `TouchableOpacity`, each with label + chevron icon.
4. Option mapping:
   ```ts
   const OPTIONS: Array<{ axis: VariationAxis; label: string; testIdSuffix: string }> = [
     { axis: 'SILHOUETTE', label: 'Top', testIdSuffix: 'top' },
     { axis: 'LAYERING', label: 'Layer', testIdSuffix: 'layer' },
     { axis: 'COLOR', label: 'Color', testIdSuffix: 'color' },
     { axis: 'NEW_ANCHOR', label: 'Full remix', testIdSuffix: 'full' },
   ];
   ```
5. testIDs:
   - Sheet root: `remix-axis-picker-sheet`
   - Each row: `remix-axis-picker-${testIdSuffix}` (e.g., `remix-axis-picker-top`)
   - Backdrop: `remix-axis-picker-backdrop`
6. accessibilityLabel for each row: "Remix top only" / "Remix layer only" etc.
7. On select: call `onSelect(axis)` then `onClose()` — parent decides if those are atomic or async.
8. Use theme tokens, no literal hex.
9. Keyboard dismiss on open: not needed (no inputs).
10. Safe area: read `useSafeAreaInsets()` for bottom padding.

**Acceptance**:
- Sheet slides up from bottom in ~250ms.
- Tapping backdrop closes without selection.
- Tapping option fires `onSelect` then `onClose`.
- All 4 testIDs distinct.

**Verify**:
```bash
cd auxi && npx tsc --noEmit 2>&1 | grep "ForcedAxisSheet" | grep "error"
# 0 errors
```

---

### Task 4.2 — Wire long-press in HomeScreen

**Wave**: 4 · **Estimated**: 30 min · **Parallel-eligible**: No (HomeScreen edit, sequential with 4.3)
**Files touched**:
- EDIT: `auxi/src/screens/HomeScreen.tsx`

**Steps**:
1. Import `ForcedAxisSheet`.
2. Add state: `const [axisPickerOpen, setAxisPickerOpen] = useState(false);`.
3. Wire `onLongPress` on RemixButton (in OptionSheet component, threaded from parent):
   ```tsx
   <RemixButton
     ...
     onLongPress={() => setAxisPickerOpen(true)}
   />
   ```
4. Mount sheet at HomeScreen root level (sibling of ContextChipsModal):
   ```tsx
   <ForcedAxisSheet
     visible={axisPickerOpen}
     onClose={() => setAxisPickerOpen(false)}
     onSelect={(axis) => {
       setAxisPickerOpen(false);
       remix({ force: axis });
     }}
   />
   ```
5. Note in inline comment: telemetry events `remix_axis_picker_opened` and `remix_axis_picker_selected` will be wired in Wave 6 — leave a TODO marker at the open + select call sites so Wave 6 grep finds them.

**Acceptance**:
- Long-press (400ms) RemixButton → sheet appears.
- Selecting an axis → sheet closes + `/next` request includes `force_variation_axis`.
- Backend response's `trace.variation_axis` matches the forced choice (verifiable in Charles).

**Verify**:
- Manual iOS sim: long-press Remix → sheet → tap "Top" → outfit changes with chip showing "New top".

---

### Task 4.3 — AxisChip animation polish (conditional)

**Wave**: 4 · **Estimated**: 30 min · **Parallel-eligible**: Yes (with 4.1)
**Files touched**:
- POSSIBLY EDIT: `auxi/src/components/features/AxisChip.tsx`
- POSSIBLY EDIT: `auxi/src/screens/HomeScreen.tsx` (key prop refinement)

**Steps**:
1. **Skip this task entirely if Wave 3 task 3.4 already produces clean animation per UX spec** (200ms slide-up + 3000ms display + 200ms fade). Run Wave 3 manual smoke first to decide.
2. If glitches found, common fixes:
   - Add `useNativeDriver: false` if opacity + transform conflict on Android.
   - Replace 3-second `setTimeout` with `Animated.sequence([Animated.delay(3000), Animated.timing(...)])` for cleaner cancellation.
   - Ensure cleanup `useEffect` cancels animation on axis change AND on unmount.
3. Re-key strategy: in HomeScreen, change AxisChip key from `key={lastAxis}` to `key={`${lastAxis}-${remixCounter}`}` where `remixCounter` increments on every successful `remix()` — guarantees fresh mount on every tap, even same-axis-twice (e.g., user forces "Top" twice in a row).

**Acceptance** (only if task executed):
- Rapid Remix taps (5 taps in 5 seconds) — chip re-animates on each, no stuck states.
- Animation timing matches UX spec §4.3 within 50ms tolerance.
- No memory leak from uncancelled timers (verifiable via Xcode Instruments if suspicious).

**Verify**:
- Manual iOS sim: stress test rapid taps; visual inspection.

---

## Todo List

- [ ] 4.1 Create `ForcedAxisSheet.tsx` (60m)
- [ ] 4.2 Wire long-press in HomeScreen (30m)
- [ ] 4.3 AxisChip animation polish (30m, conditional)
- [ ] Wave 4 verify: tsc clean + manual iOS smoke (long-press → sheet → axis → forced response)

## Success Criteria

- ✅ Success criterion #3 (long-press opens sheet, selecting axis sends `force_variation_axis`, correct swap occurs) — VERIFIED
- AxisChip animation matches UX spec §4.3 timing.
- Backend trace shows `force_variation_axis` round-tripped (request → response).

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Long-press conflicts with iOS context menu / accessibility long-press gesture | M | M | Use `delayLongPress={400}` (faster than iOS system 500ms). If conflict surfaces in QA, fall back to a small kebab button next to RemixButton (uglier but reliable). |
| `Modal` z-index issue stacks below ScrollView's snap interaction | L | L | Mount Modal at root SafeAreaView level, not inside ScrollView. Pattern matches existing ContextChipsModal. |
| `react-native-safe-area-context` already a dep but not used in feature components — `useSafeAreaInsets` returns 0 on first render | L | L | Wrap sheet bottom padding with `Math.max(insets.bottom, 16)` fallback. |
| User confused: long-press is hidden affordance | H | L | Wave 6 first-time tooltip explains. If tooltip descoped, accept as known UX gap; document in `docs/pm/remix-feature-plan.md` §9 open questions. |

## Security Considerations

- `force_variation_axis` is enum-validated client-side AND server-side (Pydantic Literal). No injection vector.
- Sheet content is static; no user input rendered. N/A for XSS.

## Next Steps

- Wave 5 blocked by Wave 4 only if Wave 5 needs the long-press path; otherwise parallel-eligible.
- If Wave 4 cut entirely (descope), skip to Wave 5.
