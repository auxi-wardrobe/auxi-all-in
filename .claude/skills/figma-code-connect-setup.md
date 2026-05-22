---
name: figma-code-connect-setup
description: Map Figma components → RN code components via Figma Code Connect so the designer sees the RN primitive in the Figma inspector. Use when bootstrapping a new shared primitive in auxi/src/components/primitives/ or auxi/src/components/atoms/ that mirrors a Figma component.
---

# Figma Code Connect → Auxi RN primitives

## Why this exists

Designer (CEO) sees a `Button` component in Figma. Mobile-dev sees
`auxi/src/components/primitives/FigmaPrimitives.tsx` exporting `PillButton`,
plus `auxi/src/components/atoms/Button.tsx`. Two different components with
overlapping purpose. Designer doesn't know which to reference; mobile-dev
re-implements per screen.

Code Connect bridges this: the Figma component card shows
`auxi/src/components/primitives/FigmaPrimitives.tsx#PillButton` directly in
the Figma inspector. Designer + mobile-dev share the same map.

## When to invoke

- Introducing a new RN primitive that mirrors a Figma component
- When mobile-dev / designer disagree on "which RN component matches this
  Figma component"
- Quarterly sweep — verify all `primitives/` exports have Code Connect mappings

## Permission requirements

- Figma file `Auxi` write access (someone has to publish the mappings)
- Confirm with CEO/designer before adding mappings to a production Figma file
  — mappings show up in EVERY designer's inspector

## Procedure

### Step 1 — List candidate mappings

Walk `auxi/src/components/primitives/FigmaPrimitives.tsx` and
`auxi/src/components/atoms/`. For each export:

```bash
grep -E "^export (const|function) " \
  auxi/src/components/primitives/FigmaPrimitives.tsx \
  auxi/src/components/atoms/*.tsx
```

For each export, find its Figma counterpart via:

```
mcp__plugin_figma_figma__search_design_system (query: "<component name>")
```

Build a map:

| RN export | RN path | Figma component | Figma nodeId |
|---|---|---|---|
| `PillButton` | `auxi/src/components/primitives/FigmaPrimitives.tsx` | `Button/Pill` | `2852:14001` |
| `DividerRow` | `auxi/src/components/primitives/FigmaPrimitives.tsx` | `Row/Divider` | `2852:14123` |
| `TopIconButton` | `auxi/src/components/primitives/FigmaPrimitives.tsx` | `IconButton/Top` | `2850:16678` |
| `BottomSheetSurface` | `auxi/src/components/primitives/FigmaPrimitives.tsx` | `Sheet/Surface` | `2852:14228` |

Flag mismatches (RN component with no Figma counterpart, or Figma component
with no RN export) — those need either a primitive added or a Figma component
created.

### Step 2 — Suggest mappings (don't write yet)

```
mcp__plugin_figma_figma__get_code_connect_suggestions
```

This returns the tool's own best-guess matches. Reconcile with your map from
Step 1.

### Step 3 — Show the proposed map to CEO/designer

Save to `plans/<active-plan>/figma-code-connect-map-<YYYY-MM-DD>.md` with the
table from Step 1. CEO confirms / corrects before any write to Figma.

### Step 4 — Publish mappings to Figma (after CEO sign-off)

For each confirmed row:

```
mcp__plugin_figma_figma__add_code_connect_map (
  figmaNodeId: <Figma nodeId>,
  codeComponentPath: <RN path>,
  codeComponentName: <RN export>
)
```

OR batch via:

```
mcp__plugin_figma_figma__send_code_connect_mappings
```

### Step 5 — Verify in Figma

Open the Figma file → Inspect a mapped component → confirm the inspector
shows the RN component path.

### Step 6 — Document the map

Update `auxi/src/components/primitives/README.md` (create if missing) with the
mapping table so mobile-dev can grep:

```bash
grep -n "PillButton" auxi/src/components/primitives/README.md
# → file:line + Figma component name + Figma nodeId
```

## Output contract

End-of-turn line:
`Code Connect: N rows proposed · M sent to Figma · K conflicts → tech-lead`

## Do NOT

- Don't publish mappings without CEO sign-off — mappings appear in every
  designer's inspector.
- Don't map RN components that are NOT meant to be reused (one-off screen-
  specific components). Only map primitives + atoms + features that are
  intentionally shared.
- Don't override an existing Figma → code mapping silently. Use
  `get_code_connect_map` to read current state first.
- Don't map to a deprecated RN file (e.g., `_HomeScreen.tsx` legacy).
