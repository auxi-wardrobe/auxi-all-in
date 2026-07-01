# PR #147 → Design-System standardization (GH-364)

> **Question answered:** when PR #147 ("Add canvas save & My Creations screen")
> is applied to the design system, what's wrong — and if #147 is the standard,
> what must the DS change. **Verdict: the feature is mergeable; its *construction*
> is NOT the DS standard.** It faithfully copies the already-legacy Favourite
> pattern, so it's on-system-by-precedent but off the `ds.*`+`M*` target.

PR: auxi-wardrobe/auxi-mobile#147 · branch `claude/brave-bardeen-eaxo16` · 4 UI surfaces
(`MyCreationsScreen`, `OutfitCanvasScreen` header, `DiscardCreationDialog`, `CreationCollageCard`).

## The two findings (short)

**1. Apply to DS → what's wrong** (full gate: `auxi/docs/design-reviews/260625-pr147-my-creations-canvas-save.md`)
- Designer gate = **PASS-WITH-MINORS** (BLOCKER 0 / MAJOR 0 / MINOR 5 / NIT 3 / DS-gap 1).
- Clean on hard trip-wires: **no raw hex**, `zIndex.toast` not raw, motion textbook (open `medium`+`enter` / close `normal`+`exit` + `useReducedMotion`), full a11y + tri-locale i18n.
- MINORs: mixes `figma*/uac*` where `ds.*` exists; raw `Modal`/`TouchableOpacity`/`TopIconButton` instead of `MBottomSheet`/`MButton`/`MIconButton`; `figmaItemDetailDanger` (#c0392b) instead of `ds.color.danger`; no error state on save/remove; under-weighted empty state.
- **Decisive nuance:** it mirrors shipped Favourite/RemoveFavourite, and the primitives lint is still warn-mode → MINOR (migrate the family together at GH-364 Phase 4), not MAJOR.

**2. If #147 is the standard → what the DS must fix**
- **Build 4 missing components** the PR (and Favourite) hand-roll: `MEmptyState` (genuine gap), `MConfirmSheet`, `BlurMenuHeader`, `CollageSurface` — specs below.
- **Decide `figma*/uac*` fate** — finish `ds.*` migration + codemod, or stop calling them legacy (can't keep "mixing = MINOR" forever).
- **Fix 2 theme.ts bugs** (token-map §0): `cream` alias note wrong for `figmaBackground` (it's white); three destructive reds, only `ds.color.danger` canonical.
- **Typography** is a NAMING bug, not a font bug — `inter*` aliases already render Poppins; consolidate into a Poppins-named scale.
- **Tokenize** the magic numbers the standard relies on (button height, icon size, sheet travel, blur amount, snackbar elevation).
- **Add `ds` tokens**: `ds.color.scrim`, `ds.color.headerBlurTint`, `spacing.sm`=12.

## Deliverables in this folder
- `token-map.md` — exact `figma*/uac*/generic → ds.*` map for the 4 files + 2 DS bugs + typography + magic-numbers.
- `spec-m-empty-state.md` · `spec-m-confirm-sheet.md` · `spec-blur-menu-header.md` · `spec-collage-surface.md` — build specs.
- Official gate: `auxi/docs/design-reviews/260625-pr147-my-creations-canvas-save.md`.

## Recommendation / sequencing
Treat #147 as the **worklist**, not the template. Standard = "looks like #147, built on `ds.*`+`M*`".

- **Now:** merge #147 (gate PASS) → qa-mobile smoke → ship. Do NOT refactor it into a lone `M*` island next to still-legacy Favourite siblings.
- **GH-364 Phase 1 (token):** apply `token-map.md` — fix the 2 theme.ts bugs, add `ds.color.scrim`/`headerBlurTint` + `spacing.sm`, start typography consolidation.
- **GH-364 Phase 2-3 (primitives):** build the 4 specs; `MEmptyState` needs CEO sign-off (new pattern).
- **GH-364 Phase 4 (migrate + gate):** migrate #147 **and** the Favourite family together onto `M*`+`ds.*`; flip `auxi-lint-ds-primitives.sh` warn→error. The "mirrors a shipped sibling" pass expires here — new canvas/creations surfaces build on `M*`+`ds.*` directly.

## Todo
- [x] Read PR #147 diff (4 UI surfaces)
- [x] Map current DS (theme.ts `ds.*`, `M*` barrel, 4 rule docs)
- [x] Token map + 2 DS bugs (`token-map.md`)
- [x] 4 primitive specs
- [x] Official designer gate doc (PASS-WITH-MINORS)
- [ ] CEO decisions (see below)
- [ ] Schedule the Phase 1-4 work on the GH-364 board (pm)

## Success criteria
- #147 merges without being orphaned on `M*`.
- After Phase 4: no `figma*/uac*` in `MyCreations`/`Favourite`/canvas screens; the 4 primitives exist + are consumed; lint at error; one Poppins-named type scale.

## Unresolved questions (CEO/designer)
1. `figmaItemDetailDanger` #c0392b → alias to `ds.color.danger` #bb251a (recolor), or bless #c0392b as a distinct item-detail danger? (token-map bug #2)
2. `BlurMenuHeader` as its own component (A) or `Header variant="blur"` (B)? (spec leans A)
3. `MEmptyState` — does Favourite's empty state need an action CTA? Discard sheet — add an explicit Cancel button or keep backdrop-only?
4. Confirm GH-364 Phase 4 is the agreed point to flip the primitives lint warn→error and migrate the Favourite family + #147 as a batch.
