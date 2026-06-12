# qa-ui Compare-mode audit — AU-311 Wardrobe Item Detail

- **Date**: 2026-06-10
- **Screen**: `auxi/src/screens/ItemDetailScreen.tsx`
- **Figma**: `0nXXMAR4Arf1ZfjtQvtBh0` node `2852:7175` "Item detail | Edit detail"
  - read frame `2852:14557` "detail" · edit frame `2852:14647` "detail - save"
- **Extraction artifact**: `plans/260610-1632-au311-item-detail-figma/figma-extraction-item-detail.md`
- **Mode**: Compare. Pass 1 (extraction review) + Pass 2 (code-vs-Figma) DONE.
  **Pass 3 (on-sim screenshots) DEFERRED** — app not built/running on a sim
  this dispatch (per instructions). See §Pass 3.

---

## Verdict: PASS WITH CONCERNS → ESCALATE (3 deliberate calls need CEO sign-off)

Implementation faithfully matches the Figma read-mode and edit-mode frames at
the layout/token level. No hard fidelity defects (no hex drift, no leftover
text glyphs, color dot is 24, Name row present, edit bar is [Cancel][Save]).
Three **deliberate** scope decisions are correct engineering calls but are
designer-domain (CEO) decisions — flagged below for explicit confirmation.
That is what tips this from a clean PASS to ESCALATE.

---

## Pass 1 — extraction artifact review

The extraction note is **faithful and thorough**. Verified against
`get_metadata` / `get_design_context` / `get_variable_defs` on `2852:7175`:

- Frame tree (read-expanded + edit-expanded) matches the Figma node trees.
- Edit-mode bottom bar correctly captured: `[Cancel]` (Text button, h56,
  radius 100) + `[Save]` (Primary, h56, **radius 16**, bg `#1d1f23`, label
  `#f2efec`), row gap 16, both `flex:1`. Confirmed against frame `2852:14647`
  reference code (`Button hierarchy="Text button"` + default Primary).
- Token table is accurate. `get_variable_defs` confirms `text/danger/base` =
  `#c0392b` (and `icon/danger/base` = `#c0392b`), `background/neutral/base` =
  `#1d1f23`, `text/primary/base` = `#f2efec`, `border-radius/2xl` = 16,
  `dimension/24` = 24, color dot uses `text/info/base` `#1465b4`.
- Icon audit correct: `edit`, `minus_circle`, `change` were genuinely missing;
  all three now exist at 24×24 viewBox with `currentColor`.
- "Open questions" section is non-empty and surfaces the 3 real ambiguities.
- "New backend fields" section accurately reflects `WardrobeAttributeUpdate`
  (category, name, description, colors, dominant_color, color_hex,
  formality_level, style_tags) — the 5 mock fields are correctly identified as
  out-of-contract.

**Extraction gaps (minor, non-blocking):**

1. **Mix icon is a PIN, not a remix/shuffle glyph.** The artifact (line 101)
   and the icon map name it `Icons.Remix` / `icon_remix.svg`. The Figma
   read-mode "Mix with this" trailing icon (`imgGroup` in `2852:14557`) renders
   a **pushpin 📌** in the design screenshot, and `icon_remix.svg`'s path is in
   fact a pin glyph. So the *visual* is correct — but the name is misleading
   and the artifact labelled it "Mix/shuffle ⤬", which it is not. No code
   change needed; note the naming for future readers.
2. **`icon_remix.svg` viewBox is `0 0 12 12`**, not the `0 0 24 24` convention
   the artifact prescribes for the new icons. It scales fine (rendered at
   20×20) and is pre-existing, but it is the one icon in this screen that
   breaks the stated viewBox convention.

---

## Pass 2 — implementation vs Figma (node 2852:7175)

### Matches (no drift)

| Aspect | Figma | Code | OK |
|---|---|---|---|
| Sheet top radius | 16 | `BottomSheetSurface` 16 | ✓ |
| Read bar: Mix pill | outline, h56, r16, border 1.5 `#1d1f23` | `PillButton variant="outline"` h56 r... see note | ⚠ radius |
| Read bar: Mix trailing icon | pin 📌 24 | `Icons.Remix` (pin) 20, `figmaAction` | ✓ visual |
| Read bar: Less used label | `text/danger/base` #c0392b (always) | `figmaAction` default → #c0392b only when active | ⚠ see D1 |
| Read bar: Trash icon | `icon/danger/base` #c0392b, 24 | `Icons.Trash` 20, `figmaItemDetailDanger` #c0392b | ✓ color |
| Read bar: Change | text pill, `text/neutral/base` #1d1f23, 24 | `figmaAction` (#272A32) | ⚠ see D2 |
| Color dot | 24 (`dimension/24`) | `colorDot` 24×24 r12 | ✓ |
| Name row | present, read-only value | present, read-only `DividerRow` | ✓ |
| Edit bar | `[Cancel]` text r100 h56 + `[Save]` primary r16 h56, gap 16 | `editCancelButton` h56 r100 + `editSaveButton` r16, gap 16 | ✓ |
| Save bg / label | `#1d1f23` / `#f2efec` | `filled` → `figmaAction` / `white` | ⚠ see D3 |
| Edit pencil on rows | 24, `name="edit"` | `Icons.Edit` 18×18, `figmaTextDark` | ⚠ size |
| Row label type | Inter Regular 14/20 | `interBodySm` | ✓ |
| More/Less/Edit type | Inter Medium 12/16, `#070707` | `uacBodyXsMedium` `figmaTextDark` #070707 | ✓ |

### Mismatches called out (Figma-value vs code-value)

**M1 — "Less used" / "Change" / Mix label & icon use `figmaAction` (#272A32),
Figma uses `text/neutral/base` (#1d1f23).**
`figmaAction = #272A32`, Figma neutral/base = `#1d1f23`. This is a small
(near-black vs near-black) but real token mismatch. The "Mix with this" label,
"Change" label+icon, and the *inactive* "Less used" label all render
`#272A32` in code where Figma specifies `#1d1f23` / `#070707` for the icons.
- Severity: **LOW** (visually ~imperceptible; both are dark neutrals).
- Route: mobile-dev — but per token-drift policy, do NOT patch the literal.
  This is the app-wide `figmaAction` token standing in for Figma's
  `text/neutral/base`. If the CEO wants exact `#1d1f23`, run `figma-theme-sync`
  to classify (DRIFT vs intentional alias) and decide once in `theme.ts`.

**M2 — "Less used" label color is conditional in code; Figma shows it red by
default in the read frame.**
In Figma read frame `2852:14557`, the "Less used" label is `text/danger/base`
`#c0392b` *as drawn*. In code, `lessUsedText` is `figmaAction` and only turns
`figmaItemDetailDanger` (#c0392b) when `usage_frequency === 'LESS_USED'`.
- This is almost certainly **correct product behavior** (the red is the
  *active/toggled* state; the Figma frame just happens to depict an item that
  is already demoted). But it is a visual delta vs the static frame.
- Severity: **LOW–MEDIUM** (depends on CEO intent for the resting state).
- Route: confirm with CEO whether "Less used" is red at rest or only when
  active. Code's interpretation (red = active) is the sensible one.

**M3 — Edit pencil rendered at 18×18; Figma = 24×24.**
`renderDetailRow` renders `Icons.Edit width={18} height={18}`; Figma pencil is
`size-[24px]`. Same for the inline color-dot edit affordance.
- Severity: **LOW**. Route: mobile-dev — bump to 24 to match, or confirm 18 is
  an intentional density choice.

**M4 — Mix pill radius.** Figma Mix button content radius = 16 (`rounded-[16px]`),
but `PillButton`'s `pillBase` is `borderRadius: 100` and the screen overrides
only `alignSelf` on `mixPill` (no radius override). So the Mix pill renders as
a **fully-rounded 100 pill**, while Figma draws it at **radius 16** (rounded
rectangle).
- Severity: **MEDIUM** — this is a visible shape difference (stadium vs
  rounded-rect) on the most prominent read-mode CTA.
- Route: **mobile-dev** — add `borderRadius: 16` to `styles.mixPill` (or a
  `radius` prop on `PillButton`) to match Figma. **This is the one mismatch I'd
  fix before merge.**

**Non-issues confirmed:**
- No leftover text glyphs (`<`, `x`, `↻`) — all icons are SVG components.
- Color dot is 24 (not 18; the 18 is only the *picker option* dot, which is a
  separate, smaller list affordance — acceptable).
- Name row present and read-only (matches the edit frame, which shows Name with
  a pencil but the value as static text; free-text edit is correctly deferred).
- Danger red `#c0392b` correctly added as `figmaItemDetailDanger` and used for
  Trash + active Less-used. `auxi-lint-tokens.sh` would not flag it (it is a
  named token, not an inline literal).

---

## Pass 3 — on-sim screenshots: DEFERRED

Not run this dispatch — the app is not built/running on a simulator (per task
constraints; I did not boot the sim or run a native build). No `mcp-doctor.sh`
pre-flight was run because no mobile-mcp calls were made.

**To complete Pass 3 later** (≤4 surfaces, save to
`auxi/docs/qa-findings/screenshots/2026-06-10/`):
1. `qa-ui-item-detail-read.png` — read mode (Mix pill shape M4, Change/Less
   used colors M1/M2).
2. `qa-ui-item-detail-read-more.png` — expanded (Color dot 24, Fit row).
3. `qa-ui-item-detail-edit.png` — edit mode bar [Cancel][Save] + row pencils
   (M3 size).
4. `qa-ui-item-detail-edit-catalog.png` — catalog item (Trash hidden, explainer).

Re-run Pass 3 after `./scripts/qa-boot.sh` once the build lands.

---

## The 3 deliberate design calls — flagged for CEO confirmation (ESCALATE)

These are intentional, well-reasoned implementation decisions. They are NOT
defects, but they are designer-domain and need the CEO's yes/no:

1. **5 Figma mock fields OMITTED** (Energy, Label, Material, Occasion, Purchase
   Date). No backend contract in `WardrobeAttributeUpdate`. Code ships only the
   contract-backed rows (Name read-only, Type, Style, Color, Fit). Correct
   "don't invent backend" call — **confirm the CEO is OK shipping the detail
   screen without these 5 rows**, or file BE work to add them.

2. **Name row is READ-ONLY** even in edit mode (Figma shows a pencil on Name).
   `name` IS in the contract, but the picker only supports enumerations, not
   free text. Code renders Name as static. **Confirm read-only Name is
   acceptable for now**, or schedule a text-input picker.

3. **Danger red = `#c0392b`** (new `figmaItemDetailDanger` token) rather than
   reusing the app's existing `figmaRed #CC4C3E` / `uacTextDangerBase #bb251a`.
   Matches Figma `text/danger/base` exactly (fidelity-first). **Confirm the CEO
   wants the screen-specific exact red** vs unifying on one app red (which
   would be a `figma-theme-sync` decision affecting other screens).

---

## Routing summary

| Finding | Severity | Route | Action |
|---|---|---|---|
| M4 Mix pill radius 100 vs Figma 16 | MEDIUM | mobile-dev | Add `borderRadius: 16` to `mixPill` |
| M2 "Less used" resting color | LOW–MED | CEO | Confirm red-at-rest vs red-when-active |
| M1 `figmaAction` vs `#1d1f23` neutral | LOW | mobile-dev / theme-sync | Decide token once in `theme.ts` (don't patch literal) |
| M3 Edit pencil 18 vs 24 | LOW | mobile-dev | Bump to 24 or confirm |
| Extraction: `icon_remix` viewBox 12 vs 24 + name | LOW | mobile-dev | Optional rename/normalize |
| 3 deliberate calls | — | CEO | Confirm omit-fields / read-only Name / screen red |

---

## Maestro flows authored (behavioral, testID-based)

All under `auxi/maestro/flows/`, added to `maestro/README.md` inventory.
Authored — **not executed** (execution is qa-mobile's job; needs a booted sim).

- `wardrobe/item-detail-open.yaml` — open journey, asserts READ-mode bar
  (Mix + Change present, Save/Cancel absent).
- `wardrobe/item-detail-edit-save.yaml` — enter edit → change Fit via picker →
  Save → returns to read-mode bar. Asserts state transition, not backend value.
- `wardrobe/item-detail-edit-cancel.yaml` — enter edit → stage Fit draft →
  Cancel → discards + exits, no PATCH.
- `_shared/open-first-wardrobe-item.yaml` — shared nav sub-flow (Home →
  sidebar → Wardrobe → first tile), used by all 3.

Self-review: every interaction targets `id:` (verified all testIDs exist in
`ItemDetailScreen.tsx`); every state change has an assert; no randomized-data
assertions; no screenshots/OCR; secrets via env; shared setup factored to
`_shared/`. Tags include `regression`.

### testID gaps filed → mobile-dev

1. `WardrobeScreen.tsx` — no stable screen-root testID; tiles use
   backend-dynamic `wardrobe-item-<id>`. Flows tap via regex `wardrobe-item-.*`
   + `index: 0`. Proposed: `wardrobe-grid-root` + optional `wardrobe-item-first`.
2. `ItemDetailScreen.tsx` — no screen-root testID. Flows use `item-detail-mix-btn`
   as the ready-signal. Proposed: `item-detail-screen-root`.

### Seed caveat for qa-mobile

`item-detail-edit-save` / `-edit-cancel` require the **first wardrobe tile to be
a NON-catalog (editable) item** — the Edit link + Change button are hidden for
common / `USR_*` clone items. If the QA account's first tile is a catalog item,
the `item-detail-change-btn` tap fails fast (correct signal, not a flow bug).
Seed a user-owned item first, or extend the open sub-flow to skip catalog tiles.

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Pass 1 + Pass 2 complete; implementation matches Figma read/edit frames at token+layout level. One MEDIUM visual fix (M4 Mix pill radius 100 vs Figma 16) + minor LOW deltas; 3 deliberate scope calls need CEO sign-off. Pass 3 sim screenshots deferred (no build running). · **Verdict:** PASS-with-concerns → ESCALATE (CEO confirms the 3 deliberate calls; mobile-dev fixes M4). · **Maestro flows:** `auxi/maestro/flows/wardrobe/item-detail-open.yaml`, `auxi/maestro/flows/wardrobe/item-detail-edit-save.yaml`, `auxi/maestro/flows/wardrobe/item-detail-edit-cancel.yaml`, `auxi/maestro/flows/_shared/open-first-wardrobe-item.yaml`
**Concerns/Blockers:** Pass 3 deferred (sim not booted — re-run after qa-boot.sh). `item-detail-edit-*` flows need a non-catalog seed item. M4 (Mix pill radius) should be fixed before merge.
