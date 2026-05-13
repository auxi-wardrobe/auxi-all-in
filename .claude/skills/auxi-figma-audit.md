---
name: auxi-figma-audit
description: 3-pass Figma design audit for the Auxi RN app. Given a Figma URL + target screen, runs Pass 1 (Figma deep extraction), Pass 2 (code vs spec comparison), Pass 3 (visual screenshot verification), then loops until all HIGH/MEDIUM findings are resolved. Use for PR review and design drift detection. Outputs findings to auxi/docs/qa-findings/.
---

# Auxi Figma Design Audit — 3-Pass Protocol

## When to use
- **PR review**: mobile-dev pushes a screen implementation → run before merge
- **Design drift audit**: periodic check of existing screens vs current Figma

## Required inputs
- Figma URL with node ID for the target screen/component
- Target screen name (e.g., `HomeScreen`)
- Source file paths (e.g., `auxi/src/screens/HomeScreen.tsx`)

---

## Pass 1 — Figma Deep Extraction

Use Figma MCP tools in this order (do NOT skip steps):

```
1. get_metadata(fileKey, nodeId)   → node tree, sizes, parent/child hierarchy
2. get_screenshot(fileKey, nodeId) → reference PNG (save for Pass 3)
3. get_variable_defs(fileKey)      → all tokens: colors, spacing, radius, fonts
4. get_design_context(fileKey, nodeId) → per-component specs, variants, layout
```

For each node, capture every property:

| Category | Properties to extract |
|---|---|
| Layout | layoutMode, paddingTop/Right/Bottom/Left, gap, alignItems, justifyContent |
| Size | width, height, layoutSizingHorizontal/Vertical (FIXED/HUG/FILL) |
| Visual | fills (with token reference), strokes, cornerRadius (per corner if uneven) |
| Effects | DROP_SHADOW (x, y, blur, spread, color, opacity) |
| Typography | fontFamily, fontWeight, fontSize, lineHeight, letterSpacing, textCase |
| Icons | name, width × height |
| States | list all variants: default, pressed, disabled, loading, error |

**Output — spec table (required before Pass 2):**

| Element | Property | Figma Value | Token |
|---|---|---|---|
| Screen container | paddingHorizontal | 16 | spacing/16 |
| Title | fontSize | 24 | font/heading-lg |
| CTA button | backgroundColor | #1A73E8 | color/primary |
| Card | cornerRadius | 12 | radius/md |
| Card | DROP_SHADOW | y:2, blur:8, rgba(0,0,0,0.08) | effect/shadow-card |

Flag any value that has no token (one-off literal) — ask designer before Pass 2.

---

## Pass 2 — Code vs Spec Comparison

Read the target TSX/stylesheet files. For each property in the spec table, compare line-by-line.

### What to check

**Colors**
- Grep for literal hex: `grep -n "#[0-9a-fA-F]" <file>`
- Every color must use `theme.colors.*` — no literals

**Spacing**
- Grep: `grep -n "padding\|margin\|gap" <file>`
- Values must match spec ±0 (not rounded — ask designer if Figma uses off-scale values)

**Typography**
- Check: `fontSize`, `fontWeight`, `lineHeight`, `fontFamily` per Text element
- Must match spec exactly — `fontWeight: '500'` vs `'600'` is a real bug

**Icons**
- Check file exists: `Glob auxi/src/assets/icons/icon_<name>.svg`
- Check rendered size matches spec (width/height prop in JSX)
- Check fill is `currentColor` (not hardcoded hex in SVG)

**Layout**
- Check `flexDirection`, `alignItems`, `justifyContent`, `gap`
- Check padding values match spec on all 4 sides

**Border radius**
- Check `borderRadius` value per element — uniform vs per-corner

**Shadows**
- Check `shadowColor`, `shadowOffset`, `shadowOpacity`, `shadowRadius` (iOS)
- Check `elevation` (Android)

**States**
- Check pressed state exists: `Pressable style={({ pressed }) => ...}`
- Check disabled state: visual diff when `disabled` prop true
- All states from Figma variant set must be implemented

### Discrepancy log format

Append each issue to the findings table:

| # | Pass | Screen | Element | Property | Expected | Actual | Severity |
|---|---|---|---|---|---|---|---|
| 1 | 2 | HomeScreen | CTA | backgroundColor | theme.colors.primary | '#1A73E8' | HIGH |
| 2 | 2 | HomeScreen | Title | fontSize | 24 | 22 | MEDIUM |
| 3 | 2 | HomeScreen | Card | gap | 12 | 8 | MEDIUM |

**Severity scale:**

| Severity | Definition |
|---|---|
| HIGH | Wrong color (brand/accessibility), size diff >4px, wrong token usage, missing state |
| MEDIUM | Spacing diff 1-4px, wrong font weight/lineHeight, icon size wrong |
| LOW | Cosmetic rounding, negligible diff (<1px), non-blocking visual noise |

---

## Pass 3 — Visual Verification

### Setup
```
mobile_list_available_devices → confirm a Booted simulator
mobile_launch_app
[navigate to target screen via mobile_click_on_screen_at_coordinates or testID]
mobile_take_screenshot → actual PNG
```

### Visual checklist (compare actual PNG vs Figma reference from Pass 1)

- [ ] Colors match overall (especially text, surface, accent, borders)?
- [ ] Icon names and sizes correct?
- [ ] Vertical/horizontal spacing rhythm matches?
- [ ] Font size and weight visually correct?
- [ ] Corner radii match?
- [ ] Shadows render correctly?
- [ ] Pressed state renders as designed?
- [ ] Disabled state renders correctly?
- [ ] Layout holds at 390px width?
- [ ] No unexpected overflow or clipping?

### What Pass 3 catches that Pass 2 misses
- Parent container causing unexpected child alignment
- Shadows appearing differently (iOS elevation vs design shadow params)
- Text truncation that code doesn't reveal
- Responsive layout issues from flex interactions
- Hidden layer accidentally showing

Add visual findings to the same discrepancy table with `Pass: 3`.

---

## Re-check loop

After mobile-dev applies fixes:
1. **Re-run Pass 2** on the changed files only (diff check)
2. **Re-run Pass 3** with fresh simulator screenshot
3. Update `Fixed` column in report
4. Repeat until all HIGH findings resolved and MEDIUM count approved

**Minimum: 2 total rounds** (initial audit + one re-check after fixes).
**Merge gate: 0 HIGH open, MEDIUM reviewed by mobile-dev + sign-off.**

---

## Findings report

Save to: `auxi/docs/qa-findings/<YYYY-MM-DD>-figma-audit-<screen-slug>.md`

```markdown
# Figma Audit: <ScreenName>

**Date:** <YYYY-MM-DD>
**Figma URL:** <url>
**Source files:** <list>
**Auditor:** qa-ui

## Summary
- Pass 2 findings: X (H:n / M:n / L:n)
- Pass 3 findings: Y (H:n / M:n / L:n)
- Blocking (HIGH): N — must resolve before merge

## Findings

| # | Pass | Element | Property | Expected | Actual | Severity | Fixed |
|---|---|---|---|---|---|---|---|
| 1 | 2 | ... | ... | ... | ... | HIGH | [ ] |

## Re-check log

| Round | Date | HIGH open | MEDIUM open | Result |
|---|---|---|---|---|
| 1 | ... | N | N | Changes requested |
| 2 | ... | 0 | N | ✅ Pass |

## Unresolved questions
- (list any one-off literals or ambiguities found in Pass 1)
```

---

## Team composition

| Trigger | Action |
|---|---|
| PR has Figma URL | Run 3-pass audit → report → route HIGH/MEDIUM to mobile-dev |
| PR has no Figma URL | Skip compare mode — run Maestro behavioral flows only |
| mobile-dev fixes ready | Re-run Pass 2+3 on changed files, update report |
| 0 HIGH open + MEDIUM signed off | Approve design gate, ready to merge |
| Pass 1 has one-off literals | Ask designer (CEO) before Pass 2 — do NOT assume |
