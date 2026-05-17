---
name: auxi-mobile-designer
description: Dedicated mobile designer skill for the Auxi RN app. Use when the task involves design work BEFORE implementation — reviewing screens in Figma, auditing design system token coverage, producing developer-ready handoff specs, checking cross-screen consistency, or proposing design changes to the CEO. Covers the design phase, not the code phase. Always pairs with figma-design-extraction for deep extraction and produces a HANDOFF.md that mobile-dev consumes. Triggered when a task says "review this design", "design audit", "check consistency", "prepare handoff", or when the user explicitly asks for designer-perspective feedback on a Figma file before any code is written.
---

# Auxi Mobile Designer

The designer is the CEO. This skill operates in the design space — before
implementation begins. Its output is a spec that mobile-dev can consume
without guessing.

## Scope

| In scope | Out of scope |
|---|---|
| Reviewing Figma screens for design quality | Writing RN code (→ mobile-dev) |
| Auditing design system completeness | Auditing code vs Figma (→ auxi-figma-audit) |
| Producing handoff specs for mobile-dev | QA execution (→ qa-mobile) |
| Cross-screen visual consistency checks | Backend API contracts (→ tech-lead) |
| Documenting interactions and motion intent | Deploying or releasing |
| Flagging off-token values to the CEO | |

---

## Figma MCP toolbox (designer mode)

| Tool | Designer use |
|---|---|
| `get_metadata` | Map every frame in the file — screens, components, variants |
| `get_screenshot` | Visual reference — capture all screens you're reviewing |
| `get_variable_defs` | Full token inventory — find gaps between Figma vars and `theme.ts` |
| `get_design_context` | Deep spec per component — layout, spacing, variant tree |
| `search_design_system` | Check what components exist in the shared library |

Start every design session with a **full-file mapping** before diving into
any single screen:

```
1. get_metadata(fileKey)           → page list, top-level frames, component sets
2. get_variable_defs(fileKey)      → full token inventory
3. get_screenshot (each screen)    → visual overview
```

Don't skip the token inventory. A missing token discovered mid-review
is slower than finding it upfront.

---

## Task 1 — Design system audit

Before reviewing any screen, check that the design system is healthy.

### Token coverage check

Pull `get_variable_defs` and compare against `auxi/src/theme/theme.ts`.

Build a coverage table:

| Figma variable | Token path | In theme.ts? | Action |
|---|---|---|---|
| color/primary | colors.primary | ✅ | — |
| color/surface/card | colors.surface.card | ❌ | Add to theme |
| spacing/20 | spacing[20] | ❌ | Flag to CEO — off-scale? |
| font/label-sm | text.labelSm | ✅ | — |

**Decision rule:**
- Missing color/font/radius → add to `theme.ts`, same semantic name as Figma var
- Off-scale spacing (not on 4/8/12/16/24/32 grid) → flag to CEO, don't silently add
- Duplicate tokens with different names → flag to CEO for cleanup

### Component library inventory

Use `search_design_system` + `get_metadata` to list all component sets (COMPONENT_SET nodes).

For each:
- Name and variant axes (e.g., `Button: size × kind × state`)
- Status: documented in Figma / implemented in `auxi/src/components/`
- Gaps: variants defined in Figma but not in RN code

Output format:

```
Component: Button
Figma variants: size=[sm,md,lg] × kind=[primary,secondary,ghost] × state=[default,pressed,disabled]
RN status: size=[md,lg] ✅ | sm ❌ MISSING
Action: Add small variant to auxi/src/components/Button.tsx
```

---

## Task 2 — Screen design review

When reviewing a Figma screen for design quality, run three checks.

### Check A — Visual hierarchy

Read the frame with `get_design_context` and `get_screenshot`. Assess:

- [ ] Clear primary action (one most important CTA per screen)
- [ ] Font scale creates clear heading/body/label hierarchy
- [ ] Color contrast: text on background (WCAG AA minimum 4.5:1)
- [ ] Whitespace rhythm — consistent padding / gap between sections
- [ ] Icons are the right family, size, and visual weight

### Check B — Cross-screen consistency

Compare the current screen against other screens in the same file (`get_screenshot` for each):

- [ ] Navigation bar style matches all screens
- [ ] Card/list item padding consistent across screens
- [ ] Button styles consistent (same shadow, same radius, same font weight)
- [ ] Heading styles consistent (same font/size/weight per level)
- [ ] No one-off colors that diverge from the palette

Flag inconsistencies as:
```
Inconsistency: Card gap
  → HomeScreen: gap 16
  → WardrobeScreen: gap 12
  Decision needed: standardise at 16 (CEO call)
```

### Check C — Interaction completeness

For each interactive element, verify Figma shows all states:

| Element | Required states |
|---|---|
| Primary button | default, pressed, disabled, loading |
| Text input | default, focused, error, disabled, with-value |
| Toggle / switch | on, off, disabled |
| Selectable card/chip | unselected, selected, disabled |
| Navigation tab | inactive, active |
| Image / media | loading (skeleton), loaded, error |

Flag missing states: "CTA button: pressed state not in Figma — ask CEO before mobile-dev implements."

---

## Task 3 — Interaction and motion spec

For screens with transitions, gestures, or animations, document intent that
code cannot derive from static Figma:

```markdown
## Interactions

### Screen entry
- Animate from bottom (slide up 0.3s, ease-out)
- Background fade to 60% opacity overlay

### Outfit card press
- Scale down to 0.97 on press (duration: 120ms)
- Spring back on release (tension: 200, friction: 15)

### Swipe to dismiss
- Threshold: 30% of screen width → dismiss
- Below threshold: spring back to center
- Velocity-sensitive: fast swipe dismisses regardless of distance

### Empty state
- Lottie animation: "wardrobe-empty.json"
- Loop: yes (pause after 3 loops when not in focus)
```

If Figma uses a prototype to show the transition, describe it in text.
Mobile-dev cannot open Figma prototypes — they need the written spec.

---

## Task 4 — Handoff spec

Produce a HANDOFF.md that mobile-dev reads instead of the Figma URL.
This is your primary deliverable.

Save to: `auxi/docs/design-handoffs/<YYYY-MM-DD>-<screen-slug>-handoff.md`

### HANDOFF.md template

```markdown
# Design Handoff: <ScreenName>

**Date:** <YYYY-MM-DD>
**Figma URL:** <url>
**Designer:** auxi-mobile-designer
**Status:** Ready for implementation

---

## Screen summary

One paragraph describing the screen's purpose, the user's goal, and any
design decisions the developer should understand.

---

## Frames covered

| Frame | Figma node ID | Screenshot |
|---|---|---|
| Default state | 1:234 | [see Figma] |
| Empty state | 1:235 | [see Figma] |

---

## Token map

All values the implementation must use. No deviation without designer sign-off.

| Element | Property | Token | Value |
|---|---|---|---|
| Screen background | backgroundColor | colors.surface.default | #FAFAFA |
| Section title | fontSize | text.heading-md.size | 20 |
| Section title | fontWeight | text.heading-md.weight | 600 |
| Card container | padding | spacing[16] | 16 |
| Card container | gap | spacing[12] | 12 |
| Card | cornerRadius | radius.md | 12 |
| Card | shadow | effect.shadow-card | y:2 blur:8 rgba(0,0,0,0.08) |
| Primary CTA | backgroundColor | colors.primary | #1A73E8 |

New tokens added to theme.ts in this handoff:
- `colors.surface.card = #FFFFFF` (matches Figma var color/surface/card)

---

## Icons required

| Icon | Size | Fill | Exists? | Path |
|---|---|---|---|---|
| icon_heart | 24×24 | currentColor | ✅ | auxi/src/assets/icons/icon_heart.svg |
| icon_close | 20×20 | currentColor | ❌ NEW | export from Figma node 2:567 |

---

## Components to use / create

| Component | Status | Notes |
|---|---|---|
| `Button` (primary, lg) | ✅ exists | No changes needed |
| `OutfitCard` | ❌ new | Create auxi/src/components/OutfitCard.tsx |
| `EmptyState` | ✅ exists | Reuse, pass `illustration="wardrobe"` prop |

---

## States and variants

| Element | States | Implementation notes |
|---|---|---|
| OutfitCard | default, pressed (0.97 scale), selected (ring border) | `Pressable` with spring animation |
| Add CTA | default, loading (spinner replaces label), disabled | `disabled` prop + 40% opacity |

---

## Interactions

(See Task 3 format above — paste here)

---

## Responsive notes

- Designed at 390px (iPhone 15)
- Cards should flex to fill width at any viewport — no fixed widths
- Bottom CTA stays pinned to safe area on all devices

---

## Open questions for CEO

- [ ] Q1: Card long-press — show context menu or nothing?
- [ ] Q2: Skeleton loading vs spinner for image loading state?

---

## New theme.ts additions needed

\`\`\`ts
// Add to auxi/src/theme/theme.ts before implementation starts
colors: {
  surface: {
    card: '#FFFFFF',  // color/surface/card
  },
}
\`\`\`
```

---

## Routing to the right agent

| Situation | Route to |
|---|---|
| HANDOFF.md complete → start coding | mobile-dev |
| Code implementation done → verify fidelity | qa-ui (auxi-figma-audit) |
| Off-token value or missing state found | Ask CEO (user) BEFORE routing |
| New screen needs navigation registration | mobile-dev (always registers both type + route) |
| Design changes post-implementation | Update HANDOFF.md → notify mobile-dev |

---

## Anti-patterns

- Handing off a Figma URL without a spec — mobile-dev will guess and ship wrong
- Approving off-scale spacing without asking the CEO
- Silently adding one-off colors to `theme.ts` with made-up names
- Skipping cross-screen consistency check — alignment bugs compound
- Missing interaction spec for animated transitions — results in static flat UI
- Marking handoff "done" without a token map — forces mobile-dev to re-extract

---

## Checklist before marking handoff complete

- [ ] Full token map produced (every color, spacing, font, radius, shadow)
- [ ] All states documented for each interactive element
- [ ] Icon inventory complete (exists ✅ or new ❌ with Figma node ID)
- [ ] New `theme.ts` additions listed
- [ ] Interaction / motion spec written (or "no animations on this screen")
- [ ] Open questions for CEO listed
- [ ] Cross-screen consistency checked (no rogue one-off values)
- [ ] HANDOFF.md saved to `auxi/docs/design-handoffs/`
