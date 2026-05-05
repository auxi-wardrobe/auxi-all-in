# `qa-ui` Agent — Design

**Date**: 2026-05-05
**Owner**: duncan
**Status**: Approved, ready for implementation plan

## Goal

A new role-scoped agent dedicated to **visual fidelity QA** for the Auxi mobile app — alignment, spacing, icons, typography, colors, layout overflow. Pairs with the existing `qa-mobile` (functional flows) and `mobile-dev` (writes RN code) agents.

The trigger: the user has shipped many alignment + icon bugs, and the existing `qa-mobile` agent's prompt is structured around functional regression flows (login, onboarding, wardrobe upload), not pixel-level inspection. Splitting the concern keeps each agent's prompt tight and adds the right tools (Figma MCP) only where they're needed.

## Files to create

```
.claude/
├── agents/
│   └── qa-ui.md          # CREATE — agent definition (~80 lines)
└── skills/
    └── auxi-qa-ui.md     # CREATE — workflow skill (~150 lines)
```

Mirrors the existing pair (`qa-mobile.md` agent + `auxi-qa-test.md` skill).

## Agent definition (`.claude/agents/qa-ui.md`)

### Frontmatter

```yaml
---
name: qa-ui
description: Visual fidelity QA for the Auxi React Native app — alignment, spacing, icons, typography, colors, layout overflow. Compares against Figma and the Icons registry. Does NOT write production code — that's mobile-dev.
tools: Read, Bash, Grep, Glob, Write, Skill, mcp__claude_ai_Figma__get_design_context, mcp__claude_ai_Figma__get_screenshot, mcp__claude_ai_Figma__get_metadata, mcp__claude_ai_Figma__get_variable_defs, mcp__mobile-mcp__mobile_take_screenshot, mcp__mobile-mcp__mobile_save_screenshot, mcp__mobile-mcp__mobile_list_available_devices, mcp__mobile-mcp__mobile_list_apps, mcp__mobile-mcp__mobile_launch_app, mcp__mobile-mcp__mobile_get_screen_size, mcp__mobile-mcp__mobile_list_elements_on_screen, mcp__mobile-mcp__mobile_click_on_screen_at_coordinates, mcp__mobile-mcp__mobile_swipe_on_screen, mcp__mobile-mcp__mobile_press_button, mcp__mobile-mcp__mobile_open_url
---
```

Two tool families:
- **Figma MCP** — mirrors what `mobile-dev` already has (per `CLAUDE.md` agent matrix). Used in compare mode to fetch the design context.
- **mobile-mcp** — primary instrumentation for the iOS sim. `mobile_save_screenshot` writes screenshots directly to a path (replacing `xcrun simctl io booted screenshot`). `mobile_list_elements_on_screen` exposes the UI tree for inspection. The navigation tools (click / swipe / press / launch / open_url) let the agent reach screens without shelling out.

The agent does NOT get `Edit` / `NotebookEdit` — it reads RN source to find root cause but cannot ship fixes. It also doesn't get `mobile_install_app` / `mobile_terminate_app` (those belong to the boot script and `qa-mobile`'s kill-and-reopen flow respectively).

### Hard boundaries (in the prompt body)

- Reads code under `auxi/src/**` to localize root cause but does NOT modify it
- Scope = visual: alignment, spacing, icons, typography, colors, layout overflow
- NOT in scope: functional flows (`qa-mobile` owns those), backend issues (`backend-dev`), accessibility audits (separate concern), Android, performance/animation glitches
- Refuses to sign off without screenshots — "looks fine to me" is not evidence

## Two operating modes

### Sweep mode (default — when no Figma URL given)

1. Read project visual sources of truth:
   - `auxi/src/theme/` — palette, spacing scale, typography
   - `auxi/src/assets/icons/index.ts` — Icons registry (the canonical icon catalog)
2. Verify the iOS sim is already booted with the app installed (`xcrun simctl list devices booted` + `xcrun simctl listapps booted | grep <bundle-id>`). If not, instruct the user to run `./scripts/qa-boot.sh` first — the agent does NOT boot the stack itself (that takes 1-3 min and is `qa-boot.sh`'s job). Fail fast with the boot-script suggestion.
3. For each requested screen, navigate via mobile-mcp + WebDriverAgent, screenshot
4. Inspect screenshot + the screen's source file in `auxi/src/screens/<X>` — flag every issue against the checklist
5. Group findings by screen, file one report per screen with severity ratings

### Compare mode (when a Figma URL is provided)

1. `get_design_context` for the Figma node → reference image + design tokens
2. With the sim already booted (via `qa-boot.sh`), navigate to the corresponding screen, screenshot the actual render
3. Side-by-side analysis:
   - Alignment offsets (e.g., button text 4px below center vs Figma)
   - Missing or wrong icons (e.g., `Trash` shipped where `Edit` was specified)
   - Typography: weight, size, line height
   - Color drift (e.g., `#1A1A1A` shipped vs `theme.colors.foreground.primary` which resolves differently)
4. Each discrepancy = one finding with BOTH screenshots attached and the Figma node referenced

## Issue checklist (what qa-ui actively looks for)

| Category | Examples |
|---|---|
| **Alignment** | items not centered, uneven list spacing, off-center icons inside buttons, misaligned text baselines, list items not flush-left |
| **Spacing** | margin/padding wrong vs Figma or inconsistent vs sibling screens, gap between cards uneven, header padding asymmetric |
| **Icons** | wrong icon used (e.g. `Icons.Trash` where `Edit` was intended), missing/blank render, `temp_*` placeholder still shipping (the prefix is a giveaway — these should never reach prod), wrong size, wrong color (hardcoded hex instead of theme token) |
| **Typography** | wrong font weight (400 vs 600), wrong size, truncation that shouldn't happen, line height off, mixed font families on the same screen |
| **Colors** | hardcoded hex instead of theme token, wrong theme key (e.g. `text.primary` where `text.muted` was specified), contrast issue with the actual background |
| **Layout overflow** | text cut off, button text wraps to 2 lines, modal too tall for sim viewport, scroll content clipped behind the bottom nav |

## Output: bug-report format

Mirrors `qa-mobile`'s format (severity / repro rate / build SHA / device) but adds **mandatory** screenshot evidence and a "fix locus" line.

Findings land at:

```
auxi/docs/qa-findings/<YYYY-MM-DD>-ui-<slug>.md
```

The `ui-` prefix in the filename lets `mobile-dev` filter their queue (and `pm` filter Linear tickets) by the visual category.

Template:

```markdown
# <Short title>

**Severity**: blocker | critical | major | minor
**Repro rate**: X/N attempts
**Build**: <commit sha or branch>
**Device**: iOS Simulator <iPhone model + OS>
**Category**: alignment | spacing | icons | typography | colors | overflow

## Steps
1. Boot via `./scripts/qa-boot.sh`
2. Navigate to <screen>
3. ...

## Expected
<from Figma node + URL, OR from theme/Icons registry, OR from sibling screen>

## Actual
<screenshot path: auxi/docs/qa-findings/screenshots/YYYY-MM-DD/<slug>.png>

## Reference
- Figma: <URL with node id>
- OR Icons registry entry: `auxi/src/assets/icons/index.ts:<line>` (the icon that SHOULD be there)
- OR sibling screen for spacing comparison: <screenshot path>

## Suspected fix locus
`auxi/src/screens/<X>/<File>.tsx:<line>` — usually a `style` block, a `theme.X` reference, or an `Icons.X` import.

## Routing
- mobile-dev (visual fix)
- (escalate to designer via tech-lead if Figma intent is ambiguous)
```

## Workflow skill (`.claude/skills/auxi-qa-ui.md`)

Pairs with the agent — keeps the agent's prompt focused on role/boundaries while the skill carries the procedural detail (mobile-mcp navigation, screenshot capture, Figma comparison, finding template).

Skill content covers:
1. **Setup** — boot script invocation, mobile-mcp connect, screenshot directory convention
2. **Sweep procedure** — concrete sequence of mobile-mcp commands per screen
3. **Compare procedure** — Figma node fetch + sim screenshot side-by-side
4. **Theme + Icons registry references** — where the source-of-truth lives
5. **Finding template** — the markdown above, ready to copy
6. **Sign-off rule** — same as qa-mobile: evidence required, no fabrication

## Composition with existing agents

| When | Hand-off |
|---|---|
| `qa-ui` finds an alignment / icon / typography bug | Route to `mobile-dev` with file:line + screenshot |
| `qa-ui` finds a `temp_*` placeholder still shipping | Route to `mobile-dev` with "swap to final asset" note + Figma node if available |
| `qa-mobile` runs a flow that passes functionally but looks wrong | Hand off to `qa-ui` for the visual pass |
| `qa-ui` finds a Figma intent that's ambiguous (e.g., spacing not specified) | Escalate to `tech-lead` who pings the designer |
| Findings need to become Linear tickets | `pm` reads `auxi/docs/qa-findings/*ui-*.md` and creates tickets the same way as qa-mobile findings |

## Out of scope (deliberately)

- **A11y audits** — touch target size, contrast ratios, VoiceOver labels. Different specialty, would bloat the prompt. Future agent: `qa-a11y`.
- **Animation / transition glitches** — rare in this RN app, can be added to the checklist later if it becomes a pattern.
- **Performance** (jank, slow renders) — `mobile-dev`'s perf skill territory.
- **Cross-platform (Android)** — iOS-only per project conventions.
- **The Phosphor Icons migration** — separate task. The `qa-ui` agent uses the existing `Icons` registry as source-of-truth; if a Phosphor migration happens later, the registry just changes name, agent logic unchanged.
- **Auto-fixing visuals** — strict read-only on `auxi/src/**`. The agent doesn't ship code changes; it files findings.

## Acceptance criteria

The agent is "useful" when, given a request like *"qa-ui agent, audit Home and Wardrobe for visual bugs"*:

1. It boots the app (or detects an already-running boot), navigates both screens via mobile-mcp, captures screenshots — without fabricating results if the sim is unavailable.
2. It produces at least 2 finding files at `auxi/docs/qa-findings/<date>-ui-*.md`, each with: severity, mandatory screenshot path, fix locus pointing at a real file:line, and routing.
3. Given a Figma URL, it fetches the design context, takes a sim screenshot, and produces a comparison finding that cites the Figma node id.
4. It refuses to write to `auxi/src/**` (no production code edits).
5. It never claims a screen is "clean" without a screenshot at the assertion point.

## Open questions

None — all resolved during brainstorming:
- Sibling agent (not replace, not sub-mode) (A)
- Scope = B: alignment + spacing + icons + typography + colors + overflow (no a11y)
- Both sweep and compare modes (C)
- Phosphor library migration is a separate concern; agent uses existing `Icons` registry
