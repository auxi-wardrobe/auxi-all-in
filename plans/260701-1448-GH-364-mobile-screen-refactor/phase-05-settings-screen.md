# Phase 05 — SettingsScreen.tsx (P1)

**File:** `auxi/src/screens/SettingsScreen.tsx` · **1133 → ~300 target** · Severity 5/5
**Status:** ⬜ todo

## Current problems
- 14 useState + 17 handlers, each mixing persist + local-state + analytics + toast.
- Module block L52–202 (~150): `LANGUAGE_OPTIONS/MAP`, `DEFAULT_SETTINGS`, 4 `build*Options/LabelMap`, `resolveSettings`, `getErrorStatus/Message`, `showSettingsError` — data/model in the screen.
- Concern soup: data mapping + persistence (`persistUserMetadata`→`updateCurrentUser`) + 3 service seams (analytics consent, AI-consent, i18n `setLanguage`) + nav + optimistic+rollback+toast + all UI.
- Duplication + DS violation: 6 nav rows raw `TouchableOpacity`+`Text`+`Icon` → `MListRow` (has label/value/chevron/danger, matches Delete-data row exactly); 4 switch rows via `SettingsSwitch` wrapping **raw RN `Switch`** → `MSwitch`; local `Divider` → `MDivider`; 5 `SettingsDialog` blocks share shape; `Icons.ArrowRight 24/24` ×4.

## Extractions (new files)
1. Swap 6 nav rows + 4 switch rows for `MListRow` / `MSwitch` (+ `MDivider`). **~-150 JSX + ~10 style keys** + fixes DS violation. (decision #2: retire `SettingsSwitch`.)
2. `settings/settingsModel.ts` — the L52–202 builders/resolveSettings/error helpers. **~-130**
3. `components/SettingsDialogs.tsx` (+ hook) — 4 dialogs + pending-state handlers. **~-95**
4. `hooks/useSettingsController.ts` — 14 useState + 17 handlers → screen becomes pure layout. **~-300 from body**
5. `components/NotificationSettingsSection.tsx` — Daily-Time group + change-time/reset handlers. **~-120**

## Steps
1. Move model block to `settingsModel.ts` (pure, no deps on component).
2. Build `useSettingsController` hook holding state + handlers.
3. Replace rows with `MListRow`/`MSwitch`/`MDivider` (decision #2 — retire `SettingsSwitch`).
4. Extract dialogs + notification section.

## Success criteria
- Screen ~300; each new file < 200; no raw settings-row `TouchableOpacity`, no raw `Switch`.
- Every toggle/nav/dialog + optimistic rollback + i18n switch behaves identically. `track()` preserved.
- `auxi-lint-ds-primitives.sh` violations for this file drop to ~0.

## Risks
- 17 handlers each persist + toast + analytics — move as units; keep exact persist→state→toast order to preserve rollback.
- `SettingsSwitch` may be imported elsewhere — grep before deleting.
