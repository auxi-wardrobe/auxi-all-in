---
name: figma-theme-sync
description: Pull Figma variable collections (colors, spacing, fonts, radius) and diff against auxi/src/theme/theme.ts to surface token drift. Use when mobile-dev or tech-lead suspects the codebase tokens no longer match the Figma source of truth, or before starting a screen that touches existing tokens.
---

# Figma → theme.ts sync

## Why this exists

Recurring qa-ui finding: app background `#F3F5F9` (cool blue-gray) vs Figma
`#f2efec` (warm cream). Font Poppins-Medium vs ArchivoNarrow/Manrope/Inter.
Hex literals scattered across screens.

Token drift compounds. Once a wrong token is in `theme.ts`, every screen
using it ships wrong. This skill catches drift mechanically before more
screens propagate it.

## When to invoke

- Before starting a screen that touches color/spacing/font tokens
- When qa-ui finding lists token mismatch
- Quarterly hygiene sweep (mobile-dev or tech-lead)
- After designer signals "design system updated in Figma"

## Procedure

### Step 1 — Pull Figma variables

You need Figma MCP read access. If not available in current session, escalate
to main session.

```
mcp__claude_ai_Figma__get_variable_defs (fileKey: <Auxi fileKey>)
```

Capture the full output. Group by collection:
- `color/*` (background, text, border, accent, etc.)
- `spacing/*` or `dimension/*`
- `font-family/*`, `font-weight/*`, `body/*`, `heading/*`
- `radius/*` or `border-radius/*`
- `effect/*` (shadows)

### Step 2 — Read theme.ts

```
Read /Users/nguyenminhduc/Desktop/wardrobe_project/auxi/src/theme/theme.ts
```

Walk every `colors.*`, `spacing.*`, `text.*`, `radius.*` key.

### Step 3 — Diff table

Produce a markdown table:

| Figma var | Figma value | theme.ts key | theme.ts value | Status |
|---|---|---|---|---|
| `background/primary/subtle_50` | `#f2efec` | `figmaBackground` | `#f2efec` | ✓ match |
| `background/primary/subtle_50` | `#f2efec` | `figmaSurfaceSoft` | `#F3F5F9` | ✗ DRIFT — wrong app background |
| `font-family/body` | `Poppins` | (no key) | — | ✗ MISSING — token absent |
| `border-radius/xl` | `12` | `figmaRadiusCard` | `16` | ✗ DRIFT |

Categorise:
- **DRIFT** — same semantic key, different value (highest priority — wrong on screens already)
- **MISSING** — Figma var has no theme.ts equivalent (mobile-dev added literal instead)
- **ORPHAN** — theme.ts key with no Figma var (legacy / dead — candidate for removal)
- **MATCH** — happy path

### Step 4 — Save diff report

```
plans/<active-plan or reports>/figma-theme-sync-<YYYY-MM-DD>.md
```

Append: list of affected screens for each DRIFT row (`grep -rn "figmaSurfaceSoft" auxi/src/screens`).

### Step 5 — Surface action items

For each DRIFT row, propose ONE of:
1. Fix `theme.ts` value to match Figma (preferred — single change, all screens benefit)
2. Rename `theme.ts` key + add new key with correct value (if both values genuinely needed)
3. Escalate to designer if Figma var itself looks wrong

Hand-off:
- **mobile-dev** — execute the theme.ts fix
- **qa-ui** — re-audit screens after fix
- **CEO** — if any Figma var change is needed

## Output contract

End-of-turn line:
`Figma vars: N total · M drift · K missing · L orphan · report at <path>`

## Do NOT

- Don't auto-rewrite theme.ts. Diff + propose, then hand off.
- Don't silently drop ORPHAN keys — they may still be referenced. Grep first.
- Don't add new Figma var → theme.ts without checking with designer that the
  semantic name carries over (e.g., `background/primary/subtle_50` should NOT
  become `figmaSurfaceSoft` — semantic name must match Figma).
