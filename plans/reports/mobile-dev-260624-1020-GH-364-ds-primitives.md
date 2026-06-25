# GH-364 — DS primitive library refactor

**Branch:** `feat/au-364-ds-page-claude-sync`
**Commits:** `fb637c7e` (lib extract) · `3585cd5b` (showcase consume + deletes)
**Date:** 2026-06-24

## What changed

Refactored the DS-page specimens from inline demo markup (in `Ds*` section
files wired to ds-tokens/DsMotion) into a real, self-contained primitive
library. Consumers now `import { X } from '<barrel>'` and render — no token,
motion, helper, or style imports needed. Everything is encapsulated inside
each primitive.

## Barrel

`auxi/src/components/design-system/lib/index.ts`

```ts
import { DsButton, DsSwitch, DsChip } from '../components/design-system/lib';
<DsButton variant="primary" onPress={save}>Save</DsButton>   // works, nothing else imported
```

The contract holds: each primitive pulls `ds-tokens` + `DsMotion` INTERNALLY.
Internal-only modules NOT re-exported: `ds-tokens`, `DsMotion`,
`useSlidingIndicator`, `useOverlayProgress`.

## Exported primitives + prop signatures

### Actions
- `DsButton({ children, variant?='primary' (primary|secondary|text|danger|dangerOutline), size?='lg' (lg|md|sm), disabled?, loading?, leftIcon?, onPress?, testID?, accessibilityLabel? })`
- `DsIconButton({ icon?=Plus, size?='md', onPress?, testID?, accessibilityLabel? })`

### Selection
- `DsSwitch({ value, onValueChange, disabled?, testID?, accessibilityLabel? })`
- `DsCheckbox({ checked, onChange, label?, indeterminate?, disabled?, testID?, accessibilityLabel? })`
- `DsRadio({ selected, onSelect, label?, disabled?, testID?, accessibilityLabel? })`
- `DsCheckMenu({ options: DsMenuOption[], selected: Record<string,boolean>, onToggle, testID? })`
- `DsRadioMenu({ options: DsMenuOption[], value, onChange, testID? })`
  - `DsMenuOption = { value, label, tag? }`

### Inputs
- `DsInput({ value, onChangeText, label?, placeholder?, error?, hint?, leftIcon?, secureTextEntry?, keyboardType?, editable?=true, testID?, accessibilityLabel? })`

### Tagging
- `DsChip({ children: string, selected?, onPress?, removable?, onRemove?, testID?, accessibilityLabel? })`
- `DsBadge({ children: string, tone?='cream' (cream|tan|soft), testID? })`
- `DsTag({ children: string, testID? })`
- `DsStatus({ children: string, tone?='info' (ok|warn|err|info), testID? })`

### Structure
- `DsDivider({ label?, inset?: number, testID? })`
- `DsListRow({ label, value?, chevron?, danger?, onPress?, testID?, accessibilityLabel? })`
- `DsSegmented({ options: string[], value, onChange, testID? })` — sliding spring thumb
- `DsTabs({ tabs: string[], value, onChange, testID? })` — sliding underline
- `DsAvatar({ size?='sm' (lg|sm), initials?, source?, testID?, accessibilityLabel? })`
- `DsCard` / `DsTile` (alias) `({ caption, sub?, tag?, fill?, source?, pinned?, onPinChange?, onPress?, index?, testID?, accessibilityLabel? })` — controlled pin via `pinned`+`onPinChange`

### Overlays (controlled `visible` + callbacks, enter/exit asymmetry baked in)
- `DsDialog({ visible, title, message?, confirmLabel?='Confirm', cancelLabel?='Cancel', destructive?, onConfirm, onCancel, testID? })`
- `DsBottomSheet({ visible, onDismiss, children?, testID? })` + `DsSheetOption({ icon?, label, onPress?, testID? })`
- `DsActionSheet({ visible, onDismiss, title?, options: DsActionSheetAction[], cancelLabel?='Cancel', testID? })`
  - `DsActionSheetAction = { label, destructive?, onPress? }`
- `DsSnackbar({ visible, message, actionLabel?, onAction?, tone?='dark' (dark|mint), testID? })`
- `DsToast({ visible, message, testID? })` — leads with spinner

### Navigation
- `DsTopAppBar({ title, onBack?, onAction?, actionIcon?, actionLabel?, testID? })`
- `DsTabBar({ items: DsTabBarItem[], value, onChange, testID? })`
  - `DsTabBarItem = { key, icon, label? }`
- `DsFloatingPill({ tabs: string[], value, onChange, testID? })` — signature overshoot spring

### Pickers
- `DsCalendar({ value, onChange, monthLabel?, daysInMonth?=31, leadingBlanks?=2, today?, testID? })`
- `DsTimePicker({ time?='07 : 30', period, onPeriodChange, testID? })`

## Single-import contract — proof

`ComponentsSection.tsx` and `MotionSection.tsx` were rewritten to a single
`import { … } from './lib'` and render every specimen with local state. No
inline component markup, no per-primitive token/motion imports remain in the
showcase. Example (from ComponentsSection):

```tsx
import { DsButton, DsSwitch, DsChip, DsCard, DsDialog /* … */ } from './lib';
<DsButton variant="danger" testID="ds-btn-danger">Danger</DsButton>
<DsSwitch value={notify} onValueChange={setNotify} testID="ds-switch-reminder" accessibilityLabel="Daily reminder" />
```

## Showcase-only (not in barrel)

- `DsKeyboardDemo` (`design-system/DsKeyboardDemo.tsx`) — a QWERTY keyboard
  isn't an app-rendered primitive (the OS owns it). Kept purely to show key
  press motion; lives outside `lib/`, barrel does not export it. (Per spec:
  "DsKeyboard can stay a static showcase-only demo if not reusable.")

## Motion preserved

All motion moved INSIDE the primitives, unchanged: press-scale spring,
3-dot/spin loaders, switch knob slide, chip select-pop + collapse-on-remove,
sliding-indicator spring (segmented/tabs), floating-pill overshoot, tile
entrance stagger + pin slide-in, overlay enter(spring)/exit(faster) asymmetry,
all honoring `useReducedMotion()`.

## Files

- New: `lib/` (19 primitive files + `index.ts` barrel + 2 internal hooks),
  `DsKeyboardDemo.tsx`
- Modified: `ComponentsSection.tsx`, `MotionSection.tsx`, `DsMotion.tsx`
  (PressScale testID → optional)
- Deleted: `DsButtons`, `DsControls`, `DsCheckMenu`, `DsInputsChips`,
  `DsListsTabs`, `DsCardsAvatar`, `DsOverlays`, `DsToasts`, `DsDateKeyboard`,
  + old root `DsDivider`/`DsFloatingPill` demos

## Verification

- `npx tsc --noEmit` — clean (exit 0)
- eslint (changed files) — 0 errors; 1 warning (unavoidable Animated inline
  style in DsChip; same kind the old code carried)
- `../scripts/auxi-lint-tokens.sh` — no violations in any changed path (27
  pre-existing repo-wide violations are all in untouched product screens)
- `yarn web:build` — success (built in 6.16s)
- `git diff --name-only` — all within `components/design-system/**` (scope clean)

## Notes / open

- 4 lib files run 221–264 LOC (DsChip, DsCalendar, DsCard, DsBottomSheet) —
  each groups tightly-related primitives + shared styles; splitting would hurt
  DRY. Kept grouped on purpose.
- `DsTopAppBar.tsx` was already present in lib/ (clean, on-pattern, simpler
  onBack/onAction API) — kept as-is rather than overwrite.
- No simulator visual verification this session (JS-only refactor, no native
  rebuild per build-workflow rule). DS page renders the same specimens; web
  build confirms it compiles web-safe. Hand to qa-ui for Compare if a visual
  gate is wanted.
