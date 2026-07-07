# Mobile Screen Code-Health Scan — auxi/src/screens

**Date:** 2026-07-01 · **Scope:** `auxi/src/screens/**` (+ big `components/features`) · **Method:** line-count + 5 parallel structural diagnoses of the 7 largest screens.
**Project rule violated:** `development-rules.md` → files should stay **< 200 lines**.

---

## 1. Headline

- `screens/` = **~17,384 lines** (excl. tests), **56 screen files**, **34 of 56 (61%) over 200 lines**.
- **7 God-files = 8,621 lines = ~50% of ALL screen code.** Half the mobile UI lives in seven files.
- Only **6 of 56** screen files have a colocated test.
- Systemic breach of `design-system-primitives-required.md`: raw `TouchableOpacity`/`Modal`/`Switch` hand-rolled where `M*` primitives already exist.

## 2. Worst offenders (all severity 5/5 except SeeThisOnMe)

| # | File | Lines | ×over 200 | Severity | Core disease |
|---|------|-------|-----------|----------|--------------|
| 1 | `HomeScreen/index.tsx` | 1709 | 8.5× | **5/5** | God-component: 22 useState + 33 refs + 22 effects; API/data-transform/state-machine fused with 400-line JSX |
| 2 | `OutfitCanvasScreen.tsx` | 1555 | 7.7× | **5/5** | 6+ concerns fused (history/persistence/exit-guard/picker/tags); 3 inline components; 0 useMemo |
| 3 | `ItemDetailScreen.tsx` | 1407 | 7.0× | **5/5** | fetch+3 mutations+image-math+presentation; raw Modal picker; 0 `M*` used |
| 4 | `SettingsScreen.tsx` | 1133 | 5.6× | **5/5** | 14 useState + 17 handlers; ~10 repeated raw settings-rows; `MListRow`/`MSwitch` ignored |
| 5 | `WardrobeScreen.tsx` | 1044 | 5.2× | **5/5** | 94-line render-tile fn + 77-line upload handler; polling/reconcile/analytics tangled |
| 6 | `BodyScreen.tsx` | 1016 | 5.1× | **5/5** | **3 separate screens** (manage/tryOn/photoDetail) + 3 modals fused into one file |
| 7 | `see-this-on-me/SeeThisOnMeScreen.tsx` | 757 | 3.8× | **4/5** | 18 useState + 4 refs hand-rolled step-machine (steps already extracted — healthier) |

Runner-ups also >200: `OutfitCanvasSurface.tsx` (467, dual gesture systems), `collage-seed-layout.ts` (623, but cohesive/pure — low severity), most `auth/*` screens (250–556), `FavouriteScreen` (420).

## 3. Cross-cutting patterns (the "loạn")

**A. God-component / concern-soup.** Every top file mixes networking + data transforms + state machines + presentation in ONE component. Screens directly call `recommendV05`, `favouriteService`, `wardrobeService`, `creationsService` and do optimistic-update+rollback inline. Business logic belongs in hooks/services.

**B. State sprawl, zero memoization.** HomeScreen 22 useState/33 useRef/22 useEffect. Canvas 12 useState/9 useRef/28 useCallback/**0 useMemo** (canUndo/canRedo recomputed every render). SeeThisOnMe 18 useState. Multiple screens are begging for `useReducer` — `restartCapture` manually resets 14 setters; Settings has 17 stateful handlers.

**C. Duplicated blocks within files.**
- Home: "reset+regenerate" primitive ×3, `requestRecommendation({...})` param shape ×5–6, toast timer pattern ×3, `recommendV05` weather-param object twice.
- Canvas: item-mutation `prev.map(...)` shape ×3, header icon-button style array ×4, "Adding…" pill ×2.
- ItemDetail: 3 parallel `switch(field)` over the same 4 fields (collapse to a config map), secondary-action row ×3, `toast error` block ×5.
- Settings: nav-row markup ×6, switch-row ×4, dialog ×5.
- Wardrobe: 3 near-identical status-pill badges.
- Body: photo-source Modal written **twice near-identically**.

**D. Design-system primitive violations** (breaks `design-system-primitives-required.md`).
- Settings: 6 nav rows raw `TouchableOpacity` → `MListRow`; `SettingsSwitch` wraps raw RN `Switch` → `MSwitch`; local `Divider` → `MDivider`.
- ItemDetail: raw `Modal` picker → `MBottomSheet`/`MSheetOption`; action buttons → `MButton`/`MIconButton`.
- Body: two raw photo-source `Modal`s → `MActionSheet` (a `PhotoSourceSheet` already exists!); lightbox raw `Modal`.
- Wardrobe: mostly migrated (good) — leftovers: status pills → `MChip`, AI-processing overlay raw `Modal`.
- **Three parallel primitive families in play** — raw RN, legacy `FigmaPrimitives` (PillButton/TopIconButton), and the canonical `M*` lib. Screens straddle all three inconsistently.

**E. Duplicated *features* across files (architectural).**
- Photo-source bottom sheet exists in **3 forms** (BodyScreen ×2 raw + `components.tsx` PhotoSourceSheet).
- **Two divergent try-on pipelines**: BodyScreen does synchronous `generateTryOn`+`pollJob` inline; SeeThisOnMe uses the background `tryOnGenerationStore`. Same feature, two implementations.

## 4. What's already been done right (the pattern exists — it just wasn't finished)

- `HomeScreen/` already extracts `styles.ts`, `outfit-normalize.ts`, `components/`, `hooks/` (useWeather, useContextRefineModal) — the God-file is what was left behind.
- `see-this-on-me/` already extracts all step views + store — bloat is orchestration, not JSX.
- `canvas/` has `DiscardCreationDialog`; Wardrobe already uses `MBottomSheet`/`MActionSheet`/`MButton` with migration comments.
- `collage-seed-layout.ts` is a clean, pure, section-commented engine — over 200 lines but healthy.

**Takeaway: the extraction convention is established. The top 7 screens simply never completed the split.**

## 5. Prioritized refactor roadmap (highest value first)

| Prio | Action | Files | Approx savings |
|------|--------|-------|----------------|
| P0 | `HomeScreen` → `useOutfitFeed` + `usePinnedOutfit` + `useTemperatureFlow` + `useHomeToasts` hooks; split `HomeHeader`/`PinStatusBanners`/`WearThisFooter`/toast layer | Home | 1709 → ~250–300 |
| P0 | `OutfitCanvasScreen` → extract `ItemPickerPanel` (self-contained) + `useCanvasHistory` + `useCanvasExitGuard` + `useCanvasAddItems` | Canvas | 1555 → ~500 then <200 |
| P1 | `ItemDetail` → `OptionPickerSheet` on `MBottomSheet` + move 13 mappers to `utils/wardrobeItemMappers.ts` + `useItemDetail` hook | ItemDetail | 1407 → ~250 |
| P1 | `BodyScreen` → lift `photoDetail` branch to its own route/screen; replace 2 raw modals with `PhotoSourceSheet`/`MActionSheet` | Body | 1016 → <200 |
| P1 | `Settings` → swap raw rows for `MListRow`/`MSwitch`/`MDivider`; `settingsModel.ts`; `useSettingsController` | Settings | 1133 → ~300 |
| P2 | `Wardrobe` → `WardrobeGridTile` + `TileStatusBadge` (fold 3 pills) + `useAddWardrobeItem`/`PreparingOverlay` | Wardrobe | 1044 → ~350 |
| P2 | `SeeThisOnMe` → `useReducer` for flow state + `useTryOnStepSync` hook + step-shell router | SeeThisOnMe | 757 → <300 |
| P3 | Consolidate photo-source sheet (3→1) and unify the two try-on pipelines | Body + SeeThisOnMe | cross-file dedup |

**Sequencing note:** each of these is independent and low-risk because the target components/hooks don't exist yet (pure additive extraction, no behavior change). Land one screen per PR, run `auxi-lint-ds-primitives.sh` + `auxi-lint-tokens.sh` + archive build each time.

## 6. Unresolved questions

1. **`FigmaPrimitives` (PillButton/TopIconButton) — approved parallel DS, or legacy to migrate onto `M*`?** Determines whether extractions target `M*` or `Figma*`. (Affects ItemDetail, Body, SeeThisOnMe.)
2. **`SettingsSwitch` (wraps raw RN `Switch`)** — intentional wrapper or retire for `MSwitch`?
3. **Wardrobe AI-processing raw `Modal`** — intentionally outside DS or slated for `MBottomSheet` like its sibling sheets?
4. **Exported ItemDetail helpers** (`formatItemDate` etc. "exported for tests") — confirm external test imports before relocating.
5. **Legacy `_HomeScreen.tsx`** — does it share blocks with `index.tsx`? De-dupe before its slated deletion.
6. **Scope decision for you:** do you want this as (a) a tracked refactor plan/tickets, (b) me starting P0 HomeScreen extraction now on a branch, or (c) report-only for now?
